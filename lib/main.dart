import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'services/navigation_service.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SupabaseService().initialize();
    
    await AIService().initialize();
    await ThemeService().initialize();
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: Colors.green.shade600,
        secondary: Colors.green.shade700,
        surface: Colors.white,
        background: const Color(0xFFF7F7F7),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, letterSpacing: 0.2),
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.green.shade400,
        secondary: Colors.green.shade700,
        surface: const Color(0xFF2A2A2A),
        background: const Color(0xFF1A1A1A),
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
    );

    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Ell-ena',
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService().navigatorKey,
          navigatorObservers: <NavigatorObserver>[AppRouteObserver.instance],
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeService().themeMode,
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
      },
    );
  }
}

// Simple singleton RouteObserver to allow screens to refresh on focus
class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver._();
  static final AppRouteObserver instance = AppRouteObserver._();
}
