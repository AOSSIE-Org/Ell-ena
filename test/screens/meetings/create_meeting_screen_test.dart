import 'dart:convert';

import 'package:ell_ena/screens/meetings/create_meeting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/test_harness.dart';
import 'meeting_test_utils.dart';

void main() {
  final platform = PlatformFakes();

  setUpAll(setUpFakeSupabase);
  setUp(() async {
    await resetFakeSupabase();
    platform
      ..googleAccount = null
      ..googleAccessToken = 'google-token'
      ..googleCalls.clear()
      ..install();
  });
  tearDown(platform.uninstall);

  Finder field(String label) => find.widgetWithText(TextFormField, label).first;

  Future<PushedResult> openForm(WidgetTester tester) =>
      pumpPushed(tester, CreateMeetingScreen());

  /// Picks the 15th of next month, which is always in the future.
  Future<void> pickFutureDate(WidgetTester tester) async {
    await tester.tap(find.text('Select Date *'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> pickTime(WidgetTester tester) async {
    await tester.tap(find.text('Select Time *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> tapCreate(WidgetTester tester) async {
    final button = find.widgetWithText(ElevatedButton, 'Create Meeting');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  testWidgets('validates title and duration before anything else',
      (tester) async {
    await openForm(tester);

    await tester.enterText(field('Duration (minutes)'), '0');
    await tapCreate(tester);
    expect(find.text('Please enter a title'), findsOneWidget);
    expect(find.text('Duration must be greater than 0'), findsOneWidget);

    await tester.enterText(field('Duration (minutes)'), 'ten');
    await tapCreate(tester);
    expect(find.text('Please enter a valid number'), findsOneWidget);
    expect(backend.bodiesFor('POST', '/rest/v1/meetings'), isEmpty);
  });

  testWidgets('asks for a date, then a time, before saving', (tester) async {
    await openForm(tester);
    await tester.enterText(field('Title *'), 'Retro');

    await tapCreate(tester);
    expect(find.text('Please select a date'), findsOneWidget);
    await clearSnackBars(tester);

    await pickFutureDate(tester);
    await tapCreate(tester);
    expect(find.text('Please select a time'), findsOneWidget);
    expect(backend.bodiesFor('POST', '/rest/v1/meetings'), isEmpty);
  });

  testWidgets('rejects meeting links that are not Google Meet', (tester) async {
    await openForm(tester);
    await tester.enterText(field('Title *'), 'Retro');
    await pickFutureDate(tester);
    await pickTime(tester);

    await tester.enterText(field('Google Meet URL'), 'https://zoom.us/j/1');
    await tester.pump();
    expect(
      find.text('Ellena AI transcription only works with Google Meet URLs'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error), findsOneWidget);

    await tapCreate(tester);
    expect(
      find.text('Only Google Meet URLs are supported for transcription'),
      findsOneWidget,
    );

    await tester.enterText(
      field('Google Meet URL'),
      'https://meet.google.com/abc-defg-hij',
    );
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(backend.bodiesFor('POST', '/rest/v1/meetings'), isEmpty);
  });

  testWidgets('creates the meeting and closes with true', (tester) async {
    final launcher = await openForm(tester);
    await tester.enterText(field('Title *'), '  Planning  ');
    await tester.enterText(field('Description'), 'Quarterly goals');
    await tester.enterText(field('Duration (minutes)'), '45');
    await tester.enterText(
      field('Google Meet URL'),
      'https://meet.google.com/abc-defg-hij',
    );
    await pickFutureDate(tester);
    await pickTime(tester);

    await tapCreate(tester);
    await tester.pumpAndSettle();

    final body = backend.bodiesFor('POST', '/rest/v1/meetings').single as Map;
    expect(body['title'], 'Planning');
    expect(body['description'], 'Quarterly goals');
    expect(body['duration_minutes'], 45);
    expect(body['meeting_url'], 'https://meet.google.com/abc-defg-hij');
    expect(body['team_id'], FakeBackend.teamId);
    expect(DateTime.parse(body['meeting_date'] as String).day, 15);
    expect(launcher.popped, isTrue);
    expect(launcher.value, isTrue);
  });

  testWidgets('blank optional fields are sent as null with the default length',
      (tester) async {
    await openForm(tester);
    await tester.enterText(field('Title *'), 'Standup');
    await tester.enterText(field('Duration (minutes)'), '');
    await pickFutureDate(tester);
    await pickTime(tester);

    await tapCreate(tester);

    final body = backend.bodiesFor('POST', '/rest/v1/meetings').single as Map;
    expect(body['description'], isNull);
    expect(body['meeting_url'], isNull);
    expect(body['duration_minutes'], 60);
  });

  testWidgets('shows the error and stays open when saving fails',
      (tester) async {
    final launcher = await openForm(tester);
    await tester.enterText(field('Title *'), 'Standup');
    await pickFutureDate(tester);
    await pickTime(tester);
    backend.failures['meetings'] = 500;

    await tapCreate(tester);

    expect(find.textContaining('Failed to create meeting:'), findsOneWidget);
    expect(find.text('Create Meeting'), findsWidgets);
    expect(launcher.popped, isFalse);
  });

  testWidgets('Meet link needs a date and time first', (tester) async {
    await openForm(tester);

    await tester.tap(find.text('Create Google Meet Link'));
    await tester.pump();

    expect(find.text('Please select date and time first'), findsOneWidget);
    expect(platform.googleCalls, isEmpty);
  });

  testWidgets('Meet link must start in the future', (tester) async {
    await openForm(tester);
    // Today at the current minute is already in the past by a few seconds.
    await tester.tap(find.text('Select Date *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await pickTime(tester);

    await tester.tap(find.text('Create Google Meet Link'));
    await tester.pump();

    expect(find.text('Meeting time must be in the future'), findsOneWidget);
  });

  testWidgets('offers a retry when Google sign-in is cancelled',
      (tester) async {
    await openForm(tester);
    await pickFutureDate(tester);
    await pickTime(tester);
    await tester.enterText(field('Duration (minutes)'), '-3');

    await tester.tap(find.text('Create Google Meet Link'));
    await settle(tester);

    expect(
      find.text(
          'Failed to create Google Meet link. Please sign in with Google.'),
      findsOneWidget,
    );
    expect(platform.googleCalls.map((c) => c.method), contains('signIn'));

    final signIns = platform.googleCalls.where((c) => c.method == 'signIn');
    final before = signIns.length;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(
      platform.googleCalls.where((c) => c.method == 'signIn').length,
      greaterThan(before),
    );
  });

  testWidgets('fills in the Meet link created in Google Calendar',
      (tester) async {
    platform.googleAccount = {
      'email': 'ada@example.com',
      'id': 'google-1',
      'displayName': 'Ada',
      'photoUrl': null,
      'idToken': null,
      'serverAuthCode': null,
    };
    final calendarBodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.host == 'www.googleapis.com') {
        calendarBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'hangoutLink': 'https://meet.google.com/new-link-xyz'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return backend.client.send(request).then(http.Response.fromStream);
    });

    await http.runWithClient(() async {
      await openForm(tester);
      await tester.enterText(field('Title *'), 'Design review');
      await tester.enterText(field('Duration (minutes)'), 'abc');
      await pickFutureDate(tester);
      await pickTime(tester);

      await tester.tap(find.text('Create Google Meet Link'));
      await pumpUntilFound(
        tester,
        find.text('Google Meet link created successfully'),
      );
    }, () => client);

    expect(calendarBodies.single['summary'], 'Design review');
    final start = DateTime.parse(
      (calendarBodies.single['start'] as Map)['dateTime'] as String,
    );
    final end = DateTime.parse(
      (calendarBodies.single['end'] as Map)['dateTime'] as String,
    );
    // An unparseable duration falls back to an hour.
    expect(end.difference(start), const Duration(minutes: 60));
    expect(
      find.text('https://meet.google.com/new-link-xyz'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
