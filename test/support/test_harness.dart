import 'dart:convert';
import 'dart:io';

import 'package:ell_ena/l10n/app_localizations.dart';
import 'package:ell_ena/providers/shared_preferences_provider.dart';
import 'package:ell_ena/providers/theme_provider.dart';
import 'package:ell_ena/router/app_routes.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:ell_ena/services/supabase_service.dart';
import 'package:ell_ena/theme/app_themes.dart';
import 'package:ell_ena/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_backend.dart';

export 'fake_backend.dart';
export 'platform_mocks.dart';

// Test harness for code that talks to Supabase.
//
// `Supabase`, `SupabaseService`, and `AppStartup` are process-wide
// singletons, and each test file runs in its own isolate, so a file calls
// [setUpFakeSupabase] once in `setUpAll` and [resetFakeSupabase] in `setUp`.
//
// Auth runs on real timers, which never fire under `testWidgets`' fake
// clock. Inside a widget test body, reset through [resetInTest].
//
// Futures cached by a singleton (`AppStartup.ensureInitialized`) must first
// be created outside a widget test, or later widget tests wait on them
// forever: call `AppStartup.ensureInitialized()` in `setUpAll` when a test
// builds something that awaits it (the splash, the router guard).

/// Shared by every test in one file.
final backend = FakeBackend();

const _fakeEnv = '''
SUPABASE_URL=https://fake.supabase.co
SUPABASE_ANON_KEY=anon-key
GEMINI_API_KEY=gemini-key
''';

bool _supabaseReady = false;

/// Serves `.env` from [_fakeEnv]; other assets come from the test bundle, as
/// in the default `flutter test` asset handler.
void _mockAssets() {
  final assetDir = Platform.environment['UNIT_TEST_ASSETS'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(
      message.offsetInBytes,
      message.lengthInBytes,
    )));
    if (key == '.env') {
      return ByteData.sublistView(utf8.encode(_fakeEnv));
    }
    if (assetDir == null) return null;
    final file = File('$assetDir/$key');
    if (!file.existsSync()) return null;
    return ByteData.sublistView(file.readAsBytesSync());
  });
}

/// Starts the real Supabase client against [backend] and initialises the
/// [SupabaseService] singleton. Call from `setUpAll`.
Future<void> setUpFakeSupabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  _mockAssets();
  if (_supabaseReady) return;
  _supabaseReady = true;
  await Supabase.initialize(
    url: 'https://fake.supabase.co',
    anonKey: 'anon-key',
    httpClient: backend.client,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      detectSessionInUri: false,
      autoRefreshToken: false,
    ),
  );
  await SupabaseService().initialize();
}

/// Clears [backend], optionally seeds a team, and signs the fake user in or
/// out. Call from `setUp`.
///
/// Signs out through [SupabaseService] so its cached profile and team roster
/// do not leak between tests, and loads the new profile so [role] applies.
Future<void> resetFakeSupabase({
  bool signedIn = true,
  bool seedTeam = true,
  String role = 'admin',
}) async {
  backend.reset();
  SharedPreferences.setMockInitialValues({});
  await SupabaseService().signOut();
  if (seedTeam) backend.seedTeam(role: role);
  if (signedIn) {
    await Supabase.instance.client.auth.signInWithPassword(
      email: FakeBackend.userEmail,
      password: 'password',
    );
    if (seedTeam) {
      await SupabaseService().getCurrentUserProfile(forceRefresh: true);
    }
  }
  backend.log.clear();
  backend.sent.clear();
}

/// [resetFakeSupabase] from inside a widget test body.
Future<void> resetInTest(
  WidgetTester tester, {
  bool signedIn = true,
  bool seedTeam = true,
  String role = 'admin',
}) async {
  await tester.runAsync(() => resetFakeSupabase(
        signedIn: signedIn,
        seedTeam: seedTeam,
        role: role,
      ));
}

/// Answers a request itself, or returns null to let [backend] handle it.
typedef Intercept = http.Response? Function(http.Request request);

/// A [SupabaseClient] wired to [backend] with its own in-memory session, for
/// testing a `SupabaseService.withClient` instance apart from the singleton.
/// [intercept] can override single responses, e.g. a row that row-level
/// security hides from a delete.
SupabaseClient fakeSupabaseClient({Intercept? intercept}) => SupabaseClient(
      'https://fake.supabase.co',
      'anon-key',
      httpClient: intercept == null
          ? backend.client
          : MockClient((request) async {
              final own = intercept(request);
              if (own != null) {
                return http.Response(
                  own.body,
                  own.statusCode,
                  headers: own.headers.isEmpty
                      ? {'content-type': 'application/json'}
                      : own.headers,
                  request: request,
                );
              }
              final copy = http.Request(request.method, request.url)
                ..headers.addAll(request.headers)
                ..bodyBytes = request.bodyBytes;
              return http.Response.fromStream(await backend.client.send(copy));
            }),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );

/// Holds the PKCE code verifier that sign-up and password reset store.
class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _values[key] = value;
}

/// Runs [body] with top-level `http` calls (used for Gemini) answered by
/// [backend].
Future<T> withFakeHttp<T>(Future<T> Function() body) =>
    http.runWithClient(body, () => backend.client);

const phoneSize = Size(400, 900);
const wideSize = Size(1440, 1000);

/// Sizes the test window to [size] for the rest of the test.
void _setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The app's providers around [app], as `main.dart` sets them up.
Future<Widget> _withProviders(
  Widget Function(ThemeController theme) app, {
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final theme = ThemeController(preferences);
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      themeControllerProvider.overrideWith((ref) => theme),
      ...overrides,
    ],
    child: ChangeNotifierProvider<ThemeController>.value(
      value: theme,
      child: app(theme),
    ),
  );
}

/// The test font draws every glyph one em wide, about twice the average
/// width of the app's real font, so rows that fit on devices overflow here.
/// Halving the scale keeps layouts close to real.
Widget _realisticTextScale(BuildContext context, Widget? app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(0.5)),
      child: app!,
    );

/// Pumps [child] inside the app's providers, theme, and localisations.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = phoneSize,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
}) async {
  _setWindow(tester, size);
  await tester.pumpWidget(await _withProviders(
    (theme) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: _realisticTextScale,
      home: child,
    ),
    overrides: overrides,
    prefs: prefs,
  ));
}

/// Shown at `/login` unless a test supplies its own page, so a test can see
/// where [NavigationService] sent the user.
const loginPageText = 'LOGIN PAGE';

/// Shown at the shell paths by [pumpRoutedScreen].
const homePageText = 'HOME PAGE';

/// Like [pumpApp], but behind a real [GoRouter] wired into
/// [NavigationService], so screens can read `GoRouterState` and navigate.
///
/// [pages] maps paths to screens; `/login` defaults to a stub page. [routes]
/// are added as given (e.g. a `ShellRoute`, as the app uses for HomeScreen).
Future<GoRouter> pumpRouted(
  WidgetTester tester, {
  required String initialLocation,
  Map<String, Widget Function(GoRouterState state)> pages = const {},
  List<RouteBase> routes = const [],
  Size size = phoneSize,
  ThemeMode themeMode = ThemeMode.light,
  Map<String, Object> prefs = const {},
}) async {
  _setWindow(tester, size);
  final allPages = <String, Widget Function(GoRouterState state)>{
    AppRoutes.login: (_) => const Scaffold(body: Text(loginPageText)),
    ...pages,
  };
  final router = GoRouter(
    navigatorKey: NavigationService().navigatorKey,
    initialLocation: initialLocation,
    routes: [
      for (final entry in allPages.entries)
        GoRoute(
          path: entry.key,
          builder: (context, state) => entry.value(state),
        ),
      ...routes,
    ],
  );
  NavigationService().setRouter(router);
  addTearDown(router.dispose);

  await tester.pumpWidget(await _withProviders(
    (theme) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: _realisticTextScale,
      routerConfig: router,
    ),
    prefs: prefs,
  ));
  await tester.pump();
  return router;
}

/// Pumps [screen] at `/start` under [pumpRouted], with stub pages for
/// `/login` and the shell paths, for screens that navigate on their own
/// (auth, splash, onboarding).
Future<GoRouter> pumpRoutedScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = phoneSize,
  ThemeMode themeMode = ThemeMode.light,
  Map<String, Object> prefs = const {},
}) {
  return pumpRouted(
    tester,
    initialLocation: '/start',
    pages: {
      '/start': (_) => screen,
      for (final path in AppRoutes.shellPaths)
        path: (_) => const Scaffold(body: Text(homePageText)),
    },
    size: size,
    themeMode: themeMode,
    prefs: prefs,
  );
}

/// Where the router is after navigation.
String currentLocation() =>
    NavigationService().router.routerDelegate.currentConfiguration.uri.path;

/// What a screen opened by [pumpPushed] popped with.
class PushedResult {
  Object? value;
  bool popped = false;
}

/// Opens [screen] from a launcher page, as the app pushes it, and records
/// what it pops with.
Future<PushedResult> pumpPushed(
  WidgetTester tester,
  Widget screen, {
  Size size = phoneSize,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final result = PushedResult();
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result.value = await Navigator.push<Object?>(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
              result.popped = true;
            },
            child: const Text('launch'),
          ),
        ),
      ),
    ),
    size: size,
    themeMode: themeMode,
  );
  await tester.tap(find.text('launch'));
  await tester.pump();
  // Let the page transition finish, so only the new page is on stage.
  await tester.pump(const Duration(seconds: 1));
  await settle(tester);
  return result;
}

/// Pumps frames until async backend work settles without waiting on
/// infinite animations.
Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Removes the snack bar on screen, so the next queued one can show.
Future<void> clearSnackBars(WidgetTester tester) async {
  final messengers = tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger, skipOffstage: false),
  );
  for (final messenger in messengers) {
    messenger.removeCurrentSnackBar();
  }
  await tester.pump(const Duration(seconds: 1));
}
