import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'services/navigation_service.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
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
    ChangeNotifierProvider<ThemeController>.value(
      value: themeController,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
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
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => HomeScreen(arguments: args),
            settings: settings,
          );
        } else if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
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

// Simple singleton RouteObserver to allow screens to refresh on focus
class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver._();
  static final AppRouteObserver instance = AppRouteObserver._();
}
