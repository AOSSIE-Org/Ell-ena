import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/navigation/models/home_tab.dart';
import '../router/app_routes.dart';
import '../screens/home/home_screen.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  GoRouter? _router;

  void setRouter(GoRouter router) {
    _router = router;
  }

  GoRouter get router {
    final router = _router;
    if (router == null) {
      throw StateError('GoRouter has not been initialized');
    }
    return router;
  }

  /// Navigates to the authenticated home shell, preserving legacy route args.
  void goHome({Map<String, dynamic>? arguments}) {
    if (arguments != null) {
      if (arguments.containsKey('screen') && arguments['screen'] is int) {
        final tab = AppRoutes.homeTabForScreenIndex(arguments['screen'] as int);
        if (arguments.containsKey('initial_message') &&
            arguments['initial_message'] is String &&
            tab == HomeTab.chat) {
          router.go(
            '${AppRoutes.chat}?message=${Uri.encodeComponent(arguments['initial_message'] as String)}',
          );
          return;
        }

        router.go(AppRoutes.pathForHomeTab(tab));
        return;
      }

      if (arguments.containsKey('initial_message') &&
          arguments['initial_message'] is String) {
        router.go(
          '${AppRoutes.chat}?message=${Uri.encodeComponent(arguments['initial_message'] as String)}',
        );
        return;
      }
    }

    router.go(AppRoutes.home);
  }

  Future<dynamic> navigateTo(Widget screen) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Navigator not initialized');
    }
    return navigator.push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<dynamic> navigateToReplacement(Widget screen) {
    if (screen is HomeScreen) {
      goHome();
      return Future<void>.value();
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Navigator not initialized');
    }
    return navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void goBack() {
    final router = _router;
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Navigator not initialized');
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
