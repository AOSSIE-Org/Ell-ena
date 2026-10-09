import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import 'app_route_observer.dart';
import '../screens/splash_screen.dart';
import '../services/navigation_service.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: NavigationService().navigatorKey,
    initialLocation: AppRoutes.splash,
    observers: <NavigatorObserver>[AppRouteObserver.instance],
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
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
