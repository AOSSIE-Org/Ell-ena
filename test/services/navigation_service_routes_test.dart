import 'package:ell_ena/router/app_routes.dart';
import 'package:ell_ena/screens/auth/login_screen.dart';
import 'package:ell_ena/screens/home/home_screen.dart';
import 'package:ell_ena/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final navigation = NavigationService();
  late GoRouter router;

  /// Each route shows its path and query so tests can read where they are.
  Future<void> pumpRouter(WidgetTester tester,
      {String initial = AppRoutes.login}) async {
    Widget page(BuildContext context, GoRouterState state) =>
        Text('at ${state.uri}');
    router = GoRouter(
      navigatorKey: navigation.navigatorKey,
      initialLocation: initial,
      routes: [
        for (final path in [AppRoutes.login, ...AppRoutes.shellPaths])
          GoRoute(path: path, builder: page),
      ],
    );
    navigation.setRouter(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  Future<void> expectAt(WidgetTester tester, String location) async {
    await tester.pumpAndSettle();
    expect(find.text('at $location'), findsOneWidget);
  }

  // Runs first: each test file has its own isolate, so no router is set yet.
  testWidgets('the router getter throws until a router is set', (tester) async {
    expect(() => navigation.router, throwsStateError);
    expect(navigation.goBack, throwsStateError);

    // Before go_router exists, goBack pops the plain navigator.
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigation.navigatorKey,
      home: const Text('root'),
    ));
    navigation.navigateTo(const Text('pushed'));
    await tester.pumpAndSettle();
    navigation.goBack();
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsNothing);
    navigation.goBack();
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    // Unmount it so go_router can take over the same navigator key.
    await tester.pumpWidget(const SizedBox());

    await pumpRouter(tester);

    expect(navigation.router, same(router));
  });

  group('goHome', () {
    testWidgets('goes to the dashboard by default', (tester) async {
      await pumpRouter(tester);

      navigation.goHome();

      await expectAt(tester, AppRoutes.home);
    });

    testWidgets('maps a legacy screen index to its tab', (tester) async {
      await pumpRouter(tester);

      navigation.goHome(arguments: {'screen': 1});
      await expectAt(tester, AppRoutes.calendar);

      navigation.goHome(arguments: {'screen': 4});
      await expectAt(tester, AppRoutes.profile);

      navigation.goHome(arguments: {'screen': 99});
      await expectAt(tester, AppRoutes.home);
    });

    testWidgets('opens chat with an encoded starter message', (tester) async {
      await pumpRouter(tester);

      navigation.goHome(
          arguments: {'screen': 3, 'initial_message': 'Summarise #42 & more'});

      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.chat);
      expect(
          router.state.uri.queryParameters['message'], 'Summarise #42 & more');
    });

    testWidgets('ignores a starter message for tabs other than chat',
        (tester) async {
      await pumpRouter(tester);

      navigation.goHome(arguments: {'screen': 2, 'initial_message': 'hi'});

      await expectAt(tester, AppRoutes.workspace);
    });

    testWidgets('a starter message alone opens chat', (tester) async {
      await pumpRouter(tester);

      navigation.goHome(arguments: {'initial_message': 'hello there'});

      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['message'], 'hello there');
    });

    testWidgets('ignores arguments of the wrong type', (tester) async {
      await pumpRouter(tester);

      navigation.goHome(arguments: {'screen': '1', 'initial_message': 3});

      await expectAt(tester, AppRoutes.home);
    });
  });

  group('replacement', () {
    testWidgets('HomeScreen means the home route', (tester) async {
      await pumpRouter(tester);

      await navigation.navigateToReplacement(const HomeScreen());

      await expectAt(tester, AppRoutes.home);
    });

    testWidgets('LoginScreen means the login route, clearing pushed screens',
        (tester) async {
      await pumpRouter(tester, initial: AppRoutes.home);
      navigation.navigateTo(const Text('pushed'));
      await tester.pumpAndSettle();

      await navigation.navigateToReplacement(const LoginScreen());

      await expectAt(tester, AppRoutes.login);
      expect(find.text('pushed'), findsNothing);
    });

    testWidgets('other screens replace the top route', (tester) async {
      await pumpRouter(tester);
      navigation.navigateTo(const Text('first'));
      await tester.pumpAndSettle();

      navigation.navigateToReplacement(const Text('second'));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      navigation.goBack();
      await expectAt(tester, AppRoutes.login);
    });
  });

  group('goBack', () {
    testWidgets('pops a pushed screen', (tester) async {
      await pumpRouter(tester);
      navigation.navigateTo(const Text('details'));
      await tester.pumpAndSettle();

      navigation.goBack();
      await tester.pumpAndSettle();

      expect(find.text('details'), findsNothing);
      await expectAt(tester, AppRoutes.login);
    });

    testWidgets('does nothing at the root', (tester) async {
      await pumpRouter(tester);

      navigation.goBack();

      await expectAt(tester, AppRoutes.login);
    });
  });

  testWidgets('navigating without a mounted navigator is an error',
      (tester) async {
    await tester.pumpWidget(const SizedBox());

    expect(() => navigation.navigateTo(const Text('x')), throwsStateError);
    expect(() => navigation.navigateToReplacement(const Text('x')),
        throwsStateError);
  });
}
