import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/auth/forgot_password_screen.dart';
import 'package:ell_ena/screens/auth/login_screen.dart';
import 'package:ell_ena/screens/auth/signup_screen.dart';
import 'package:ell_ena/screens/auth/team_selection_dialog.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:ell_ena/widgets/social_share_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String email = FakeBackend.userEmail,
    String password = 'secret1',
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.text(l10n.login));
    await settle(tester);
  }

  testWidgets('validates empty, malformed, and short input', (tester) async {
    await pumpRoutedScreen(tester, const LoginScreen());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text(l10n.login));
    await tester.pump();
    expect(find.text(l10n.authEnterEmail), findsOneWidget);
    expect(find.text(l10n.authEnterPassword), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.text(l10n.login));
    await tester.pump();
    expect(find.text(l10n.authEnterValidEmail), findsOneWidget);
    expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
    expect(backend.log, isEmpty);
  });

  testWidgets('signs in with the entered credentials and goes home',
      (tester) async {
    await pumpRoutedScreen(tester, const LoginScreen());
    await fillAndSubmit(tester);

    expect(find.text(homePageText), findsOneWidget);
    expect(currentLocation(), '/home');
    final body = backend.bodiesFor('POST', '/auth/v1/token').single as Map;
    expect(body['email'], FakeBackend.userEmail);
    expect(body['password'], 'secret1');
  });

  testWidgets('shows invalid credentials when the auth API rejects them',
      (tester) async {
    backend.authFailures['/token'] = 400;
    await pumpRoutedScreen(tester, const LoginScreen());
    await fillAndSubmit(tester);

    expect(find.text(l10n.authInvalidCredentials), findsOneWidget);
    expect(find.text(homePageText), findsNothing);
    // The button is enabled again once the request finishes.
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows a connection error when the server is unavailable',
      (tester) async {
    backend.authFailures['/token'] = 503;
    await pumpRoutedScreen(tester, const LoginScreen());
    await fillAndSubmit(tester);

    expect(find.text(l10n.authConnectionError), findsOneWidget);
  });

  testWidgets('links to forgot password and sign up', (tester) async {
    await pumpRoutedScreen(tester, const LoginScreen());

    await tester.tap(find.text(l10n.authForgotPassword));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    NavigationService().navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.signUp));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);
  });

  group('Google sign-in', () {
    Future<void> startGoogle(WidgetTester tester) async {
      await pumpRoutedScreen(tester, const LoginScreen());
      await tester.tap(find.text(l10n.authSignInWithGoogle));
      await settle(tester);
    }

    Future<void> completeOAuth(WidgetTester tester) async {
      await tester.runAsync(() => Supabase.instance.client.auth
          .signInWithPassword(email: FakeBackend.userEmail, password: 'x'));
      await settle(tester);
    }

    testWidgets('opens the Google consent page and sends known users home',
        (tester) async {
      final launcher = mockUrlLauncher();
      await startGoogle(tester);

      final url = Uri.parse(launcher.urls.single);
      expect(url.path, '/auth/v1/authorize');
      expect(url.queryParameters['provider'], 'google');
      expect(url.queryParameters['access_type'], 'offline');

      await completeOAuth(tester);
      expect(find.text(homePageText), findsOneWidget);
    });

    testWidgets('asks new users to join or create a team', (tester) async {
      backend.tables['users']!.clear();
      mockUrlLauncher();
      await startGoogle(tester);
      await completeOAuth(tester);

      expect(find.byType(TeamSelectionDialog), findsOneWidget);
      expect(find.text(homePageText), findsNothing);
    });

    testWidgets('reports a consent page that could not be opened',
        (tester) async {
      mockUrlLauncher(launched: false);
      await startGoogle(tester);

      expect(find.text('Failed to launch Google sign-in'), findsOneWidget);
    });
  });

  testWidgets('wide layout centres the form and shows the AOSSIE mark',
      (tester) async {
    final launcher = mockUrlLauncher();
    await pumpRoutedScreen(tester, const LoginScreen(), size: wideSize);
    await tester.pump(const Duration(seconds: 1));

    final card = find.ancestor(
      of: find.text(l10n.authWelcomeBack),
      matching: find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 480),
    );
    expect(card, findsOneWidget);
    expect(find.byType(SocialShareSlot), findsOneWidget);

    final mark = find.bySemanticsLabel('AOSSIE');
    expect(mark, findsOneWidget);
    // The logo has no width until the image decodes, so tap its link
    // directly rather than by position.
    tester
        .widget<InkWell>(
            find.ancestor(of: mark, matching: find.byType(InkWell)))
        .onTap!();
    await settle(tester);
    expect(launcher.urls, ['https://aossie.org']);
  });

  testWidgets('phone layout has no AOSSIE mark and renders in dark mode',
      (tester) async {
    await pumpRoutedScreen(tester, const LoginScreen(),
        themeMode: ThemeMode.dark);
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('AOSSIE'), findsNothing);
    expect(find.byType(SocialShareSlot), findsNothing);
    final context = tester.element(find.byType(LoginScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
