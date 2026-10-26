import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/auth/team_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() async {
    await resetFakeSupabase();
    // A Google user signing in for the first time has no profile yet.
    backend.tables['users']!.clear();
  });

  Future<void> openDialog(
    WidgetTester tester, {
    String email = FakeBackend.userEmail,
  }) async {
    await pumpRoutedScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => TeamSelectionDialog(
                userEmail: email,
                googleRefreshToken: 'google-refresh',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The dialog action, as opposed to the option card with the same label.
  Finder action(String label) => find.descendant(
        of: find.byType(TextButton),
        matching: find.text(label),
      );

  Future<void> fill(WidgetTester tester, String name, String second) async {
    await tester.enterText(find.byType(TextFormField).at(0), name);
    await tester.enterText(find.byType(TextFormField).at(1), second);
  }

  testWidgets('cannot be dismissed with the back button', (tester) async {
    await openDialog(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TeamSelectionDialog), findsOneWidget);
  });

  group('join', () {
    testWidgets('requires a name and a team code', (tester) async {
      await openDialog(tester);
      await tester.tap(action(l10n.authJoinTeam));
      await tester.pump();

      expect(find.text(l10n.authEnterName), findsOneWidget);
      expect(find.text(l10n.authEnterTeamCode), findsOneWidget);
    });

    testWidgets('creates a member profile and goes home', (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => true;
      await openDialog(tester);
      await fill(tester, ' Eve ', ' ABC123 ');
      await tester.tap(action(l10n.authJoinTeam));
      await settle(tester);

      final profile = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(profile['full_name'], 'Eve');
      expect(profile['team_id'], FakeBackend.teamId);
      expect(profile['role'], 'member');
      expect(profile['google_refresh_token'], 'google-refresh');
      expect(find.byType(TeamSelectionDialog), findsNothing);
      expect(find.text(homePageText), findsOneWidget);
    });

    testWidgets('shows why joining failed', (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => false;
      await openDialog(tester);
      await fill(tester, 'Eve', 'NOPE00');
      await tester.tap(action(l10n.authJoinTeam));
      await settle(tester);

      expect(find.text('Team not found'), findsOneWidget);
      expect(find.byType(TeamSelectionDialog), findsOneWidget);
    });

    testWidgets('refuses an email that is not the signed-in user',
        (tester) async {
      await openDialog(tester, email: 'someone@else.com');
      await fill(tester, 'Eve', 'ABC123');
      await tester.tap(action(l10n.authJoinTeam));
      await settle(tester);

      expect(
          find.text('Email mismatch for authenticated user'), findsOneWidget);
      expect(backend.bodiesFor('POST', '/rest/v1/users'), isEmpty);
    });
  });

  group('create', () {
    Future<void> chooseCreate(WidgetTester tester) async {
      await openDialog(tester);
      await tester.tap(find.text(l10n.authCreateTeam).first);
      await tester.pump();
    }

    testWidgets('switches the form to ask for a team name', (tester) async {
      await chooseCreate(tester);
      expect(find.text(l10n.authTeamCodeLabel), findsNothing);
      expect(find.text(l10n.authTeamNameLabel), findsOneWidget);

      await tester.tap(action(l10n.authCreateTeam));
      await tester.pump();
      expect(find.text(l10n.authEnterTeamName), findsOneWidget);

      // And back again.
      await tester.tap(find.text(l10n.authJoinTeam).first);
      await tester.pump();
      expect(find.text(l10n.authTeamCodeLabel), findsOneWidget);
    });

    testWidgets('creates the team, shows its code, and continues home',
        (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => false;
      await chooseCreate(tester);
      await fill(tester, 'Ada', 'Engines');
      await tester.tap(action(l10n.authCreateTeam));
      await settle(tester);

      final team = backend.bodiesFor('POST', '/rest/v1/teams').single as Map;
      expect(team['name'], 'Engines');
      expect(team['admin_name'], 'Ada');
      final code = team['team_code'] as String;
      final admin = backend.bodiesFor('POST', '/rest/v1/users').single as Map;
      expect(admin['role'], 'admin');
      expect(admin['google_refresh_token'], 'google-refresh');

      expect(find.text(l10n.authTeamCreatedTitle), findsOneWidget);
      expect(find.text(code), findsOneWidget);

      await tester.tap(find.text(l10n.authContinue));
      await settle(tester);
      expect(find.byType(TeamSelectionDialog), findsNothing);
      expect(find.text(homePageText), findsOneWidget);
    });

    testWidgets('reports a team that could not be created', (tester) async {
      backend.rpcs['check_team_code_exists'] = (_) => false;
      backend.failures['teams'] = 500;
      await chooseCreate(tester);
      await fill(tester, 'Ada', 'Engines');
      await tester.tap(action(l10n.authCreateTeam));
      await settle(tester);

      expect(find.text('Failed to create team. Please try again.'),
          findsOneWidget);
      expect(find.text(l10n.authTeamCreatedTitle), findsNothing);
    });
  });

  testWidgets('renders in dark mode', (tester) async {
    await pumpRoutedScreen(
      tester,
      const Scaffold(
        body: TeamSelectionDialog(userEmail: FakeBackend.userEmail),
      ),
      themeMode: ThemeMode.dark,
    );
    expect(find.text(l10n.authCompleteSetup), findsOneWidget);
    expect(find.text(l10n.authChooseHowToProceed), findsOneWidget);
  });
}
