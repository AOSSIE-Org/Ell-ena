import 'package:flutter/material.dart';

/// Supported app theme modes.
enum AppThemeMode {
  light,
  dark,
  system,
}

extension AppThemeModeX on AppThemeMode {
  ThemeMode get flutterThemeMode {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
