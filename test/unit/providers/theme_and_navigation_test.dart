import 'package:ell_ena/providers/navigation_provider.dart';
import 'package:ell_ena/providers/theme_provider.dart';
import 'package:ell_ena/theme/app_theme_mode.dart';
import 'package:ell_ena/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('themeControllerProvider', () {
    late ProviderContainer container;

    Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    ProviderContainer containerFor(SharedPreferences prefs) {
      return ProviderContainer(
        overrides: [
          themeControllerProvider.overrideWith(
            (ref) => ThemeController(prefs),
          ),
        ],
      );
    }

    tearDown(() {
      container.dispose();
    });

    test('defaults to system when nothing is stored', () async {
      container = containerFor(await prefsWith({}));

      final theme = container.read(themeControllerProvider);

      expect(theme.themeMode, AppThemeMode.system);
      expect(theme.flutterThemeMode, ThemeMode.system);
    });

    test('falls back to system when the stored value is unknown', () async {
      container = containerFor(await prefsWith({'app_theme_mode': 'sepia'}));

      expect(
        container.read(themeControllerProvider).themeMode,
        AppThemeMode.system,
      );
    });

    test('setThemeMode updates the provider and persists the choice', () async {
      final prefs = await prefsWith({});
      container = containerFor(prefs);

      final theme = container.read(themeControllerProvider);
      await theme.setThemeMode(AppThemeMode.dark);

      expect(
          container.read(themeControllerProvider).themeMode, AppThemeMode.dark);
      expect(theme.flutterThemeMode, ThemeMode.dark);
      expect(theme.isDarkMode, isTrue);
      expect(prefs.getString('app_theme_mode'), 'dark');

      await theme.setThemeMode(AppThemeMode.light);
      expect(theme.themeMode, AppThemeMode.light);
      expect(theme.flutterThemeMode, ThemeMode.light);
      expect(theme.isDarkMode, isFalse);

      expect(ThemeController(prefs).themeMode, AppThemeMode.light);
    });
  });

  group('homeTabIndexProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('starts on the dashboard tab', () {
      expect(container.read(homeTabIndexProvider), 0);
    });

    test('updates when the selected tab changes', () {
      container.read(homeTabIndexProvider.notifier).state = 3;
      expect(container.read(homeTabIndexProvider), 3);

      container.read(homeTabIndexProvider.notifier).state = 4;
      expect(container.read(homeTabIndexProvider), 4);
    });
  });
}
