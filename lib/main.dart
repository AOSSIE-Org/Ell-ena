import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';

import 'services/navigation_service.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
import 'services/app_shortcuts_service.dart'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize app shortcuts service first
    await AppShortcutsService.initialize();
    
    // Initialize other services
    await SupabaseService().initialize();
    await AIService().initialize();
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ell-ena',
      debugShowCheckedModeBanner: false,

      navigatorKey: NavigationService().navigatorKey,
      navigatorObservers: <NavigatorObserver>[
        AppRouteObserver.instance,
      ],

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.green.shade400,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: ColorScheme.dark(
          primary: Colors.green.shade400,
          secondary: Colors.green.shade700,
          surface: const Color(0xFF2A2A2A),
          background: const Color(0xFF1A1A1A),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),

      home: const SplashScreen(),

      onGenerateRoute: (settings) {
        // Get initial shortcut if any
        final initialShortcut = AppShortcutsService.getPendingShortcut();
        
        // Convert shortcut to screen index
        int getScreenIndex(String? shortcut) {
          switch (shortcut) {
            case 'dashboard': return 0;
            case 'calendar': return 1;
            case 'workspace': return 2;
            case 'chat': return 3;
            case 'profile': return 4;
            default: return 0;
          }
        }
        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
              settings: settings,
            );

          case '/home':
            Map<String, dynamic>? args;
            
            // If there's an initial shortcut, use it
            if (initialShortcut != null) {
              args = {
                'screen': getScreenIndex(initialShortcut),
                'initial_route': initialShortcut
              };
            }
            
            // Merge with any existing arguments
            if (settings.arguments != null) {
              args = {
                ...args ?? {},
                ...settings.arguments as Map<String, dynamic>,
              };
            }
            
            return MaterialPageRoute(
              builder: (_) => HomeScreen(arguments: args),
              settings: settings,
            );

          case '/chat':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChatScreen(arguments: args),
              settings: settings,
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
              settings: settings,
            );
        }
      },
    );
  }
}

/// Simple singleton RouteObserver
/// Used so screens can refresh when they regain focus
class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver._();
  static final AppRouteObserver instance = AppRouteObserver._();
}