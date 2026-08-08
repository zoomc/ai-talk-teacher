import 'package:flutter/material.dart';

/// SpeakFlow color palette — Premium UI Design System v2
///
/// Inspired by international top-tier apps (Linear, Arc, Spotify, Duolingo):
/// - Deeper, richer dark backgrounds with subtle warmth
/// - More sophisticated accent gradients (purple → cyan → pink)
/// - Enhanced glass morphism with multi-layer depth
/// - Better contrast ratios for accessibility (WCAG AA+)
class AppColors {
  // ── Backgrounds (Dark) ──────────────────────────────────────────────
  // Deeper, warmer dark tones — less "flat black", more "deep space"
  static const Color bgPrimary = Color(0xFF06080F);
  static const Color bgSecondary = Color(0xFF0C1019);
  static const Color bgTertiary = Color(0xFF141926);
  static const Color bgElevated = Color(0xFF1A2034);

  // ── Surface / Glass — Premium multi-layer depth ─────────────────────
  static const Color bgSurface = Color(0x0DFFFFFF); // white 5% base
  static const Color glassBg = bgSurface;
  static const Color glassBgHover = Color(0x1FFFFFFF); // white 12%
  static const Color glassBgActive = Color(0x29FFFFFF); // white 16%
  static const Color glassBorder = Color(0x33FFFFFF); // white 20% — refined
  static const Color glassBorderHover = Color(0x4DFFFFFF); // white 30%
  static const Color glassShadow = Color(0x66000000); // black 40% depth
  static const Color glassSpecular = Color(0x4DFFFFFF); // white 30% rim
  static const double glassBlur = 24;
  static const LinearGradient glassTintGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1FFFFFFF), Color(0x05FFFFFF), Color(0x00000000)],
    stops: [0.0, 0.5, 1.0],
  );

  // ── Accent colors — Rich gradient spectrum ──────────────────────────
  static const Color accentPrimary = Color(0xFF7C6CF0); // vivid purple
  static const Color accentPrimaryLight = Color(0xFFB4A8FF);
  static const Color accentPrimaryDark = Color(0xFF5A4BD1);
  static const Color accentSecondary = Color(0xFF00E5FF); // electric cyan
  static const Color accentSecondaryLight = Color(0xFF7DF9FF);
  static const Color accentSecondaryDark = Color(0xFF0099C7);
  static const Color accentTertiary = Color(0xFFFF6B9D); // pink accent
  static const Color accentTertiaryLight = Color(0xFFFFA0C4);
  // ── Semantic colors (more vibrant) ─────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFFF9800);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color info = Color(0xFF42A5F5);
  static const Color infoDark = Color(0xFF1976D2);

  // ── Text (Dark) — Higher contrast for readability ───────────────────
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF8B9BB4);
  static const Color textMuted = Color(0xFF6B7A90);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFF4A5568);
  static const Color textPlaceholder = Color(0xFF5A6578);

  // ── Outline / shadow ────────────────────────────────────────────────
  static const Color disabled = Color(0xFF3D4654);
  static const Color outline = Color(0xFF2D3748);
  static const Color outlineVariant = Color(0xFF1E293B);
  static const Color shadow = Color(0xCC000000); // black 80%

  // ── Glow effects — More visible for premium feel ────────────────────
  static const Color glowPurple = Color(0x667C6CF0); // purple 40%
  static const Color glowCyan = Color(0x6600E5FF); // cyan 40%
  static const Color glowGreen = Color(0x4D00E676); // green 30%
  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient gradientBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgPrimary, bgSecondary, bgTertiary],
  );

  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  // Phase-1 P0 #8 — flat fallbacks used in low-bandwidth mode instead of
  // gradients, so the GPU never has to interpolate a fill each frame.
  static const Color darkFlatBg = bgPrimary;
  static const Color lightFlatBg = lightBgPrimary;

  // ── Light mode backgrounds ─────────────────────────────────────────
  static const Color lightBgPrimary = Color(0xFFF2F4F9);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightBgTertiary = Color(0xFFE8ECF4);
  static const Color lightBgElevated = Color(0xFFFFFFFF);

  // ── Light glass ────────────────────────────────────────────────────
  static const Color lightGlassBg = Color(0xD9FFFFFF); // white 85%
  static const Color lightGlassBgHover = Color(0xF0FFFFFF); // white 94%
  static const Color lightGlassBgActive = Color(0xFAFFFFFF); // white 98%
  static const Color lightGlassBorder = Color(0x1F000000); // black 12%
  static const Color lightGlassBorderHover = Color(0x33000000); // black 20%
  static const Color lightGlassShadow = Color(0x1A000000); // black 10%
  static const Color lightGlassSpecular = Color(0xF2FFFFFF); // white 95%
  static const LinearGradient lightGlassTintGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFAFFFFFF), Color(0xD9FFFFFF), Color(0xCCFFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );

  // ── Light accents ──────────────────────────────────────────────────
  static const Color lightAccentPrimary = Color(0xFF5A4BD1);
  static const Color lightAccentSecondary = Color(0xFF0099C7);
  static const Color lightAccentTertiary = Color(0xFFD81B60);

  // ── Light text ─────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightTextOnAccent = Color(0xFFFFFFFF);
  static const Color lightTextDisabled = Color(0xFF94A3B8);
  static const Color lightTextPlaceholder = Color(0xFF94A3B8);

  // ── Light outline / shadow ─────────────────────────────────────────
  static const Color lightDisabled = Color(0xFFE2E8F0);
  static const Color lightOutline = Color(0xFFCBD5E1);
  static const Color lightOutlineVariant = Color(0xFFE2E8F0);
  static const Color lightShadow = Color(0x14000000); // black 8%

  // ── Light glow ─────────────────────────────────────────────────────
  static const Color lightGlowPurple = Color(0x337C6CF0);
  static const Color lightGlowCyan = Color(0x3300E5FF);
  static const Color lightGlowGreen = Color(0x2600E676);

  // ── Light gradients ────────────────────────────────────────────────
  static const LinearGradient lightGradientBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgPrimary, Color(0xFFEEF1F6)],
  );

  static const LinearGradient lightGradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightAccentPrimary, lightAccentSecondary],
  );

  // ── Light semantic colors ──────────────────────────────────────────
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightWarning = Color(0xFFD97706);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightInfo = Color(0xFF2563EB);

  // ── Chat bubble colors ──────────────────────────────────────────────
  static const Color bubbleAi = Color(0x3D7C6CF0); // purple 24%
  static const Color bubbleUser = Color(0x3D00E5FF); // cyan 24%
  static const Color bubbleCorrection = Color(0x2600E676); // green 15%
  static const Color onBubbleAi = textPrimary;
  static const Color onBubbleUser = textPrimary;
  static const Color onBubbleCorrection = textPrimary;

  // Light mode bubbles
  static const Color lightBubbleAi = Color(0x4D7C6CF0); // purple 30%
  static const Color lightBubbleUser = Color(0x4D00E5FF); // cyan 30%
  static const Color lightBubbleCorrection = Color(0x3300E676); // green 20%
  static const Color lightOnBubbleAi = lightTextPrimary;
  static const Color lightOnBubbleUser = lightTextPrimary;
  static const Color lightOnBubbleCorrection = lightTextPrimary;
}
