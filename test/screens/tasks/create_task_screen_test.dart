import 'package:ell_ena/screens/tasks/create_task_screen.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'task_fixtures.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  /// Opens [CreateTaskScreen] from a launcher page and returns a getter for
  /// the value the screen pops with.
  Future<Object? Function()> openCreate(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    Object? popped = 'not popped';
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
      themeMode: themeMode,
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return () => popped;
  }

  testWidgets('requires a title before creating anything', (tester) async {
    final popped = await openCreate(tester);

    expect(find.text('Create New Task'), findsOneWidget);
    await tester.tap(find.text('Create Task'));
    await settle(tester);

    expect(find.text('Please enter a task title'), findsOneWidget);
    expect(backend.bodiesFor('POST', '/rest/v1/tasks'), isEmpty);
    expect(popped(), 'not popped');
  });

  testWidgets('creates a task with due date, assignee and linked ticket',
      (tester) async {
    backend.table('tickets').add(ticketRow('ticket-9', 'TKT-9', 'Login bug'));
    final popped = await openCreate(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '  Ship it  ');
    await tester.enterText(find.byType(TextFormField).at(1), 'Release notes');

    await tester.tap(find.text('Select due date'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(
      find.text('${tomorrow.day}/${tomorrow.month}/${tomorrow.year}'),
      findsOneWidget,
    );

    // The roster lists both team members, with the admin badged. With no
    // assignee the picker shows its Unassigned entry.
    await tester.tap(find.text('Unassigned'));
    await settle(tester);
    expect(find.text('Admin'), findsWidgets);
    await tester.tap(find.text('Bob').last);
    await settle(tester);

    await tester.tap(find.text('No linked ticket').first);
    await settle(tester);
    await tester.tap(find.text('TKT-9 · Login bug').last);
    await settle(tester);

    await tester.tap(find.text('Create Task'));
    await settle(tester);

    final body = backend.bodiesFor('POST', '/rest/v1/tasks').single as Map;
    expect(body['title'], 'Ship it');
    expect(body['description'], 'Release notes');
    expect(body['assigned_to'], 'user-2');
    expect(body['ticket_id'], 'ticket-9');
    expect(body['status'], 'todo');
    expect(body['approval_status'], 'pending');
    expect(body['team_id'], FakeBackend.teamId);
    expect(DateTime.parse(body['due_date'] as String).day, tomorrow.day);
    expect(popped(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(CreateTaskScreen), findsNothing);
  });

  testWidgets('choosing Unassigned clears the assignee', (tester) async {
    await openCreate(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Solo task');

    await tester.tap(find.text('Unassigned'));
    await settle(tester);
    await tester.tap(find.text('Bob').last);
    await settle(tester);
    await tester.tap(find.text('Bob').last);
    await settle(tester);
    await tester.tap(find.text('Unassigned').last);
    await settle(tester);

    await tester.tap(find.text('Create Task'));
    await settle(tester);

    final body = backend.bodiesFor('POST', '/rest/v1/tasks').single as Map;
    expect(body.containsKey('assigned_to'), isFalse);
    expect(body.containsKey('due_date'), isFalse);
    expect(body.containsKey('ticket_id'), isFalse);
  });

  testWidgets('shows the backend error and stays open when creation fails',
      (tester) async {
    final popped = await openCreate(tester, themeMode: ThemeMode.dark);
    await tester.enterText(find.byType(TextFormField).first, 'Doomed');
    backend.failures['tasks'] = 500;

    await tester.tap(find.text('Create Task'));
    await settle(tester);

    expect(find.textContaining('Error creating task:'), findsOneWidget);
    expect(find.byType(CreateTaskScreen), findsOneWidget);
    expect(popped(), 'not popped');
    // The form is usable again after the failure.
    expect(find.text('Create Task'), findsOneWidget);
  });

  testWidgets('offers only Unassigned when the profile has no team',
      (tester) async {
    backend.table('users').first['teams'] = null;
    await SupabaseService().getCurrentUserProfile(forceRefresh: true);
    await openCreate(tester);

    await tester.tap(find.text('Unassigned'));
    await settle(tester);

    expect(find.text('Bob'), findsNothing);
    expect(find.text('Unassigned'), findsWidgets);
    expect(
      backend.log.where((r) => r == 'GET /rest/v1/teams'),
      isEmpty,
    );
  });
}
