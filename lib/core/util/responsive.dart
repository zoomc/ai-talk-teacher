import 'package:flutter/material.dart';

/// Screen-size breakpoints for adaptive layouts.
///
/// Follows Material 3 window-size classes:
///   compact  < 600 dp   (phone portrait)
///   medium   600–1239 dp (phone landscape, small tablet)
///   expanded >= 1240 dp  (desktop, large tablet landscape)
enum Breakpoint { compact, medium, expanded }

/// Form factor classification used for layout regime selection.
///
/// [FormFactor.phone] covers small handsets in any orientation.
/// [FormFactor.tablet] covers iPads and other tablets (≥768dp on the
/// long edge). [FormFactor.desktop] covers wide browser windows and
/// desktop apps (≥1240dp).
enum FormFactor { phone, tablet, desktop }

/// Centralized responsive helpers so chat / home / settings screens can
/// adapt to browsers, mobile, and desktop apps with one source of truth.
///
/// The helpers cover four orthogonal axes:
///   1. Width breakpoint (compact / medium / expanded) — Material 3.
///   2. Form factor (phone / tablet / desktop) — coarse device class.
///   3. Orientation (portrait / landscape) — drives layout regime.
///   4. Specific dimension queries (height, side-panel width, etc.).
///
/// Combined with [OrientationBuilder] at the call site, these let each
/// screen pick a layout that fits the actual device instead of hard-
/// stretching a single column across an iPad.
class Responsive {
  Responsive._();

  // -- Width breakpoints ------------------------------------------------

  static Breakpoint breakpointOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1240) return Breakpoint.expanded;
    if (width >= 600) return Breakpoint.medium;
    return Breakpoint.compact;
  }

  static bool isCompact(BuildContext context) =>
      breakpointOf(context) == Breakpoint.compact;

  static bool isMedium(BuildContext context) =>
      breakpointOf(context) == Breakpoint.medium;

  static bool isExpanded(BuildContext context) =>
      breakpointOf(context) == Breakpoint.expanded;

  /// True for phone-class widths.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  /// Tablet or desktop — anything wide enough to consider side-by-side.
  /// Note: this is the *legacy* 900dp threshold used by chat_screen. For
  /// finer control prefer [formFactorOf] / [shouldUseSideBySide].
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  // -- Form factor ------------------------------------------------------

  /// Coarse device class. iPad (any orientation) → tablet; phone (any
  /// orientation) → phone; wide browser/desktop → desktop.
  ///
  /// We classify by the *long edge* so an iPad in portrait (768×1024)
  /// and in landscape (1024×768) both report [FormFactor.tablet]. This
  /// is what lets us give every iPad a split-view chat regardless of
  /// orientation.
  static FormFactor formFactorOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final longEdge = size.longestSide;
    if (longEdge >= 1240) return FormFactor.desktop;
    if (longEdge >= 768) return FormFactor.tablet;
    return FormFactor.phone;
  }

  static bool isPhone(BuildContext context) =>
      formFactorOf(context) == FormFactor.phone;

  static bool isTablet(BuildContext context) =>
      formFactorOf(context) == FormFactor.tablet;

  static bool isDesktop(BuildContext context) =>
      formFactorOf(context) == FormFactor.desktop;

  // -- Orientation ------------------------------------------------------

  static bool isPortrait(BuildContext context) =>
      MediaQuery.sizeOf(context).height >= MediaQuery.sizeOf(context).width;

  static bool isLandscape(BuildContext context) => !isPortrait(context);

  /// True when the viewport is too short to show a stacked character
  /// panel above the chat — e.g. iPhone landscape (~390pt tall) or
  /// iPad Split View sliver. Callers should hide/shrink the panel.
  static bool isShortViewport(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 480;

  // -- Layout regime decisions -----------------------------------------

  /// Whether the chat screen (and similar two-pane layouts) should put
  /// the character panel beside the chat instead of stacked on top.
  ///
  /// Returns true when:
  ///   - The form factor is tablet/desktop (≥768 long edge), OR
  ///   - The width is ≥900 (legacy wide-browser threshold), OR
  ///   - We're on a phone in landscape with ≥700pt width AND a
  ///     not-short viewport (so the panel doesn't dominate).
  ///
  /// Otherwise (phone portrait, or short landscape phone) we stack and
  /// let [shouldHideStackedCharacterPanel] decide whether the panel is
  /// shown at all.
  static bool shouldUseSideBySide(BuildContext context) {
    final ff = formFactorOf(context);
    if (ff == FormFactor.desktop) return true;
    final w = MediaQuery.sizeOf(context).width;
    if (ff == FormFactor.tablet) {
      // On a portrait tablet under 900pt (e.g. iPad mini portrait 768pt),
      // stacking gives the chat column the full width — the side-by-side
      // 280pt panel + 488pt chat feels cramped on a 768pt device.
      // Landscape tablets (≥1024pt) and portrait tablets ≥900pt get
      // side-by-side.
      if (isPortrait(context) && w < 900) return false;
      return true;
    }
    if (w >= 900) return true;
    if (isLandscape(context) && w >= 700 && !isShortViewport(context)) {
      return true;
    }
    return false;
  }

  /// On a short phone-landscape viewport (~390pt tall) the stacked
  /// character panel (~168pt) eats half the screen. Hide it entirely
  /// and let the chat breathe; the AppBar already identifies the tutor.
  static bool shouldHideStackedCharacterPanel(BuildContext context) {
    if (shouldUseSideBySide(context)) return false;
    return isShortViewport(context);
  }

  // -- Sizing tokens ----------------------------------------------------

  /// Max width to constrain full-bleed content on large screens so
  /// text lines stay readable on desktop browsers.
  ///
  /// Tablet-tier (medium) is bumped from 640 → 880 so iPads actually
  /// use their width instead of leaving ~300pt of dead centered space.
  static double contentMaxWidth(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return double.infinity;
      case Breakpoint.medium:
        return 880;
      case Breakpoint.expanded:
        return 1040;
    }
  }

  /// Side-panel width (character / sidebar) on wide layouts.
  static double sidePanelWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Keep the chat column ~60% of the screen, panel takes the rest
    // but is clamped so it never gets cramped or absurdly wide.
    return (w * 0.36).clamp(280.0, 400.0);
  }

  /// Suggested diameter (px) of the virtual character circle.
  static double characterSize(BuildContext context) {
    if (shouldHideStackedCharacterPanel(context)) return 0;
    if (shouldUseSideBySide(context)) {
      // Side panel is wider — scale the character up.
      switch (breakpointOf(context)) {
        case Breakpoint.compact:
          return 120; // phone landscape side-by-side (rare)
        case Breakpoint.medium:
          return 168;
        case Breakpoint.expanded:
          return 200;
      }
    }
    // Phone practice is a character-led stage, not a small utility strip.
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 230;
      case Breakpoint.medium:
        return 270;
      case Breakpoint.expanded:
        return 168;
    }
  }

  /// Avatar emoji font-size scaled to [characterSize].
  static double characterAvatarFontSize(BuildContext context) {
    return characterSize(context) * 0.42;
  }

  /// Vertical height of the character panel when stacked on top of chat
  /// (compact/medium). On expanded layouts the panel sits beside the chat
  /// and uses its intrinsic height instead. Returns 0 when the panel
  /// should be hidden (short landscape phone).
  static double characterPanelHeight(BuildContext context) {
    if (shouldHideStackedCharacterPanel(context)) return 0;
    if (shouldUseSideBySide(context)) return double.infinity;
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 292;
      case Breakpoint.medium:
        return 340;
      case Breakpoint.expanded:
        return double.infinity;
    }
  }

  /// Horizontal padding for screen-level content.
  static double screenHorizontalPadding(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 16;
      case Breakpoint.medium:
        return 24;
      case Breakpoint.expanded:
        return 32;
    }
  }

  /// Number of columns for grid-style content (Quick Start cards, etc.).
  /// Adds an expanded-tablet tier so iPads in landscape get 3 columns
  /// and iPad Pro / desktop gets 4.
  static int gridColumnCount(BuildContext context) {
    final ff = formFactorOf(context);
    final w = MediaQuery.sizeOf(context).width;
    if (ff == FormFactor.desktop || w >= 1400) return 4;
    if (ff == FormFactor.tablet || w >= 900) return 3;
    if (w >= 600) return 2;
    return 1;
  }

  /// Number of columns for stat-card grids (smaller cards, can pack
  /// tighter than quick-action cards).
  static int statCardColumnCount(BuildContext context) {
    final ff = formFactorOf(context);
    final w = MediaQuery.sizeOf(context).width;
    if (ff == FormFactor.desktop || w >= 1400) return 4;
    if (ff == FormFactor.tablet || w >= 900) return 3;
    if (w >= 600) return 2;
    // Phone: 2 columns fits even on SE, 1 is too sparse for stats.
    return 2;
  }

  /// Bubble max width as a fraction of the chat column width.
  static double bubbleMaxWidthFraction(BuildContext context) {
    // Wider screens get narrower bubbles (more whitespace), mobile keeps
    // a generous bubble for readability.
    if (isCompact(context)) return 0.80;
    return 0.66;
  }

  /// Whether the bottom navigation bar should be shown (phone only).
  /// Tablets/desktops use the navigation rail.
  static bool useBottomNav(BuildContext context) =>
      formFactorOf(context) == FormFactor.phone;

  /// Whether to render the side navigation rail.
  static bool useNavRail(BuildContext context) => !useBottomNav(context);

  /// Minimum tap-target size (iOS HIG: 44pt). Used by buttons that
  /// would otherwise shrink below the threshold.
  static const double minTapTarget = 44;
}
