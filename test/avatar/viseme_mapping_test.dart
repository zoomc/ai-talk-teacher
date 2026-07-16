import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/avatar/domain/viseme_mapping.dart';
import 'package:speakflow/shared/widgets/virtual_character.dart' show Viseme;

void main() {
  group('RhubarbViseme.fromCode', () {
    test('parses every canonical code', () {
      final cases = {
        'A': RhubarbViseme.a,
        'B': RhubarbViseme.b,
        'C': RhubarbViseme.c,
        'D': RhubarbViseme.d,
        'E': RhubarbViseme.e,
        'F': RhubarbViseme.f,
        'G': RhubarbViseme.g,
        'H': RhubarbViseme.h,
        'X': RhubarbViseme.x,
      };
      cases.forEach((code, expected) {
        expect(RhubarbViseme.fromCode(code), expected,
            reason: 'code "$code" should map to $expected');
      });
    });

    test('parses lowercase codes', () {
      expect(RhubarbViseme.fromCode('a'), RhubarbViseme.a);
      expect(RhubarbViseme.fromCode('x'), RhubarbViseme.x);
    });

    test('falls back to silence for unknown codes', () {
      expect(RhubarbViseme.fromCode(''), RhubarbViseme.x);
      expect(RhubarbViseme.fromCode('Z'), RhubarbViseme.x);
      expect(RhubarbViseme.fromCode('?'), RhubarbViseme.x);
    });
  });

  group('kRhubarbToLive2DMap', () {
    test('covers every Rhubarb viseme', () {
      for (final v in RhubarbViseme.values) {
        expect(kRhubarbToLive2DMap.containsKey(v), isTrue,
            reason: 'viseme $v missing from map');
      }
    });

    test('silence viseme has fully closed mouth', () {
      final shape = kRhubarbToLive2DMap[RhubarbViseme.x]!;
      expect(shape.mouthOpenY, lessThan(0.01));
    });

    test('open-vowel viseme G has the widest opening', () {
      final g = kRhubarbToLive2DMap[RhubarbViseme.g]!.mouthOpenY;
      for (final v in RhubarbViseme.values) {
        if (v == RhubarbViseme.g) continue;
        expect(kRhubarbToLive2DMap[v]!.mouthOpenY, lessThanOrEqualTo(g),
            reason: 'viseme $v should not open wider than G');
      }
    });

    test('smile viseme F has the most positive mouthForm', () {
      final f = kRhubarbToLive2DMap[RhubarbViseme.f]!.mouthForm;
      for (final v in RhubarbViseme.values) {
        if (v == RhubarbViseme.f) continue;
        expect(kRhubarbToLive2DMap[v]!.mouthForm, lessThanOrEqualTo(f),
            reason: 'viseme $v should not smile more than F');
      }
    });

    test('mouthOpenY is in the canonical 0..1 range', () {
      for (final v in RhubarbViseme.values) {
        final o = kRhubarbToLive2DMap[v]!.mouthOpenY;
        expect(o, greaterThanOrEqualTo(0.0));
        expect(o, lessThanOrEqualTo(1.0));
      }
    });

    test('mouthForm is in the canonical -1..1 range', () {
      for (final v in RhubarbViseme.values) {
        final m = kRhubarbToLive2DMap[v]!.mouthForm;
        expect(m, greaterThanOrEqualTo(-1.0));
        expect(m, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('shapeForViseme', () {
    test('returns the map entry when present', () {
      expect(shapeForViseme(RhubarbViseme.a),
          equals(kRhubarbToLive2DMap[RhubarbViseme.a]));
      expect(shapeForViseme(RhubarbViseme.g),
          equals(kRhubarbToLive2DMap[RhubarbViseme.g]));
    });
  });

  group('Live2DMouthShape.lerp', () {
    test('linearly interpolates both axes', () {
      const a = Live2DMouthShape(mouthOpenY: 0.0, mouthForm: -1.0);
      const b = Live2DMouthShape(mouthOpenY: 1.0, mouthForm: 1.0);
      final mid = a.lerp(b, 0.5);
      expect(mid.mouthOpenY, closeTo(0.5, 1e-9));
      expect(mid.mouthForm, closeTo(0.0, 1e-9));
    });

    test('clamps t to 0..1', () {
      const a = Live2DMouthShape(mouthOpenY: 0.2, mouthForm: 0.0);
      const b = Live2DMouthShape(mouthOpenY: 0.8, mouthForm: 0.5);
      expect(a.lerp(b, -1).mouthOpenY, closeTo(0.2, 1e-9));
      expect(a.lerp(b, 2).mouthOpenY, closeTo(0.8, 1e-9));
    });

    test('asymmetric mouthFormL/R stays null when one side is null', () {
      const a = Live2DMouthShape(mouthOpenY: 0.0, mouthForm: 0.0);
      const b = Live2DMouthShape(
          mouthOpenY: 1.0, mouthForm: 0.0, mouthFormL: 0.5, mouthFormR: 0.5);
      final mid = a.lerp(b, 0.5);
      expect(mid.mouthFormL, isNull);
      expect(mid.mouthFormR, isNull);
    });

    test('asymmetric mouthFormL/R blends when both sides have values', () {
      const a = Live2DMouthShape(
          mouthOpenY: 0.0, mouthForm: 0.0, mouthFormL: 0.0, mouthFormR: 0.0);
      const b = Live2DMouthShape(
          mouthOpenY: 1.0, mouthForm: 0.0, mouthFormL: 1.0, mouthFormR: -1.0);
      final mid = a.lerp(b, 0.5);
      expect(mid.mouthFormL, closeTo(0.5, 1e-9));
      expect(mid.mouthFormR, closeTo(-0.5, 1e-9));
    });
  });

  group('visemeToPainter', () {
    test('maps every viseme to a non-null painter Viseme', () {
      for (final v in RhubarbViseme.values) {
        expect(visemeToPainter(v), isA<Viseme>());
      }
    });

    test('silence + lip-closed visemes both map to Viseme.closed', () {
      expect(visemeToPainter(RhubarbViseme.x), Viseme.closed);
      expect(visemeToPainter(RhubarbViseme.a), Viseme.closed);
    });

    test('wide-open vowel viseme maps to Viseme.wideOpen', () {
      expect(visemeToPainter(RhubarbViseme.g), Viseme.wideOpen);
    });
  });
}
