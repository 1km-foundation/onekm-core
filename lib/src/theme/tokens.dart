import 'package:flutter/material.dart';

/// Shared design tokens: high-contrast, big targets, portrait-first.
/// One seed color per brand surface comes later; the default is a deep
/// trust green shared by all three apps for the pilot.
const kSeedColor = Color(0xFF1B7A43);

/// Minimum touch target edge (above the 48dp guideline for glove use).
const kMinTouchTarget = 52.0;

const kPaddingPage = EdgeInsets.all(16);
const kPaddingCard = EdgeInsets.all(12);
const kRadiusCard = BorderRadius.all(Radius.circular(12));

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kSeedColor);
  return _base(scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: Brightness.dark,
  );
  return _base(scheme);
}

ThemeData _base(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: const TextTheme(
      // Readable at arm's length, on cheap screens, in sunlight.
      bodyLarge: TextStyle(fontSize: 17, height: 1.4),
      bodyMedium: TextStyle(fontSize: 15, height: 1.4),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, kMinTouchTarget),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, kMinTouchTarget),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
