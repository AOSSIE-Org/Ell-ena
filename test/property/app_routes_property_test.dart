import 'package:ell_ena/providers/navigation/models/home_tab.dart';
import 'package:ell_ena/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/property.dart';

void main() {
  final inAppPaths = [AppRoutes.login, ...AppRoutes.shellPaths];
  final pathGen = Gens.oneOf(inAppPaths);
  final queryGen = Gens.listOf(Gens.word(), maxLength: 3);

  String withQuery(String path, List<String> words) {
    if (words.isEmpty) return path;
    return Uri(path: path, queryParameters: {
      for (var i = 0; i < words.length; i++) 'k$i': words[i],
    }).toString();
  }

  group('resumableLocation', () {
    property<List<Object>>(
      'returns in-app locations unchanged, query included',
      (r) => [pathGen(r), queryGen(r)],
      (input) {
        final location =
            withQuery(input[0] as String, input[1] as List<String>);

        expect(AppRoutes.resumableLocation(location), location);
      },
    );

    property<List<Object>>(
      'rejects absolute and protocol-relative URLs, even to app paths',
      (r) => [
        Gens.oneOf(['https', 'http', 'javascript', 'ftp'])(r),
        Gens.word()(r),
        pathGen(r),
      ],
      (input) {
        final scheme = input[0] as String;
        final host = '${input[1]}.example';
        final path = input[2] as String;

        expect(AppRoutes.resumableLocation('$scheme://$host$path'), isNull);
        expect(AppRoutes.resumableLocation('//$host$path'), isNull);
      },
    );

    property<String>(
      'never resumes outside the known routes, and never throws',
      Gens.string(alphabet: 'abc/:?#%.-_ '),
      (raw) {
        final result = AppRoutes.resumableLocation(raw);

        if (result != null) {
          final uri = Uri.parse(result);
          expect(uri.hasScheme || uri.hasAuthority, isFalse);
          expect(inAppPaths, contains(uri.path));
          // Idempotent: a resumable location stays resumable.
          expect(AppRoutes.resumableLocation(result), result);
        }
      },
      runs: 500,
    );
  });

  group('tab mappings', () {
    property<int>(
      'every screen index maps to a tab whose path maps back to it',
      Gens.intIn(-20, 20),
      (index) {
        final tab = AppRoutes.homeTabForScreenIndex(index);
        final path = AppRoutes.pathForHomeTab(tab);

        expect(AppRoutes.homeTabForPath(path), tab);
        expect(AppRoutes.shellPaths, contains(path));
        if (index >= 0 && index < HomeTab.values.length) {
          expect(tab.index, index);
        }
      },
    );

    property<String>(
      'unknown paths fall back to the dashboard',
      Gens.string(),
      (path) {
        final tab = AppRoutes.homeTabForPath(path);

        if (!AppRoutes.shellPaths.contains(path)) {
          expect(tab, HomeTab.dashboard);
        }
      },
    );

    property<int>(
      'workspace tab indexes round-trip through their paths',
      Gens.intIn(-5, 8),
      (index) {
        final path = AppRoutes.pathForWorkspaceTabIndex(index);
        final back = AppRoutes.workspaceTabIndexForPath(path);

        if (index >= 0 && index <= 2) {
          expect(back, index);
          expect(AppRoutes.homeTabForPath(path), HomeTab.workspace);
        } else {
          expect(path, AppRoutes.workspace);
          expect(back, isNull);
        }
      },
    );
  });
}
