import 'package:flutter/material.dart';

/// SpeakFlow color palette
/// Deep space blue gradient with purple/cyan accents
class AppColors {
  // Backgrounds
  static const Color bgPrimary = Color(0xFF0A0E1A);
  static const Color bgSecondary = Color(0xFF111827);
  static const Color bgTertiary = Color(0xFF1A2035);
  static const Color bgSurface = Color(0x0FFFFFFF); // white 6%

  // Glass
  static const Color glassBg = Color(0x0FFFFFFF); // white 6%
  static const Color glassBgHover = Color(0x1AFFFFFF); // white 10%
  static const Color glassBorder = Color(0x14FFFFFF); // white 8%

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
  static const Color textMuted = Color(0xFF5A6478);
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

  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  // Light mode
  static const Color lightBgPrimary = Color(0xFFF5F7FB);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightGlassBg = Color(0xB3FFFFFF); // white 70%
  static const Color lightGlassBorder = Color(0xE6FFFFFF); // white 90%
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Chat bubble colors
  static const Color bubbleAi = Color(0x1A6C5CE7); // purple 10%
  static const Color bubbleUser = Color(0x1A00D2FF); // cyan 10%
  static const Color bubbleCorrection = Color(0x1A00E676); // green 10%
}
