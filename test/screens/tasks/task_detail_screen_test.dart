import 'package:ell_ena/screens/tasks/task_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'task_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  Future<void> pumpDetail(
    WidgetTester tester, {
    String taskId = 't1',
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpApp(
      tester,
      TaskDetailScreen(taskId: taskId),
      themeMode: themeMode,
    );
    await settle(tester);
  }

  /// Opens the detail page from a launcher and returns a getter for the value
  /// it pops with.
  Future<Object? Function()> pushDetail(WidgetTester tester) async {
    Object? popped = 'not popped';
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(
                  builder: (_) => const TaskDetailScreen(taskId: 't1'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return () => popped;
  }

  String ago(Duration duration) =>
      DateTime.now().toUtc().subtract(duration).toIso8601String();

  void seedComments() {
    backend.table('task_comments').addAll([
      {
        'id': 'c1',
        'task_id': 't1',
        'user_id': 'user-2',
        'content': 'Started on it',
        'created_at': ago(const Duration(days: 2, hours: 1)),
      },
      {
        'id': 'c2',
        'task_id': 't1',
        'user_id': FakeBackend.userId,
        'content': 'Looks good',
        'created_at': ago(const Duration(hours: 3, minutes: 5)),
      },
      {
        'id': 'c3',
        'task_id': 't1',
        'user_id': 'ghost',
        'content': 'Who am I',
        'created_at': ago(const Duration(minutes: 5, seconds: 10)),
      },
      {
        'id': 'c4',
        'task_id': 't1',
        'user_id': 'user-2',
        'content': 'Done',
        'created_at': ago(const Duration(seconds: 5)),
      },
    ]);
  }

  testWidgets('shows the task, people, and comments with relative times',
      (tester) async {
    backend.table('tasks').add(taskRow(
          't1',
          title: 'Write docs',
          description: 'For the API',
          dueDate: '2026-11-05',
        ));
    seedComments();
    await pumpDetail(tester);

    expect(find.text('Task Details'), findsOneWidget);
    expect(find.text('Write docs'), findsOneWidget);
    expect(find.text('For the API'), findsOneWidget);
    expect(find.text('Due: 5/11/2026'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('Created by Bob'), findsOneWidget);
    expect(find.text('Assigned to Ada'), findsOneWidget);
    expect(find.text('No linked ticket'), findsOneWidget);

    expect(find.text('Comments (4)'), findsOneWidget);
    expect(find.text('2d ago'), findsOneWidget);
    expect(find.text('3h ago'), findsOneWidget);
    expect(find.text('5m ago'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
    // A commenter missing from the users table shows as Unknown.
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Who am I'), findsOneWidget);

    // Sorting is not implemented; the button must not break the page.
    await tester.tap(find.text('Latest first'));
    await settle(tester);
    expect(find.text('Comments (4)'), findsOneWidget);
  });

  testWidgets('fills in placeholders for a sparse task', (tester) async {
    backend.table('tasks').add(taskRow(
          't1',
          title: null,
          description: null,
          dueDate: null,
          createdBy: null,
          assignedTo: null,
          status: 'blocked',
          approval: 'rejected',
        ));
    await pumpDetail(tester, themeMode: ThemeMode.dark);

    expect(find.text('Untitled Task'), findsOneWidget);
    expect(find.text('No description'), findsOneWidget);
    expect(find.text('Due: No due date'), findsOneWidget);
    expect(find.text('Created by Unknown'), findsOneWidget);
    expect(find.textContaining('Assigned to'), findsNothing);
    // An unrecognised status gets the Unknown label and no status actions.
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('REJECTED'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Complete'), findsNothing);
    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Be the first to comment'), findsOneWidget);
  });

  testWidgets('says the task is gone when it no longer exists', (tester) async {
    await pumpDetail(tester, taskId: 'missing');

    expect(find.text('Task not found'), findsOneWidget);
    expect(find.text('The task may have been deleted'), findsOneWidget);
  });

  testWidgets('Start and Complete send the next status', (tester) async {
    backend.table('tasks').add(taskRow('t1'));
    await pumpDetail(tester);

    await tester.tap(find.text('Start'));
    await settle(tester);

    expect(
      backend.bodiesFor('PATCH', '/rest/v1/tasks'),
      [
        {'status': 'in_progress'}
      ],
    );
    expect(find.text('Task status updated to In Progress'), findsOneWidget);

    // The saved status shows after a refresh.
    await tester.tap(find.byTooltip('Refresh'));
    await settle(tester);
    expect(find.text('In Progress'), findsOneWidget);

    await tester.tap(find.text('Complete'));
    await settle(tester);
    expect(
      backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
      {'status': 'completed'},
    );
  });

  testWidgets('admins approve and reject pending tasks', (tester) async {
    backend.table('tasks').add(taskRow('t1', status: 'completed'));
    await pumpDetail(tester);

    // Completed but pending approval: only the approval actions remain.
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Start'), findsNothing);

    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(find.text('Task approved'), findsOneWidget);
    expect(
      backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
      {'approval_status': 'approved'},
    );
    // Approved and completed: nothing left to do.
    expect(find.text('Actions'), findsNothing);

    // Let the first snackbar time out so the next one shows.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    backend.table('tasks').single['approval_status'] = 'pending';
    await tester.tap(find.byTooltip('Refresh'));
    await settle(tester);
    await tester.tap(find.text('Reject'));
    await settle(tester);
    expect(find.text('Task rejected'), findsOneWidget);
    expect(
      backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
      {'approval_status': 'rejected'},
    );
  });

  testWidgets('a failed approval reports the error, not success',
      (tester) async {
    backend.table('tasks').add(taskRow('t1', status: 'completed'));
    await pumpDetail(tester);

    backend.failures['tasks'] = 500;
    await tester.tap(find.text('Approve'));
    await settle(tester);

    expect(find.text('Task approved'), findsNothing);
    expect(
      find.textContaining('Error updating task approval'),
      findsOneWidget,
    );
    expect(backend.table('tasks').single['approval_status'], 'pending');
  });

  testWidgets('members cannot approve or delete tasks they did not create',
      (tester) async {
    await resetInTest(tester, role: 'member');
    backend.table('tasks').add(taskRow('t1', createdBy: 'user-2'));
    await pumpDetail(tester);

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.byTooltip('Delete Task'), findsNothing);
  });

  testWidgets('members can delete their own task', (tester) async {
    await resetInTest(tester, role: 'member');
    backend.table('tasks').add(taskRow('t1', createdBy: FakeBackend.userId));
    await pumpDetail(tester);

    expect(find.byTooltip('Delete Task'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the task', (tester) async {
    backend.table('tasks').add(taskRow('t1'));
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Delete Task'));
    await settle(tester);
    expect(
      find.text(
        'Are you sure you want to delete this task? This action cannot be '
        'undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(backend.log.where((r) => r == 'DELETE /rest/v1/tasks'), isEmpty);
    expect(backend.table('tasks'), hasLength(1));
  });

  testWidgets('deleting closes the page with a refresh result', (tester) async {
    backend.table('tasks').add(taskRow('t1'));
    final popped = await pushDetail(tester);

    await tester.tap(find.byTooltip('Delete Task'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(backend.table('tasks'), isEmpty);
    expect(popped(), isTrue);
    expect(find.text('Task deleted successfully'), findsOneWidget);
  });

  testWidgets('a failed delete shows the error and stays open', (tester) async {
    backend.table('tasks').add(taskRow('t1'));
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Delete Task'));
    await settle(tester);
    backend.failures['tasks'] = 500;
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.textContaining('Error deleting task:'), findsOneWidget);
    expect(find.text('Task Details'), findsOneWidget);
    expect(backend.table('tasks'), hasLength(1));
  });

  testWidgets('adds a trimmed comment and ignores blank ones', (tester) async {
    backend.table('tasks').add(taskRow('t1'));
    await pumpDetail(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Send comment'));
    await settle(tester);
    expect(backend.bodiesFor('POST', '/rest/v1/task_comments'), isEmpty);

    await tester.enterText(find.byType(TextField), '  On it  ');
    await tester.tap(find.byTooltip('Send comment'));
    await settle(tester);

    expect(backend.bodiesFor('POST', '/rest/v1/task_comments'), [
      {'task_id': 't1', 'user_id': FakeBackend.userId, 'content': 'On it'}
    ]);
    expect(find.text('Comments (1)'), findsOneWidget);
    expect(find.text('On it'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a failed comment keeps the text and shows the error',
      (tester) async {
    backend.table('tasks').add(taskRow('t1'));
    await pumpDetail(tester);

    backend.failures['task_comments'] = 500;
    await tester.enterText(find.byType(TextField), 'Lost words');
    await tester.tap(find.byTooltip('Send comment'));
    await settle(tester);

    expect(find.textContaining('Error adding comment:'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Lost words',
    );
  });

  testWidgets('links, relinks, and unlinks a ticket', (tester) async {
    backend.table('tickets').addAll([
      ticketRow('ticket-1', 'TKT-1', 'Crash'),
      ticketRow('ticket-2', 'TKT-2', 'Typo'),
    ]);
    backend.table('tasks').add(taskRow('t1', ticketId: 'ticket-1'));
    await pumpDetail(tester);

    expect(find.text('TKT-1 · Crash'), findsOneWidget);

    await tester.tap(find.text('TKT-1 · Crash'));
    await settle(tester);
    await tester.tap(find.text('TKT-2 · Typo').last);
    await settle(tester);
    expect(
      backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
      {'ticket_id': 'ticket-2'},
    );
    expect(find.text('TKT-2 · Typo'), findsOneWidget);

    await tester.tap(find.text('TKT-2 · Typo'));
    await settle(tester);
    await tester.tap(find.text('No linked ticket').last);
    await settle(tester);
    expect(
      backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
      {'ticket_id': null},
    );
  });

  testWidgets('keeps showing a linked ticket from outside the team list',
      (tester) async {
    backend.table('tickets').add({
      ...ticketRow('ticket-x', 'TKT-X', 'Elsewhere'),
      'team_id': 'other-team',
    });
    backend.table('tasks').add(taskRow('t1', ticketId: 'ticket-x'));
    await pumpDetail(tester);

    expect(find.text('TKT-X · Elsewhere'), findsOneWidget);
  });

  testWidgets('reports a failed ticket link', (tester) async {
    backend.table('tickets').add(ticketRow('ticket-1', 'TKT-1', 'Crash'));
    backend.table('tasks').add(taskRow('t1'));
    await pumpDetail(tester);

    await tester.tap(find.text('No linked ticket'));
    await settle(tester);
    backend.failures['tasks'] = 500;
    await tester.tap(find.text('TKT-1 · Crash').last);
    await settle(tester);

    expect(find.textContaining('forced failure'), findsOneWidget);
    expect(backend.table('tasks').single['ticket_id'], isNull);
  });
}
