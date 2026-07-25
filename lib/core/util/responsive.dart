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

  // -- Breakpoint tokens ------------------------------------------------

  static const double _breakpointCompact = 600;
  static const double _breakpointMedium = 1240;
  static const double _legacyWideThreshold = 900;
  static const double _sideBySidePhoneLandscapeWidth = 700;
  static const double _shortViewportThreshold = 480;
  static const double _tabletShortEdgeThreshold = 768;
  static const double _desktopLongEdgeThreshold = 1240;
  static const double _gridColumnsExpanded = 1400;
  static const double _gridColumnsMedium = 900;
  static const double _gridColumnsCompact = 600;
  static const double _navRailCollapsedWidth = 72;
  static const double _navRailExpandedWidth = 200;
  static const double _sidePanelMin = 280;
  static const double _sidePanelMax = 400;

  // -- Width breakpoints ------------------------------------------------

  static Breakpoint breakpointOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= _breakpointMedium) return Breakpoint.expanded;
    if (width >= _breakpointCompact) return Breakpoint.medium;
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
      MediaQuery.sizeOf(context).width < _breakpointCompact;

  /// Tablet or desktop — anything wide enough to consider side-by-side.
  /// Note: this is the *legacy* 900dp threshold used by chat_screen. For
  /// finer control prefer [formFactorOf] / [shouldUseSideBySide].
  @Deprecated('Use shouldUseSideBySide or breakpointOf instead')
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _legacyWideThreshold;

  // -- Form factor ------------------------------------------------------

  /// Coarse device class. iPad (any orientation) → tablet; phone (any
  /// orientation) → phone; wide browser/desktop → desktop.
  ///
  /// Uses [shortestSide] instead of longestSide so large phones
  /// (e.g. iPhone 14 Pro Max 430×932) are not misclassified as tablets.
  static FormFactor formFactorOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortEdge = size.shortestSide;
    final longEdge = size.longestSide;
    if (longEdge >= _desktopLongEdgeThreshold && shortEdge >= _breakpointCompact) {
      return FormFactor.desktop;
    }
    if (shortEdge >= _tabletShortEdgeThreshold) return FormFactor.tablet;
    return FormFactor.phone;
  }

  static bool isPhone(BuildContext context) =>
      formFactorOf(context) == FormFactor.phone;

  static bool isTablet(BuildContext context) =>
      formFactorOf(context) == FormFactor.tablet;

  static bool isDesktop(BuildContext context) =>
      formFactorOf(context) == FormFactor.desktop;

  // -- Orientation ------------------------------------------------------

  static bool isPortrait(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.height > size.width;
  }

  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  static bool isSquare(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width == size.height;
  }

  /// True when the available content height is too short to show a stacked
  /// character panel above the chat — e.g. iPhone landscape (~390pt tall) or
  /// iPad Split View sliver. Callers should hide/shrink the panel.
  static bool isShortViewport(BuildContext context) {
    final mq = MediaQuery.of(context);
    final availableHeight = mq.size.height - mq.viewInsets.bottom - mq.padding.bottom;
    return availableHeight < _shortViewportThreshold;
  }

  // -- Layout regime decisions -----------------------------------------

  /// Whether the chat screen (and similar two-pane layouts) should put
  /// the character panel beside the chat instead of stacked on top.
  ///
  /// Returns true when:
  ///   - The form factor is tablet/desktop (≥768 short edge), OR
  ///   - The width is ≥900 (legacy wide-browser threshold), OR
  ///   - We're on a phone in landscape with ≥700pt width AND a
  ///     not-short viewport (so the panel doesn't dominate).
  ///
  /// Otherwise (phone portrait, or short landscape phone) we stack and
  /// let [shouldHideStackedCharacterPanel] decide whether the panel is
  /// shown at all.
  static bool shouldUseSideBySide(BuildContext context) {
    final ff = formFactorOf(context);
    final w = MediaQuery.sizeOf(context).width;

    final isDesktopLayout = ff == FormFactor.desktop;
    final isWideTabletLandscape = ff == FormFactor.tablet && !isPortrait(context);
    final isLargePortraitTablet = ff == FormFactor.tablet &&
        isPortrait(context) &&
        w >= _legacyWideThreshold;
    final isLegacyWide = w >= _legacyWideThreshold;
    final isPhoneLandscapeSideBySide = isLandscape(context) &&
        ff == FormFactor.phone &&
        w >= _sideBySidePhoneLandscapeWidth &&
        !isShortViewport(context);

    return isDesktopLayout ||
        isWideTabletLandscape ||
        isLargePortraitTablet ||
        isLegacyWide ||
        isPhoneLandscapeSideBySide;
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
  /// These are *upper bounds*; callers should clamp with the actual
  /// available width using `min(availableWidth, contentMaxWidth(...))`.
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

  /// Width of the navigation rail in the current breakpoint.
  static double navRailWidth(BuildContext context) {
    return isExpanded(context) ? _navRailExpandedWidth : _navRailCollapsedWidth;
  }

  /// Side-panel width (character / sidebar) on wide layouts.
  /// [bodyWidth] is the available width after the nav rail has been
  /// subtracted. If omitted the full screen width is used.
  static double sidePanelWidth(BuildContext context, {double? bodyWidth}) {
    final w = bodyWidth ?? MediaQuery.sizeOf(context).width;
    // Keep the chat column ~60% of the available body width, panel takes
    // the rest but is clamped so it never gets cramped or absurdly wide.
    return (w * 0.36).clamp(_sidePanelMin, _sidePanelMax);
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
        return 132;
      case Breakpoint.medium:
        return 160;
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
  /// and should use its intrinsic height — callers must provide a bounded
  /// parent. Returns 0 when the panel should be hidden (short landscape
  /// phone).
  static double? characterPanelHeight(BuildContext context) {
    if (shouldHideStackedCharacterPanel(context)) return 0;
    if (shouldUseSideBySide(context)) return null;
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 184;
      case Breakpoint.medium:
        return 208;
      case Breakpoint.expanded:
        return null;
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
  /// [bodyWidth] lets callers subtract the nav rail width so column counts
  /// are accurate on desktop layouts.
  static int gridColumnCount(BuildContext context, {double? bodyWidth}) {
    final w = bodyWidth ?? MediaQuery.sizeOf(context).width;
    // Grid density is determined by usable *width*. A 390×844 phone has a
    // tablet-sized long edge, but still only has room for one readable card.
    if (w >= _gridColumnsExpanded) return 4;
    if (w >= _gridColumnsMedium) return 3;
    if (w >= _gridColumnsCompact) return 2;
    return 1;
  }

  /// Number of columns for stat-card grids (smaller cards, can pack
  /// tighter than quick-action cards).
  static int statCardColumnCount(BuildContext context, {double? bodyWidth}) {
    final ff = formFactorOf(context);
    final w = bodyWidth ?? MediaQuery.sizeOf(context).width;
    if (ff == FormFactor.desktop || w >= _gridColumnsExpanded) return 4;
    if (ff == FormFactor.tablet || w >= _gridColumnsMedium) return 3;
    if (w >= _gridColumnsCompact) return 2;
    // Very narrow phones (e.g. iPhone SE) fall back to 1 column.
    if (w < 360) return 1;
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

  /// Whether the bottom navigation bar should be shown.
  ///
  /// Uses width as the primary signal, but desktop-class windows that
  /// happen to be narrow (e.g. split-screen) keep the rail so the content
  /// area isn't crushed by a phone-style bottom bar.
  static bool useBottomNav(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final ff = formFactorOf(context);
    if (ff == FormFactor.desktop) return false;
    // Wide phone landscape / foldable expanded keeps the rail so the
    // content area isn't crushed by a phone-style bottom bar (UX-033, UX-050).
    if (ff == FormFactor.phone && w >= _breakpointCompact) return false;
    return w < _breakpointCompact;
  }

  /// Whether to render the side navigation rail.
  static bool useNavRail(BuildContext context) => !useBottomNav(context);

  /// Minimum tap-target size (iOS HIG: 44pt). Used by buttons that
  /// would otherwise shrink below the threshold.
  static const double minTapTarget = 44;
}
