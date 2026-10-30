import 'package:ell_ena/screens/meetings/create_meeting_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_screen.dart';
import 'package:ell_ena/screens/tasks/create_task_screen.dart';
import 'package:ell_ena/screens/tasks/task_screen.dart';
import 'package:ell_ena/screens/tickets/create_ticket_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_screen.dart';
import 'package:ell_ena/screens/workspace/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../tasks/task_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  Future<List<int>> pumpWorkspace(
    WidgetTester tester, {
    int initialTabIndex = 0,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final selected = <int>[];
    await pumpApp(
      tester,
      WorkspaceScreen(
        initialTabIndex: initialTabIndex,
        onTabSelected: selected.add,
      ),
      themeMode: themeMode,
    );
    await settle(tester);
    return selected;
  }

  int taskLoads() =>
      backend.log.where((r) => r == 'GET /rest/v1/tasks').length;

  testWidgets('starts on tasks and reports tab changes', (tester) async {
    final selected = await pumpWorkspace(tester);

    expect(find.byType(TaskScreen), findsOneWidget);

    await tester.tap(find.text('Tickets'));
    await settle(tester);
    expect(find.byType(TicketScreen), findsOneWidget);

    await tester.tap(find.text('Meetings'));
    await settle(tester);
    expect(find.byType(MeetingScreen), findsOneWidget);

    expect(selected, [1, 2]);
  });

  testWidgets('switching tabs keeps each list and its status filter',
      (tester) async {
    backend.table('tasks').add(
          taskRow('t1', title: 'Build API', status: 'in_progress'),
        );
    await pumpWorkspace(tester);

    await tester.tap(find.text('In Progress').last);
    await settle(tester);
    expect(find.text('Build API'), findsOneWidget);
    final loads = taskLoads();

    await tester.tap(find.text('Tickets'));
    await settle(tester);
    await tester.tap(find.text('Tasks'));
    await settle(tester);

    expect(find.text('Build API'), findsOneWidget);
    expect(taskLoads(), loads);
  });

  testWidgets('out-of-range initial tab is clamped', (tester) async {
    await pumpWorkspace(tester, initialTabIndex: 7, themeMode: ThemeMode.dark);

    expect(find.byType(MeetingScreen), findsOneWidget);
  });

  testWidgets('a new initial tab from the route moves the tab bar',
      (tester) async {
    await pumpWorkspace(tester);
    final state = tester.state(find.byType(WorkspaceScreen));

    await pumpApp(tester, const WorkspaceScreen(initialTabIndex: 1));
    await settle(tester);
    expect(find.byType(TicketScreen), findsOneWidget);
    // Same state object: the tab bar animated rather than rebuilt.
    expect(tester.state(find.byType(WorkspaceScreen)), same(state));
  });

  for (final entry in {
    0: [CreateTaskScreen, 'Task created successfully', 'tasks'],
    1: [CreateTicketScreen, 'Ticket created successfully', 'tickets'],
    2: [CreateMeetingScreen, 'Meeting created successfully', 'meetings'],
  }.entries) {
    testWidgets('tab ${entry.key} has one add button that creates and confirms',
        (tester) async {
      await pumpWorkspace(tester, initialTabIndex: entry.key);

      // Only the open page's own button, not a second workspace one.
      final addButton = find.byType(FloatingActionButton);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await settle(tester);
      final form = find.byType(entry.value[0] as Type);
      expect(form, findsOneWidget);

      backend.log.clear();
      Navigator.of(tester.element(form)).pop(true);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      expect(form, findsNothing);
      expect(find.text(entry.value[1] as String), findsOneWidget);
      // The open list reloads.
      expect(backend.log, contains('GET /rest/v1/${entry.value[2]}'));
    });
  }
}
