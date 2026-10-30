import 'package:ell_ena/screens/tasks/create_task_screen.dart';
import 'package:ell_ena/screens/tasks/task_detail_screen.dart';
import 'package:ell_ena/screens/tasks/task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'task_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  Future<void> pumpTasks(
    WidgetTester tester, {
    Size size = taskPhoneSize,
    ThemeMode themeMode = ThemeMode.light,
    bool withKey = true,
  }) async {
    await pumpApp(
      tester,
      withKey ? TaskScreen(key: TaskScreen.globalKey) : const TaskScreen(),
      size: size,
      themeMode: themeMode,
    );
    await settle(tester);
  }

  void seedBoard() {
    backend.table('tasks').addAll([
      taskRow('t1', title: 'Plan sprint', createdAt: '2026-10-04T00:00:00Z'),
      taskRow(
        't2',
        title: 'Fix login',
        createdBy: FakeBackend.userId,
        approval: 'approved',
        createdAt: '2026-10-03T00:00:00Z',
      ),
      taskRow('t3', title: 'Build API', status: 'in_progress'),
      taskRow('t4', title: 'Ship v1', status: 'completed', dueDate: null),
      // The workspace list shows the whole team's tasks, not just the user's.
      taskRow('t5',
          title: 'Pair review', assignedTo: 'user-2', approval: 'approved'),
      taskRow('t6',
          title: 'Open issue', assignedTo: null, approval: 'approved'),
    ]);
  }

  int count(String request) => backend.log.where((r) => r == request).length;

  group('phone', () {
    testWidgets('shows team progress and the to-do cards', (tester) async {
      seedBoard();
      await pumpTasks(tester);

      // Four of six tasks to do, one in progress, one completed.
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('17%'), findsNWidgets(2));
      expect(find.text('Plan sprint'), findsOneWidget);
      expect(find.text('Fix login'), findsOneWidget);
      expect(find.text('Build API'), findsNothing);

      final plan = find.ancestor(
        of: find.text('Plan sprint'),
        matching: find.byType(GestureDetector),
      );
      Finder inPlan(String text) =>
          find.descendant(of: plan.first, matching: find.text(text));
      expect(inPlan('Created by Bob'), findsOneWidget);
      expect(inPlan('Assigned to You'), findsOneWidget);
      expect(inPlan('5/11/2026'), findsOneWidget);
      expect(inPlan('PENDING'), findsOneWidget);
      expect(inPlan('Drag to change status'), findsOneWidget);
      expect(find.text('Created by You'), findsOneWidget);
      expect(find.text('APPROVED'), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.drag(
          find.byType(ReorderableListView), const Offset(0, -600));
      await settle(tester);
      expect(find.text('Assigned to Bob'), findsOneWidget);
      // Unassigned tasks have no assignee line on the card.
      expect(find.text('Open issue'), findsOneWidget);
    });

    testWidgets('status tabs filter the list', (tester) async {
      seedBoard();
      await pumpTasks(tester, themeMode: ThemeMode.dark);

      await tester.tap(find.text('In Progress').last);
      await settle(tester);
      expect(find.text('Build API'), findsOneWidget);
      expect(find.text('Plan sprint'), findsNothing);

      await tester.tap(find.text('Completed').last);
      await settle(tester);
      expect(find.text('Ship v1'), findsOneWidget);
      expect(find.text('No due date'), findsOneWidget);
    });

    testWidgets('empty tabs explain themselves and point to the next tab',
        (tester) async {
      await pumpTasks(tester);

      expect(find.text('0%'), findsNWidgets(3));
      expect(find.text('No tasks found'), findsOneWidget);
      expect(find.text('Add new tasks to get started'), findsOneWidget);

      await tester.tap(find.text('View In Progress Tasks'));
      await settle(tester);
      expect(
        find.text('Move tasks here when you start working on them'),
        findsOneWidget,
      );

      await tester.tap(find.text('View Completed Tasks'));
      await settle(tester);
      expect(find.text('Completed tasks will appear here'), findsOneWidget);

      await tester.tap(find.text('View To Do Tasks'));
      await settle(tester);
      expect(find.text('Add new tasks to get started'), findsOneWidget);
    });

    testWidgets('shows placeholders for missing task fields', (tester) async {
      backend.table('tasks').add(taskRow(
            't1',
            title: null,
            description: null,
            createdBy: null,
          ));
      await pumpTasks(tester);

      expect(find.text('Untitled Task'), findsOneWidget);
      expect(find.text('No description'), findsOneWidget);
      expect(find.text('Created by Unknown'), findsOneWidget);
    });

    testWidgets('names creators missing from the roster as Team Member',
        (tester) async {
      backend.table('tasks').add(taskRow('t1', createdBy: 'stranger'));
      await pumpTasks(tester);

      expect(find.text('Created by Team Member'), findsOneWidget);
    });

    testWidgets('admins approve and reject pending tasks from the card',
        (tester) async {
      seedBoard();
      await pumpTasks(tester);

      // Only the pending task offers approval.
      expect(find.byTooltip('Approve'), findsOneWidget);
      await tester.tap(find.byTooltip('Approve'));
      await settle(tester);
      expect(backend.table('tasks').first['approval_status'], 'approved');
      expect(find.byTooltip('Approve'), findsNothing);

      backend.table('tasks').first['approval_status'] = 'pending';
      TaskScreen.refreshTasks();
      await settle(tester);
      await tester.tap(find.byTooltip('Reject'));
      await settle(tester);
      expect(
        backend.bodiesFor('PATCH', '/rest/v1/tasks').last,
        {'approval_status': 'rejected'},
      );
      expect(find.text('REJECTED'), findsOneWidget);
    });

    testWidgets('members only see delete on tasks they created',
        (tester) async {
      await resetInTest(tester, role: 'member');
      seedBoard();
      await pumpTasks(tester);

      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('delete asks first, then removes the task', (tester) async {
      seedBoard();
      await pumpTasks(tester);

      await tester.tap(find.byTooltip('Delete').first);
      await settle(tester);
      expect(find.text('Delete Task'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(count('DELETE /rest/v1/tasks'), 0);

      await tester.tap(find.byTooltip('Delete').first);
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);

      expect(count('DELETE /rest/v1/tasks'), 1);
      expect(find.text('Task deleted successfully'), findsOneWidget);
      expect(find.text('Plan sprint'), findsNothing);
      expect(find.text('Fix login'), findsOneWidget);
    });

    testWidgets('a failed delete shows the error', (tester) async {
      seedBoard();
      await pumpTasks(tester);

      await tester.tap(find.byTooltip('Delete').first);
      await settle(tester);
      backend.failures['tasks'] = 500;
      await tester.tap(find.text('Delete'));
      await settle(tester);

      expect(find.textContaining('forced failure'), findsOneWidget);
      expect(find.text('Plan sprint'), findsOneWidget);
    });

    testWidgets('a delete the database ignores reports a failure',
        (tester) async {
      seedBoard();
      await pumpTasks(tester);

      await tester.tap(find.byTooltip('Delete').first);
      await settle(tester);
      // Someone else removed the row first: the delete matches nothing.
      backend.table('tasks').removeWhere((t) => t['id'] == 't1');
      await tester.tap(find.text('Delete'));
      await settle(tester);

      expect(
        find.text('Task not found or permission denied'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a card opens its details and refreshes on delete',
        (tester) async {
      seedBoard();
      await pumpTasks(tester);

      await tester.tap(find.text('Plan sprint'));
      await settle(tester);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.text('Task Details'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete Task'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(find.text('Plan sprint'), findsNothing);
      expect(find.text('Fix login'), findsOneWidget);
    });

    testWidgets('the add button creates a task and confirms it',
        (tester) async {
      await pumpTasks(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);
      expect(find.byType(CreateTaskScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Fresh task');
      await tester.tap(find.text('Create Task'));
      await settle(tester);

      expect(find.text('Task created successfully'), findsOneWidget);
      expect(backend.table('tasks').single['title'], 'Fresh task');
    });

    testWidgets('dragging a card onto a status tab moves the task',
        (tester) async {
      seedBoard();
      await pumpTasks(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Plan sprint')));
      await tester.pump();
      final target = tester.getCenter(find.text('In Progress').last);
      for (var i = 1; i <= 10; i++) {
        final from = tester.getCenter(find.text('Plan sprint').first);
        await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(
        backend.bodiesFor('PATCH', '/rest/v1/tasks'),
        [
          {'status': 'in_progress'}
        ],
      );
      expect(backend.table('tasks').first['status'], 'in_progress');
    });

    testWidgets('dropping a card on its own tab changes nothing',
        (tester) async {
      seedBoard();
      await pumpTasks(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Plan sprint')));
      await tester.pump();
      final target = tester.getCenter(find.text('To Do').last);
      for (var i = 1; i <= 10; i++) {
        final from = tester.getCenter(find.text('Plan sprint').first);
        await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);

      expect(backend.bodiesFor('PATCH', '/rest/v1/tasks'), isEmpty);
    });

    testWidgets('a status drag the database ignores reports a failure',
        (tester) async {
      seedBoard();
      await pumpTasks(tester);

      // Someone else removed the row: the update matches nothing.
      backend.table('tasks').removeWhere((t) => t['id'] == 't1');
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Plan sprint')));
      await tester.pump();
      final target = tester.getCenter(find.text('In Progress').last);
      for (var i = 1; i <= 10; i++) {
        final from = tester.getCenter(find.text('Plan sprint').first);
        await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(
        find.textContaining('Error updating task status'),
        findsOneWidget,
      );
    });

    testWidgets('a failed approval shows the error', (tester) async {
      seedBoard();
      await pumpTasks(tester);

      backend.failures['tasks'] = 500;
      await tester.tap(find.byTooltip('Approve'));
      await settle(tester);

      expect(
        find.textContaining('Error updating task approval'),
        findsOneWidget,
      );
      expect(backend.table('tasks').first['approval_status'], 'pending');
    });

    testWidgets('long-press reordering is kept but not saved', (tester) async {
      seedBoard();
      await pumpTasks(tester);

      expect(
        tester.getTopLeft(find.text('Plan sprint')).dy,
        lessThan(tester.getTopLeft(find.text('Fix login')).dy),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Plan sprint')));
      await tester.pump(const Duration(milliseconds: 600));
      final distance = tester.getCenter(find.text('Fix login')).dy -
          tester.getCenter(find.text('Plan sprint')).dy;
      for (var i = 1; i <= 10; i++) {
        await gesture.moveBy(Offset(0, (distance + 120) / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);

      // The new order stays on screen; order isn't stored server-side.
      expect(backend.bodiesFor('PATCH', '/rest/v1/tasks'), isEmpty);
      expect(
        tester.getTopLeft(find.text('Plan sprint')).dy,
        greaterThan(tester.getTopLeft(find.text('Fix login')).dy),
      );
    });

    testWidgets('without the shared key the static refresh does nothing',
        (tester) async {
      seedBoard();
      await pumpTasks(tester, withKey: false);
      final before = count('GET /rest/v1/tasks');

      TaskScreen.refreshTasks();
      TaskScreen.openCreateTask();
      await settle(tester);

      expect(count('GET /rest/v1/tasks'), before);
      expect(find.byType(CreateTaskScreen), findsNothing);
      expect(find.text('Plan sprint'), findsOneWidget);
    });
  });

  group('wide', () {
    testWidgets('lists tasks as a table without the add button',
        (tester) async {
      seedBoard();
      await pumpTasks(tester, size: wideSize);

      expect(find.byType(FloatingActionButton), findsNothing);
      for (final heading in [
        'Task',
        'Approval',
        'Created by',
        'Assigned to',
        'Due date',
      ]) {
        expect(find.text(heading), findsOneWidget);
      }
      expect(find.text('Plan sprint'), findsOneWidget);
      // Creators: Bob, You, Bob, Bob. Assignees: You, You, Bob.
      expect(find.text('Bob'), findsNWidgets(4));
      expect(find.text('You'), findsNWidgets(3));
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('Drag to change status'), findsNothing);
    });

    testWidgets('row actions approve, reject and delete', (tester) async {
      seedBoard();
      await pumpTasks(tester, size: wideSize, themeMode: ThemeMode.dark);

      await tester.tap(find.byTooltip('Approve'));
      await settle(tester);
      expect(backend.table('tasks').first['approval_status'], 'approved');

      backend.table('tasks').first['approval_status'] = 'pending';
      TaskScreen.refreshTasks();
      await settle(tester);
      await tester.tap(find.byTooltip('Reject'));
      await settle(tester);
      expect(backend.table('tasks').first['approval_status'], 'rejected');

      await tester.tap(find.byTooltip('Delete').first);
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(backend.table('tasks').any((t) => t['id'] == 't1'), isFalse);
      expect(find.text('Plan sprint'), findsNothing);
    });

    testWidgets('selecting a row highlights it and opens the side panel',
        (tester) async {
      seedBoard();
      await pumpTasks(tester, size: wideSize);

      await tester.tap(find.text('Plan sprint'));
      await settle(tester);
      // The progress bars are sized from the screen width, so they overflow
      // once the panel takes part of it.
      expect(tester.takeException(), isA<FlutterError>());
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      // A 1440px window still has room for the table beside the panel.
      expect(find.text('Approval'), findsOneWidget);
      final row = find.ancestor(
        of: find.text('Plan sprint').first,
        matching: find.byType(Material),
      );
      final scheme = Theme.of(tester.element(row.first)).colorScheme;
      expect(
        tester.widget<Material>(row.first).color,
        scheme.primary.withValues(alpha: 0.08),
      );
    });

    testWidgets(
        'narrow wide windows show cards beside the panel; closing '
        'refreshes', (tester) async {
      seedBoard();
      await pumpTasks(tester, size: const Size(1100, 900));
      expect(find.text('Approval'), findsOneWidget);

      await tester.tap(find.text('Plan sprint'));
      await settle(tester);
      expect(tester.takeException(), isA<FlutterError>());
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      // Beside the panel the list is too narrow for the table.
      expect(find.text('Approval'), findsNothing);
      expect(find.text('Drag to change status'), findsWidgets);

      final before = count('GET /rest/v1/tasks');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);

      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(find.text('Approval'), findsOneWidget);
      expect(count('GET /rest/v1/tasks'), greaterThan(before));
    });

    testWidgets('the top bar opens the create dialog through the static hook',
        (tester) async {
      await pumpTasks(tester, size: wideSize);

      TaskScreen.openCreateTask();
      await settle(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CreateTaskScreen), findsOneWidget);
    });
  });
}
