import 'package:flutter/material.dart';

// Light theme: strong contrast, white surface, dark text, visible cards & inputs.
ThemeData get lightTheme {
  const surface = Color(0xFFFFFFFF);
  const onSurface = Color(0xFF1C1C1C);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: Colors.green.shade400,
    scaffoldBackgroundColor: const Color(0xFFF0F0F0),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      iconTheme: IconThemeData(color: onSurface),
      titleTextStyle: TextStyle(
          color: onSurface, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    iconTheme: const IconThemeData(color: onSurface),
    colorScheme: ColorScheme.light(
      primary: Colors.green.shade400,
      secondary: Colors.green.shade700,
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1C1C1C),
      onSurfaceVariant: const Color(0xFF5C5C5C),
      outline: const Color(0xFFE0E0E0),
      outlineVariant: const Color(0xFFEEEEEE),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF8F8F8),
      surfaceContainer: const Color(0xFFF2F2F2),
      surfaceContainerHigh: const Color(0xFFECECEC),
      surfaceContainerHighest: const Color(0xFFE6E6E6),
      onInverseSurface: const Color(0xFFF0F0F0),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: const Color(0xFF303030),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    dividerColor: const Color(0xFFBDBDBD),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFBDBDBD),
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: const Color(0xFF000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade400, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB00020)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      labelStyle: const TextStyle(color: Color(0xFF5C5C5C)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Color(0xFF1C1C1C),
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1C1C1C),
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1C1C1C),
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1C1C),
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1C1C),
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1C1C),
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1C1C),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1C1C1C),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1C1C1C),
      ),
      bodyLarge:
          TextStyle(fontSize: 16, letterSpacing: 0.5, color: Color(0xFF1C1C1C)),
      bodyMedium: TextStyle(
          fontSize: 14, letterSpacing: 0.25, color: Color(0xFF1C1C1C)),
      bodySmall:
          TextStyle(fontSize: 12, letterSpacing: 0.4, color: Color(0xFF5C5C5C)),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1C)),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF5C5C5C)),
      labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: Color(0xFF5C5C5C)),
    ),
  );
}

/// Dark theme: unchanged behavior, add CardTheme and InputDecorationTheme for consistency.
ThemeData get darkTheme {
  const onSurfaceDark = Color(0xFFE8E8E8);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: Colors.green.shade400,
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2A2A2A),
      foregroundColor: onSurfaceDark,
      iconTheme: IconThemeData(color: onSurfaceDark),
      titleTextStyle: TextStyle(
          color: onSurfaceDark, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    iconTheme: const IconThemeData(color: onSurfaceDark),
    colorScheme: ColorScheme.dark(
      primary: Colors.green.shade400,
      secondary: Colors.green.shade700,
      surface: const Color(0xFF2A2A2A),
      onSurface: const Color(0xFFE8E8E8),
      onSurfaceVariant: const Color(0xFFB0B0B0),
      outline: const Color(0xFF404040),
      outlineVariant: const Color(0xFF383838),
      surfaceContainerLowest: const Color(0xFF1E1E1E),
      surfaceContainerLow: const Color(0xFF242424),
      surfaceContainer: const Color(0xFF2A2A2A),
      surfaceContainerHigh: const Color(0xFF303030),
      surfaceContainerHighest: const Color(0xFF363636),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    dividerColor: const Color(0xFF404040),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF404040),
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: const Color(0xFF000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF2A2A2A),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF242424),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF404040)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade400, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCF6679)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Color(0xFFE8E8E8),
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE8E8E8),
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE8E8E8),
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE8E8E8),
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE8E8E8),
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE8E8E8),
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE8E8E8),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFFE8E8E8),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFFE8E8E8),
      ),
      bodyLarge:
          TextStyle(fontSize: 16, letterSpacing: 0.5, color: Color(0xFFE8E8E8)),
      bodyMedium: TextStyle(
          fontSize: 14, letterSpacing: 0.25, color: Color(0xFFE8E8E8)),
      bodySmall:
          TextStyle(fontSize: 12, letterSpacing: 0.4, color: Color(0xFFB0B0B0)),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE8E8E8)),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFB0B0B0)),
      labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: Color(0xFFB0B0B0)),
    ),
  );
}
