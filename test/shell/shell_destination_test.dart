import 'package:ell_ena/router/app_routes.dart';
import 'package:ell_ena/shell/shell_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShellDestination', () {
    test('maps every destination to its path and back', () {
      for (final destination in ShellDestination.values) {
        expect(ShellDestination.fromPath(destination.path), destination);
      }
    });

    test('opens Tasks for the phone-only workspace path', () {
      expect(
        ShellDestination.fromPath(AppRoutes.workspace),
        ShellDestination.tasks,
      );
    });

    test('falls back to the dashboard for unknown paths', () {
      expect(ShellDestination.fromPath('/unknown'), ShellDestination.dashboard);
    });

    test('lists tasks, tickets and meetings in the sidebar, not profile', () {
      expect(ShellDestination.sidebar, [
        ShellDestination.dashboard,
        ShellDestination.calendar,
        ShellDestination.tasks,
        ShellDestination.tickets,
        ShellDestination.meetings,
        ShellDestination.chat,
      ]);
    });

    test('only chat has nothing to refresh', () {
      for (final destination in ShellDestination.values) {
        expect(
          destination.canRefresh,
          destination != ShellDestination.chat,
        );
      }
    });
  });
}
