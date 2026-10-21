import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

/// ISO timestamp [offset] from now, in UTC, as the backend stores it.
String isoFromNow(Duration offset) =>
    DateTime.now().add(offset).toUtc().toIso8601String();

/// A meeting row as `SupabaseService.getMeetings` reads it.
Map<String, dynamic> meetingRow({
  String id = 'm1',
  String title = 'Sync',
  Duration offset = const Duration(days: 3),
  String? meetingDate,
  String? url = 'https://meet.google.com/abc-defg-hij',
  String createdBy = FakeBackend.userId,
  Map<String, dynamic> extra = const {},
}) =>
    {
      'id': id,
      'title': title,
      'description': 'Weekly planning',
      'meeting_date': meetingDate ?? isoFromNow(offset),
      'meeting_url': url,
      'team_id': FakeBackend.teamId,
      'created_by': createdBy,
      'duration_minutes': 30,
      'meeting_number': 'MTG-007',
      'created_at': '2026-01-01T00:00:00Z',
      ...extra,
    };

/// Records calls on the platform channels the meeting screens use.
class PlatformFakes {
  /// Fresh for each test; installed by [install].
  late UrlLauncherMock url;

  final List<MethodCall> googleCalls = [];

  /// `signIn` result; null means the user cancelled.
  Map<String, Object?>? googleAccount;
  String? googleAccessToken = 'google-token';

  final List<String> clipboard = [];

  /// Directory returned by `getTemporaryDirectory`; null makes it fail.
  String? tempDir;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    url = mockUrlLauncher();
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      (call) async {
        googleCalls.add(call);
        switch (call.method) {
          case 'signIn':
            return googleAccount;
          case 'getTokens':
            return {'accessToken': googleAccessToken, 'idToken': null};
          default:
            return null;
        }
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (tempDir == null) {
          throw PlatformException(code: 'unavailable');
        }
        return tempDir;
      },
    );
  }

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'plugins.flutter.io/google_sign_in',
      'plugins.flutter.io/path_provider',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

/// Pumps, letting real async work (file IO, PDF encoding) run, until
/// [finder] matches or [maxTries] runs out.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 100,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Fresh temporary directory, deleted after the test.
String makeTempDir() {
  final dir = Directory.systemTemp.createTempSync('ellena_meeting_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir.path;
}
