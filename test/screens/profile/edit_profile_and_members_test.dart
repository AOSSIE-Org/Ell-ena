import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/screens/profile/edit_profile_screen.dart';
import 'package:ell_ena/screens/profile/team_members_screen.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(setUpFakeSupabase);
  setUp(() => resetFakeSupabase());

  group('EditProfileScreen', () {
    var updates = 0;

    Future<void> pumpEdit(
      WidgetTester tester, {
      String role = 'admin',
      String? fullName = 'Ada Lovelace',
    }) async {
      updates = 0;
      await pumpRoutedScreen(
        tester,
        Scaffold(
          body: TextButton(
            onPressed: () => NavigationService().navigateTo(
              EditProfileScreen(
                userProfile: {
                  'full_name': fullName,
                  'email': FakeBackend.userEmail,
                  'role': role,
                },
                onProfileUpdated: () => updates++,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    TextFormField field(WidgetTester tester, int index) =>
        tester.widget<TextFormField>(find.byType(TextFormField).at(index));

    testWidgets('splits the name and locks the email', (tester) async {
      await pumpEdit(tester);

      expect(field(tester, 0).controller!.text, 'Ada');
      expect(field(tester, 1).controller!.text, 'Lovelace');
      expect(field(tester, 2).controller!.text, FakeBackend.userEmail);
      expect(
          tester.widget<EditableText>(find.byType(EditableText).at(2)).readOnly,
          isTrue);
      expect(find.text(l10n.profileEmailCannotChange), findsOneWidget);
      expect(find.text(l10n.profileTeamAdmin), findsOneWidget);
      expect(find.text(l10n.profileAdminPrivileges), findsOneWidget);
    });

    testWidgets('shows member access for members and handles no name',
        (tester) async {
      await pumpEdit(tester, role: 'member', fullName: null);

      expect(field(tester, 0).controller!.text, '');
      expect(find.text(l10n.profileTeamMember), findsOneWidget);
      expect(find.text(l10n.profileStandardAccess), findsOneWidget);
    });

    testWidgets('requires a first name', (tester) async {
      await pumpEdit(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.tap(find.text(l10n.save));
      await tester.pump();

      expect(find.text(l10n.profileFirstNameRequired), findsOneWidget);
      expect(backend.log, isEmpty);
    });

    testWidgets('saves a changed name, notifies, and closes', (tester) async {
      await pumpEdit(tester);
      await tester.enterText(find.byType(TextFormField).at(1), 'King');
      await tester.tap(find.text(l10n.save));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(backend.bodiesFor('PATCH', '/rest/v1/users'), [
        {'full_name': 'Ada King'}
      ]);
      expect(backend.table('users').first['full_name'], 'Ada King');
      expect(updates, 1);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text(l10n.profileUpdated), findsOneWidget);
    });

    testWidgets('closes without saving when nothing changed', (tester) async {
      await pumpEdit(tester);
      await tester.tap(find.text(l10n.save));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(backend.log, isEmpty);
      expect(updates, 0);
      expect(find.byType(EditProfileScreen), findsNothing);
    });

    testWidgets('stays open and reports a failed save', (tester) async {
      backend.failures['users'] = 500;
      await pumpEdit(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Augusta');
      await tester.tap(find.text(l10n.save));
      await settle(tester);

      expect(find.text(l10n.profileUpdateFailed), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(updates, 0);
    });
  });

  group('TeamMembersScreen', () {
    testWidgets('lists members with their roles', (tester) async {
      await pumpApp(
        tester,
        const TeamMembersScreen(teamId: 'ABC123', teamName: 'Engines'),
        themeMode: ThemeMode.dark,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await settle(tester);

      expect(
          find.text(l10n.profileTeamMembersTitle('Engines')), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('bob@example.com'), findsOneWidget);
      expect(find.text(l10n.profileRoleAdmin), findsOneWidget);
      expect(find.text(l10n.profileRoleMember), findsOneWidget);
    });

    testWidgets('names members without a name as unknown', (tester) async {
      backend.table('users').add({
        'id': 'user-3',
        'team_id': FakeBackend.teamId,
        'role': null,
      });
      await pumpApp(
        tester,
        const TeamMembersScreen(teamId: 'ABC123', teamName: 'Engines'),
      );
      await settle(tester);

      expect(find.text(l10n.profileUnknownMember), findsOneWidget);
    });

    testWidgets('shows an empty state for an unknown team', (tester) async {
      await pumpApp(
        tester,
        const TeamMembersScreen(teamId: 'NOPE00', teamName: 'Nobody'),
      );
      await settle(tester);

      expect(find.text(l10n.profileNoMembersFound), findsOneWidget);
      expect(find.text(l10n.profileNoMembersYet), findsOneWidget);
    });

    testWidgets('shows an error with retry when loading fails', (tester) async {
      backend.failures['teams'] = 500;
      await pumpApp(
        tester,
        const TeamMembersScreen(teamId: 'ABC123', teamName: 'Engines'),
      );
      await settle(tester);

      expect(find.text(l10n.profileMembersLoadFailed), findsOneWidget);
      expect(find.text(l10n.profileNoMembersFound), findsNothing);

      await tester.tap(find.text(l10n.profileRetry));
      await settle(tester);

      expect(find.text(l10n.profileMembersLoadFailed), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
    });
  });
}
