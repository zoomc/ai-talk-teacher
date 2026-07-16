import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/project_space/domain/project_palette.dart';

void main() {
  test('fromHex parses a 6-digit hex string with leading #', () {
    expect(ProjectPalette.fromHex('#6C5CE7'), const Color(0xFF6C5CE7));
  });

  test('fromHex parses a 6-digit hex string without leading #', () {
    expect(ProjectPalette.fromHex('00D2FF'), const Color(0xFF00D2FF));
  });

  test('fromHex falls back to the default colour on malformed input', () {
    expect(ProjectPalette.fromHex('not-a-hex'), ProjectPalette.defaultColor);
    expect(ProjectPalette.fromHex(''), ProjectPalette.defaultColor);
  });

  test('toHex emits an uppercase #RRGGBB string', () {
    expect(ProjectPalette.toHex(const Color(0xFF6C5CE7)), '#6C5CE7');
    expect(ProjectPalette.toHex(const Color(0xFF00D2FF)), '#00D2FF');
  });

  test('presetHexes is non-empty and every entry parses', () {
    expect(ProjectPalette.presetHexes, isNotEmpty);
    for (final hex in ProjectPalette.presetHexes) {
      expect(() => ProjectPalette.fromHex(hex), returnsNormally);
    }
  });

  test('defaultHex matches defaultColor', () {
    expect(ProjectPalette.fromHex(ProjectPalette.defaultHex),
        ProjectPalette.defaultColor);
  });
}
