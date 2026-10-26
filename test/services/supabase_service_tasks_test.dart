import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/test_harness.dart';
import 'supabase_service_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  Map<String, dynamic> task(
    String id, {
    String createdAt = '2026-10-01T00:00:00Z',
    String? assignedTo = 'user-2',
    String? ticketId,
  }) =>
      {
        'id': id,
        'title': 'Task $id',
        'status': 'todo',
        'approval_status': 'pending',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'assigned_to': assignedTo,
        'ticket_id': ticketId,
        'created_at': createdAt,
      };

  group('getTasks', () {
    test('returns the team tasks newest first with creator and assignee',
        () async {
      backend.table('tasks').addAll([
        task('old', createdAt: '2026-01-01T00:00:00Z'),
        task('new', createdAt: '2026-09-01T00:00:00Z', assignedTo: null),
        {...task('other-team'), 'team_id': 'team-2'},
      ]);
      final service = await signedInService();

      final tasks = await service.getTasks();

      expect(tasks.map((t) => t['id']), ['new', 'old']);
      expect(tasks.first['creator'],
          {'id': FakeBackend.userId, 'full_name': 'Ada', 'role': 'admin'});
      expect(tasks.first.containsKey('assignee'), isFalse);
      expect(tasks.last['assignee']['full_name'], 'Bob');
    });

    test('uses cached team members instead of looking users up', () async {
      backend
          .table('tasks')
          .add({...task('t1'), 'team_id': FakeBackend.teamId});
      final service = await signedInService();
      await service.loadTeamMembers(FakeBackend.teamId);
      backend.log.clear();

      final tasks = await service.getTasks();

      expect(tasks.single['assignee']['full_name'], 'Bob');
      // The profile read is the only user lookup; names come from the cache.
      expect(backend.log.where((l) => l == 'GET /rest/v1/users'), hasLength(1));
      expect(backend.log, contains('GET /rest/v1/tasks'));
    });

    test('shares one request between concurrent identical calls', () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      final results = await Future.wait([
        service.getTasks(filterByStatus: 'todo'),
        service.getTasks(filterByStatus: 'todo'),
      ]);

      expect(results[0], same(results[1]));
      expect(backend.log.where((l) => l == 'GET /rest/v1/tasks'), hasLength(1));
    });

    test('accepts assignment and due date filters, ignoring a bad date',
        () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      final assigned = await service.getTasks(
        filterByAssignment: true,
        filterByDueDate: '2026-10-01',
      );
      final badDate = await service.getTasks(filterByDueDate: 'not a date');

      expect(assigned.single['id'], 't1');
      expect(badDate.single['id'], 't1');
    });

    test('member filters by assignment without failing', () async {
      backend.table('users').first['role'] = 'member';
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      final tasks = await service.getTasks(filterByAssignment: true);

      expect(tasks, hasLength(1));
    });

    test('returns nothing when the user has no team', () async {
      backend.table('users').first['team_id'] = null;
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      expect(await service.getTasks(), isEmpty);
      expect(backend.log, isNot(contains('GET /rest/v1/tasks')));
    });

    test('returns nothing when the tasks query fails', () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['tasks'] = 500;

      expect(await service.getTasks(), isEmpty);
    });

    test('leaves out user info that cannot be loaded', () async {
      backend.table('tasks').add(task('t1', assignedTo: 'ghost'));
      final service = await signedInService();
      await service.getCurrentUserProfile();

      final tasks = await service.getTasks();

      expect(tasks.single.containsKey('assignee'), isFalse);
      expect(tasks.single['creator']['full_name'], 'Ada');
    });
  });

  group('createTask', () {
    test('inserts a pending todo for the team with optional fields', () async {
      final service = await signedInService();
      final due = DateTime.utc(2026, 11, 2, 9);

      final result = await service.createTask(
        title: 'Ship it',
        description: 'Before Friday',
        dueDate: due,
        assignedToUserId: 'user-2',
        ticketId: '  ticket-9  ',
      );

      expect(result['success'], isTrue);
      final body = backend.bodiesFor('POST', '/rest/v1/tasks').single as Map;
      expect(body, {
        'title': 'Ship it',
        'description': 'Before Friday',
        'status': 'todo',
        'approval_status': 'pending',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'assigned_to': 'user-2',
        'due_date': due.toIso8601String(),
        'ticket_id': 'ticket-9',
      });
      expect(result['task']['title'], 'Ship it');
      expect(backend.table('tasks'), hasLength(1));
    });

    test('leaves out blank assignee and ticket', () async {
      final service = await signedInService();

      await service.createTask(
        title: 'Plain',
        assignedToUserId: '',
        ticketId: '   ',
      );

      final body = backend.bodiesFor('POST', '/rest/v1/tasks').single as Map;
      expect(body.containsKey('assigned_to'), isFalse);
      expect(body.containsKey('ticket_id'), isFalse);
      expect(body.containsKey('due_date'), isFalse);
    });

    test('refuses users without a team', () async {
      backend.table('users').first['team_id'] = null;
      final service = await signedInService();

      final result = await service.createTask(title: 'x');

      expect(result, {
        'success': false,
        'error': 'User not associated with a team',
      });
      expect(backend.table('tasks'), isEmpty);
    });

    test('reports an empty insert response', () async {
      final service = await signedInService(
        intercept: (r) => r.method == 'POST' && r.url.path.endsWith('/tasks')
            ? http.Response('[]', 201)
            : null,
      );

      final result = await service.createTask(title: 'x');

      expect(result, {'success': false, 'error': 'Failed to create task'});
    });

    test('reports a backend error', () async {
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['tasks'] = 400;

      final result = await service.createTask(title: 'x');

      expect(result['success'], isFalse);
      expect(result['error'], contains('forced failure'));
    });
  });

  group('task updates', () {
    test('updateTaskStatus patches only the status', () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      final result =
          await service.updateTaskStatus(taskId: 't1', status: 'completed');

      expect(result, {'success': true});
      expect(backend.bodiesFor('PATCH', '/rest/v1/tasks'), [
        {'status': 'completed'}
      ]);
      expect(backend.table('tasks').single['status'], 'completed');
    });

    test('updateTaskStatus reports failures', () async {
      final service = await signedInService();
      backend.failures['tasks'] = 500;

      final result =
          await service.updateTaskStatus(taskId: 't1', status: 'completed');

      expect(result['success'], isFalse);
    });

    test('updateTaskTicket trims the id and clears blank ids', () async {
      backend.table('tasks').add(task('t1', ticketId: 'old'));
      final service = await signedInService();

      await service.updateTaskTicket(taskId: 't1', ticketId: ' new ');
      expect(backend.table('tasks').single['ticket_id'], 'new');

      await service.updateTaskTicket(taskId: 't1', ticketId: '  ');
      expect(backend.table('tasks').single['ticket_id'], isNull);

      await service.updateTaskTicket(taskId: 't1');
      expect(backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
          {'ticket_id': null});
    });

    test('updateTaskTicket reports failures', () async {
      final service = await signedInService();
      backend.failures['tasks'] = 500;

      final result = await service.updateTaskTicket(taskId: 't1');

      expect(result['success'], isFalse);
    });

    test('updateTaskApproval lets admins approve', () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      final result = await service.updateTaskApproval(
          taskId: 't1', approvalStatus: 'approved');

      expect(result, {'success': true});
      expect(backend.table('tasks').single['approval_status'], 'approved');
    });

    test('updateTaskApproval refuses members without writing', () async {
      backend.table('users').first['role'] = 'member';
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      final result = await service.updateTaskApproval(
          taskId: 't1', approvalStatus: 'approved');

      expect(result['error'], 'Only admins can approve tasks');
      expect(writesTo('/rest/v1/tasks'), isEmpty);
    });

    test('updateTaskApproval reports failures', () async {
      final service = await signedInService();
      await service.getCurrentUserProfile();
      backend.failures['tasks'] = 500;

      final result = await service.updateTaskApproval(
          taskId: 't1', approvalStatus: 'approved');

      expect(result['success'], isFalse);
    });
  });

  group('getTaskDetails', () {
    test('joins people, comments in order, and the linked ticket', () async {
      backend.table('tasks').add(task('t1', ticketId: 'k1'));
      backend.table('tickets').add({
        'id': 'k1',
        'ticket_number': 'TKT-1',
        'title': 'Crash',
        'team_id': FakeBackend.teamId,
      });
      backend.table('task_comments').addAll([
        {
          'id': 'c2',
          'task_id': 't1',
          'user_id': 'user-2',
          'content': 'second',
          'created_at': '2026-10-02T00:00:00Z',
        },
        {
          'id': 'c1',
          'task_id': 't1',
          'user_id': FakeBackend.userId,
          'content': 'first',
          'created_at': '2026-10-01T00:00:00Z',
        },
        {
          'id': 'c3',
          'task_id': 't1',
          'user_id': null,
          'content': 'system',
          'created_at': '2026-10-03T00:00:00Z',
        },
        {'id': 'cx', 'task_id': 'other', 'content': 'elsewhere'},
      ]);
      final service = await signedInService();

      final details = await service.getTaskDetails('t1');

      final t = details!['task'] as Map;
      expect(t['creator']['full_name'], 'Ada');
      expect(t['assignee']['full_name'], 'Bob');
      expect(t['ticket']['ticket_number'], 'TKT-1');
      final comments = details['comments'] as List;
      expect(comments.map((c) => c['content']), ['first', 'second', 'system']);
      expect(comments[1]['user']['full_name'], 'Bob');
      expect(comments[2]['user'], isNull);
    });

    test('leaves missing people and tickets empty', () async {
      backend.table('tasks').add({
        ...task('t1', assignedTo: 'ghost', ticketId: 'gone'),
        'created_by': 'ghost'
      });
      backend.table('task_comments').add({
        'id': 'c1',
        'task_id': 't1',
        'user_id': 'ghost',
        'content': 'boo',
      });
      final service = await signedInService();

      final details = await service.getTaskDetails('t1');

      final t = details!['task'] as Map;
      expect(t['creator'], isNull);
      expect(t['assignee'], isNull);
      expect(t['ticket'], isNull);
      expect((details['comments'] as List).single['user'], isNull);
    });

    test('returns null for an unknown task', () async {
      final service = await signedInService();

      expect(await service.getTaskDetails('missing'), isNull);
    });
  });

  group('addTaskComment', () {
    test('stores the comment and returns it with the author', () async {
      final service = await signedInService();

      final result =
          await service.addTaskComment(taskId: 't1', content: 'Looks good');

      expect(result['success'], isTrue);
      expect(backend.bodiesFor('POST', '/rest/v1/task_comments').single, {
        'task_id': 't1',
        'user_id': FakeBackend.userId,
        'content': 'Looks good',
      });
      expect(result['comment']['content'], 'Looks good');
      expect(result['comment']['user']['id'], FakeBackend.userId);
      expect(result['comment']['user']['full_name'], 'Ada');
    });

    test('reports an empty insert response', () async {
      final service = await signedInService(
        intercept: (r) =>
            r.method == 'POST' && r.url.path.endsWith('/task_comments')
                ? http.Response('[]', 201)
                : null,
      );

      final result = await service.addTaskComment(taskId: 't1', content: 'x');

      expect(result, {'success': false, 'error': 'Failed to add comment'});
    });

    test('reports a backend error', () async {
      final service = await signedInService();
      backend.failures['task_comments'] = 500;

      final result = await service.addTaskComment(taskId: 't1', content: 'x');

      expect(result['success'], isFalse);
    });
  });

  group('deleteTask', () {
    test('removes the task', () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService();

      expect(await service.deleteTask('t1'), {'success': true});
      expect(backend.table('tasks'), isEmpty);
    });

    test('explains a delete that row-level security blocked', () async {
      backend.table('tasks').add(task('t1'));
      final service = await signedInService(
        intercept: (r) =>
            r.method == 'DELETE' ? http.Response('[]', 200) : null,
      );

      final result = await service.deleteTask('t1');

      expect(result['success'], isFalse);
      expect(result['error'], startsWith('Permission denied'));
      expect(backend.table('tasks'), hasLength(1));
    });

    test('explains a delete of a task that does not exist', () async {
      final service = await signedInService();

      final result = await service.deleteTask('missing');

      expect(result['error'], 'Task not found or permission denied');
    });

    test('reports a backend error', () async {
      final service = await signedInService();
      backend.failures['tasks'] = 500;

      expect((await service.deleteTask('t1'))['success'], isFalse);
    });
  });
}
