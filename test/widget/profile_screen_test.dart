import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/providers/shared_preferences_provider.dart';
import 'package:ell_ena/screens/profile/profile_screen.dart';
import 'package:ell_ena/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpProfile(
    WidgetTester tester,
    Size size, {
    bool besideSidebar = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: ChangeNotifierProvider<ThemeController>.value(
          value: ThemeController(prefs),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: besideSidebar
                // Sidebar (288px) plus its divider, as in DesktopShell.
                ? const Row(
                    children: [
                      SizedBox(width: 289),
                      Expanded(child: ProfileScreen()),
                    ],
                  )
                : const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('wide profile shows the identity card beside the sections',
      (tester) async {
    await pumpProfile(tester, const Size(1440, 1000));

    expect(tester.takeException(), isNull);
    // No phone header, and no second logout next to the account menu's.
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('Logout'), findsNothing);
    expect(find.text('Team Information'), findsOneWidget);

    final identity = tester.getTopLeft(find.text('Team Member'));
    final sections = tester.getTopLeft(find.text('Team Information'));
    expect(identity.dx, lessThan(sections.dx));
  });

  testWidgets('wide profile stacks beside the sidebar at 1024px',
      (tester) async {
    await pumpProfile(tester, const Size(1024, 1000), besideSidebar: true);

    expect(tester.takeException(), isNull);
    final identity = tester.getTopLeft(find.text('Team Member'));
    final sections = tester.getTopLeft(find.text('Team Information'));
    expect(identity.dy, lessThan(sections.dy));
  });

  testWidgets('phone profile keeps its header', (tester) async {
    await pumpProfile(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.byType(SliverAppBar), findsOneWidget);
  });
}
