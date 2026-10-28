import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/test_harness.dart';
import 'supabase_service_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  Map<String, dynamic> ticket(
    String id, {
    String createdAt = '2026-10-01T00:00:00Z',
    String? assignedTo = 'user-2',
  }) =>
      {
        'id': id,
        'ticket_number': 'TKT-$id',
        'title': 'Ticket $id',
        'priority': 'high',
        'category': 'Bug',
        'status': 'open',
        'approval_status': 'pending',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'assigned_to': assignedTo,
        'created_at': createdAt,
      };

  test('ticket categories match the create_ticket tool enum', () async {
    final service = await signedInService();

    expect(service.getTicketCategories(), [
      'Bug',
      'Feature Request',
      'UI/UX',
      'Performance',
      'Documentation',
      'Security',
      'Other',
    ]);
  });

  group('getTickets', () {
    test('returns team tickets newest first with people attached', () async {
      backend.table('tickets').addAll([
        ticket('a', createdAt: '2026-01-01T00:00:00Z'),
        ticket('b', createdAt: '2026-05-01T00:00:00Z', assignedTo: null),
        {...ticket('c'), 'team_id': 'elsewhere'},
      ]);
      final service = await signedInService();

      final tickets = await service.getTickets();

      expect(tickets.map((t) => t['id']), ['b', 'a']);
      expect(tickets.first['creator']['full_name'], 'Ada');
      expect(tickets.first.containsKey('assignee'), isFalse);
      expect(tickets.last['assignee']['full_name'], 'Bob');
    });

    test('applies the assignment, status and priority filters', () async {
      backend.table('tickets').addAll([
        ticket('match', assignedTo: FakeBackend.userId),
        ticket('someone-else'),
        {
          ...ticket('closed', assignedTo: FakeBackend.userId),
          'status': 'closed'
        },
        {...ticket('low', assignedTo: FakeBackend.userId), 'priority': 'low'},
      ]);
      final service = await signedInService();

      final tickets = await service.getTickets(
        filterByAssignment: true,
        filterByStatus: 'open',
        filterByPriority: 'high',
      );

      expect(tickets.map((t) => t['id']), ['match']);
    });

    test('members can filter by assignment', () async {
      backend.table('users').first['role'] = 'member';
      backend.table('tickets').addAll([
        ticket('mine', assignedTo: FakeBackend.userId),
        ticket('theirs'),
      ]);
      final service = await signedInService();

      final tickets = await service.getTickets(filterByAssignment: true);

      expect(tickets.map((t) => t['id']), ['mine']);
    });

    test('returns nothing without a team or when the query fails', () async {
      backend.table('tickets').add(ticket('a'));
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['tickets'] = 500;
      expect(await service.getTickets(), isEmpty);

      backend.table('users').first['team_id'] = null;
      final teamless = await signedInService();
      expect(await teamless.getTickets(), isEmpty);
    });
  });

  group('createTicket', () {
    test('inserts an open pending ticket and refreshes the list', () async {
      final service = await signedInService();

      final result = await service.createTicket(
        title: 'Login fails',
        description: 'On Safari',
        priority: 'high',
        category: 'Bug',
        assignedToUserId: 'user-2',
      );

      expect(result['success'], isTrue);
      expect(backend.bodiesFor('POST', '/rest/v1/tickets').single, {
        'title': 'Login fails',
        'description': 'On Safari',
        'priority': 'high',
        'category': 'Bug',
        'status': 'open',
        'approval_status': 'pending',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'sync_to_github': false,
        'assigned_to': 'user-2',
      });
      expect(result['ticket']['title'], 'Login fails');
      // The list refresh after the insert.
      expect(backend.log.lastIndexOf('GET /rest/v1/tickets'),
          greaterThan(backend.log.indexOf('POST /rest/v1/tickets')));
      expect(backend.functionBodies('github-sync'), isEmpty);
    });

    test('syncs to GitHub when asked and returns the refreshed row', () async {
      backend.functions['github-sync'] = (body) {
        final row = backend
            .table('tickets')
            .firstWhere((t) => t['id'] == body['ticket_id']);
        row['github_sync_status'] = 'synced';
        row['gh_issue_url'] = 'https://github.com/acme/app/issues/1';
        return {'success': true};
      };
      final service = await signedInService();

      final result = await service.createTicket(
        title: 'Sync me',
        priority: 'low',
        category: 'Other',
        assignedToUserId: '',
        syncToGithub: true,
      );

      expect(result['success'], isTrue);
      expect(result['ticket']['github_sync_status'], 'synced');
      final insert =
          backend.bodiesFor('POST', '/rest/v1/tickets').single as Map;
      expect(insert['sync_to_github'], isTrue);
      expect(insert.containsKey('assigned_to'), isFalse);
      expect(
        backend.functionBodies('github-sync').single,
        {'ticket_id': result['ticket']['id']},
      );
    });

    test('refuses users without a team', () async {
      backend.table('users').first['team_id'] = null;
      final service = await signedInService();

      final result = await service.createTicket(
          title: 'x', priority: 'low', category: 'Bug');

      expect(result['error'], 'User not associated with a team');
    });

    test('reports an empty insert response and backend errors', () async {
      final empty = await signedInService(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/tickets')
            ? http.Response('[]', 201)
            : null,
      );
      expect(
        await empty.createTicket(title: 'x', priority: 'low', category: 'Bug'),
        {'success': false, 'error': 'Failed to create ticket'},
      );

      final failing = await signedInService();
      await failing.getCurrentUserProfile();
      backend.failures['tickets'] = 400;
      final result = await failing.createTicket(
          title: 'x', priority: 'low', category: 'Bug');
      expect(result['success'], isFalse);
    });
  });

  group('syncTicketToGithub', () {
    test('passes through a successful sync with the refreshed ticket',
        () async {
      backend.table('tickets').add(ticket('k1'));
      backend.functions['github-sync'] = (_) => {'issue_number': 7};
      final service = await signedInService();

      final result = await service.syncTicketToGithub('k1');

      expect(result['success'], isTrue);
      expect(result['status'], 200);
      expect(result['response'], {'issue_number': 7});
      expect(result['ticket']['id'], 'k1');
      expect(result.containsKey('error'), isFalse);
    });

    test('surfaces the function error message on failure', () async {
      backend.table('tickets').add(ticket('k1'));
      backend.functions['github-sync'] =
          (_) => throw FakeHttpError(502, {'error': 'GitHub is down'});
      final service = await signedInService();

      final result = await service.syncTicketToGithub('k1');

      expect(result['success'], isFalse);
      expect(result['status'], 502);
      expect(result['error'], 'GitHub is down');
      expect(result['ticket']['id'], 'k1');
    });

    test('uses a plain-text error body', () async {
      final service = await signedInService(
        intercept: (r) => r.url.path.endsWith('/github-sync')
            ? http.Response('rate limited', 429,
                headers: {'content-type': 'text/plain'})
            : null,
      );

      final result = await service.syncTicketToGithub('k1');

      expect(result['success'], isFalse);
      expect(result['status'], 429);
      expect(result['response'], {'error': 'rate limited'});
      expect(result['error'], 'rate limited');
      expect(result.containsKey('ticket'), isFalse);
    });

    test('falls back to the exception text when the body has no error',
        () async {
      backend.functions['github-sync'] =
          (_) => throw FakeHttpError(500, {'detail': 'nope'});
      final service = await signedInService();

      final result = await service.syncTicketToGithub('k1');

      expect(result['success'], isFalse);
      expect(result['error'], contains('500'));
    });

    test('still answers when the ticket refresh fails', () async {
      backend.functions['github-sync'] = (_) => {'ok': true};
      final service = await signedInService();
      backend.failures['tickets'] = 500;

      final result = await service.syncTicketToGithub('k1');

      expect(result['success'], isTrue);
      expect(result.containsKey('ticket'), isFalse);
    });

    test('reports a transport failure', () async {
      final service = await signedInService(
        intercept: (r) => r.url.path.endsWith('/github-sync')
            ? throw http.ClientException('offline')
            : null,
      );

      final result = await service.syncTicketToGithub('k1');

      expect(result['success'], isFalse);
      expect(result['error'], contains('offline'));
    });
  });

  group('ticket updates', () {
    test('status, priority, and assignee patches refresh the list', () async {
      backend.table('tickets').add(ticket('k1'));
      final service = await signedInService();

      expect(
        await service.updateTicketStatus(ticketId: 'k1', status: 'resolved'),
        {'success': true},
      );
      expect(
        await service.updateTicketPriority(ticketId: 'k1', priority: 'low'),
        {'success': true},
      );
      expect(
        await service.assignTicket(ticketId: 'k1', userId: FakeBackend.userId),
        {'success': true},
      );

      expect(backend.bodiesFor('PATCH', '/rest/v1/tickets'), [
        {'status': 'resolved'},
        {'priority': 'low'},
        {'assigned_to': FakeBackend.userId},
      ]);
      final row = backend.table('tickets').single;
      expect(row['status'], 'resolved');
      expect(row['priority'], 'low');
      expect(row['assigned_to'], FakeBackend.userId);
      expect(
          backend.log.where((l) => l == 'GET /rest/v1/tickets'), hasLength(3));
    });

    test('updates report backend errors', () async {
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['tickets'] = 500;
      expect(
        (await service.updateTicketStatus(
            ticketId: 'k', status: 's'))['success'],
        isFalse,
      );
      backend.failures['tickets'] = 500;
      expect(
        (await service.updateTicketPriority(
            ticketId: 'k', priority: 'p'))['success'],
        isFalse,
      );
      backend.failures['tickets'] = 500;
      expect(
        (await service.assignTicket(ticketId: 'k', userId: 'u'))['success'],
        isFalse,
      );
      backend.failures['tickets'] = 500;
      expect(
        (await service.updateTicketApproval(
            ticketId: 'k', approvalStatus: 'approved'))['success'],
        isFalse,
      );
    });

    test('updates that row-level security blocks report failure', () async {
      backend.table('tickets').add(ticket('k1'));
      final service = await signedInService(
        intercept: (r) => r.method == 'PATCH' ? http.Response('[]', 200) : null,
      );
      const blocked = {
        'success': false,
        'error': 'Ticket not found or permission denied',
      };

      expect(await service.updateTicketStatus(ticketId: 'k1', status: 'x'),
          blocked);
      expect(await service.updateTicketPriority(ticketId: 'k1', priority: 'x'),
          blocked);
      expect(await service.assignTicket(ticketId: 'k1', userId: 'u'), blocked);
      expect(
          await service.updateTicketApproval(
              ticketId: 'k1', approvalStatus: 'approved'),
          blocked);
      expect(backend.table('tickets').single['status'], 'open');
    });

    test('only admins can change approval', () async {
      backend.table('tickets').add(ticket('k1'));
      final admin = await signedInService();
      expect(
        await admin.updateTicketApproval(
            ticketId: 'k1', approvalStatus: 'rejected'),
        {'success': true},
      );
      expect(backend.table('tickets').single['approval_status'], 'rejected');

      backend.table('users').first['role'] = 'member';
      backend.sent.clear();
      final member = await signedInService();
      final result = await member.updateTicketApproval(
          ticketId: 'k1', approvalStatus: 'approved');
      expect(result['error'], 'Only admins can approve tickets');
      expect(writesTo('/rest/v1/tickets'), isEmpty);
    });
  });

  group('getTicketDetails', () {
    test('joins people and comments in order', () async {
      backend.table('tickets').add(ticket('k1'));
      backend.table('ticket_comments').addAll([
        {
          'id': 'c2',
          'ticket_id': 'k1',
          'user_id': 'user-2',
          'content': 'later',
          'created_at': '2026-10-05T00:00:00Z',
        },
        {
          'id': 'c1',
          'ticket_id': 'k1',
          'user_id': FakeBackend.userId,
          'content': 'earlier',
          'created_at': '2026-10-04T00:00:00Z',
        },
        {
          'id': 'c3',
          'ticket_id': 'k1',
          'user_id': null,
          'content': 'bot',
          'created_at': '2026-10-06T00:00:00Z',
        },
      ]);
      final service = await signedInService();

      final details = await service.getTicketDetails('k1');

      final t = details!['ticket'] as Map;
      expect(t['creator']['full_name'], 'Ada');
      expect(t['assignee']['full_name'], 'Bob');
      final comments = details['comments'] as List;
      expect(comments.map((c) => c['content']), ['earlier', 'later', 'bot']);
      expect(comments.first['user']['role'], 'admin');
      expect(comments.last['user'], isNull);
    });

    test('handles unassigned tickets and unknown ids', () async {
      backend
          .table('tickets')
          .add({...ticket('k1', assignedTo: null), 'created_by': null});
      final service = await signedInService();

      final details = await service.getTicketDetails('k1');
      expect(details!['ticket']['creator'], isNull);
      expect(details['ticket']['assignee'], isNull);
      expect(details['comments'], isEmpty);

      expect(await service.getTicketDetails('missing'), isNull);
    });

    test('a failing user lookup leaves the person empty', () async {
      backend.table('tickets').add(ticket('k1'));
      final service = await signedInService(
        intercept: (r) => r.method == 'GET' && r.url.path.endsWith('/users')
            ? http.Response('{"message":"down"}', 500)
            : null,
      );

      final details = await service.getTicketDetails('k1');

      expect(details!['ticket']['creator'], isNull);
    });
  });

  group('addTicketComment', () {
    test('stores the comment and returns its author', () async {
      final service = await signedInService();

      final result =
          await service.addTicketComment(ticketId: 'k1', content: 'On it');

      expect(result['success'], isTrue);
      expect(backend.bodiesFor('POST', '/rest/v1/ticket_comments').single, {
        'ticket_id': 'k1',
        'user_id': FakeBackend.userId,
        'content': 'On it',
      });
      expect(result['comment']['user']['full_name'], 'Ada');
    });

    test('reports an empty insert and backend errors', () async {
      final empty = await signedInService(
        intercept: (r) =>
            r.method == 'POST' && r.url.path.endsWith('/ticket_comments')
                ? http.Response('[]', 201)
                : null,
      );
      expect(await empty.addTicketComment(ticketId: 'k1', content: 'x'),
          {'success': false, 'error': 'Failed to add comment'});

      final failing = await signedInService();
      backend.failures['ticket_comments'] = 500;
      expect(
        (await failing.addTicketComment(
            ticketId: 'k1', content: 'x'))['success'],
        isFalse,
      );
    });
  });

  group('deleteTicket', () {
    test('removes the ticket', () async {
      backend.table('tickets').add(ticket('k1'));
      final service = await signedInService();

      expect(await service.deleteTicket('k1'), {'success': true});
      expect(backend.table('tickets'), isEmpty);
    });

    test('distinguishes blocked deletes from missing tickets', () async {
      backend.table('tickets').add(ticket('k1'));
      final service = await signedInService(
        intercept: (r) =>
            r.method == 'DELETE' ? http.Response('[]', 200) : null,
      );

      expect((await service.deleteTicket('k1'))['error'],
          startsWith('Permission denied'));
      expect((await service.deleteTicket('missing'))['error'],
          'Ticket not found or permission denied');
    });

    test('reports a backend error', () async {
      final service = await signedInService();
      backend.failures['tickets'] = 500;

      expect((await service.deleteTicket('k1'))['success'], isFalse);
    });
  });
}
