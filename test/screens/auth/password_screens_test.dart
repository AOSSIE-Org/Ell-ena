import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/auth/forgot_password_screen.dart';
import 'package:ell_ena/screens/auth/set_new_password_screen.dart';
import 'package:ell_ena/screens/auth/verify_otp_screen.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);

  /// A start page that pushes [screen] the way the app does, so "back"
  /// has somewhere to return to.
  Future<void> pumpNavigatedTo(WidgetTester tester, Widget screen) async {
    await pumpRoutedScreen(
      tester,
      Scaffold(
        body: TextButton(
          onPressed: () => NavigationService().navigateTo(screen),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('ForgotPasswordScreen', () {
    setUp(() => resetFakeSupabase(signedIn: false));

    testWidgets('validates the email', (tester) async {
      await pumpRoutedScreen(tester, const ForgotPasswordScreen());

      await tester.tap(find.text(l10n.authSendResetCode));
      await tester.pump();
      expect(find.text(l10n.authEnterEmail), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.tap(find.text(l10n.authSendResetCode));
      await tester.pump();
      expect(find.text(l10n.authEnterValidEmail), findsOneWidget);
      expect(backend.log, isEmpty);
    });

    testWidgets('sends a reset code and opens verification', (tester) async {
      await pumpRoutedScreen(tester, const ForgotPasswordScreen());
      await tester.enterText(find.byType(TextFormField), FakeBackend.userEmail);
      await tester.tap(find.text(l10n.authSendResetCode));
      await settle(tester);
      await tester.pumpAndSettle();

      final body = backend.bodiesFor('POST', '/auth/v1/recover').single as Map;
      expect(body['email'], FakeBackend.userEmail);
      final verify =
          tester.widget<VerifyOTPScreen>(find.byType(VerifyOTPScreen));
      expect(verify.verifyType, 'reset_password');
      expect(verify.email, FakeBackend.userEmail);
    });

    testWidgets('shows a friendly error when the request fails',
        (tester) async {
      backend.authFailures['/recover'] = 400;
      await pumpRoutedScreen(tester, const ForgotPasswordScreen());
      await tester.enterText(find.byType(TextFormField), FakeBackend.userEmail);
      await tester.tap(find.text(l10n.authSendResetCode));
      await settle(tester);

      expect(find.text(l10n.authGenericError), findsWidgets);
      expect(find.byType(VerifyOTPScreen), findsNothing);
    });

    for (final entry in {
      'Invalid email': l10n.authInvalidEmailAddress,
      'Email not found': l10n.authEmailNotFound,
      'Rate limit exceeded': l10n.authTooManyAttempts,
    }.entries) {
      testWidgets('explains a failure reading "${entry.key}"', (tester) async {
        backend
          ..authFailures['/recover'] = 400
          ..authFailureMessage = entry.key;
        await pumpRoutedScreen(tester, const ForgotPasswordScreen());
        await tester.enterText(
            find.byType(TextFormField), FakeBackend.userEmail);
        await tester.tap(find.text(l10n.authSendResetCode));
        await settle(tester);

        expect(find.text(entry.value), findsWidgets);
        expect(find.byType(VerifyOTPScreen), findsNothing);
      });
    }

    testWidgets('back returns to the previous page', (tester) async {
      await pumpNavigatedTo(tester, const ForgotPasswordScreen());
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);

      await tester.tap(find.text(l10n.authBackToLogin));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('SetNewPasswordScreen', () {
    setUp(() => resetFakeSupabase());

    const screen = SetNewPasswordScreen(email: FakeBackend.userEmail);

    testWidgets('validates the new password and confirmation', (tester) async {
      await pumpRoutedScreen(tester, screen);

      await tester.tap(find.text(l10n.authUpdatePassword));
      await tester.pump();
      expect(find.text(l10n.authEnterNewPassword), findsOneWidget);
      expect(find.text(l10n.authConfirmPasswordPrompt), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '123');
      await tester.enterText(find.byType(TextFormField).at(1), '1234');
      await tester.tap(find.text(l10n.authUpdatePassword));
      await tester.pump();
      expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
      expect(find.text(l10n.authPasswordsDoNotMatch), findsOneWidget);
      expect(backend.log, isEmpty);
    });

    testWidgets('updates the password and returns to login', (tester) async {
      await pumpRoutedScreen(tester, screen);
      await tester.enterText(find.byType(TextFormField).at(0), 'newpass1');
      await tester.enterText(find.byType(TextFormField).at(1), 'newpass1');
      await tester.tap(find.text(l10n.authUpdatePassword));
      await settle(tester);

      final body = backend.bodiesFor('PUT', '/auth/v1/user').single as Map;
      expect(body['password'], 'newpass1');
      expect(find.text(loginPageText), findsOneWidget);
      expect(find.text(l10n.authPasswordUpdated), findsOneWidget);
    });

    testWidgets('shows the error when the update fails', (tester) async {
      backend.authFailures['/user'] = 422;
      await pumpRoutedScreen(tester, screen);
      await tester.enterText(find.byType(TextFormField).at(0), 'newpass1');
      await tester.enterText(find.byType(TextFormField).at(1), 'newpass1');
      await tester.tap(find.text(l10n.authUpdatePassword));
      await settle(tester);

      expect(find.textContaining('Auth failed'), findsOneWidget);
      expect(find.text(loginPageText), findsNothing);
    });

    testWidgets('back to login goes to the login page', (tester) async {
      await pumpRoutedScreen(tester, screen);
      await tester.tap(find.text(l10n.authBackToLogin));
      await settle(tester);

      expect(find.text(loginPageText), findsOneWidget);
    });
  });
}
