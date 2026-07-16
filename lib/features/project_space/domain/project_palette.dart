import 'package:flutter/material.dart';

/// Curated palette for the new/edit project dialog's colour picker.
/// `projects.color` stores one of these hex strings (or any 6-digit hex
/// the user typed); the picker just constrains the choice to a tasteful set.
class ProjectPalette {
  static const String defaultHex = '#6C5CE7';

  /// The default `Color` — SpeakFlow's accent purple.
  static const Color defaultColor = Color(0xFF6C5CE7);

  /// 10 preset swatches spanning warm/cool/neutral hues, all bright enough
  /// to read on the dark glass surface.
  static const List<String> presetHexes = [
    '#6C5CE7', // purple (accent)
    '#00D2FF', // cyan (accent)
    '#00E676', // green
    '#FFB74D', // amber
    '#FF5252', // red
    '#42A5F5', // blue
    '#EC407A', // pink
    '#7E57C2', // deep purple
    '#26A69A', // teal
    '#78909C', // blue-grey
  ];

  /// Parses `#RRGGBB` or `RRGGBB` to a [Color]. Falls back to
  /// [defaultColor] on any malformed input so a corrupt DB row never
  /// crashes the UI.
  static Color fromHex(String? hex) {
    if (hex == null || hex.isEmpty) return defaultColor;
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length != 6) return defaultColor;
    final value = int.tryParse('FF$s', radix: 16);
    if (value == null) return defaultColor;
    return Color(value);
  }

  /// Formats a [Color] as an uppercase `#RRGGBB` string (no alpha).
  static String toHex(Color c) {
    final r = (c.r * 255).round() & 0xFF;
    final g = (c.g * 255).round() & 0xFF;
    final b = (c.b * 255).round() & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}
