import 'package:ell_ena/services/supabase_service.dart';
import 'package:ell_ena/shell/shell_destination.dart';
import 'package:ell_ena/shell/widgets/shell_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  Future<void> pumpTopBar(
    WidgetTester tester, {
    ShellDestination destination = ShellDestination.tasks,
    ShellPageAction? pageAction,
    Future<void> Function()? onRefresh,
    VoidCallback? onTeamChanged,
    VoidCallback? onOpenProfile,
  }) async {
    await pumpRouted(
      tester,
      size: wideSize,
      initialLocation: '/',
      pages: {
        '/': (_) => Scaffold(
              body: Column(
                children: [
                  ShellTopBar(
                    destination: destination,
                    pageAction: pageAction,
                    onRefresh: onRefresh,
                    onTeamChanged: onTeamChanged,
                    onOpenProfile: onOpenProfile,
                  ),
                ],
              ),
            ),
      },
    );
    await settle(tester);
  }

  testWidgets('shows the page title, team and signed-in user', (tester) async {
    await pumpTopBar(tester, destination: ShellDestination.meetings);

    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('Analytical Engines'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    // One team only: the team button is informational, not a switcher.
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(find.byIcon(Icons.unfold_more), findsNothing);
    // No refresh callback, no page action: neither control is shown.
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('page action button runs its callback', (tester) async {
    var pressed = 0;
    await pumpTopBar(
      tester,
      pageAction: ShellPageAction(
        label: 'New Task',
        icon: Icons.add,
        onPressed: () => pressed++,
      ),
    );

    expect(find.byTooltip('New Task (N)'), findsOneWidget);
    await tester.tap(find.text('New Task'));
    expect(pressed, 1);
  });

  testWidgets('refresh reloads the page and the account, spinner meanwhile',
      (tester) async {
    var refreshes = 0;
    await pumpTopBar(
      tester,
      onRefresh: () async {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
    );
    backend.log.clear();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(refreshes, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A second press while refreshing is ignored.
    final state = tester.state<ShellTopBarState>(find.byType(ShellTopBar));
    await state.refresh();
    expect(refreshes, 1);

    await tester.pump(const Duration(milliseconds: 250));
    await settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // forceRefresh re-reads the profile from the backend.
    expect(backend.log, contains('GET /rest/v1/users'));
  });

  testWidgets('switches team and reports the change', (tester) async {
    backend.seedSecondTeam();
    var changed = 0;
    await pumpTopBar(tester, onTeamChanged: () => changed++);

    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    await tester.tap(find.text('Analytical Engines'));
    await settle(tester);

    expect(find.text('Switch Team'), findsOneWidget);
    backend.moveUserToSecondTeam();
    await tester.tap(find.text('Difference Engines'));
    await settle(tester);

    expect(changed, 1);
    // The top bar re-reads the account and shows the new team.
    expect(find.text('Difference Engines'), findsOneWidget);
    expect(find.text('Analytical Engines'), findsNothing);
  });

  testWidgets('picking the current team again changes nothing', (tester) async {
    backend.seedSecondTeam();
    var changed = 0;
    await pumpTopBar(tester, onTeamChanged: () => changed++);

    await tester.tap(find.text('Analytical Engines'));
    await settle(tester);
    // Inside the dialog the current team is the first list tile.
    await tester.tap(find.widgetWithText(ListTile, 'Analytical Engines'));
    await settle(tester);

    expect(changed, 0);
    expect(find.text('Switch Team'), findsNothing);
  });

  testWidgets('a failed switch shows the error', (tester) async {
    backend.seedSecondTeam();
    var changed = 0;
    await pumpTopBar(tester, onTeamChanged: () => changed++);

    await tester.tap(find.text('Analytical Engines'));
    await settle(tester);
    // The user is no longer in team 2 by the time they confirm.
    await tester.tap(find.text('Difference Engines'));
    await settle(tester);

    expect(changed, 0);
    expect(
      find.textContaining('User is not a member of this team'),
      findsOneWidget,
    );
  });

  testWidgets('account menu opens the profile', (tester) async {
    var opened = 0;
    await pumpTopBar(tester, onOpenProfile: () => opened++);

    await tester.tap(find.byTooltip('Ada'));
    await settle(tester);
    expect(find.text(FakeBackend.userEmail), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await settle(tester);
    expect(opened, 1);
  });

  testWidgets('account menu signs out to the login page', (tester) async {
    await pumpTopBar(tester);

    await tester.tap(find.byTooltip('Ada'));
    await settle(tester);
    await tester.tap(find.text('Logout'));
    await settle(tester);

    // Confirmation dialog, then the confirm button.
    expect(find.text('You will need to log in again to access your account.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await settle(tester);

    expect(find.text(loginPageText), findsOneWidget);
    expect(backend.log, contains('POST /auth/v1/logout'));
    expect(SupabaseService().currentUser, isNull);
  });

  testWidgets('without a profile shows only the generic account menu',
      (tester) async {
    await resetInTest(tester, signedIn: false);
    await pumpTopBar(tester);

    expect(find.text('?'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
