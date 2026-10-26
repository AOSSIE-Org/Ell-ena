import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');

/// Answers and records url_launcher calls. See [mockUrlLauncher].
class UrlLauncherMock {
  final List<MethodCall> calls = [];

  /// Answer to `canLaunch`.
  bool canLaunch = true;

  /// Answer to `launch`.
  bool launched = true;

  /// When set, every call fails with it.
  PlatformException? error;

  /// URLs passed to any call, oldest first.
  List<String> get urls => [
        for (final call in calls)
          if (call.arguments is Map && (call.arguments as Map)['url'] is String)
            (call.arguments as Map)['url'] as String,
      ];

  /// URLs actually launched, oldest first.
  List<String> get launchedUrls => [
        for (final call in calls)
          if (call.method == 'launch') (call.arguments as Map)['url'] as String,
      ];
}

/// Installs a [UrlLauncherMock] for the rest of the test.
UrlLauncherMock mockUrlLauncher({bool canLaunch = true, bool launched = true}) {
  final mock = UrlLauncherMock()
    ..canLaunch = canLaunch
    ..launched = launched;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_urlLauncher, (call) async {
    mock.calls.add(call);
    final error = mock.error;
    if (error != null) throw error;
    if (call.method == 'canLaunch') return mock.canLaunch;
    if (call.method == 'launch') return mock.launched;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_urlLauncher, null));
  return mock;
}
