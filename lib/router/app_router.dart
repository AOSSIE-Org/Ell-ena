import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import 'app_route_observer.dart';
import '../screens/splash_screen.dart';
import '../services/app_startup.dart';
import '../services/navigation_service.dart';
import '../services/supabase_service.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: NavigationService().navigatorKey,
    initialLocation: AppRoutes.splash,
    observers: <NavigatorObserver>[AppRouteObserver.instance],
    redirect: (context, state) => appRedirect(
      location: state.uri,
      isReady: AppStartup.isReady,
      isSignedIn: () => SupabaseService().client.auth.currentUser != null,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(
          from: state.uri.queryParameters[AppRoutes.fromParam],
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return HomeScreen(
            location: state.uri.path,
            queryParameters: state.uri.queryParameters,
          );
        },
        routes: _shellTabRoutes,
      ),
    ],
  );

  NavigationService().setRouter(router);
  return router;
});

/// Routes a location before startup finishes through the splash, and keeps
/// signed-out users out of the app shell.
///
/// [isSignedIn] is lazy because the Supabase client does not exist until
/// startup is ready.
@visibleForTesting
String? appRedirect({
  required Uri location,
  required bool isReady,
  required bool Function() isSignedIn,
}) {
  final path = location.path;
  if (!isReady) {
    if (path == AppRoutes.splash) return null;
    return Uri(
      path: AppRoutes.splash,
      queryParameters: {AppRoutes.fromParam: location.toString()},
    ).toString();
  }
  if (AppRoutes.shellPaths.contains(path) && !isSignedIn()) {
    return AppRoutes.login;
  }
  return null;
}

final List<GoRoute> _shellTabRoutes = <GoRoute>[
  GoRoute(
    path: AppRoutes.home,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.calendar,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.workspace,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.tasks,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.tickets,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.meetings,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.chat,
    pageBuilder: _shellPage,
  ),
  GoRoute(
    path: AppRoutes.profile,
    pageBuilder: _shellPage,
  ),
];

Page<void> _shellPage(BuildContext context, GoRouterState state) {
  return const NoTransitionPage<void>(child: SizedBox.shrink());
}
