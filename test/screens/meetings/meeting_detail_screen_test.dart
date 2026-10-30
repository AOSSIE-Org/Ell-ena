import 'dart:convert';

import 'package:ell_ena/screens/meetings/meeting_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'meeting_test_utils.dart';

const _summary = {
  'overall_summary': 'We agreed on the launch plan.',
  'meeting_highlights': ['Beta is feature complete'],
  'key_discussion_points': <String>[],
  'action_items': [
    {'item': 'Write launch post', 'owner': 'Ada', 'deadline': '2026-11-02'},
    {'item': 'Call the printer'},
  ],
  'follow_up_tasks': [
    {'task': 'Send invites', 'deadline': '2026-11-05'},
    {'task': 'Collect feedback', 'deadline': 'N/A'},
  ],
};

void main() {
  final platform = PlatformFakes();

  setUpAll(setUpFakeSupabase);
  setUp(() async {
    await resetFakeSupabase();
    platform
      ..clipboard.clear()
      ..install();
  });
  tearDown(platform.uninstall);

  void seed({
    Duration offset = const Duration(days: 3),
    String? url = 'https://meet.google.com/abc-defg-hij',
    String createdBy = FakeBackend.userId,
    Map<String, dynamic> extra = const {},
  }) {
    backend.table('meetings').add(meetingRow(
          offset: offset,
          url: url,
          createdBy: createdBy,
          extra: extra,
        ));
  }

  // Tall enough that the whole detail list is built without scrolling.
  const tallPhone = Size(420, 2600);

  Future<void> pumpDetail(
    WidgetTester tester, {
    Size size = tallPhone,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpApp(
      tester,
      const MeetingDetailScreen(meetingId: 'm1'),
      size: size,
      themeMode: themeMode,
    );
    await settle(tester);
  }

  Future<PushedResult> pushDetail(WidgetTester tester) =>
      pumpPushed(tester, const MeetingDetailScreen(meetingId: 'm1'));

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  group('upcoming meeting', () {
    testWidgets('shows the schedule, link, and bot controls', (tester) async {
      seed(extra: {'meeting_number': null});
      await pumpDetail(tester);

      expect(find.text('Meeting Details'), findsOneWidget);
      expect(find.text('MTG-???'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Weekly planning'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(
        find.text('https://meet.google.com/abc-defg-hij'),
        findsOneWidget,
      );
      expect(find.text('Transcription: Not started'), findsOneWidget);
      expect(find.text('Call Bot'), findsOneWidget);
      expect(find.text('Fetch Summary'), findsNothing);
      expect(find.text('Join Meeting'), findsOneWidget);
      // Summaries are only managed after the meeting.
      expect(find.text('Manage Tasks'), findsNothing);
      expect(find.byTooltip('Edit Meeting'), findsOneWidget);
      expect(find.byTooltip('Delete Meeting'), findsOneWidget);
    });

    testWidgets('a member who did not create it cannot edit or delete',
        (tester) async {
      await resetInTest(tester, role: 'member');
      seed(createdBy: 'user-2', extra: {'title': null});
      await pumpDetail(tester, size: wideSize, themeMode: ThemeMode.dark);

      expect(find.text('Untitled Meeting'), findsOneWidget);
      expect(find.byTooltip('Edit Meeting'), findsNothing);
      expect(find.byTooltip('Delete Meeting'), findsNothing);
    });

    testWidgets('the creator can edit even without the admin role',
        (tester) async {
      await resetInTest(tester, role: 'member');
      seed();
      await pumpDetail(tester);

      expect(find.byTooltip('Edit Meeting'), findsOneWidget);
    });

    testWidgets('copies the meeting link', (tester) async {
      seed();
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Copy URL'));
      await settle(tester);

      expect(platform.clipboard, ['https://meet.google.com/abc-defg-hij']);
      expect(find.text('Meeting URL copied to clipboard'), findsOneWidget);
    });

    testWidgets('opens the meeting link from the link row and Join button',
        (tester) async {
      seed();
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Open URL'));
      await settle(tester);
      await tapText(tester, 'Join Meeting');

      final launches =
          platform.url.calls.where((c) => c.method == 'launch').toList();
      expect(launches, hasLength(2));
      expect(
        (launches.first.arguments as Map)['url'],
        'https://meet.google.com/abc-defg-hij',
      );
    });

    testWidgets('says so when the link cannot be opened', (tester) async {
      platform.url.canLaunch = false;
      seed();
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Open URL'));
      await settle(tester);

      expect(find.text('Could not launch meeting URL'), findsOneWidget);
      expect(
          platform.url.calls.map((c) => c.method), isNot(contains('launch')));
    });

    testWidgets('calls the bot and then shows it in progress', (tester) async {
      seed();
      backend.functions['start-bot'] = (body) {
        backend.table('meetings').single['bot_started_at'] =
            DateTime.now().toUtc().toIso8601String();
        return {'bot_id': 'bot-1'};
      };
      await pumpDetail(tester);

      await tapText(tester, 'Call Bot');

      expect(backend.functionBodies('start-bot').single, {
        'meeting_id': 'm1',
        'meeting_url': 'https://meet.google.com/abc-defg-hij',
      });
      expect(find.text('Bot called'), findsOneWidget);
      expect(find.text('Transcription: In progress'), findsOneWidget);
      expect(find.text('Call Bot'), findsNothing);
      expect(find.text('Fetch Summary'), findsOneWidget);
    });

    testWidgets('shows the bot error from the Edge Function', (tester) async {
      seed();
      backend.functions['start-bot'] =
          (_) => throw FakeHttpError(502, {'error': 'Vexa is down'});
      await pumpDetail(tester);

      await tapText(tester, 'Call Bot');

      expect(find.text("Couldn't call the bot. Please try again."),
          findsOneWidget);
      expect(find.textContaining('Vexa'), findsNothing);
      expect(find.text('Call Bot'), findsOneWidget);
    });

    testWidgets('meetings without a Meet link show no transcription controls',
        (tester) async {
      seed(url: 'https://zoom.us/j/42');
      await pumpDetail(tester);

      expect(find.textContaining('Transcription:'), findsNothing);
      expect(find.text('Call Bot'), findsNothing);
      expect(find.text('Join Meeting'), findsOneWidget);
    });

    testWidgets('meetings with no link or description hide those cards',
        (tester) async {
      seed(url: null, extra: {'description': null});
      await pumpDetail(tester);

      expect(find.text('Meeting URL'), findsNothing);
      expect(find.text('Description'), findsNothing);
      expect(find.text('Join Meeting'), findsNothing);
    });
  });

  group('in-progress meeting', () {
    testWidgets('stays upcoming and editable until it ends', (tester) async {
      // Started ten minutes ago; the fixture lasts 30 minutes.
      seed(offset: const Duration(minutes: -10));
      await pumpDetail(tester);

      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.byTooltip('Edit Meeting'), findsOneWidget);
      expect(find.byTooltip('Delete Meeting'), findsOneWidget);
      expect(find.text('Join Meeting'), findsOneWidget);
    });

    testWidgets('becomes past once its duration is over', (tester) async {
      seed(offset: const Duration(minutes: -31));
      await pumpDetail(tester);

      expect(find.text('PAST'), findsOneWidget);
      expect(find.byTooltip('Edit Meeting'), findsNothing);
    });
  });

  group('localisation', () {
    testWidgets('bot controls and summary titles follow the app language',
        (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'meeting_summary_json': _summary},
      );
      await pumpApp(
        tester,
        const MeetingDetailScreen(meetingId: 'm1'),
        size: tallPhone,
        locale: const Locale('hi'),
      );
      await settle(tester);

      expect(find.text('बॉट बुलाएं'), findsOneWidget);
      expect(find.text('मीटिंग की मुख्य बातें'), findsOneWidget);
      expect(find.text('Call Bot'), findsNothing);
      expect(find.text('Highlights'), findsNothing);
    });
  });

  group('transcription status', () {
    Future<void> expectStatus(
      WidgetTester tester,
      Map<String, dynamic> extra,
      String status, {
      Duration offset = const Duration(days: -2),
    }) async {
      seed(offset: offset, extra: extra);
      await pumpDetail(tester);
      expect(find.text('Transcription: $status'), findsOneWidget);
    }

    testWidgets('completed once a transcript exists', (tester) async {
      await expectStatus(tester, {'transcription': 'Hello'}, 'Completed');
    });

    testWidgets('attempted after a failed fetch', (tester) async {
      await expectStatus(
        tester,
        {'transcription_attempted_at': '2026-10-01T00:00:00Z'},
        'Attempted',
      );
    });

    testWidgets('pending for a past Meet call with no bot', (tester) async {
      await expectStatus(tester, {}, 'Pending');
      expect(find.text('PAST'), findsOneWidget);
      // Nothing to fetch until a bot has joined.
      expect(find.text('Fetch Summary'), findsNothing);
    });
  });

  group('past meeting summary', () {
    testWidgets('renders the structured summary and manage sections',
        (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'meeting_summary_json': _summary},
      );
      await pumpDetail(tester, themeMode: ThemeMode.dark);

      expect(find.text('We agreed on the launch plan.'), findsOneWidget);
      expect(find.text('Beta is feature complete'), findsOneWidget);
      // Empty key points.
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Write launch post'), findsNWidgets(2));
      expect(find.text('Owner: Ada  •  Deadline: 2026-11-02'), findsOneWidget);
      expect(find.text('Call the printer'), findsNWidgets(2));
      expect(find.text('Manage Important Discussion'), findsOneWidget);
      expect(
        find.text('Owner: Ada   •   Deadline: 2026-11-02'),
        findsOneWidget,
      );
      expect(find.text('Send invites'), findsOneWidget);
      expect(find.text('Deadline: 2026-11-05'), findsOneWidget);
    });

    testWidgets('reads a summary stored as a JSON string', (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {
          'meeting_summary_json': jsonEncode({
            'overall_summary': 'Decoded summary',
            'action_items': <Object>[],
            'follow_up_tasks': <Object>[],
          }),
        },
      );
      await pumpDetail(tester);

      expect(find.text('Decoded summary'), findsOneWidget);
      // Highlights, key points, and action items are all empty.
      expect(find.text('None'), findsNWidgets(3));
      expect(find.text('No action items detected'), findsOneWidget);
      expect(find.text('No follow-up tasks detected'), findsOneWidget);
    });

    testWidgets('falls back to the markdown summary', (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {
          'meeting_summary_json': 'not json',
          'ai_summary': '**Launch** is on track',
        },
      );
      await pumpDetail(tester);

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('AI summary not available yet.'), findsOneWidget);
    });

    testWidgets('creates a ticket from an action item', (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'meeting_summary_json': _summary},
      );
      await pumpDetail(tester);

      await tester.ensureVisible(find.text('Manage Important Discussion'));
      await tester.tap(find.text('Write launch post').last);
      await settle(tester);

      final ticket =
          backend.bodiesFor('POST', '/rest/v1/tickets').single as Map;
      expect(ticket['title'], 'Write launch post');
      expect(ticket['category'], 'Meeting Discussion');
      expect(ticket['priority'], 'medium');
      expect(
        ticket['description'],
        'Created from meeting action item. Owner: Ada • Deadline: 2026-11-02',
      );
      expect(find.text('Ticket created'), findsOneWidget);
    });

    testWidgets('reports a ticket that could not be created', (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {
          'meeting_summary_json': {
            'action_items': [<String, dynamic>{}],
          },
        },
      );
      await pumpDetail(tester);
      backend.failures['tickets'] = 500;

      await tapText(tester, 'Action Item');

      expect(find.textContaining('Failed to create ticket:'), findsOneWidget);
    });

    testWidgets('creates tasks from follow-ups with parsed deadlines',
        (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'meeting_summary_json': _summary},
      );
      await pumpDetail(tester);

      await tapText(tester, 'Send invites');
      await clearSnackBars(tester);
      await tapText(tester, 'Collect feedback');

      final tasks = backend.bodiesFor('POST', '/rest/v1/tasks');
      expect(tasks, hasLength(2));
      final first = tasks.first as Map;
      expect(first['title'], 'Send invites');
      expect(first['description'], 'Created from meeting follow-up task');
      expect(
          DateTime.parse(first['due_date'] as String), DateTime(2026, 11, 5));
      // "N/A" is not a date.
      expect((tasks.last as Map).containsKey('due_date'), isFalse);
      expect(find.text('Task created'), findsOneWidget);
    });

    testWidgets('ignores deadlines that are not dates', (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {
          'meeting_summary_json': {
            'follow_up_tasks': [
              {'deadline': 'next week'},
              {'task': 'Blank', 'deadline': ' '},
              {'task': 'Missing'},
            ],
          },
        },
      );
      await pumpDetail(tester);

      await tapText(tester, 'Follow-up Task');
      await clearSnackBars(tester);
      await tapText(tester, 'Blank');
      await clearSnackBars(tester);
      await tapText(tester, 'Missing');

      final tasks = backend.bodiesFor('POST', '/rest/v1/tasks');
      expect(tasks.map((t) => (t as Map)['title']),
          ['Follow-up Task', 'Blank', 'Missing']);
      expect(tasks.every((t) => !(t as Map).containsKey('due_date')), isTrue);
    });

    testWidgets('reports a task that could not be created', (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'meeting_summary_json': _summary},
      );
      await pumpDetail(tester);
      backend.failures['tasks'] = 500;

      await tapText(tester, 'Send invites');

      expect(find.textContaining('Failed to create task:'), findsOneWidget);
    });

    testWidgets('fetches, summarizes, and embeds the transcript',
        (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'bot_started_at': '2026-10-01T00:00:00Z'},
      );
      backend.functions['fetch-transcript'] = (_) => {'segments': 3};
      backend.functions['summarize-transcription'] = (_) {
        backend.table('meetings').single
          ..['ai_summary'] = 'Fresh summary'
          ..['transcription'] = 'Hello world';
        return {'ok': true};
      };
      backend.functions['generate-embeddings'] = (_) => {'ok': true};
      await pumpDetail(tester);

      await tapText(tester, 'Fetch Summary');

      expect(
        backend.functionCalls,
        ['fetch-transcript', 'summarize-transcription', 'generate-embeddings'],
      );
      expect(find.text('Summary ready'), findsOneWidget);
      expect(find.text('Fresh summary'), findsOneWidget);
      expect(find.text('Transcription: Completed'), findsOneWidget);
    });

    testWidgets('says the summary could not be fetched without raw errors',
        (tester) async {
      seed(
        offset: const Duration(days: -2),
        extra: {'bot_started_at': '2026-10-01T00:00:00Z'},
      );
      backend.functions['fetch-transcript'] =
          (_) => throw FakeHttpError(404, {'error': 'No transcript yet'});
      await pumpDetail(tester);

      await tapText(tester, 'Fetch Summary');

      expect(
        find.text(
            "Couldn't fetch the summary. The transcript may not be ready yet, so try again later."),
        findsOneWidget,
      );
      expect(find.text('No transcript yet'), findsNothing);
      expect(find.text('Fetch Summary'), findsOneWidget);
    });
  });

  group('editing', () {
    Finder field(String label) => find.widgetWithText(TextFormField, label);

    Future<void> saveWithCheck(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Save Changes'));
      await settle(tester);
    }

    testWidgets('saves the edited fields and returns to the details',
        (tester) async {
      seed();
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Meeting'), findsOneWidget);

      await tester.enterText(field('Title'), 'Renamed sync');
      await tester.enterText(field('Description'), 'New agenda');
      await tester.enterText(field('Duration (minutes)'), '90');
      await saveWithCheck(tester);

      final patch = backend.bodiesFor('PATCH', '/rest/v1/meetings').single
          as Map<String, dynamic>;
      expect(patch['title'], 'Renamed sync');
      expect(patch['description'], 'New agenda');
      expect(patch['duration_minutes'], 90);
      expect(patch['meeting_url'], 'https://meet.google.com/abc-defg-hij');
      expect(find.text('Meeting Details'), findsOneWidget);
      expect(find.text('Renamed sync'), findsOneWidget);
    });

    testWidgets('picks a new date and time from the pickers', (tester) async {
      seed();
      await pumpDetail(tester);
      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.access_time));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settle(tester);

      final patch =
          backend.bodiesFor('PATCH', '/rest/v1/meetings').single as Map;
      expect(DateTime.parse(patch['meeting_date'] as String).day, 20);
    });

    testWidgets('normalises blank and invalid input', (tester) async {
      seed(url: 'https://zoom.us/j/1');
      await pumpDetail(tester);
      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ellena AI transcription only works with Google Meet URLs'),
        findsOneWidget,
      );

      await tester.enterText(field('Meeting URL'), '');
      await tester.enterText(field('Duration (minutes)'), 'soon');
      await saveWithCheck(tester);
      var patch = backend.bodiesFor('PATCH', '/rest/v1/meetings').last as Map;
      expect(patch['meeting_url'], isNull);
      expect(patch['duration_minutes'], 60);
      expect(patch.containsKey('transcription'), isFalse);
      expect(patch.containsKey('ai_summary'), isFalse);

      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Duration (minutes)'), '-10');
      await saveWithCheck(tester);
      patch = backend.bodiesFor('PATCH', '/rest/v1/meetings').last as Map;
      expect(patch['duration_minutes'], 60);

      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Duration (minutes)'), '');
      await saveWithCheck(tester);
      patch = backend.bodiesFor('PATCH', '/rest/v1/meetings').last as Map;
      expect(patch.containsKey('duration_minutes'), isFalse);
    });

    testWidgets('refuses an empty title', (tester) async {
      seed();
      await pumpDetail(tester);
      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Title'), '   ');
      await saveWithCheck(tester);

      expect(find.text('Title cannot be empty'), findsOneWidget);
      expect(backend.bodiesFor('PATCH', '/rest/v1/meetings'), isEmpty);
    });

    testWidgets('keeps the form open when saving fails', (tester) async {
      seed();
      await pumpDetail(tester);
      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle();
      backend.failures['meetings'] = 500;

      await saveWithCheck(tester);

      expect(find.textContaining('Error updating meeting:'), findsOneWidget);
      expect(find.text('Edit Meeting'), findsOneWidget);
    });
  });

  group('deleting and loading', () {
    testWidgets('cancelling the dialog keeps the meeting', (tester) async {
      seed();
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Delete Meeting'));
      await tester.pumpAndSettle();
      expect(
        find.text('Are you sure you want to delete this meeting? '
            'This action cannot be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(backend.log, isNot(contains('DELETE /rest/v1/meetings')));
      expect(find.text('Sync'), findsOneWidget);
    });

    testWidgets('deletes the meeting and closes with true', (tester) async {
      seed();
      final launcher = await pushDetail(tester);

      await tester.tap(find.byTooltip('Delete Meeting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(backend.log, contains('DELETE /rest/v1/meetings'));
      expect(backend.table('meetings'), isEmpty);
      expect(launcher.popped, isTrue);
      expect(launcher.value, isTrue);
    });

    testWidgets('reports a delete that failed', (tester) async {
      seed();
      await pumpDetail(tester);

      await tester.tap(find.byTooltip('Delete Meeting'));
      await tester.pumpAndSettle();
      backend.failures['meetings'] = 500;
      await tester.tap(find.text('Delete'));
      await settle(tester);

      expect(find.textContaining('Error deleting meeting:'), findsOneWidget);
      expect(backend.table('meetings'), hasLength(1));
    });

    testWidgets('closes with a message when the meeting is gone',
        (tester) async {
      final launcher = await pushDetail(tester);
      await tester.pumpAndSettle();

      expect(launcher.popped, isTrue);
      expect(launcher.value, isNull);
      expect(find.text('Meeting not found'), findsOneWidget);
    });

    testWidgets('shows the load error for a malformed meeting', (tester) async {
      backend.table('meetings').add(meetingRow(meetingDate: 'not a date'));
      await pumpDetail(tester);

      expect(
        find.textContaining('Error loading meeting details:'),
        findsOneWidget,
      );
      expect(find.text('Meeting not found'), findsOneWidget);
    });
  });
}
