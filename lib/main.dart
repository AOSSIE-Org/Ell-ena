

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
  
  // Initialize theme service first to load saved preference
  final themeService = ThemeService();
  await themeService.initialize();
  
  try {
    await SupabaseService().initialize();
    
    await AIService().initialize();
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
  
  runApp(MyApp(themeService: themeService));
}

class MyApp extends StatelessWidget {
  final ThemeService themeService;
  
  const MyApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ell-ena',
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService().navigatorKey,
          navigatorObservers: <NavigatorObserver>[AppRouteObserver.instance],
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: themeService.themeMode,
          home: const SplashScreen(),
          builder: (context, child) {
            // Make theme service accessible throughout the app
            return _ThemeServiceProvider(
              themeService: themeService,
              child: child!,
            );
          },
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

// InheritedWidget to provide ThemeService throughout the widget tree
class _ThemeServiceProvider extends InheritedWidget {
  final ThemeService themeService;

  const _ThemeServiceProvider({
    required this.themeService,
    required super.child,
  });

  static ThemeService of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<_ThemeServiceProvider>();
    assert(provider != null, 'No ThemeServiceProvider found in context');
    return provider!.themeService;
  }

  @override
  bool updateShouldNotify(_ThemeServiceProvider oldWidget) {
    return themeService != oldWidget.themeService;
  }
}

// Simple singleton RouteObserver to allow screens to refresh on focus
class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver._();
  static final AppRouteObserver instance = AppRouteObserver._();
}
