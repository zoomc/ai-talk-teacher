/// Rhubarb Lip Sync viseme model + Live2D parameter mapping table.
///
/// Rhubarb (https://github.com/DanielSWolf/rhubarb-lip-sync) is an offline
/// CLI tool that analyses a WAV file and emits a viseme timeline (JSON).
/// Its viseme set is intentionally compact (9 visemes) so it generalises
/// across languages — see the table below. Each viseme is identified by a
/// single uppercase letter and accompanied by a start time + end time.
///
/// This file is the *single source of truth* for how those 9 Rhubarb
/// visemes map to:
///   1. Live2D Cubism parameter values ([VisemeMapping] → mouthOpenY /
///      mouthForm / mouthFormL/R) — used when a Live2D model is loaded.
///   2. The painter-fallback [Viseme] enum used by [VirtualCharacter] and
///      the existing mouth overlay — used when no Live2D model is present.
///
/// Keeping the mapping here (not inline in the rhubarb player or the
/// Live2D renderer) means the viseme set is the only thing that changes
/// if we ever swap Rhubarb for another analyser (e.g. Oculus visemes,
/// Preston Blair phoneme set).
library;

import '../../../shared/widgets/virtual_character.dart' show Viseme;

/// The 9 Rhubarb visemes. `silence` is the rest / closed-mouth viseme
/// emitted between speech and during pauses.
enum RhubarbViseme {
  /// PB — p, b, m (lips together). Mouth fully closed.
  a,
  /// TD — t, d, s, n, l, r (tongue behind teeth). Slight open, neutral form.
  b,
  /// KG — k, g, ng (back of mouth). Slight open, neutral form.
  c,
  /// CH — ch, j, sh, zh (pursed). Small opening, pursed form.
  d,
  /// FV — f, v (lower lip tucked under upper teeth). Small open, tucked form.
  e,
  /// EE — ee, ih, ey (wide smile). Wide mouth, smile form, slight open.
  f,
  /// AA — aa, ay (wide open). Maximum opening, neutral form.
  g,
  /// AW — aw, ow (rounded open). Medium open, rounded/pursed form.
  h,
  /// Silence / rest. Mouth closed, neutral form.
  x;

  /// Parse a single-character viseme code emitted by Rhubarb. Returns
  /// [RhubarbViseme.x] for unknown codes so a malformed timeline can never
  /// crash the player.
  static RhubarbViseme fromCode(String code) {
    if (code.isEmpty) return RhubarbViseme.x;
    final c = code[0].toLowerCase();
    switch (c) {
      case 'a':
        return RhubarbViseme.a;
      case 'b':
        return RhubarbViseme.b;
      case 'c':
        return RhubarbViseme.c;
      case 'd':
        return RhubarbViseme.d;
      case 'e':
        return RhubarbViseme.e;
      case 'f':
        return RhubarbViseme.f;
      case 'g':
        return RhubarbViseme.g;
      case 'h':
        return RhubarbViseme.h;
      default:
        return RhubarbViseme.x;
    }
  }
}

/// A single Live2D mouth-shape target. All values are in the canonical
/// Cubism parameter ranges:
///   - `mouthOpenY`: 0 (closed) .. 1 (fully open)
///   - `mouthForm`: -1 (frown) .. 0 (neutral) .. 1 (smile)
///   - `mouthFormL` / `mouthFormR`: optional asymmetric mouth-corner lift;
///     leave null when the model has no such parameter.
class Live2DMouthShape {
  final double mouthOpenY;
  final double mouthForm;
  final double? mouthFormL;
  final double? mouthFormR;

  const Live2DMouthShape({
    required this.mouthOpenY,
    required this.mouthForm,
    this.mouthFormL,
    this.mouthFormR,
  });

  /// Linearly interpolate two mouth shapes — used by the viseme player to
  /// ease between consecutive visemes (no hard cuts). Cubism SDK also blends
  /// additively, but pre-blending here keeps the fallback painter in sync.
  Live2DMouthShape lerp(Live2DMouthShape other, double t) {
    return Live2DMouthShape(
      mouthOpenY: _lerpDouble(mouthOpenY, other.mouthOpenY, t),
      mouthForm: _lerpDouble(mouthForm, other.mouthForm, t),
      mouthFormL: (mouthFormL != null && other.mouthFormL != null)
          ? _lerpDouble(mouthFormL!, other.mouthFormL!, t)
          : null,
      mouthFormR: (mouthFormR != null && other.mouthFormR != null)
          ? _lerpDouble(mouthFormR!, other.mouthFormR!, t)
          : null,
    );
  }

  static double _lerpDouble(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);
}

/// The canonical Rhubarb viseme → Live2D parameter table.
///
/// Tuned against the Live2D sample models' default mouth parameter ranges
/// (0..1 open, -1..1 form) and the Rhubarb viseme documentation. The shape
/// values were chosen so a sustained "AAAAAAAA" (viseme G) reads as
/// full-open, while "MMMMMM" (viseme A) reads as fully closed.
const Map<RhubarbViseme, Live2DMouthShape> kRhubarbToLive2DMap = {
  // PB — p/b/m: lips together, fully closed.
  RhubarbViseme.a: Live2DMouthShape(mouthOpenY: 0.05, mouthForm: 0.0),
  // TD — t/d/s/n/l/r: tongue behind upper teeth, slight open, neutral form.
  RhubarbViseme.b: Live2DMouthShape(mouthOpenY: 0.30, mouthForm: 0.05),
  // KG — k/g/ng: back of mouth open, slight open, slight frown.
  RhubarbViseme.c: Live2DMouthShape(mouthOpenY: 0.40, mouthForm: -0.10),
  // CH — ch/j/sh/zh: pursed, small opening.
  RhubarbViseme.d: Live2DMouthShape(mouthOpenY: 0.35, mouthForm: -0.30),
  // FV — f/v: lower lip tucked under upper teeth, small open, tucked form.
  RhubarbViseme.e: Live2DMouthShape(mouthOpenY: 0.20, mouthForm: -0.40),
  // EE — ee/ih/ey: wide smile, slight open.
  RhubarbViseme.f: Live2DMouthShape(mouthOpenY: 0.40, mouthForm: 0.70),
  // AA — aa/ay: maximum open, neutral form.
  RhubarbViseme.g: Live2DMouthShape(mouthOpenY: 0.85, mouthForm: 0.0),
  // AW — aw/ow: medium open, rounded/pursed.
  RhubarbViseme.h: Live2DMouthShape(mouthOpenY: 0.60, mouthForm: -0.50),
  // Silence — closed, neutral.
  RhubarbViseme.x: Live2DMouthShape(mouthOpenY: 0.0, mouthForm: 0.0),
};

/// Map a Rhubarb viseme to the painter-fallback [Viseme] enum so the same
/// timeline can drive the existing [_TutorMouthOverlay] / [VirtualCharacter]
/// rendering when no Live2D model is loaded. This keeps the visual mouth
/// behaviour consistent across Live2D and fallback modes.
Viseme visemeToPainter(RhubarbViseme v) {
  switch (v) {
    case RhubarbViseme.a:
      return Viseme.closed;
    case RhubarbViseme.b:
      return Viseme.smallOpen;
    case RhubarbViseme.c:
      return Viseme.mediumOpen;
    case RhubarbViseme.d:
      return Viseme.pucker;
    case RhubarbViseme.e:
      return Viseme.biteLip;
    case RhubarbViseme.f:
      return Viseme.smileOpen;
    case RhubarbViseme.g:
      return Viseme.wideOpen;
    case RhubarbViseme.h:
      return Viseme.roundedLarge;
    case RhubarbViseme.x:
      return Viseme.closed;
  }
}

/// Lookup the Live2D mouth-shape target for a viseme. Always returns a
/// valid shape (silence when unknown) so the player never sees a null.
Live2DMouthShape shapeForViseme(RhubarbViseme v) =>
    kRhubarbToLive2DMap[v] ?? kRhubarbToLive2DMap[RhubarbViseme.x]!;
