import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'shared_preferences_provider.dart';

const String _localeStorageKey = 'app_locale';

/// Supported app locales. Add new entries when ARB files are added.
const List<Locale> supportedAppLocales = [
  Locale('en'),
  Locale('es'),
];

/// Manages the active app [Locale] with SharedPreferences persistence.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final code = prefs.getString(_localeStorageKey);
    if (code == null || code.isEmpty) {
      return null;
    }
    return Locale(code);
  }

  /// Updates locale and persists the language code.
  Future<void> setLocale(Locale locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_localeStorageKey, locale.languageCode);
    state = locale;
  }

  /// Returns the effective locale, falling back to English.
  Locale effectiveLocale(BuildContext context) {
    return state ?? Localizations.localeOf(context);
  }

  /// Whether [locale] matches the persisted selection.
  bool isSelected(Locale locale) {
    final current = state;
    if (current == null) {
      return locale.languageCode == 'en';
    }
    return current.languageCode == locale.languageCode;
  }

  /// Localized display label for a supported locale.
  String labelFor(AppLocalizations l10n, Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return l10n.languageEnglish;
      case 'es':
        return l10n.languageSpanish;
      default:
        return locale.languageCode;
    }
  }

  /// Subtitle for the settings row showing the active language.
  String currentLanguageLabel(AppLocalizations l10n) {
    final code = state?.languageCode ?? 'en';
    return labelFor(l10n, Locale(code));
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
