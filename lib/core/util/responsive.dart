import 'package:flutter/material.dart';

/// Screen-size breakpoints for adaptive layouts.
///
/// Follows Material 3 window-size classes:
///   compact  < 600 dp   (phone portrait)
///   medium   600–1239 dp (phone landscape, small tablet)
///   expanded >= 1240 dp  (desktop, large tablet landscape)
enum Breakpoint { compact, medium, expanded }

/// Centralized responsive helpers so chat / home / settings screens can
/// adapt to browsers, mobile, and desktop apps with one source of truth.
class Responsive {
  Responsive._();

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
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  /// Max width to constrain full-bleed content on large screens so
  /// text lines stay readable on desktop browsers.
  static double contentMaxWidth(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return double.infinity;
      case Breakpoint.medium:
        return 640;
      case Breakpoint.expanded:
        return 920;
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
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 96;
      case Breakpoint.medium:
        return 120;
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
  /// and uses its intrinsic height instead.
  static double characterPanelHeight(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 168;
      case Breakpoint.medium:
        return 200;
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
  static int gridColumnCount(BuildContext context) {
    switch (breakpointOf(context)) {
      case Breakpoint.compact:
        return 1;
      case Breakpoint.medium:
        return 2;
      case Breakpoint.expanded:
        return 3;
    }
  }

  /// Bubble max width as a fraction of the chat column width.
  static double bubbleMaxWidthFraction(BuildContext context) {
    // Wider screens get narrower bubbles (more whitespace), mobile keeps
    // a generous bubble for readability.
    if (isCompact(context)) return 0.80;
    return 0.66;
  }

  /// Whether the bottom navigation bar should be shown (mobile only).
  /// Tablets/desktops use the navigation rail.
  static bool useBottomNav(BuildContext context) => isMobile(context);

  /// Whether to render the side navigation rail.
  static bool useNavRail(BuildContext context) => !isMobile(context);
}
