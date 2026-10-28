import 'package:ell_ena/screens/tickets/ticket_detail_screen.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'ticket_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  void seedTicket({
    String? assignedTo = 'user-2',
    String createdBy = 'user-2',
    String priority = 'high',
    String status = 'open',
    String approval = 'pending',
    Map<String, dynamic> extra = const {},
  }) {
    backend.table('tickets').add(ticketRow(
          assignedTo: assignedTo,
          createdBy: createdBy,
          priority: priority,
          status: status,
          approval: approval,
          extra: extra,
        ));
  }

  Future<PushedResult> openDetail(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    if (themeMode == ThemeMode.light) {
      return pumpPushed(tester, const TicketDetailScreen(ticketId: 'tk-1'));
    }
    await pumpApp(tester, const TicketDetailScreen(ticketId: 'tk-1'),
        themeMode: themeMode);
    await settle(tester);
    return PushedResult();
  }

  Future<void> chooseMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  testWidgets('shows the ticket, people, and comments in order',
      (tester) async {
    seedTicket();
    backend.table('ticket_comments').addAll([
      {
        'id': 'c2',
        'ticket_id': 'tk-1',
        'user_id': 'user-1',
        'content': 'Second look',
        'created_at': '2026-10-03T09:07:00Z',
      },
      {
        'id': 'c1',
        'ticket_id': 'tk-1',
        'user_id': 'user-2',
        'content': 'First look',
        'created_at': '2026-10-02T14:30:00Z',
      },
      {
        'id': 'c3',
        'ticket_id': 'other',
        'user_id': 'user-2',
        'content': 'Not this ticket',
        'created_at': '2026-10-02T14:30:00Z',
      },
    ]);

    await openDetail(tester);

    expect(find.text('TKT-001'), findsOneWidget);
    expect(find.text('Login crash'), findsOneWidget);
    expect(find.text('App crashes on login'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('Assigned to'), findsOneWidget);
    expect(find.text('Comments (2)'), findsOneWidget);
    expect(find.text('Not this ticket'), findsNothing);
    expect(find.text('2/10/2026 14:30'), findsOneWidget);
    expect(find.text('3/10/2026 9:07'), findsOneWidget);
    final first = tester.getTopLeft(find.text('First look')).dy;
    final second = tester.getTopLeft(find.text('Second look')).dy;
    expect(first, lessThan(second));
    // Not shown when nothing was requested from GitHub.
    expect(find.text('GitHub'), findsNothing);
  });

  testWidgets('chips follow the stored priority, status, and approval',
      (tester) async {
    seedTicket(priority: 'low', status: 'resolved', approval: 'approved');
    await openDetail(tester, themeMode: ThemeMode.dark);
    expect(find.text('LOW'), findsOneWidget);
    expect(find.text('RESOLVED'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('medium, in-progress, and rejected tickets render their chips',
      (tester) async {
    seedTicket(priority: 'medium', status: 'in_progress', approval: 'rejected');
    await openDetail(tester);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('REJECTED'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('unknown values fall back to neutral chips and defaults',
      (tester) async {
    backend.table('tickets').add(ticketRow(
          priority: 'urgent',
          status: 'blocked',
          approval: 'unknown',
          number: null,
          title: null,
          description: null,
          createdBy: 'ghost',
          assignedTo: null,
          extra: {'category': null},
        ));
    await openDetail(tester);

    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('BLOCKED'), findsOneWidget);
    expect(find.text('UNKNOWN'), findsOneWidget);
    expect(find.text('Ticket Details'), findsOneWidget);
    expect(find.text('Untitled Ticket'), findsOneWidget);
    expect(find.text('No description provided.'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    // An unknown creator has no profile to show.
    expect(find.text('Created by'), findsNothing);
    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Be the first to add a comment'), findsOneWidget);
  });

  testWidgets('a missing ticket shows the not-found page and a snackbar',
      (tester) async {
    await openDetail(tester);

    expect(find.text('Ticket not found'), findsOneWidget);
    expect(
      find.text(
          'The ticket may have been deleted or you do not have access to it.'),
      findsOneWidget,
    );
    expect(find.text('Failed to load ticket details'), findsWidgets);
  });

  testWidgets('adds a trimmed comment and ignores blank input', (tester) async {
    seedTicket();
    await openDetail(tester);

    await tester.tap(find.byTooltip('Send comment'));
    await settle(tester);
    expect(backend.bodiesFor('POST', '/rest/v1/ticket_comments'), isEmpty);

    await tester.enterText(find.byType(TextField), '  Repro on Android  ');
    await tester.tap(find.byTooltip('Send comment'));
    await settle(tester);

    expect(backend.bodiesFor('POST', '/rest/v1/ticket_comments').single, {
      'ticket_id': 'tk-1',
      'user_id': FakeBackend.userId,
      'content': 'Repro on Android',
    });
    expect(find.text('Repro on Android'), findsOneWidget);
    expect(find.text('Comments (1)'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('a failed comment keeps the text and reports the error',
      (tester) async {
    seedTicket();
    await openDetail(tester);

    backend.failures['ticket_comments'] = 500;
    await tester.enterText(find.byType(TextField), 'Lost comment');
    await tester.tap(find.byTooltip('Send comment'));
    await settle(tester);

    expect(find.textContaining('Failed to add comment:'), findsOneWidget);
    expect(find.text('Comments (0)'), findsOneWidget);
  });

  testWidgets('admins change status and priority from the menu',
      (tester) async {
    seedTicket();
    await openDetail(tester);

    await chooseMenu(tester, 'In Progress');
    expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').last,
        {'status': 'in_progress'});
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('Ticket status updated successfully'), findsOneWidget);
    await clearSnackBars(tester);

    await chooseMenu(tester, 'Low');
    expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').last,
        {'priority': 'low'});
    expect(find.text('LOW'), findsOneWidget);
    expect(find.text('Ticket priority updated successfully'), findsOneWidget);
  });

  testWidgets('the admin menu lists every status and priority', (tester) async {
    seedTicket();
    await openDetail(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    for (final label in const [
      'Change Status',
      'Open',
      'In Progress',
      'Resolved',
      'Change Priority',
      'High',
      'Medium',
      'Low',
      'Delete Ticket',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('failed status and priority updates report the error',
      (tester) async {
    seedTicket();
    await openDetail(tester);

    backend.failures['tickets'] = 500;
    await chooseMenu(tester, 'Resolved');
    expect(
        find.textContaining('Failed to update ticket status:'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    await clearSnackBars(tester);

    backend.failures['tickets'] = 500;
    await chooseMenu(tester, 'Medium');
    expect(find.textContaining('Failed to update ticket priority:'),
        findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
  });

  testWidgets('deleting asks first, then removes the ticket and pops true',
      (tester) async {
    seedTicket();
    final result = await openDetail(tester);

    await chooseMenu(tester, 'Delete Ticket');
    expect(
      find.text('Are you sure you want to delete this ticket? '
          'This action cannot be undone.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(backend.table('tickets'), hasLength(1));
    expect(result.popped, isFalse);

    await chooseMenu(tester, 'Delete Ticket');
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(backend.table('tickets'), isEmpty);
    expect(backend.log, contains('DELETE /rest/v1/tickets'));
    expect(result.popped, isTrue);
    expect(result.value, isTrue);
    expect(find.text('Ticket deleted successfully'), findsOneWidget);
  });

  testWidgets('a failed delete stays on the page with the error',
      (tester) async {
    seedTicket();
    final result = await openDetail(tester);

    backend.failures['tickets'] = 500;
    await chooseMenu(tester, 'Delete Ticket');
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.textContaining('Error deleting ticket:'), findsOneWidget);
    expect(result.popped, isFalse);
    expect(backend.table('tickets'), hasLength(1));
  });

  testWidgets('a member who created the ticket can only delete it',
      (tester) async {
    await resetInTest(tester, role: 'member');
    seedTicket(createdBy: FakeBackend.userId);
    await openDetail(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    expect(find.text('Delete Ticket'), findsOneWidget);
    expect(find.text('Change Status'), findsNothing);
    expect(find.text('Change Priority'), findsNothing);
  });

  testWidgets('a member viewing someone else\'s ticket gets no menu',
      (tester) async {
    await resetInTest(tester, role: 'member');
    seedTicket();
    await openDetail(tester);

    expect(find.text('Login crash'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('assigns an unassigned ticket from the member list',
      (tester) async {
    seedTicket(assignedTo: null);
    await openDetail(tester);

    await tester.tap(find.text('Assign'));
    await settle(tester);
    expect(find.text('Assign Ticket'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Team Member'), findsOneWidget);

    await tester.tap(find.text('Bob').last);
    await settle(tester);

    expect(backend.bodiesFor('PATCH', '/rest/v1/tickets').single,
        {'assigned_to': 'user-2'});
    expect(find.text('Ticket assigned successfully'), findsOneWidget);
    // Reloaded with the new assignee.
    expect(find.text('Assigned to'), findsOneWidget);
    expect(find.text('Assign'), findsNothing);
  });

  testWidgets('cancelling the assign dialog changes nothing', (tester) async {
    seedTicket(assignedTo: null);
    await openDetail(tester);

    await tester.tap(find.text('Assign'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Assign Ticket'), findsNothing);
    expect(backend.bodiesFor('PATCH', '/rest/v1/tickets'), isEmpty);
  });

  testWidgets('a failed assignment reports the error', (tester) async {
    seedTicket(assignedTo: null);
    await openDetail(tester);

    await tester.tap(find.text('Assign'));
    await settle(tester);
    backend.failures['tickets'] = 500;
    await tester.tap(find.text('Ada').last);
    await settle(tester);

    expect(find.textContaining('Failed to assign ticket:'), findsOneWidget);
  });

  testWidgets('people without a stored name show as Unknown', (tester) async {
    backend.table('users').add({
      'id': 'user-3',
      'full_name': null,
      'role': 'member',
      'team_id': 'elsewhere',
    });
    seedTicket(createdBy: 'user-3', assignedTo: 'user-3');
    backend.table('ticket_comments').add({
      'id': 'c1',
      'ticket_id': 'tk-1',
      'user_id': 'user-3',
      'content': 'Anonymous note',
      'created_at': '2026-10-02T14:30:00Z',
    });
    await openDetail(tester);

    // Creator, assignee, and commenter.
    expect(find.text('Unknown'), findsNWidgets(3));
    expect(find.text('?'), findsNWidgets(3));
    expect(find.text('Anonymous note'), findsOneWidget);
  });

  testWidgets('without a team the assign dialog has nobody to offer',
      (tester) async {
    backend.table('users').first['team_id'] = null;
    await SupabaseService().getCurrentUserProfile(forceRefresh: true);
    seedTicket(assignedTo: null);
    await openDetail(tester);

    await tester.tap(find.text('Assign'));
    await settle(tester);

    expect(find.text('No team members found'), findsOneWidget);
  });

  group('GitHub section', () {
    testWidgets('a synced ticket links to its issue', (tester) async {
      final launcher = mockUrlLauncher();
      seedTicket(extra: {
        'sync_to_github': true,
        'github_sync_status': 'synced',
        'gh_issue_url': 'https://github.com/acme/app/issues/12',
        'gh_issue_id': 12,
      });
      await openDetail(tester);

      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Synced to GitHub'), findsOneWidget);
      expect(find.text('Retry GitHub sync'), findsNothing);

      await tester.tap(find.text('View on GitHub (#12)'));
      await settle(tester);
      expect(find.text('Could not open GitHub issue'), findsNothing);
      expect(
        launcher.launchedUrls,
        ['https://github.com/acme/app/issues/12'],
      );
    });

    testWidgets('an issue link without an id still opens, and reports errors',
        (tester) async {
      seedTicket(extra: {
        'github_sync_status': 'synced',
        'gh_issue_url': 'https://github.com/acme/app/issues/13',
      });
      await openDetail(tester);

      // No platform implementation is registered, so launching fails.
      await tester.tap(find.text('View on GitHub'));
      await settle(tester);
      expect(find.text('Could not open GitHub issue'), findsOneWidget);
    });

    testWidgets('a pending sync shows progress without actions',
        (tester) async {
      seedTicket(extra: {
        'sync_to_github': true,
        'github_sync_status': 'pending',
      });
      await openDetail(tester);

      expect(find.text('GitHub sync in progress'), findsOneWidget);
      expect(find.text('Retry GitHub sync'), findsNothing);
    });

    testWidgets('an opted-in ticket that was never sent shows not synced',
        (tester) async {
      seedTicket(extra: {'sync_to_github': true});
      await openDetail(tester);

      expect(find.text('Not synced to GitHub'), findsOneWidget);
    });

    testWidgets('an ambiguous failure shows the cleaned error but no retry',
        (tester) async {
      seedTicket(extra: {
        'sync_to_github': true,
        'github_sync_status': 'failed',
        'github_sync_error': '[ambiguous_create] Issue may exist',
      });
      await openDetail(tester);

      expect(find.text('GitHub sync failed'), findsOneWidget);
      expect(find.text('Issue may exist'), findsOneWidget);
      expect(find.text('Retry GitHub sync'), findsNothing);
    });

    testWidgets('retrying a failed sync shows the refreshed ticket',
        (tester) async {
      seedTicket(extra: {
        'sync_to_github': true,
        'github_sync_status': 'failed',
        'github_sync_error': 'Repository not configured',
      });
      backend.functions['github-sync'] = (body) {
        final row = backend.table('tickets').single;
        row['github_sync_status'] = 'synced';
        row['github_sync_error'] = null;
        row['gh_issue_url'] = 'https://github.com/acme/app/issues/14';
        row['gh_issue_id'] = 14;
        return {'ok': true};
      };
      await openDetail(tester);
      expect(find.text('Repository not configured'), findsOneWidget);

      await tester.tap(find.text('Retry GitHub sync'));
      await settle(tester);

      expect(backend.functionBodies('github-sync').single,
          {'ticket_id': 'tk-1'});
      expect(find.text('GitHub sync updated'), findsOneWidget);
      expect(find.text('Synced to GitHub'), findsOneWidget);
      expect(find.text('View on GitHub (#14)'), findsOneWidget);
    });

    testWidgets('a failed retry shows the server error', (tester) async {
      seedTicket(extra: {
        'sync_to_github': true,
        'github_sync_status': 'failed',
      });
      backend.functions['github-sync'] =
          (_) => throw FakeHttpError(502, {'error': 'GitHub is unreachable'});
      await openDetail(tester);

      await tester.tap(find.text('Retry GitHub sync'));
      await settle(tester);

      expect(find.text('GitHub is unreachable'), findsOneWidget);
      expect(find.text('Retry GitHub sync'), findsOneWidget);
    });

    testWidgets('a retry for a ticket that vanished reloads and reports it',
        (tester) async {
      seedTicket(extra: {
        'sync_to_github': true,
        'github_sync_status': 'failed',
      });
      backend.functions['github-sync'] = (_) {
        backend.table('tickets').clear();
        return {'ok': true};
      };
      await openDetail(tester);

      await tester.tap(find.text('Retry GitHub sync'));
      await settle(tester);

      // No refreshed row came back, so the page reloads the details itself.
      expect(find.text('Failed to load ticket details'), findsWidgets);
      expect(
          backend.functionBodies('github-sync'), hasLength(1));
    });
  });
}
