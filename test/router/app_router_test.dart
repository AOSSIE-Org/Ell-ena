import 'package:ell_ena/router/app_router.dart';
import 'package:ell_ena/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appRedirect', () {
    String? redirect(
      String location, {
      bool isReady = true,
      bool isSignedIn = true,
    }) {
      return appRedirect(
        location: Uri.parse(location),
        isReady: isReady,
        isSignedIn: () => isSignedIn,
      );
    }

    test('sends deep links through the splash until startup finishes', () {
      final target = Uri.parse(
        redirect('/tasks?filter=open', isReady: false)!,
      );

      expect(target.path, AppRoutes.splash);
      expect(target.queryParameters[AppRoutes.fromParam], '/tasks?filter=open');
    });

    test('leaves the splash alone before startup finishes', () {
      expect(redirect('/', isReady: false), isNull);
      expect(redirect('/?code=abc', isReady: false), isNull);
    });

    test('does not read the session before startup finishes', () {
      expect(
        () => appRedirect(
          location: Uri.parse(AppRoutes.home),
          isReady: false,
          isSignedIn: () => throw StateError('client not ready'),
        ),
        returnsNormally,
      );
    });

    test('sends signed-out users from the shell to login', () {
      for (final path in AppRoutes.shellPaths) {
        expect(redirect(path, isSignedIn: false), AppRoutes.login);
      }
    });

    test('lets signed-in users into the shell', () {
      for (final path in AppRoutes.shellPaths) {
        expect(redirect(path), isNull);
      }
    });

    test('lets anyone reach login and the splash once ready', () {
      expect(redirect(AppRoutes.login, isSignedIn: false), isNull);
      expect(redirect(AppRoutes.splash, isSignedIn: false), isNull);
    });
  });
}
