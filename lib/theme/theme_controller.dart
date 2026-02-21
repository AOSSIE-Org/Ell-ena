import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_mode.dart';

const String _themeModeKey = 'app_theme_mode';

/// Manages app theme state with persistence via SharedPreferences.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    _themeMode = _loadThemeMode();
  }

  final SharedPreferences _prefs;
  late AppThemeMode _themeMode;

  AppThemeMode get themeMode => _themeMode;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool get isDarkMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  AppThemeMode _loadThemeMode() {
    final stored = _prefs.getString(_themeModeKey);
    if (stored == null) return AppThemeMode.system;
    return AppThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setString(_themeModeKey, mode.name);
    notifyListeners();
  }

  /// Static factory to create and initialize the controller.
  static Future<ThemeController> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeController(prefs);
  }
}
