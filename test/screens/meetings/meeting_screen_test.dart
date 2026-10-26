import 'package:ell_ena/screens/meetings/create_meeting_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_detail_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_insights_screen.dart';
import 'package:ell_ena/screens/meetings/meeting_screen.dart';
import 'package:ell_ena/widgets/detail_side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'meeting_test_utils.dart';

void main() {
  final platform = PlatformFakes();

  setUpAll(setUpFakeSupabase);
  setUp(() async {
    await resetFakeSupabase();
    platform.install();
  });
  tearDown(platform.uninstall);

  Future<void> pumpMeetings(
    WidgetTester tester, {
    Size size = phoneSize,
    ThemeMode themeMode = ThemeMode.light,
    Key? key,
  }) async {
    await pumpApp(
      tester,
      MeetingScreen(key: key),
      size: size,
      themeMode: themeMode,
    );
    await settle(tester);
  }

  Future<void> showPast(WidgetTester tester) async {
    await tester.tap(find.text('Past').last);
    await tester.pumpAndSettle();
  }

  /// The upcoming and past counts in the header, in that order.
  List<String> headerCounts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => RegExp(r'^\d+$').hasMatch(s))
      .take(2)
      .toList();

  testWidgets('shows empty states for both filters', (tester) async {
    await pumpMeetings(tester);

    expect(find.text('No upcoming meetings'), findsOneWidget);
    expect(find.text('Create new meetings to get started'), findsOneWidget);
    expect(headerCounts(tester), ['0', '0']);

    await showPast(tester);
    expect(find.text('No past meetings'), findsOneWidget);
    expect(find.text('Past meetings will appear here'), findsOneWidget);
  });

  testWidgets('splits meetings into upcoming and past', (tester) async {
    backend.table('meetings').addAll([
      meetingRow(
          id: 'm1', title: 'Tomorrow call', offset: const Duration(days: 1)),
      meetingRow(
        id: 'm2',
        title: 'A very long meeting title that gets cut',
        offset: const Duration(days: 10),
        createdBy: 'user-2',
      ),
      meetingRow(
        id: 'm3',
        title: 'Done already',
        offset: const Duration(days: -3),
        extra: {'duration': 45},
      ),
      // Upcoming by date, but a summary means it already happened.
      meetingRow(
        id: 'm4',
        title: 'Summarised',
        offset: const Duration(days: 2),
        extra: {'ai_summary': 'Done'},
      ),
      meetingRow(
        id: 'm5',
        title: 'Long ago',
        offset: const Duration(days: -60),
        url: null,
      ),
      meetingRow(
        id: 'm6',
        title: 'Yesterday sync',
        offset: const Duration(days: -1),
        extra: {'transcription_status': 'completed'},
      ),
    ]);
    await pumpMeetings(tester);

    expect(headerCounts(tester), ['2', '4']);
    expect(find.text('Tomorrow call'), findsOneWidget);
    expect(find.text('A very long meeting title...'), findsOneWidget);
    expect(find.textContaining('Tomorrow, '), findsOneWidget);
    expect(find.text('Created by Ada'), findsOneWidget);
    expect(find.text('Created by Bob'), findsOneWidget);
    expect(find.text('Join'), findsNWidgets(2));
    // Only the admin's own and the admin-visible upcoming meetings can be
    // cancelled; the admin sees both.
    expect(find.byTooltip('Cancel Meeting'), findsNWidgets(2));
    expect(find.text('Done already'), findsNothing);

    await showPast(tester);
    expect(find.text('Done already'), findsOneWidget);
    expect(find.text('3 days ago'), findsNothing);
    expect(find.textContaining('3 days ago'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.textContaining('Yesterday, '), findsOneWidget);
    expect(find.text('Long ago'), findsOneWidget);
    expect(find.text('Summarised'), findsOneWidget);
    // Past meetings with a link offer transcript and summary.
    expect(find.text('Transcription'), findsNWidgets(3));
    expect(find.byTooltip('Cancel Meeting'), findsNothing);
  });

  testWidgets('members can only cancel meetings they created', (tester) async {
    await resetInTest(tester, role: 'member');
    backend.table('meetings').addAll([
      meetingRow(id: 'm1', title: 'Mine'),
      meetingRow(id: 'm2', title: 'Theirs', createdBy: 'user-2'),
      meetingRow(
        id: 'm3',
        title: 'Nobody',
        createdBy: 'ghost',
        extra: {'title': null},
      ),
    ]);
    await pumpMeetings(tester, themeMode: ThemeMode.dark);

    expect(find.byTooltip('Cancel Meeting'), findsOneWidget);
    expect(find.text('Untitled Meeting'), findsOneWidget);
    expect(find.text('Created by Unknown'), findsOneWidget);
  });

  testWidgets('cancelling a meeting deletes it and reloads', (tester) async {
    backend.table('meetings').add(meetingRow(title: 'Cancel me'));
    await pumpMeetings(tester);

    await tester.tap(find.byTooltip('Cancel Meeting'));
    await settle(tester);

    expect(backend.log, contains('DELETE /rest/v1/meetings'));
    expect(find.text('Cancel me'), findsNothing);
    expect(find.text('No upcoming meetings'), findsOneWidget);
  });

  testWidgets('shows the error when cancelling fails', (tester) async {
    backend.table('meetings').add(meetingRow(title: 'Stays'));
    await pumpMeetings(tester);
    backend.failures['meetings'] = 500;

    await tester.tap(find.byTooltip('Cancel Meeting'));
    await settle(tester);

    expect(find.textContaining('Error deleting meeting:'), findsOneWidget);
    expect(find.text('Stays'), findsOneWidget);
  });

  testWidgets('Join opens the meeting link externally', (tester) async {
    backend.table('meetings').add(meetingRow());
    await pumpMeetings(tester);

    await tester.tap(find.text('Join'));
    await settle(tester);

    final launch = platform.url.calls.singleWhere((c) => c.method == 'launch');
    final args = launch.arguments as Map;
    expect(args['url'], 'https://meet.google.com/abc-defg-hij');
    expect(args['useSafariVC'], isFalse);
  });

  testWidgets('Join reports a link that cannot be opened', (tester) async {
    platform.url.canLaunch = false;
    backend.table('meetings').add(meetingRow());
    await pumpMeetings(tester);

    await tester.tap(find.text('Join'));
    await settle(tester);

    expect(find.text('Could not launch meeting URL'), findsOneWidget);
  });

  testWidgets('Join reports an error from the launcher', (tester) async {
    backend.table('meetings').add(meetingRow(url: 'https://meet.google.com/x'));
    await pumpMeetings(tester);
    platform.url.error = PlatformException(code: 'boom');

    await tester.tap(find.text('Join'));
    await settle(tester);

    expect(find.textContaining('Error launching URL:'), findsOneWidget);
  });

  testWidgets('phones open a meeting as a page and reload on return',
      (tester) async {
    backend.table('meetings').add(meetingRow(title: 'Open me'));
    await pumpMeetings(tester);

    await tester.tap(find.text('Open me'));
    await settle(tester);
    expect(find.byType(MeetingDetailScreen), findsOneWidget);

    backend.log.clear();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.byType(MeetingDetailScreen), findsNothing);
    expect(backend.log, contains('GET /rest/v1/meetings'));
  });

  testWidgets('past meeting buttons open transcript and summary insights',
      (tester) async {
    backend.table('meetings').add(meetingRow(offset: const Duration(days: -2)));
    await pumpMeetings(tester);
    await showPast(tester);

    await tester.tap(find.text('Transcription'));
    await settle(tester);
    var insights = tester.widget<MeetingInsightsScreen>(
      find.byType(MeetingInsightsScreen),
    );
    expect(insights.initialTab, 'transcript');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await settle(tester);

    await tester.tap(find.text('AI Summary'));
    await settle(tester);
    insights = tester.widget<MeetingInsightsScreen>(
      find.byType(MeetingInsightsScreen),
    );
    expect(insights.initialTab, 'summary');
    expect(insights.meetingId, 'm1');
  });

  testWidgets('the add button opens the create form and reloads after saving',
      (tester) async {
    await pumpMeetings(tester);

    await tester.tap(find.byTooltip('New Meeting'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateMeetingScreen), findsOneWidget);

    // Simulate the form saving.
    backend.table('meetings').add(meetingRow(title: 'Fresh'));
    Navigator.of(tester.element(find.byType(CreateMeetingScreen))).pop(true);
    await settle(tester);

    expect(find.text('Fresh'), findsOneWidget);
  });

  testWidgets('wide screens show a grid and open details in a side panel',
      (tester) async {
    backend.table('meetings').addAll([
      for (var i = 1; i <= 4; i++)
        meetingRow(
          id: 'm$i',
          title: 'Meeting $i',
          offset: Duration(days: i + 2),
        ),
    ]);
    await pumpMeetings(tester, size: wideSize, themeMode: ThemeMode.dark);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Meeting 4'), findsOneWidget);
    // Three columns on the first row.
    final y1 = tester.getTopLeft(find.text('Meeting 1')).dy;
    expect(tester.getTopLeft(find.text('Meeting 3')).dy, y1);
    expect(tester.getTopLeft(find.text('Meeting 4')).dy, greaterThan(y1));

    await tester.tap(find.text('Meeting 2'));
    await settle(tester);
    expect(find.byType(DetailSidePanel), findsOneWidget);
    expect(
      tester
          .widget<MeetingDetailScreen>(find.byType(MeetingDetailScreen))
          .meetingId,
      'm2',
    );

    backend.log.clear();
    await tester.tap(find.byType(CloseButton));
    await settle(tester);
    expect(find.byType(DetailSidePanel), findsNothing);
    expect(backend.log, contains('GET /rest/v1/meetings'));
  });

  testWidgets('narrower wide windows use two columns', (tester) async {
    backend.table('meetings').addAll([
      meetingRow(id: 'm1', title: 'First'),
      meetingRow(id: 'm2', title: 'Second', offset: const Duration(days: 4)),
      meetingRow(id: 'm3', title: 'Third', offset: const Duration(days: 5)),
    ]);
    await pumpMeetings(tester, size: const Size(1024, 900));

    final y1 = tester.getTopLeft(find.text('First')).dy;
    expect(tester.getTopLeft(find.text('Second')).dy, y1);
    expect(tester.getTopLeft(find.text('Third')).dy, greaterThan(y1));
  });

  testWidgets('static hooks reload and open the create form', (tester) async {
    await pumpMeetings(tester, size: wideSize, key: MeetingScreen.globalKey);

    backend.table('meetings').add(meetingRow(title: 'Added elsewhere'));
    MeetingScreen.refreshMeetings();
    await settle(tester);
    expect(find.text('Added elsewhere'), findsOneWidget);

    MeetingScreen.openCreateMeeting();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(CreateMeetingScreen), findsOneWidget);
  });

  testWidgets('pull to refresh reloads without a spinner', (tester) async {
    await pumpMeetings(tester);
    backend.table('meetings').add(meetingRow(title: 'Pulled in'));

    await tester.fling(
      find.text('No upcoming meetings'),
      const Offset(0, 400),
      1000,
    );
    await settle(tester, frames: 20);

    expect(find.text('Pulled in'), findsOneWidget);
  });
}
