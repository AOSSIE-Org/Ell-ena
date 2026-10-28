import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/widgets/account_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase());

  group('showTeamSwitcherDialog', () {
    const teams = [
      {'id': 'team-1', 'name': 'Analytical Engines', 'team_code': 'ABC123'},
      {'id': 'team-2', 'name': 'difference', 'team_code': null},
      {'id': 'team-3'},
    ];

    Future<List<String?>> openSwitcher(WidgetTester tester) async {
      final results = <String?>[];
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await showTeamSwitcherDialog(
                context,
                teams: teams,
                currentTeamId: 'team-1',
              )),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('lists teams with codes and marks the current one',
        (tester) async {
      await openSwitcher(tester);

      expect(find.text(l10n.switchTeam), findsOneWidget);
      expect(find.text('Analytical Engines'), findsOneWidget);
      expect(find.text(l10n.teamCode('ABC123')), findsOneWidget);
      expect(find.text(l10n.teamCode('N/A')), findsNWidgets(2));
      expect(find.text(l10n.teamFallbackName), findsOneWidget);
      // Avatars use the first letter, upper-cased.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('returns another team that is picked', (tester) async {
      final results = await openSwitcher(tester);
      await tester.tap(find.text('difference'));
      await tester.pumpAndSettle();

      expect(results, ['team-2']);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('returns null for the current team or cancel', (tester) async {
      final results = await openSwitcher(tester);
      await tester.tap(find.text('Analytical Engines'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(results, [null, null]);
    });
  });

  group('confirmAndSignOut', () {
    Future<void> start(WidgetTester tester) async {
      await pumpRoutedScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmAndSignOut(context),
              child: const Text('sign out'),
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('sign out'));
      await tester.pumpAndSettle();
    }

    testWidgets('cancelling keeps the session', (tester) async {
      await start(tester);
      expect(find.text(l10n.logoutMessage), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await settle(tester);

      expect(backend.log, isEmpty);
      expect(find.text('sign out'), findsOneWidget);
    });

    testWidgets('confirming signs out and opens login', (tester) async {
      await start(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, l10n.logout));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await settle(tester);

      expect(backend.log, contains('POST /auth/v1/logout'));
      expect(find.text(loginPageText), findsOneWidget);
    });

    testWidgets('a failed sign-out closes the loader and explains',
        (tester) async {
      backend.authFailures['/logout'] = 500;
      await start(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, l10n.logout));
      await settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Auth failed'), findsOneWidget);
      expect(find.text(loginPageText), findsNothing);
    });
  });
}
