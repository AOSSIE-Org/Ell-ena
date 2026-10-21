import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/profile/edit_profile_screen.dart';
import 'package:ell_ena/screens/profile/profile_screen.dart';
import 'package:ell_ena/screens/profile/team_members_screen.dart';
import 'package:ell_ena/shell/shell_refreshable.dart';
import 'package:ell_ena/theme/app_theme_mode.dart';
import 'package:ell_ena/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);

  Future<void> pumpProfile(WidgetTester tester, {Size size = phoneSize}) async {
    await pumpRoutedScreen(tester, const ProfileScreen(), size: size);
    await settle(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  group('admin', () {
    setUp(() => resetFakeSupabase());

    testWidgets('shows the profile, team, and admin-only settings',
        (tester) async {
      await pumpProfile(tester);

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text(l10n.profileAdminBadge), findsOneWidget);
      expect(find.text('Analytical Engines'), findsWidgets);
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text(l10n.profileTeamMembers), findsOneWidget);
      // One team only, so no switcher.
      expect(find.text(l10n.switchTeam), findsNothing);
    });

    testWidgets('edits the name and reloads the profile', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.profileEditProfile));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Augusta');
      await tester.enterText(find.byType(TextFormField).at(1), 'King');
      await tester.tap(find.text(l10n.save));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(backend.bodiesFor('PATCH', '/rest/v1/users'), [
        {'full_name': 'Augusta King'}
      ]);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Augusta King'), findsOneWidget);
    });

    testWidgets('lists team members from the team code', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.profileTeamMembers));
      await tester.pumpAndSettle();

      final screen =
          tester.widget<TeamMembersScreen>(find.byType(TeamMembersScreen));
      expect(screen.teamId, 'ABC123');
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('changes the language from the picker', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.language));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.languageName('hi')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'hi');
      // The sheet closed and the setting now names the chosen language.
      expect(find.text(l10n.languageName('hi')), findsOneWidget);
    });

    testWidgets('changes the theme from the picker', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.profileTheme));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileThemeDark));
      await tester.pumpAndSettle();

      final controller = Provider.of<ThemeController>(
          tester.element(find.byType(ProfileScreen)),
          listen: false);
      expect(controller.themeMode, AppThemeMode.dark);
      expect(find.text(l10n.profileThemeDark), findsOneWidget);
    });

    testWidgets('placeholder settings do nothing yet', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.profileNotifications));
      await tapVisible(tester, find.text(l10n.profilePushNotifications));
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(backend.log, isNot(contains('PATCH /rest/v1/users')));
    });

    testWidgets('logs out after confirmation', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byTooltip(l10n.logout));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logoutTitle), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(backend.log, isNot(contains('POST /auth/v1/logout')));

      await tapVisible(
          tester, find.widgetWithText(ElevatedButton, l10n.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, l10n.logout).last);
      await settle(tester);

      expect(backend.log, contains('POST /auth/v1/logout'));
      expect(find.text(loginPageText), findsOneWidget);
    });

    testWidgets('reports a failed logout and stays', (tester) async {
      await pumpProfile(tester);
      backend.authFailures['/logout'] = 500;

      await tester.tap(find.byTooltip(l10n.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, l10n.logout).last);
      await settle(tester);

      expect(find.textContaining('Auth failed'), findsOneWidget);
      expect(find.text(loginPageText), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the shell can ask it to reload', (tester) async {
      await pumpProfile(tester);
      backend.table('users').first['full_name'] = 'Augusta';
      backend.log.clear();

      final state =
          tester.state(find.byType(ProfileScreen)) as ShellRefreshable;
      await tester.runAsync(state.refreshFromShell);
      await settle(tester);

      // The profile comes from the service's cache; the team list reloads.
      expect(backend.log, contains('GET /rest/v1/users'));
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('wide layout shows the identity card beside the sections',
        (tester) async {
      await pumpProfile(tester, size: wideSize);

      expect(find.byType(SliverAppBar), findsNothing);
      expect(find.text(l10n.profileAdminBadge), findsOneWidget);
      final identity = tester.getTopLeft(find.text(l10n.profileAdminBadge));
      final sections =
          tester.getTopLeft(find.text(l10n.profileTeamInformation));
      expect(identity.dx, lessThan(sections.dx));
    });
  });

  group('teams', () {
    setUp(() async {
      await resetFakeSupabase();
      backend.seedSecondTeam();
    });

    testWidgets('switches to another team', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.switchTeam));
      await tester.pumpAndSettle();
      expect(find.text(l10n.teamCode('XYZ789')), findsOneWidget);

      backend.moveUserToSecondTeam();
      await tester.tap(find.text('Difference Engines'));
      await settle(tester);

      expect(find.text(l10n.profileTeamSwitched), findsOneWidget);
      expect(find.text('XYZ789'), findsOneWidget);
    });

    testWidgets('reports a team the user is not a member of', (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.switchTeam));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Difference Engines'));
      await settle(tester);

      expect(
          find.text(
              l10n.errorSwitchingTeam('User is not a member of this team')),
          findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
    });

    testWidgets('names an unnamed team with a placeholder initial',
        (tester) async {
      backend.table('users').add({
        'id': 'user-1-team-3',
        'email': FakeBackend.userEmail,
        'team_id': 'team-3',
        'teams': {'name': null, 'team_code': null},
      });
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.switchTeam));
      await tester.pumpAndSettle();

      expect(find.text(l10n.teamFallbackName), findsOneWidget);
      expect(find.text(l10n.teamCode('N/A')), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('picking the current team or cancelling changes nothing',
        (tester) async {
      await pumpProfile(tester);
      await tapVisible(tester, find.text(l10n.switchTeam));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analytical Engines').last);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text(l10n.switchTeam));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.log.where((r) => r == 'GET /rest/v1/teams'), isEmpty);
    });
  });

  group('member', () {
    setUp(() => resetFakeSupabase(role: 'member'));

    testWidgets('hides admin-only settings', (tester) async {
      await pumpProfile(tester);

      expect(find.text(l10n.profileMemberBadge), findsOneWidget);
      expect(find.text(l10n.profileTeamMembers), findsNothing);
    });
  });
}
