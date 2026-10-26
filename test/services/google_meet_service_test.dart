import 'dart:convert';

import 'package:ell_ena/services/google_meet_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/google_sign_in');

  late List<MethodCall> signInCalls;
  late Map<String, dynamic>? account;
  late String? accessToken;

  setUp(() {
    signInCalls = [];
    account = {'email': 'ada@example.com', 'id': 'g-1', 'displayName': 'Ada'};
    accessToken = 'access-123';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      signInCalls.add(call);
      switch (call.method) {
        case 'signIn':
          return account;
        case 'getTokens':
          return {'accessToken': accessToken, 'idToken': 'id-1'};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Runs [body] with Google Calendar answered by [respond].
  Future<T> withCalendar<T>(
    http.Response Function(http.Request request) respond,
    Future<T> Function() body,
  ) =>
      http.runWithClient(body, () => MockClient((r) async => respond(r)));

  final start = DateTime.utc(2026, 11, 3, 15);

  Future<String?> create(GoogleMeetService service) => service.createMeetLink(
        start: start,
        durationMinutes: 45,
        title: 'Planning',
        description: 'Q4',
      );

  test('creates a Calendar event with a Meet and returns its link', () async {
    late http.Request sent;

    final link = await withCalendar((request) {
      sent = request;
      return http.Response(
        jsonEncode({'hangoutLink': 'https://meet.google.com/abc-defg-hij'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }, () => create(GoogleMeetService()));

    expect(link, 'https://meet.google.com/abc-defg-hij');
    expect(sent.url.path, '/calendar/v3/calendars/primary/events');
    expect(sent.url.queryParameters['conferenceDataVersion'], '1');
    expect(sent.headers['Authorization'], 'Bearer access-123');
    final event = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(event['summary'], 'Planning');
    expect(event['description'], 'Q4');
    expect(DateTime.parse(event['start']['dateTime'] as String), start);
    expect(DateTime.parse(event['end']['dateTime'] as String),
        start.add(const Duration(minutes: 45)));
    expect(
      event['conferenceData']['createRequest']['conferenceSolutionKey'],
      {'type': 'hangoutsMeet'},
    );
    final init = signInCalls.firstWhere((c) => c.method == 'init');
    expect(
      init.arguments['scopes'],
      containsAll([
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/calendar.events',
      ]),
    );
  });

  test('falls back to the video entry point when there is no hangout link',
      () async {
    final link = await withCalendar(
      (_) => http.Response(
        jsonEncode({
          'conferenceData': {
            'entryPoints': [
              {'entryPointType': 'phone', 'uri': 'tel:+1'},
              {'entryPointType': 'video', 'uri': 'https://meet.google.com/x'},
            ]
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
      () => create(GoogleMeetService()),
    );

    expect(link, 'https://meet.google.com/x');
  });

  test('returns an empty link when no video entry point exists', () async {
    final link = await withCalendar(
      (_) => http.Response(
        jsonEncode({
          'conferenceData': {
            'entryPoints': [
              {'entryPointType': 'phone', 'uri': 'tel:+1'}
            ]
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
      () => create(GoogleMeetService()),
    );

    expect(link, '');
  });

  test('returns null when the user cancels sign-in', () async {
    account = null;
    var calendarCalled = false;

    final link = await withCalendar((_) {
      calendarCalled = true;
      return http.Response('{}', 200);
    }, () => create(GoogleMeetService()));

    expect(link, isNull);
    expect(calendarCalled, isFalse);
  });

  test('returns null without an access token', () async {
    accessToken = null;

    final link = await withCalendar(
        (_) => http.Response('{}', 200), () => create(GoogleMeetService()));

    expect(link, isNull);
  });

  test('returns null when Calendar rejects the event', () async {
    final link = await withCalendar(
      (_) => http.Response('{"error":{"code":403,"message":"denied"}}', 403,
          headers: {'content-type': 'application/json'}),
      () => create(GoogleMeetService()),
    );

    expect(link, isNull);
  });

  test('signOut signs out of Google', () async {
    await GoogleMeetService().signOut();

    expect(signInCalls.map((c) => c.method), contains('signOut'));
  });
}
