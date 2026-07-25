import 'package:flutter/material.dart';

class AppTextStyles {
  static const String _fontFamily = 'Inter';
  // Fallback chain so a missing custom font doesn't jump to the system default.
  static const List<String> _fontFallback = [
    _fontFamily,
    'Roboto',
    'Noto Sans SC',
    'sans-serif',
  ];

  // --------------------------------------------------------------------------
  // Material 3 type scale (matching semantic names).
  // --------------------------------------------------------------------------
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: 1.12,
    letterSpacing: -0.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.22,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  // --------------------------------------------------------------------------
  // Legacy aliases — kept for backwards compatibility.
  // --------------------------------------------------------------------------
  static const TextStyle display = headlineLarge;
  static const TextStyle heading = headlineSmall;
  static const TextStyle title = titleLarge;
  static const TextStyle body = bodyLarge;
  static const TextStyle caption = bodyMedium;
  static const TextStyle captionMedium = labelLarge;
  static const TextStyle overline = labelMedium;
}
