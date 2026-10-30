import 'dart:convert';

import 'package:ell_ena/screens/calendar/calendar_screen.dart';
import 'package:ell_ena/screens/chat/chat_screen.dart';
import 'package:ell_ena/screens/meetings/create_meeting_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_detail_screen.dart';
import 'package:ell_ena/screens/tasks/create_task_screen.dart';
import 'package:ell_ena/screens/tasks/task_detail_screen.dart';
import 'package:ell_ena/screens/tickets/create_ticket_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_detail_screen.dart';
import 'package:ell_ena/shell/shell_refreshable.dart';
import 'package:ell_ena/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_harness.dart';
import '../chat/speech_mock.dart';

/// Tall enough for the month grid plus all 24 hour slots, so no scrolling.
const _tallPhone = Size(480, 2400);

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(() async {
    mockSpeech();
    await resetFakeSupabase();
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String at(int hour) => today.add(Duration(hours: hour)).toIso8601String();

  void seedEvents() {
    backend.table('tasks').addAll([
      {
        'id': 'task-1',
        'title': 'Write report',
        'description': 'Quarterly numbers',
        'status': 'todo',
        'approval_status': 'approved',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'assigned_to': null,
        'due_date': today.toIso8601String(),
        'created_at': at(1),
      },
      {
        'id': 'task-2',
        'title': 'Not mine',
        'status': 'todo',
        'team_id': FakeBackend.teamId,
        'created_by': 'user-2',
        'assigned_to': 'user-2',
        'due_date': today.toIso8601String(),
        'created_at': at(1),
      },
    ]);
    backend.table('tickets').add({
      'id': 'ticket-1',
      'ticket_number': 'TKT-1',
      'title': 'Fix login',
      'description': 'Users cannot sign in',
      'category': 'Bug',
      'status': 'open',
      'priority': 'high',
      'approval_status': 'approved',
      'team_id': FakeBackend.teamId,
      'created_by': FakeBackend.userId,
      'created_at': at(10),
    });
    backend.table('meetings').add({
      'id': 'meeting-1',
      'title': 'Standup',
      'team_id': FakeBackend.teamId,
      'created_by': FakeBackend.userId,
      'meeting_date': at(14),
    });
  }

  Future<void> pumpCalendar(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    ThemeMode themeMode = ThemeMode.light,
    Key? key,
  }) async {
    await pumpApp(
      tester,
      CalendarScreen(key: key),
      size: _tallPhone,
      prefs: prefs,
      themeMode: themeMode,
    );
    await settle(tester);
  }

  /// The green badge over a day cell showing how many events it has.
  bool hasMarker(WidgetTester tester, int count) => tester
      .widgetList<Text>(find.text('$count'))
      .any((text) => text.style?.fontSize == 10);

  testWidgets('shows a skeleton, then today\'s events from the network',
      (tester) async {
    seedEvents();
    await pumpApp(tester, const CalendarScreen(), size: _tallPhone);
    expect(find.byType(CalendarLoadingSkeleton), findsOneWidget);

    await settle(tester);

    expect(find.byType(CalendarLoadingSkeleton), findsNothing);
    // Admins see every task, including ones neither created nor assigned.
    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Not mine'), findsOneWidget);
    expect(find.text('Fix login'), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);
    expect(hasMarker(tester, 4), isTrue);
    // Tasks are pinned to the end of their due day; meetings last an hour.
    expect(find.text('11:00 PM - 11:59 PM'), findsNWidgets(2));
    expect(find.text('2:00 PM - 3:00 PM'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar_last_fetch_time'), isNotNull);
    final cachedTasks = jsonDecode(prefs.getString('calendar_tasks')!) as List;
    expect(cachedTasks.map((t) => t['id']), ['task-1', 'task-2']);
  });

  testWidgets('members only see tasks they created, own, or nobody owns',
      (tester) async {
    await resetInTest(tester, role: 'member');
    seedEvents();
    backend.table('tickets').add({
      'id': 'ticket-2',
      'title': 'Someone else',
      'status': 'open',
      'team_id': FakeBackend.teamId,
      'created_by': 'user-2',
      'assigned_to': 'user-2',
      'created_at': at(11),
    });

    await pumpCalendar(tester, themeMode: ThemeMode.dark);

    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Not mine'), findsNothing);
    expect(find.text('Someone else'), findsNothing);
    expect(find.text('Fix login'), findsOneWidget);
    expect(hasMarker(tester, 3), isTrue);
  });

  testWidgets('a fresh cache is used instead of the network', (tester) async {
    seedEvents();
    await pumpCalendar(
      tester,
      prefs: {
        'calendar_last_fetch_time': DateTime.now().toIso8601String(),
        'calendar_tasks': jsonEncode([
          {'id': 'cached', 'title': 'From cache', 'due_date': at(0)},
        ]),
        'calendar_tickets': jsonEncode([
          {'id': 'ct', 'title': 'Cached ticket', 'created_at': at(9)},
        ]),
        'calendar_meetings': jsonEncode([
          {'id': 'cm', 'title': null, 'meeting_date': at(16)},
        ]),
      },
    );

    expect(find.text('From cache'), findsOneWidget);
    expect(find.text('Cached ticket'), findsOneWidget);
    // A meeting without a title gets a placeholder.
    expect(find.text('Untitled Meeting'), findsOneWidget);
    expect(find.text('Write report'), findsNothing);
    expect(backend.log, isNot(contains('GET /rest/v1/tasks')));
  });

  testWidgets('a stale or broken cache falls back to the network',
      (tester) async {
    seedEvents();
    await pumpCalendar(
      tester,
      prefs: {
        'calendar_last_fetch_time': 'not a date',
        'calendar_tasks': 'not json',
      },
    );
    expect(find.text('Write report'), findsOneWidget);

    // Cache is valid but unreadable: still loads from the network.
    await tester.pumpWidget(const SizedBox());
    await pumpCalendar(
      tester,
      prefs: {
        'calendar_last_fetch_time': DateTime.now().toIso8601String(),
        'calendar_tasks': '{not json',
      },
    );
    expect(find.text('Write report'), findsOneWidget);
    expect(backend.log, contains('GET /rest/v1/tasks'));
  });

  testWidgets('selecting another day shows that day\'s events', (tester) async {
    seedEvents();
    // An event on another day of the visible month.
    final other = today.day == 15 ? 16 : 15;
    backend.table('meetings').add({
      'id': 'meeting-2',
      'title': 'Retro',
      'team_id': FakeBackend.teamId,
      'meeting_date':
          DateTime(today.year, today.month, other, 9).toIso8601String(),
    });
    await pumpCalendar(tester);
    expect(find.text('Retro'), findsNothing);

    await tester.tap(find.text('$other').first);
    await settle(tester);

    expect(find.text('Retro'), findsOneWidget);
    expect(find.text('Standup'), findsNothing);
  });

  testWidgets('tapping events opens their detail pages and reloads on change',
      (tester) async {
    seedEvents();
    await pumpCalendar(tester);

    await tester.tap(find.text('Write report'));
    await settle(tester);
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    backend.log.clear();
    Navigator.of(tester.element(find.byType(TaskDetailScreen))).pop(true);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.byType(TaskDetailScreen), findsNothing);
    // An update reloads the calendar from the network.
    expect(find.text('Write report'), findsOneWidget);

    await tester.tap(find.text('Fix login'));
    await settle(tester);
    expect(find.byType(TicketDetailScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(TicketDetailScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    await tester.tap(find.text('Standup'));
    await settle(tester);
    expect(find.byType(MeetingDetailScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(MeetingDetailScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  Future<void> openSlot(WidgetTester tester, String time) async {
    await tester.tap(find.text(time));
    await settle(tester);
  }

  for (final option in [
    ['Schedule a Meeting', CreateMeetingScreen],
    ['Create a Task', CreateTaskScreen],
    ['Create a Ticket', CreateTicketScreen],
  ]) {
    testWidgets('hour slot offers "${option[0]}"', (tester) async {
      await pumpCalendar(tester);

      await openSlot(tester, '3:00 am');
      expect(find.text('Create at 3:00 AM'), findsOneWidget);
      await tester.tap(find.text(option[0] as String));
      await settle(tester);

      final screen = find.byType(option[1] as Type);
      expect(screen, findsOneWidget);
      // Something was created: the calendar reloads with it, even though
      // its cache is still fresh.
      seedEvents();
      Navigator.of(tester.element(screen)).pop(true);
      await settle(tester);
      expect(find.text('Standup'), findsOneWidget);
    });
  }

  testWidgets('a task created from a day starts with that due date',
      (tester) async {
    await pumpCalendar(tester);

    await openSlot(tester, '3:00 am');
    await tester.tap(find.text('Create a Task'));
    await settle(tester);

    final screen =
        tester.widget<CreateTaskScreen>(find.byType(CreateTaskScreen));
    expect(screen.initialDueDate, today);
  });

  testWidgets('a task created from a past day has no due date prefilled',
      (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.text('1').first);
    await settle(tester);
    await openSlot(tester, '3:00 am');
    await tester.tap(find.text('Create a Task'));
    await settle(tester);

    final screen =
        tester.widget<CreateTaskScreen>(find.byType(CreateTaskScreen));
    expect(screen.initialDueDate, isNull);
  }, skip: today.day == 1);

  testWidgets('"Create with AI" opens chat with a prefilled request',
      (tester) async {
    await withFakeHttp(() async {
      backend.geminiHandler = (_) => FakeBackend.geminiText('Sure thing');
      await pumpCalendar(tester);

      await openSlot(tester, '9:00 am');
      await tester.tap(find.text('Create with Ell-ena AI'));
      await settle(tester);

      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      final y = today.year.toString();
      final m = today.month.toString().padLeft(2, '0');
      final d = today.day.toString().padLeft(2, '0');
      expect(
        chat.arguments,
        {'initial_message': 'I need to create a task for $y-$m-$d at 9:00 AM'},
      );

      // The chat sends it once its services are ready.
      await tester.pump(const Duration(milliseconds: 1100));
      await settle(tester);
      expect(
        find.text('I need to create a task for $y-$m-$d at 9:00 AM'),
        findsOneWidget,
      );
      expect(find.text('Sure thing'), findsOneWidget);
    });
  });

  testWidgets('shell refresh skips the cache', (tester) async {
    final key = GlobalKey();
    await pumpCalendar(
      tester,
      key: key,
      prefs: {'calendar_last_fetch_time': DateTime.now().toIso8601String()},
    );
    expect(find.text('Standup'), findsNothing);

    seedEvents();
    final refresh = (key.currentState as ShellRefreshable).refreshFromShell();
    await settle(tester);
    await refresh;

    expect(find.text('Standup'), findsOneWidget);
  });
}
