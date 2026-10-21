import 'package:ell_ena/providers/navigation/models/home_tab.dart';
import 'package:ell_ena/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('maps home tab paths bidirectionally', () {
      for (final tab in HomeTab.values) {
        final path = AppRoutes.pathForHomeTab(tab);
        expect(AppRoutes.homeTabForPath(path), tab);
      }
    });

    test('maps workspace deep links to workspace tab', () {
      expect(AppRoutes.homeTabForPath(AppRoutes.tasks), HomeTab.workspace);
      expect(AppRoutes.homeTabForPath(AppRoutes.tickets), HomeTab.workspace);
      expect(AppRoutes.homeTabForPath(AppRoutes.meetings), HomeTab.workspace);
      expect(AppRoutes.workspaceTabIndexForPath(AppRoutes.tasks), 0);
      expect(AppRoutes.workspaceTabIndexForPath(AppRoutes.tickets), 1);
      expect(AppRoutes.workspaceTabIndexForPath(AppRoutes.meetings), 2);
    });

    test('maps workspace tab indexes to paths', () {
      expect(AppRoutes.pathForWorkspaceTabIndex(0), AppRoutes.tasks);
      expect(AppRoutes.pathForWorkspaceTabIndex(1), AppRoutes.tickets);
      expect(AppRoutes.pathForWorkspaceTabIndex(2), AppRoutes.meetings);
    });

    test('resumes only in-app locations after startup', () {
      expect(AppRoutes.resumableLocation('/tasks'), '/tasks');
      expect(
        AppRoutes.resumableLocation('/chat?message=hi'),
        '/chat?message=hi',
      );
      expect(AppRoutes.resumableLocation(AppRoutes.login), AppRoutes.login);

      expect(AppRoutes.resumableLocation(null), isNull);
      expect(AppRoutes.resumableLocation('https://example.com'), isNull);
      expect(AppRoutes.resumableLocation('https://example.com/home'), isNull);
      expect(AppRoutes.resumableLocation('//example.com/home'), isNull);
      expect(AppRoutes.resumableLocation('javascript:alert(1)'), isNull);
      expect(AppRoutes.resumableLocation(AppRoutes.splash), isNull);
      expect(AppRoutes.resumableLocation('/not-a-route'), isNull);
    });
  });
}
