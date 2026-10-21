import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/shared_preferences_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/supabase_service.dart';
import 'theme/app_themes.dart';
import 'theme/theme_controller.dart';
import 'utils/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();

  // Only local reads before the first frame; network-bound service setup runs
  // behind the splash via AppStartup.
  final prefs = await SharedPreferences.getInstance();
  final themeController = await ThemeController.create();

  runApp(
    WidgetsBindingObserverWidget(
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          themeControllerProvider.overrideWith((ref) => themeController),
        ],
        child: ChangeNotifierProvider<ThemeController>.value(
          value: themeController,
          child: const MyApp(),
        ),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeControllerProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeController.flutterThemeMode,
      routerConfig: router,
    );
  }
}

class WidgetsBindingObserverWidget extends StatefulWidget {
  final Widget child;

  const WidgetsBindingObserverWidget({
    super.key,
    required this.child,
  });

  @override
  State<WidgetsBindingObserverWidget> createState() =>
      _WidgetsBindingObserverWidgetState();
}

class _WidgetsBindingObserverWidgetState
    extends State<WidgetsBindingObserverWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      SupabaseService().dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
