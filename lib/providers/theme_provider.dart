import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

/// Riverpod exposure of [ThemeController].
/// Overridden at app startup with the instance from [ThemeController.create].
/// [ProfileScreen] still reads theme via the `provider` package until migrated.
final themeControllerProvider = ChangeNotifierProvider<ThemeController>((ref) {
  throw StateError(
    'themeControllerProvider must be overridden in ProviderScope',
  );
});
