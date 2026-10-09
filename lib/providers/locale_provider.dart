import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../l10n/app_localizations.dart';
import 'shared_preferences_provider.dart';

part 'locale_provider.g.dart';

const String _localeStorageKey = 'app_locale';
const Locale _defaultLocale = Locale('en');

/// Manages the active app [Locale] with SharedPreferences persistence.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final code = prefs.getString(_localeStorageKey);
    if (code != null && code.isNotEmpty) {
      for (final locale in AppLocalizations.supportedLocales) {
        if (locale.languageCode == code) {
          return locale;
        }
      }
    }
    return _defaultLocale;
  }

  /// Updates locale and persists the language code.
  Future<void> setLocale(Locale locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_localeStorageKey, locale.languageCode);
    state = locale;
  }
}
