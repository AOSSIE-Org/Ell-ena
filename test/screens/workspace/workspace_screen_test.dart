import 'package:ell_ena/screens/meetings/create_meeting_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_screen.dart';
import 'package:ell_ena/screens/tasks/create_task_screen.dart';
import 'package:ell_ena/screens/tasks/task_screen.dart';
import 'package:ell_ena/screens/tickets/create_ticket_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_screen.dart';
import 'package:ell_ena/screens/workspace/workspace_screen.dart';
import 'package:ell_ena/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  /// Pumps the workspace and waits out its two-second loading skeleton.
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
    expect(find.byType(WorkspaceLoadingSkeleton), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.byType(WorkspaceLoadingSkeleton), findsNothing);
    return selected;
  }

  // Each tab's own page has an add button too; this is the workspace's.
  final addButton = find.byWidgetPredicate(
    (w) => w is FloatingActionButton && w.heroTag == 'workspace-add-button',
  );

  FloatingActionButton fab(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(addButton);

  testWidgets('starts on tasks and reports tab changes', (tester) async {
    final selected = await pumpWorkspace(tester);

    expect(find.byType(TaskScreen), findsOneWidget);
    expect(fab(tester).tooltip, 'New Task');

    await tester.tap(find.text('Tickets'));
    await settle(tester);
    expect(find.byType(TicketScreen), findsOneWidget);
    expect(fab(tester).tooltip, 'New Ticket');

    await tester.tap(find.text('Meetings'));
    await settle(tester);
    expect(find.byType(MeetingScreen), findsOneWidget);
    expect(fab(tester).tooltip, 'New Meeting');

    expect(selected, [1, 2]);
  });

  testWidgets('out-of-range initial tab is clamped', (tester) async {
    await pumpWorkspace(tester, initialTabIndex: 7, themeMode: ThemeMode.dark);

    expect(find.byType(MeetingScreen), findsOneWidget);
    expect(fab(tester).tooltip, 'New Meeting');
  });

  testWidgets('a new initial tab from the route moves the tab bar',
      (tester) async {
    await pumpWorkspace(tester);

    // The parent rebuilds with another deep-link tab.
    await tester.pumpWidget(Container());
    await pumpApp(tester, const WorkspaceScreen(initialTabIndex: 0));
    final state = tester.state(find.byType(WorkspaceScreen));
    expect(state.mounted, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

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
    testWidgets('add button on tab ${entry.key} creates and confirms',
        (tester) async {
      await pumpWorkspace(tester, initialTabIndex: entry.key);

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

    testWidgets('closing the form on tab ${entry.key} shows nothing',
        (tester) async {
      await pumpWorkspace(tester, initialTabIndex: entry.key);

      await tester.tap(addButton);
      await settle(tester);
      Navigator.of(tester.element(find.byType(entry.value[0] as Type))).pop();
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      expect(find.byType(SnackBar), findsNothing);
    });
  }
}
