import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/providers/shared_preferences_provider.dart';
import 'package:ell_ena/providers/theme_provider.dart';
import 'package:ell_ena/router/app_route_observer.dart';
import 'package:ell_ena/router/app_router.dart';
import 'package:ell_ena/router/app_routes.dart';
import 'package:ell_ena/screens/auth/login_screen.dart';
import 'package:ell_ena/screens/home/home_screen.dart';
import 'package:ell_ena/screens/splash_screen.dart';
import 'package:ell_ena/services/app_startup.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:ell_ena/theme/app_themes.dart';
import 'package:ell_ena/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_harness.dart';

/// The app's real router, as `MyApp` builds it, against the fake backend.
void main() {
  setUpAll(() async {
    await setUpFakeSupabase();
    // Start-up caches its future. Created inside one widget test's fake-async
    // zone it could never resume in the next, so finish it here, for real.
    await AppStartup.ensureInitialized();
  });
  setUp(() => resetFakeSupabase(signedIn: false));

  late GoRouter router;

  Future<void> pumpRouterApp(WidgetTester tester) async {
    tester.view.physicalSize = wideSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final theme = ThemeController(prefs);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      themeControllerProvider.overrideWith((ref) => theme),
    ]);
    addTearDown(container.dispose);
    router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ChangeNotifierProvider<ThemeController>.value(
          value: theme,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: lightTheme,
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(0.5)),
              child: app!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
  }

  /// Lets the splash finish its 1.5 s intro and start-up.
  Future<void> finishSplash(WidgetTester tester) async {
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester);
  }

  testWidgets('starts on the splash, then sends signed-out users to login',
      (tester) async {
    await pumpRouterApp(tester);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(NavigationService().router, same(router));
    expect(router.configuration.navigatorKey,
        same(NavigationService().navigatorKey));
    expect(router.routerDelegate.builder.observers,
        contains(AppRouteObserver.instance));

    await finishSplash(tester);

    expect(router.state.uri.path, AppRoutes.login);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('keeps signed-out users out of the shell', (tester) async {
    await pumpRouterApp(tester);
    await finishSplash(tester);

    router.go(AppRoutes.tasks);
    await settle(tester);

    expect(router.state.uri.path, AppRoutes.login);
  });

  testWidgets('every shell path opens the home shell once signed in',
      (tester) async {
    // The chat tab starts speech recognition, a plugin with no test host.
    const speech = MethodChannel('plugin.csdcorp.com/speech_to_text');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speech, (_) async => false);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speech, null));
    await Supabase.instance.client.auth
        .signInWithPassword(email: FakeBackend.userEmail, password: 'password');
    await pumpRouterApp(tester);
    await finishSplash(tester);

    expect(router.state.uri.path, AppRoutes.home);
    for (final path in AppRoutes.shellPaths) {
      router.go(path);
      await settle(tester, frames: 3);

      expect(router.state.uri.path, path);
      final shell = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(shell.location, path);
    }

    router.go('${AppRoutes.chat}?message=hi');
    await settle(tester, frames: 3);
    expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).queryParameters,
        {'message': 'hi'});

    // Unmount the shell and let its delayed callbacks run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
