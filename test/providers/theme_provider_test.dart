import 'package:ell_ena/providers/shared_preferences_provider.dart';
import 'package:ell_ena/providers/theme_provider.dart';
import 'package:ell_ena/theme/app_theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('throws when shared preferences are not overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(themeControllerProvider), throwsA(anything));
  });

  test('defaults to system when nothing is stored', () async {
    final container = await _container({});

    expect(container.read(themeControllerProvider), AppThemeMode.system);
  });

  test('loads the stored mode', () async {
    final container = await _container({'app_theme_mode': 'dark'});

    expect(container.read(themeControllerProvider), AppThemeMode.dark);
  });

  test('falls back to system for an unknown stored value', () async {
    final container = await _container({'app_theme_mode': 'sepia'});

    expect(container.read(themeControllerProvider), AppThemeMode.system);
  });

  test('setThemeMode updates state and persists it', () async {
    final container = await _container({});

    await container
        .read(themeControllerProvider.notifier)
        .setThemeMode(AppThemeMode.light);

    expect(container.read(themeControllerProvider), AppThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode'), 'light');
  });

  test('flutterThemeMode maps every mode', () {
    expect(AppThemeMode.light.flutterThemeMode, ThemeMode.light);
    expect(AppThemeMode.dark.flutterThemeMode, ThemeMode.dark);
    expect(AppThemeMode.system.flutterThemeMode, ThemeMode.system);
  });

  testWidgets('Consumer rebuilds when theme mode changes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Text(ref.watch(themeControllerProvider).name);
            },
          ),
        ),
      ),
    );

    expect(find.text('system'), findsOneWidget);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(Consumer)));
    await container
        .read(themeControllerProvider.notifier)
        .setThemeMode(AppThemeMode.dark);
    await tester.pump();

    expect(find.text('dark'), findsOneWidget);
  });
}
