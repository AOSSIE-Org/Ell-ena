import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/auth/signup_screen.dart';
import 'package:ell_ena/screens/auth/team_selection_dialog.dart';
import 'package:ell_ena/screens/auth/verify_otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase(signedIn: false));

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> enter(WidgetTester tester, List<String> values) async {
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
  }

  group('join a team', () {
    testWidgets('validates every field', (tester) async {
      await pumpRoutedScreen(tester, const SignupScreen());

      await tapText(tester, l10n.authJoinTeam);
      expect(find.text(l10n.authEnterTeamId), findsOneWidget);
      expect(find.text(l10n.authEnterName), findsOneWidget);
      expect(find.text(l10n.authEnterEmail), findsOneWidget);
      expect(find.text(l10n.authEnterPassword), findsOneWidget);
      expect(find.text(l10n.authConfirmPasswordPrompt), findsOneWidget);

      await enter(tester, ['ABC', 'Eve', 'eve', '123', '456']);
      await tapText(tester, l10n.authJoinTeam);
      expect(find.text(l10n.authTeamIdLength), findsOneWidget);
      expect(find.text(l10n.authEnterValidEmail), findsOneWidget);
      expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
      expect(find.text(l10n.authPasswordsDoNotMatch), findsOneWidget);
      expect(backend.log, isEmpty);
    });

    testWidgets('rejects a team code that does not exist', (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => false;
      await pumpRoutedScreen(tester, const SignupScreen());
      await enter(
          tester, ['ZZZ999', 'Eve', 'eve@example.com', 'secret1', 'secret1']);
      await tapText(tester, l10n.authJoinTeam);

      expect(find.text(l10n.authTeamIdNotFound), findsOneWidget);
      expect(backend.bodiesFor('POST', '/rest/v1/rpc/check_team_code_exists'), [
        {'code': 'ZZZ999'}
      ]);
      expect(backend.log, isNot(contains('POST /auth/v1/otp')));
    });

    testWidgets('emails a code and opens verification for a known team',
        (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => true;
      await pumpRoutedScreen(tester, const SignupScreen());
      await enter(
          tester, ['abc123', 'Eve', 'eve@example.com', 'secret1', 'secret1']);
      await tapText(tester, l10n.authJoinTeam);
      await tester.pumpAndSettle();

      expect(backend.bodiesFor('POST', '/rest/v1/rpc/check_team_code_exists'), [
        {'code': 'ABC123'}
      ]);
      final otp = backend.bodiesFor('POST', '/auth/v1/otp').single as Map;
      expect(otp['email'], 'eve@example.com');
      final verify =
          tester.widget<VerifyOTPScreen>(find.byType(VerifyOTPScreen));
      expect(verify.verifyType, 'signup_join');
      expect(verify.email, 'eve@example.com');
      expect(verify.userData, {
        'teamId': 'ABC123',
        'fullName': 'Eve',
        'password': 'secret1',
      });
    });

    testWidgets('shows the error when the code email fails', (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => true;
      backend.authFailures['/otp'] = 422;
      await pumpRoutedScreen(tester, const SignupScreen());
      await enter(
          tester, ['ABC123', 'Eve', 'eve@example.com', 'secret1', 'secret1']);
      await tapText(tester, l10n.authJoinTeam);

      expect(find.textContaining('Auth failed'), findsOneWidget);
      expect(find.byType(VerifyOTPScreen), findsNothing);
    });
  });

  group('create a team', () {
    Future<void> openCreateTab(WidgetTester tester) async {
      await pumpRoutedScreen(tester, const SignupScreen());
      await tester.tap(find.text(l10n.authCreateTheTeamTab));
      await tester.pumpAndSettle();
    }

    testWidgets('validates every field', (tester) async {
      await openCreateTab(tester);
      await tapText(tester, l10n.authCreateTeam);

      expect(find.text(l10n.authEnterTeamName), findsOneWidget);
      expect(find.text(l10n.authEnterAdminName), findsOneWidget);
      expect(find.text(l10n.authEnterAdminEmail), findsOneWidget);
      expect(find.text(l10n.authEnterPassword), findsOneWidget);
      expect(find.text(l10n.authConfirmPasswordPrompt), findsOneWidget);

      await enter(tester, ['Engines', 'Ada', 'ada', '123', '1234']);
      await tapText(tester, l10n.authCreateTeam);
      expect(find.text(l10n.authEnterValidEmail), findsOneWidget);
      expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
      expect(find.text(l10n.authPasswordsDoNotMatch), findsOneWidget);
    });

    testWidgets('emails a code and opens verification with the team details',
        (tester) async {
      await openCreateTab(tester);
      await enter(
          tester, ['Engines', 'Ada', 'ada@example.com', 'secret1', 'secret1']);
      await tapText(tester, l10n.authCreateTeam);
      await tester.pumpAndSettle();

      final verify =
          tester.widget<VerifyOTPScreen>(find.byType(VerifyOTPScreen));
      expect(verify.verifyType, 'signup_create');
      expect(verify.userData, {
        'teamName': 'Engines',
        'adminName': 'Ada',
        'password': 'secret1',
      });
    });

    testWidgets('shows the error when the code email fails', (tester) async {
      backend.authFailures['/otp'] = 422;
      await openCreateTab(tester);
      await enter(
          tester, ['Engines', 'Ada', 'ada@example.com', 'secret1', 'secret1']);
      await tapText(tester, l10n.authCreateTeam);

      expect(find.textContaining('Auth failed'), findsOneWidget);
      expect(find.byType(VerifyOTPScreen), findsNothing);
    });
  });

  group('Google sign-up', () {
    Future<void> startGoogle(WidgetTester tester) async {
      await pumpRoutedScreen(tester, const SignupScreen());
      await tapText(tester, l10n.authSignUpWithGoogle);
    }

    Future<void> completeOAuth(WidgetTester tester) async {
      await tester.runAsync(() => Supabase.instance.client.auth
          .signInWithPassword(email: FakeBackend.userEmail, password: 'x'));
      await settle(tester);
    }

    testWidgets('sends an existing user home', (tester) async {
      mockUrlLauncher();
      await startGoogle(tester);
      await completeOAuth(tester);

      expect(find.text(homePageText), findsOneWidget);
    });

    testWidgets('asks a new user to set up a team', (tester) async {
      backend.tables['users']!.clear();
      mockUrlLauncher();
      await startGoogle(tester);
      await completeOAuth(tester);

      final dialog =
          tester.widget<TeamSelectionDialog>(find.byType(TeamSelectionDialog));
      expect(dialog.userEmail, FakeBackend.userEmail);
    });

    testWidgets('reports a consent page that could not be opened',
        (tester) async {
      mockUrlLauncher(launched: false);
      await startGoogle(tester);

      expect(find.text('Failed to launch Google sign-in'), findsOneWidget);
    });
  });

  testWidgets('returns to the login page', (tester) async {
    await pumpRoutedScreen(tester, const SignupScreen());
    await tapText(tester, l10n.authAlreadyHaveAccount);

    expect(find.text(loginPageText), findsOneWidget);
  });

  testWidgets('wide layout shows the form in a centred card', (tester) async {
    await pumpRoutedScreen(tester, const SignupScreen(),
        size: wideSize, themeMode: ThemeMode.dark);

    final card = find.ancestor(
      of: find.text(l10n.authCreateAccount),
      matching: find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 480),
    );
    expect(card, findsOneWidget);
    expect(find.text(l10n.authJoinTheTeamTab), findsOneWidget);
  });
}
