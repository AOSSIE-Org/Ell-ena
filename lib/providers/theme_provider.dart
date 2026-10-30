import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../theme/app_theme_mode.dart';
import 'shared_preferences_provider.dart';

part 'theme_provider.g.dart';

const String _themeModeKey = 'app_theme_mode';

/// App theme mode, persisted via SharedPreferences.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  AppThemeMode build() {
    final stored =
        ref.watch(sharedPreferencesProvider).getString(_themeModeKey);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_themeModeKey, mode.name);
  }
}
