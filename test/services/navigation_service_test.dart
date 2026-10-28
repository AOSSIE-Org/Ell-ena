import 'package:ell_ena/router/app_routes.dart';
import 'package:ell_ena/screens/auth/login_screen.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;

  Future<void> pumpRouter(WidgetTester tester) async {
    router = GoRouter(
      navigatorKey: NavigationService().navigatorKey,
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Text('login page'),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Text('home page'),
        ),
      ],
    );
    NavigationService().setRouter(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  Future<void> pushSignUp(WidgetTester tester) async {
    NavigationService().navigateTo(const Text('sign-up page'));
    await tester.pumpAndSettle();
    expect(find.text('sign-up page'), findsOneWidget);
  }

  testWidgets('goHome clears screens pushed above the router pages',
      (tester) async {
    await pumpRouter(tester);
    await pushSignUp(tester);

    NavigationService().goHome();
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.home);
    expect(find.text('sign-up page'), findsNothing);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('goHome clears open dialogs', (tester) async {
    await pumpRouter(tester);
    showDialog<void>(
      context: NavigationService().navigatorKey.currentContext!,
      builder: (_) => const Text('team dialog'),
    );
    await tester.pumpAndSettle();

    NavigationService().goHome();
    await tester.pumpAndSettle();

    expect(find.text('team dialog'), findsNothing);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('returning to the current /login clears pushed screens',
      (tester) async {
    await pumpRouter(tester);
    await pushSignUp(tester);

    // Only used as a marker; the router builds its own /login page.
    NavigationService().navigateToReplacement(const LoginScreen());
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.login);
    expect(find.text('sign-up page'), findsNothing);
    expect(find.text('login page'), findsOneWidget);
  });
}
