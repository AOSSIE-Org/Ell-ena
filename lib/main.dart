import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'services/navigation_service.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
import 'providers/theme_provider.dart';
import 'theme/theme_controller.dart';
import 'theme/app_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService().initialize();
    await AIService().initialize();
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
  
  final themeController = await ThemeController.create();

runApp(
  WidgetsBindingObserverWidget(
    child: ProviderScope(
      overrides: [
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
    return MaterialApp(
      title: 'Ell-ena',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService().navigatorKey,
      navigatorObservers: <NavigatorObserver>[AppRouteObserver.instance],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeController.flutterThemeMode,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) => const SplashScreen(),
            settings: settings,
          );
        } else if (settings.name == '/home') {
          final args = (settings.arguments is Map<String, dynamic>) 
              ? settings.arguments as Map<String, dynamic> 
              : null;
              
          return MaterialPageRoute(
            builder: (context) => HomeScreen(arguments: args),
            settings: settings,
          );
        } else if (settings.name == '/chat') {
          final args = (settings.arguments is Map<String, dynamic>) 
              ? settings.arguments as Map<String, dynamic> 
              : null;
              
          return MaterialPageRoute(
            builder: (context) => ChatScreen(arguments: args),
            settings: settings,
          );
        }
        return null;
      },
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
      extends State<WidgetsBindingObserverWidget>
      with WidgetsBindingObserver {

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this);
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      if (state == AppLifecycleState.detached) {
        SupabaseService().dispose(); // ✅ ONLY IMPORTANT LINE
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

// Simple singleton RouteObserver to allow screens to refresh on focus
class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver._();
  static final AppRouteObserver instance = AppRouteObserver._();
}

