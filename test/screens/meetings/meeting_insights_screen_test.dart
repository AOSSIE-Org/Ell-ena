import 'dart:io';

import 'package:ell_ena/screens/meetings/meeting_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'meeting_test_utils.dart';

const _summary = {
  'key_discussion_points': ['Roadmap for Q4'],
  'important_decisions': ['Ship the beta'],
  'action_items': [
    {'item': 'Draft release notes', 'owner': 'Ada', 'deadline': '2026-11-01'},
    {'item': 'Book venue'},
  ],
  'meeting_highlights': ['Record attendance'],
  'follow_up_tasks': [
    {'task': 'Email the team', 'deadline': '2026-11-03'},
  ],
  'overall_summary': 'A productive planning session.',
};

const _transcript = [
  {'speaker': 'Ada', 'text': 'Let us begin.'},
  {'speaker': '', 'text': 'Agreed.'},
  {'text': 'Who said this?'},
];

void main() {
  final platform = PlatformFakes();

  setUpAll(setUpFakeSupabase);
  setUp(() async {
    await resetFakeSupabase();
    platform
      ..tempDir = null
      ..install();
  });
  tearDown(platform.uninstall);

  void seed({Object? transcript, Object? summary}) {
    backend.table('meetings').add(meetingRow(
          offset: const Duration(days: -2),
          extra: {
            'final_transcription': transcript,
            'meeting_summary_json': summary,
          },
        ));
  }

  Future<void> pumpInsights(
    WidgetTester tester, {
    String tab = 'transcript',
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpApp(
      tester,
      MeetingInsightsScreen(meetingId: 'm1', initialTab: tab),
      themeMode: themeMode,
    );
    await settle(tester);
  }

  testWidgets('transcript tab lists each speaker and their words',
      (tester) async {
    seed(transcript: _transcript, summary: _summary);
    await pumpInsights(tester);

    expect(find.text('Meeting Insights'), findsOneWidget);
    expect(find.text('Let us begin.'), findsOneWidget);
    expect(find.text('Agreed.'), findsOneWidget);
    // A blank speaker shows "?" in the avatar; a missing one falls back.
    expect(find.text('?'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
    expect(backend.log, contains('GET /rest/v1/meetings'));
  });

  testWidgets('summary tab shows every section of the AI summary',
      (tester) async {
    seed(transcript: _transcript, summary: _summary);
    await pumpInsights(tester, tab: 'summary', themeMode: ThemeMode.dark);

    expect(find.text('Key Discussion Points'), findsOneWidget);
    expect(find.text('Roadmap for Q4'), findsOneWidget);
    expect(find.text('Ship the beta'), findsOneWidget);
    expect(find.text('Draft release notes'), findsOneWidget);
    expect(
      find.text('Owner: Ada   •   Deadline: 2026-11-01'),
      findsOneWidget,
    );
    // Missing owner and deadline use the placeholders.
    expect(find.text('Owner: —   •   Deadline: N/A'), findsOneWidget);
    expect(find.text('Record attendance'), findsOneWidget);
    expect(find.text('Email the team'), findsOneWidget);
    expect(find.text('Owner:    •   Deadline: 2026-11-03'), findsOneWidget);
    expect(find.text('A productive planning session.'), findsOneWidget);
  });

  testWidgets('empty sections render without bullets or items', (tester) async {
    seed(summary: {'overall_summary': 'Short call.'});
    await pumpInsights(tester, tab: 'summary');

    expect(find.text('Short call.'), findsOneWidget);
    expect(find.text('• '), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('shows placeholders when nothing was recorded', (tester) async {
    seed();
    await pumpInsights(tester);

    expect(find.text('No transcription available'), findsOneWidget);
    await tester.tap(find.text('AI Summary'));
    await tester.pumpAndSettle();
    expect(find.text('No AI summary generated yet'), findsOneWidget);
  });

  testWidgets('downloads the transcript as a PDF into the temp directory',
      (tester) async {
    platform.tempDir = makeTempDir();
    seed(transcript: _transcript, summary: _summary);
    await pumpInsights(tester);

    await tester.tap(find.byTooltip('Download PDF'));
    await pumpUntilFound(tester, find.textContaining('Saved to'));

    final saved = Directory(platform.tempDir!).listSync();
    expect(saved, hasLength(1));
    expect(saved.single.path, contains('Meeting_Transcription_'));
    expect(saved.single.path, endsWith('.pdf'));
    expect(find.text('Saved to ${saved.single.path}'), findsOneWidget);
  });

  testWidgets('downloads the summary as a PDF', (tester) async {
    platform.tempDir = makeTempDir();
    seed(transcript: _transcript, summary: _summary);
    await pumpInsights(tester, tab: 'summary');

    await tester.tap(find.byTooltip('Download PDF'));
    await pumpUntilFound(tester, find.textContaining('Saved to'));

    final saved = Directory(platform.tempDir!).listSync();
    expect(saved.single.path, contains('AI_Summary_'));
  });

  testWidgets('PDFs still save when nothing was recorded', (tester) async {
    platform.tempDir = makeTempDir();
    backend.table('meetings').add(meetingRow(
          offset: const Duration(days: -2),
          extra: {'meeting_date': null},
        ));
    await pumpInsights(tester);

    await tester.tap(find.byTooltip('Download PDF'));
    await pumpUntilFound(tester, find.textContaining('Saved to'));
    expect(Directory(platform.tempDir!).listSync(), hasLength(1));

    await tester.tap(find.text('AI Summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download PDF'));
    await pumpUntilFound(
      tester,
      find.textContaining('AI_Summary_'),
    );
    expect(Directory(platform.tempDir!).listSync(), hasLength(2));
  });

  testWidgets('reports a PDF error when there is nowhere to save',
      (tester) async {
    seed(transcript: _transcript);
    await pumpInsights(tester);

    await tester.tap(find.byTooltip('Download PDF'));
    await pumpUntilFound(tester, find.textContaining('PDF error'));

    expect(find.textContaining('PDF error'), findsOneWidget);
  });
}
