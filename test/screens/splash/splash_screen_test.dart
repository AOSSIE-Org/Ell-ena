import 'dart:convert';
import 'dart:io';

import 'package:ell_ena/screens/splash_screen.dart';
import 'package:ell_ena/services/app_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  setUpAll(() async {
    await setUpFakeSupabase();
    // Run startup once on the real clock. Its future is shared across tests,
    // and a future completed inside one test's fake clock never notifies
    // listeners in the next test.
    await AppStartup.ensureInitialized();
  });

  // Sessions are reset inside each test with runAsync: the auth client's
  // requests do not complete under the test's fake clock.

  /// Startup waits for the 1.5s intro as well as service setup.
  Future<void> finishIntro(WidgetTester tester) async {
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester);
  }

  testWidgets('sends a signed-in user home after startup', (tester) async {
    await tester.runAsync(resetFakeSupabase);
    await pumpRoutedScreen(tester, const SplashScreen());

    expect(find.text('Ell-ena'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'AOSSIE'),
      findsOneWidget,
    );
    await finishIntro(tester);

    expect(AppStartup.isReady, isTrue);
    expect(currentLocation(), '/home');
  });

  testWidgets('sends a signed-out user to login', (tester) async {
    await resetInTest(tester, signedIn: false);
    await pumpRoutedScreen(tester, const SplashScreen(),
        themeMode: ThemeMode.dark);
    await finishIntro(tester);

    expect(find.text(loginPageText), findsOneWidget);
  });

  testWidgets('resumes the in-app location that was opened', (tester) async {
    await tester.runAsync(resetFakeSupabase);
    await pumpRoutedScreen(tester, const SplashScreen(from: '/tasks'));
    await finishIntro(tester);

    expect(currentLocation(), '/tasks');
  });

  testWidgets('ignores a location outside the app', (tester) async {
    await tester.runAsync(resetFakeSupabase);
    await pumpRoutedScreen(
        tester, const SplashScreen(from: 'https://example.com/home'));
    await finishIntro(tester);

    expect(currentLocation(), '/home');
  });

  testWidgets('falls back to a drawn logo when the image is missing',
      (tester) async {
    await tester.runAsync(resetFakeSupabase);
    // Hide only the Ell-ena logo; other assets load as usual.
    final assets = Platform.environment['UNIT_TEST_ASSETS'];
    tester.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List()));
      final file = File('$assets/$key');
      if (key.contains('logo-removed-bg') || !file.existsSync()) return null;
      return ByteData.sublistView(file.readAsBytesSync());
    });
    // Puts the harness asset handler back for later tests.
    addTearDown(setUpFakeSupabase);
    // Earlier tests cached the decoded logo.
    imageCache.clear();

    await pumpRoutedScreen(tester, const SplashScreen());
    await settle(tester);

    expect(find.byIcon(Icons.task_alt), findsOneWidget);
    await finishIntro(tester);
  });
}
