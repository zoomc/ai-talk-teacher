import 'package:flutter/material.dart';

/// SpeakFlow color palette
/// Deep space blue gradient with purple/cyan accents
class AppColors {
  // Backgrounds
  static const Color bgPrimary = Color(0xFF0A0E1A);
  static const Color bgSecondary = Color(0xFF111827);
  static const Color bgTertiary = Color(0xFF1A2035);
  static const Color bgSurface = Color(0x0FFFFFFF); // white 6%

  // Glass — dark
  static const Color glassBg = Color(0x0FFFFFFF); // white 6%
  static const Color glassBgHover = Color(0x1AFFFFFF); // white 10%
  static const Color glassBgActive = Color(0x24FFFFFF); // white 14% (pressed)
  static const Color glassBorder = Color(0x14FFFFFF); // white 8%
  static const Color glassShadow = Color(0x4D000000); // black 30% depth
  static const Color glassSpecular = Color(0x40FFFFFF); // white 25% rim
  static const double glassBlur = 20;
  static const LinearGradient glassTintGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x14FFFFFF), Color(0x00000000)],
  );

  // Accent
  static const Color accentPrimary = Color(0xFF6C5CE7); // purple
  static const Color accentPrimaryLight = Color(0xFFA29BFE);
  static const Color accentSecondary = Color(0xFF00D2FF); // cyan
  static const Color accentSecondaryLight = Color(0xFF74E8FF);

  // Semantic
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF42A5F5);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF8892A4);
  static const Color textMuted = Color(0xFF7A8494); // improved contrast ~4.5:1
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Glow effects
  static const Color glowPurple = Color(0x4D6C5CE7); // purple 30%
  static const Color glowCyan = Color(0x4D00D2FF); // cyan 30%
  static const Color glowGreen = Color(0x4D00E676); // green 30%

  // Gradients
  static const LinearGradient gradientBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgPrimary, bgSecondary],
  );

  // Phase-1 P0 #8 — flat fallbacks used in low-bandwidth mode instead of
  // gradients, so the GPU never has to interpolate a fill each frame.
  static const Color darkFlatBg = bgPrimary;
  static const Color lightFlatBg = lightBgPrimary;

  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  // Light mode
  static const Color lightBgPrimary = Color(0xFFF5F7FB);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightBgTertiary = Color(0xFFEEF1F7); // card bg
  static const Color lightBgSurface = Color(0xFFF1F3F9); // surface overlay

  // Light glass (frosted white overlay on bright surfaces)
  static const Color lightGlassBg = Color(0xCCFFFFFF); // white 80%
  static const Color lightGlassBgHover = Color(0xE6FFFFFF); // white 90%
  static const Color lightGlassBgActive = Color(0xF2FFFFFF); // white 95%
  static const Color lightGlassBorder = Color(0x1A000000); // black 10% visible border
  static const Color lightGlassShadow = Color(0x14000000); // black 8% depth
  static const Color lightGlassSpecular = Color(0xE6FFFFFF); // white 90% rim
  static const LinearGradient lightGlassTintGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xF2FFFFFF), Color(0xCCFFFFFF)],
  );

  // Light accents (deeper than dark variants for white-bg contrast)
  static const Color lightAccentPrimary = Color(0xFF5A4BD1); // deeper purple
  static const Color lightAccentSecondary = Color(0xFF0099C7); // deeper cyan

  // Light text
  static const Color lightTextPrimary = Color(0xFF1A1A2E); // ~15.7:1 on bg
  static const Color lightTextSecondary = Color(0xFF6B7280); // ~4.5:1 on bg (AA)
  static const Color lightTextMuted = Color(0xFF9CA3AF); // weaker than secondary
  static const Color lightTextOnAccent = Color(0xFFFFFFFF);

  // Light glow (reduced opacity for bright surfaces)
  static const Color lightGlowPurple = Color(0x266C5CE7); // purple 15%
  static const Color lightGlowCyan = Color(0x2600D2FF); // cyan 15%
  static const Color lightGlowGreen = Color(0x2600E676); // green 15%

  // Light gradients
  static const LinearGradient lightGradientBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgPrimary, lightBgTertiary],
  );

  static const LinearGradient lightGradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightAccentPrimary, lightAccentSecondary],
  );

  // Light semantic colors (deeper than dark variants for white-bg AA contrast)
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightWarning = Color(0xFFD97706);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightInfo = Color(0xFF2563EB);

  // Chat bubble colors
  static const Color bubbleAi = Color(0x1A6C5CE7); // purple 10%
  static const Color bubbleUser = Color(0x1A00D2FF); // cyan 10%
  static const Color bubbleCorrection = Color(0x1A00E676); // green 10%
  static const Color lightBubbleAi = Color(0x406C5CE7); // purple 25%
  static const Color lightBubbleUser = Color(0x4000D2FF); // cyan 25%
  static const Color lightBubbleCorrection = Color(0x4000E676); // green 25%
}
