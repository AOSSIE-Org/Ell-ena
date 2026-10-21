import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/auth/set_new_password_screen.dart';
import 'package:ell_ena/screens/auth/verify_otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  Future<void> pumpOtp(
    WidgetTester tester, {
    String type = 'signup_join',
    Map<String, dynamic> userData = const {},
  }) {
    return pumpRoutedScreen(
      tester,
      VerifyOTPScreen(
        email: FakeBackend.userEmail,
        verifyType: type,
        userData: userData,
      ),
    );
  }

  Future<void> enterCode(WidgetTester tester, [String code = '123456']) async {
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(find.byType(TextField).at(i), code[i]);
    }
    await tester.pump();
  }

  ElevatedButton verifyButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  Future<void> verify(WidgetTester tester) async {
    await tester.tap(find.text(l10n.authVerifyCode));
    // verifyOTP waits 500ms for the session before continuing.
    await settle(tester, frames: 20);
  }

  testWidgets('enables verification only once all six digits are entered',
      (tester) async {
    await pumpOtp(tester);

    expect(find.text(l10n.authVerifyEmailSubtitle(FakeBackend.userEmail)),
        findsOneWidget);
    expect(verifyButton(tester).onPressed, isNull);

    await enterCode(tester, '12345');
    expect(verifyButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(5), '6');
    await tester.pump();
    expect(verifyButton(tester).onPressed, isNotNull);
  });

  testWidgets('joining a team creates a member profile and goes home',
      (tester) async {
    await pumpOtp(tester, userData: {
      'teamId': 'ABC123',
      'fullName': 'Eve',
      'password': 'secret1',
    });
    await enterCode(tester);
    await verify(tester);

    final verifyBody =
        backend.bodiesFor('POST', '/auth/v1/verify').single as Map;
    expect(verifyBody['token'], '123456');
    expect(verifyBody['email'], FakeBackend.userEmail);
    expect(
        (backend.bodiesFor('PUT', '/auth/v1/user').single as Map)['password'],
        'secret1');
    final profile = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
    expect(profile['team_id'], FakeBackend.teamId);
    expect(profile['role'], 'member');
    expect(profile['full_name'], 'Eve');
    expect(find.text(homePageText), findsOneWidget);
  });

  testWidgets('joining an unknown team shows the error and stays',
      (tester) async {
    await pumpOtp(tester, userData: {'teamId': 'NOPE00', 'fullName': 'Eve'});
    await enterCode(tester);
    await verify(tester);

    expect(find.text('Team not found'), findsOneWidget);
    expect(find.byType(VerifyOTPScreen), findsOneWidget);
    expect(backend.bodiesFor('POST', '/rest/v1/users'), isEmpty);
  });

  testWidgets('a rejected code shows the auth error', (tester) async {
    backend.authFailures['/verify'] = 400;
    await pumpOtp(tester);
    await enterCode(tester);
    await verify(tester);

    expect(find.textContaining('Auth failed'), findsOneWidget);
    expect(verifyButton(tester).onPressed, isNotNull);
  });

  for (final entry in {
    'Token has expired': l10n.authCodeExpiredOrInvalid,
    'Token is invalid': l10n.authInvalidCode,
  }.entries) {
    testWidgets('a rejected code reading "${entry.key}" is explained',
        (tester) async {
      backend
        ..authFailures['/verify'] = 400
        ..authFailureMessage = entry.key;
      await pumpOtp(tester);
      await enterCode(tester);
      await verify(tester);

      expect(find.text(entry.value), findsWidgets);
      expect(find.textContaining(entry.key), findsNothing);
    });
  }

  testWidgets('creating a team shows its code, copies it, and continues home',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    backend.rpcs['check_team_code_exists'] = (_) => false;

    await pumpOtp(tester, type: 'signup_create', userData: {
      'teamName': 'Engines',
      'adminName': 'Ada',
      'password': 'secret1',
    });
    await enterCode(tester);
    await verify(tester);

    final team = backend.bodiesFor('POST', '/rest/v1/teams').single as Map;
    expect(team['name'], 'Engines');
    expect(team['admin_email'], FakeBackend.userEmail);
    final code = team['team_code'] as String;
    expect(code, hasLength(6));
    final admin = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
    expect(admin['role'], 'admin');

    expect(find.text(l10n.authTeamCreatedTitle), findsOneWidget);
    expect(find.text(code), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.authCopyTeamId));
    await tester.pump();
    expect(copied, code);
    expect(find.text(l10n.authTeamIdCopied), findsOneWidget);

    await tester.tap(find.text(l10n.authContinue));
    await settle(tester);
    expect(find.text(homePageText), findsOneWidget);
  });

  testWidgets('a password reset code opens the new password screen',
      (tester) async {
    await pumpOtp(tester, type: 'reset_password');
    await enterCode(tester);
    await verify(tester);
    await tester.pumpAndSettle();

    final screen =
        tester.widget<SetNewPasswordScreen>(find.byType(SetNewPasswordScreen));
    expect(screen.email, FakeBackend.userEmail);
  });

  group('resend', () {
    testWidgets('resends a sign-up code and counts down before allowing more',
        (tester) async {
      await pumpOtp(tester);

      await tester.tap(find.text(l10n.authResend));
      await settle(tester);
      final body = backend.bodiesFor('POST', '/auth/v1/resend').single as Map;
      expect(body['email'], FakeBackend.userEmail);
      expect(body['type'], 'signup');
      expect(find.text(l10n.authCodeResent), findsOneWidget);
      expect(find.text(l10n.authResendCodeIn('00:60')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.authResendCodeIn('00:59')), findsOneWidget);

      // A second tap during the countdown sends nothing.
      await tester.tap(find.text(l10n.authResend));
      await settle(tester);
      expect(backend.bodiesFor('POST', '/auth/v1/resend'), hasLength(1));

      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(find.textContaining('00:'), findsNothing);
    });

    testWidgets('resends a password reset email', (tester) async {
      await pumpOtp(tester, type: 'reset_password');

      await tester.tap(find.text(l10n.authResend));
      await settle(tester);

      final body = backend.bodiesFor('POST', '/auth/v1/recover').single as Map;
      expect(body['email'], FakeBackend.userEmail);
      expect(find.text(l10n.authCodeResent), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('shows why a resend failed', (tester) async {
      backend.authFailures['/resend'] = 400;
      await pumpOtp(tester);

      await tester.tap(find.text(l10n.authResend));
      await settle(tester);

      expect(find.textContaining('Auth failed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    for (final entry in {
      'Rate limit exceeded': l10n.authTooManyAttempts,
      'User not found': l10n.authEmailNotFoundOrInvalid,
    }.entries) {
      testWidgets('explains a resend failure reading "${entry.key}"',
          (tester) async {
        backend
          ..authFailures['/resend'] = 429
          ..authFailureMessage = entry.key;
        await pumpOtp(tester);

        await tester.tap(find.text(l10n.authResend));
        await settle(tester);

        expect(find.text(entry.value), findsWidgets);
        await tester.pump(const Duration(seconds: 61));
      });
    }

    testWidgets('rejects an unsupported verification type', (tester) async {
      await pumpOtp(tester, type: 'magic_link');

      await tester.tap(find.text(l10n.authResend));
      await settle(tester);

      expect(find.text('Invalid OTP type: magic_link'), findsOneWidget);
      expect(backend.log, isEmpty);
      await tester.pump(const Duration(seconds: 61));
    });
  });
}
