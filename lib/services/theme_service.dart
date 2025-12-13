import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _prefKey = 'theme_mode';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_prefKey);
    if (saved != null) {
      switch (saved) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
      }
    } else {
      // default to dark to match current design until user changes it
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs?.setString(_prefKey, mode.name);
    notifyListeners();
  }

  void toggleThemeMode() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
