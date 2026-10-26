import 'package:ell_ena/screens/home/dashboard_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_detail_screen.dart';
import 'package:ell_ena/screens/tasks/task_detail_screen.dart';
import 'package:ell_ena/screens/tickets/ticket_detail_screen.dart';
import 'package:ell_ena/shell/shell_refreshable.dart';
import 'package:ell_ena/widgets/custom_widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime d) => d.toIso8601String();

  Map<String, dynamic> task(
    String id,
    String status, {
    String? title,
    DateTime? due,
    DateTime? updated,
  }) =>
      {
        'id': id,
        'title': title,
        'description': 'about $id',
        'status': status,
        'approval_status': 'approved',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'due_date': due == null ? null : iso(due),
        'created_at': iso(today.subtract(const Duration(days: 20))),
        'updated_at': updated == null ? null : iso(updated),
      };

  void seedWorkspace() {
    backend.table('tasks').addAll([
      task('t-today', 'todo',
          title: 'Due today', due: today.add(const Duration(hours: 9))),
      task('t-untitled', 'in_progress',
          due: today.add(const Duration(hours: 10))),
      task('t-done', 'completed',
          title: 'Done today', due: today, updated: now),
      task('t-old', 'completed',
          title: 'Done earlier',
          updated: today.subtract(const Duration(days: 2))),
    ]);
    backend.table('tickets').addAll([
      {
        'id': 'k-open',
        'ticket_number': 'TKT-1',
        'title': 'Open ticket',
        'description': 'x',
        'category': 'Bug',
        'status': 'open',
        'priority': 'high',
        'approval_status': 'approved',
        'team_id': FakeBackend.teamId,
        'created_by': FakeBackend.userId,
        'created_at': iso(today.add(const Duration(hours: 8))),
      },
      {
        'id': 'k-done',
        'title': 'Resolved ticket',
        'status': 'resolved',
        'priority': 'low',
        'team_id': FakeBackend.teamId,
        'created_at': iso(today.subtract(const Duration(days: 3))),
      },
    ]);
    backend.table('meetings').addAll([
      {
        'id': 'm-soon',
        'title': 'Planning',
        'team_id': FakeBackend.teamId,
        'meeting_date': iso(now.add(const Duration(days: 2))),
      },
      {
        'id': 'm-untitled',
        'title': null,
        'team_id': FakeBackend.teamId,
        'meeting_date': iso(now.add(const Duration(days: 3))),
      },
      {
        'id': 'm-far',
        'title': 'Next quarter',
        'team_id': FakeBackend.teamId,
        'meeting_date': iso(now.add(const Duration(days: 40))),
      },
    ]);
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(480, 2600),
    ThemeMode themeMode = ThemeMode.light,
    Key? key,
  }) async {
    await pumpApp(
      tester,
      DashboardScreen(key: key),
      size: size,
      themeMode: themeMode,
    );
    await settle(tester);
  }

  /// The number above an overview label.
  String overviewValue(WidgetTester tester, String label) {
    final card =
        find.ancestor(of: find.text(label), matching: find.byType(Column));
    final texts = tester
        .widgetList<Text>(
            find.descendant(of: card.first, matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    return texts.first!;
  }

  testWidgets('counts, upcoming items and recent activity come from the team',
      (tester) async {
    seedWorkspace();
    await pumpDashboard(tester);

    expect(find.text('Ada'), findsOneWidget);
    expect(overviewValue(tester, 'Total Tasks'), '4');
    expect(overviewValue(tester, 'Completed'), '2');
    expect(overviewValue(tester, 'Open Tickets'), '1');
    expect(overviewValue(tester, 'Resolved'), '1');
    // Two of four tasks completed.
    expect(find.text('+50%'), findsOneWidget);

    // Upcoming: open tasks due today, today's open tickets, meetings within
    // two weeks. Completed tasks and far-off meetings are left out.
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Open ticket'), findsWidgets);
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Next quarter'), findsNothing);
    // Items without a title are named by type.
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Meeting'), findsOneWidget);

    expect(find.text('Task: Done today'), findsOneWidget);
    expect(find.text('Ticket: Open ticket'), findsOneWidget);
    expect(find.text('Status: completed'), findsWidgets);

    // Week view: a bar per day, today's completion in the last bar.
    final bars = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
    expect(bars, hasLength(7));
    expect(bars.last.barRods.single.toY, 1);
    expect(bars[4].barRods.single.toY, 1);
  });

  testWidgets('month view plots completions by day of month', (tester) async {
    seedWorkspace();
    await pumpDashboard(tester, themeMode: ThemeMode.dark);

    await tester.tap(find.text('Month'));
    await tester.pump();

    final line = tester.widget<LineChart>(find.byType(LineChart));
    final spots = line.data.lineBarsData.single.spots;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    expect(spots, hasLength(daysInMonth));
    expect(spots[now.day - 1].y, greaterThanOrEqualTo(1));
    // Done today, plus "done earlier" (two days ago) if still this month.
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    expect(
      spots.fold<double>(0, (sum, s) => sum + s.y),
      twoDaysAgo.month == now.month ? 2 : 1,
    );

    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.byType(BarChart), findsOneWidget);
  });

  for (final entry in {
    'Due today': TaskDetailScreen,
    'Planning': MeetingDetailScreen,
  }.entries) {
    testWidgets('tapping upcoming "${entry.key}" opens its details',
        (tester) async {
      seedWorkspace();
      await pumpDashboard(tester);

      await tester.tap(find.text(entry.key));
      await settle(tester);
      expect(find.byType(entry.value), findsOneWidget);
    });
  }

  testWidgets('tapping an upcoming ticket opens its details', (tester) async {
    seedWorkspace();
    await pumpDashboard(tester);

    // Listed under Upcoming and Recent Activity; Upcoming comes first.
    await tester.tap(find.text('Open ticket').first);
    await settle(tester);
    expect(find.byType(TicketDetailScreen), findsOneWidget);
  });

  testWidgets('switches team from the phone header', (tester) async {
    seedWorkspace();
    backend.seedSecondTeam();
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await settle(tester);
    backend.moveUserToSecondTeam();
    await tester.tap(find.text('Difference Engines'));
    await settle(tester);

    // Reloaded for team 2, which has none of team 1's tasks.
    expect(find.text('Difference Engines'), findsOneWidget);
    expect(overviewValue(tester, 'Total Tasks'), '0');
  });

  testWidgets('a failed team switch shows the error', (tester) async {
    backend.seedSecondTeam(withTeamRow: false);
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await settle(tester);
    await tester.tap(find.text('Difference Engines'));
    await settle(tester);

    expect(
      find.text('Error switching team: User is not a member of this team'),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh and shell refresh reload the data',
      (tester) async {
    final key = GlobalKey();
    await pumpDashboard(tester, key: key);
    expect(overviewValue(tester, 'Total Tasks'), '0');

    seedWorkspace();
    final pull = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    await pull;
    expect(overviewValue(tester, 'Total Tasks'), '4');

    backend.table('tasks').clear();
    final refresh = (key.currentState as ShellRefreshable).refreshFromShell();
    await settle(tester);
    await refresh;
    expect(overviewValue(tester, 'Total Tasks'), '0');
  });

  testWidgets('a broken profile still ends loading with an empty chart',
      (tester) async {
    backend.table('users').first['teams'] = 'not a map';
    await pumpDashboard(tester);

    expect(find.byType(DashboardLoadingSkeleton), findsNothing);
    expect(find.text('No completions yet'), findsOneWidget);
  });

  test('dot pattern paints a dot every 30px and never repaints', () {
    final canvas = _RecordingCanvas();
    final painter = DotPatternPainter(color: Colors.white);
    painter.paint(canvas, const Size(90, 60));

    expect(canvas.circles, const [
      Offset(0, 0),
      Offset(0, 30),
      Offset(30, 0),
      Offset(30, 30),
      Offset(60, 0),
      Offset(60, 30),
    ]);
    expect(
      painter.shouldRepaint(DotPatternPainter(color: Colors.black)),
      isFalse,
    );
  });
}

class _RecordingCanvas extends Fake implements Canvas {
  final circles = <Offset>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles.add(c);
}
