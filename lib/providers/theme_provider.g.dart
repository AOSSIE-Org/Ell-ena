// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$themeControllerHash() => r'32400109fa9a8cbb232bb0ea630284f2a47b9ee1';

/// App theme mode, persisted via SharedPreferences.
///
/// Copied from [ThemeController].
@ProviderFor(ThemeController)
final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeMode>.internal(
  ThemeController.new,
  name: r'themeControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$themeControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ThemeController = Notifier<AppThemeMode>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
