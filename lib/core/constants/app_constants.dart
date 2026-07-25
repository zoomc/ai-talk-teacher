import 'package:flutter/animation.dart';

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Expanded 4dp/8dp grid to avoid magic numbers.
  static const double smPlus = 20;
  static const double mdPlus = 28;
  static const double lgPlus = 40;
  static const double xlPlus = 56;
  static const double huge = 64;

  // Semantic tokens for common layout needs.
  static const double screenPadding = md;
  static const double cardPadding = md;
  static const double sectionGap = lg;
  static const double buttonVertical = sm;
  static const double buttonHorizontal = lg;
}

class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Pill / stadium shape. Prefer [StadiumBorder] for true stadiums; this
  /// value is a safe large radius for rounded rectangles.
  static const double pill = 9999;

  /// Legacy alias — kept for backwards compatibility.
  static const double full = pill;
}

class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard UI transitions (buttons, fades, toggles).
  static const Duration normal = Duration(milliseconds: 250);

  /// Slightly longer transitions for layout changes / page swaps.
  static const Duration slow = Duration(milliseconds: 350);

  /// Emphasis / hero animations.
  static const Duration emphasis = Duration(milliseconds: 500);

  /// Deprecated alias for normal. Use [normal] for transitions and [slow]
  /// for layout changes.
  static const Duration medium = normal;

  // Common curves.
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;
}
