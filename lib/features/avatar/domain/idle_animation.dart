/// Phase 3 — idle micro-animation controller.
///
/// Drives the slow "is this character alive?" motions that should keep
/// playing whenever the avatar is on screen, even when no TTS is running:
/// breathing, blinking, a gentle smile, and a slow head micro-turn. These
/// motions compose on top of the speaking emotion + viseme timeline so the
/// avatar feels alive in every [VoicePhase] (idle / listening / thinking /
/// speaking).
///
/// Pure-Dart so it can be unit-tested without a widget tree: the public API
/// is [IdleAnimationController.sample] which takes the elapsed time and a
/// phase, and returns a parameter → value map keyed by [Live2DParamId].
/// The widget layer is responsible for ticking a `Ticker` and forwarding
/// the resulting map to whichever renderer is active (Live2D binding or the
/// CustomPainter fallback).
library;

import 'dart:math' as math;

import 'live2d_model.dart';
import '../../chat/domain/tutor_emotion.dart'
    show TutorEmotion;
import '../../shared/voice_phase.dart' show VoicePhase;

/// A single frame of idle parameters, ready to be merged into the avatar's
/// parameter set. Values are always in the canonical Cubism range.
///
/// Keys come from [Live2DParamId]; this class is intentionally a thin map
/// wrapper so the renderer can iterate without case-by-case branching.
class IdleFrame {
  /// Parameter id → normalised value (typically -1..1 or 0..1).
  final Map<String, double> values;

  const IdleFrame(this.values);

  /// Empty (all-default) frame — used when the controller is stopped.
  static const IdleFrame empty = IdleFrame(<String, double>{});

  /// Look up a parameter value, falling back to [fallback] when the frame
  /// doesn't drive it (so the renderer can keep the previous value).
  double value(String id, {double fallback = 0.0}) =>
      values[id] ?? fallback;

  @override
  String toString() => 'IdleFrame(${values.length} params)';
}

/// Tunable knobs for the idle animation. Exposed so future tuning (or a
/// user "calmer avatar" accessibility setting) can dial each motion
/// without touching the controller.
class IdleAnimationConfig {
  /// Breath cycle period (seconds). Live2D's reference is ~3.3s.
  final double breathPeriod;

  /// Breath amplitude (0..1). 0.05 keeps the chest motion subtle.
  final double breathAmplitude;

  /// Mean time between blinks (seconds). Adults blink ~every 3–4s.
  final double blinkMeanInterval;

  /// Blink duration (seconds). ~120ms is the natural eye-closure duration.
  final double blinkDuration;

  /// How long the eyelid stays fully closed inside a blink (seconds).
  final double blinkClosedHold;

  /// Head yaw amplitude (degrees, will be normalised to -1..1 by the
  /// controller using the Cubism ±30 unit range).
  final double headYawAmplitudeDeg;

  /// Head yaw sweep period (seconds). Slow drift, ~8s.
  final double headYawPeriod;

  /// Head pitch amplitude (degrees, ±30 unit).
  final double headPitchAmplitudeDeg;

  /// Head pitch period (seconds).
  final double headPitchPeriod;

  /// Head roll amplitude (degrees, ±30 unit). Very subtle.
  final double headRollAmplitudeDeg;

  /// Head roll period (seconds).
  final double headRollPeriod;

  /// Smile baseline (0 = neutral, +1 = full smile). Idle defaults to a
  /// gentle +0.25.
  final double smileBaseline;

  /// Eye smile baseline for the idle face (0 = none, 1 = full arc). The
  /// `happy`/`encouraging` emotions boost this further via the emotion
  /// controller, so idle keeps it modest.
  final double eyeSmileBaseline;

  /// Body sway amplitude (degrees, ±10 unit). Should stay smaller than head
  /// yaw for a natural look.
  final double bodyYawAmplitudeDeg;

  /// Body sway period (seconds).
  final double bodyYawPeriod;

  const IdleAnimationConfig({
    this.breathPeriod = 3.3,
    this.breathAmplitude = 0.06,
    this.blinkMeanInterval = 3.5,
    this.blinkDuration = 0.12,
    this.blinkClosedHold = 0.04,
    this.headYawAmplitudeDeg = 6.0,
    this.headYawPeriod = 8.0,
    this.headPitchAmplitudeDeg = 2.5,
    this.headPitchPeriod = 11.0,
    this.headRollAmplitudeDeg = 1.5,
    this.headRollPeriod = 13.0,
    this.smileBaseline = 0.25,
    this.eyeSmileBaseline = 0.15,
    this.bodyYawAmplitudeDeg = 2.0,
    this.bodyYawPeriod = 7.0,
  });

  /// Default profile used when callers don't override.
  static const IdleAnimationConfig defaults = IdleAnimationConfig();
}

/// Drives idle micro-animations deterministically from an elapsed time.
///
/// The controller is *time-driven* (no internal timers) so it is fully
/// reproducible in tests — pass the same `elapsed` and `phase` and the
/// same frame comes out. The widget layer is expected to drive a `Ticker`
/// and forward `DateTime.now()` deltas.
///
/// Blink scheduling: instead of holding timer state, the controller hashes
/// the elapsed time into discrete slots spaced `blinkMeanInterval` seconds
/// apart, and tests whether the current elapsed time falls inside a blink
/// window that starts somewhere inside each slot. This keeps the controller
/// stateless while still producing realistic-looking blink patterns (blinks
/// roughly every 3–4s with slight jitter, never at exactly fixed
/// intervals).
class IdleAnimationController {
  final IdleAnimationConfig config;

  /// Per-phase multipliers so the avatar reacts contextually even when idle:
  ///   - [VoicePhase.idle] — full idle motion, gentle smile.
  ///   - [VoicePhase.listening] — head tilts slightly toward the user,
  ///     reduced smile (attentive), normal blink rate.
  ///   - [VoicePhase.thinking] — slower blinks, head looks slightly up.
  ///   - [VoicePhase.speaking] — idle motion mostly suppressed so the viseme
  ///     timeline + emotion controller drive the face; only breathing + a
  ///     subtle body sway remain.
  IdleAnimationController({this.config = IdleAnimationConfig.defaults});

  /// Sample an idle frame at [elapsed] seconds for the given [phase] and
  /// base [emotion]. The [emotion] subtly biases the smile baseline so a
  /// happy idle face rests with a wider smile than a confused one.
  IdleFrame sample(
    Duration elapsed, {
    VoicePhase phase = VoicePhase.idle,
    TutorEmotion emotion = TutorEmotion.neutral,
  }) {
    final t = elapsed.inMicroseconds / 1e6;

    // Breathing never stops, regardless of phase.
    final breath = _breath(t);

    // Phase-dependent multipliers.
    final m = _phaseMultiplier(phase);
    final headScale = m.headScale;
    final bodyScale = m.bodyScale;
    final smileScale = m.smileScale;
    final blinkScale = m.blinkScale;

    // Head micro-turn — three sinusoids at different periods/phases.
    final yaw = _sin(t, config.headYawPeriod, phase: 0.0) *
        (config.headYawAmplitudeDeg / 30.0) *
        headScale;
    final pitch = _sin(t, config.headPitchPeriod, phase: 1.2) *
        (config.headPitchAmplitudeDeg / 30.0) *
        headScale;
    // Listening tilts head slightly toward the user (positive roll).
    final rollBase =
        _sin(t, config.headRollPeriod, phase: 2.4) *
            (config.headRollAmplitudeDeg / 30.0);
    final rollOffset = phase == VoicePhase.listening ? 0.05 : 0.0;
    final roll = (rollBase * headScale) + (rollOffset * headScale);

    // Body sway — slower + smaller than head yaw.
    final bodyYaw = _sin(t, config.bodyYawPeriod, phase: 0.7) *
        (config.bodyYawAmplitudeDeg / 10.0) *
        bodyScale;

    // Smile baseline biased by emotion.
    final smile = _smileForEmotion(emotion) * smileScale;

    // Eye smile is a function of the smile baseline so the eyes track the
    // mouth shape — but only in phases where we want the smile visible.
    final eyeSmile = smile.clamp(0.0, 1.0) * 0.6 * smileScale +
        config.eyeSmileBaseline * smileScale;

    // Blink — pseudo-random schedule, scaled by phase (thinking blinks
    // slower / less frequently to convey concentration).
    final blink = _blink(t) * blinkScale;

    return IdleFrame({
      Live2DParamId.breath: breath,
      Live2DParamId.angleX: yaw,
      Live2DParamId.angleY: pitch,
      Live2DParamId.angleZ: roll,
      Live2DParamId.bodyAngleX: bodyYaw,
      Live2DParamId.mouthForm: smile,
      Live2DParamId.eyeSmile: eyeSmile,
      // Eyes close during blink — both eyes driven together. 1 = open,
      // 0 = closed, so invert the blink signal.
      Live2DParamId.eyeLOpen: 1.0 - blink,
      Live2DParamId.eyeROpen: 1.0 - blink,
    });
  }

  /// Breathing sine. Output range is centred on 0.5 with amplitude
  /// [IdleAnimationConfig.breathAmplitude] so the chest visibly rises and
  /// falls without saturating the [Live2DParamId.breath] parameter.
  double _breath(double t) {
    final raw = math.sin((2 * math.pi * t) / config.breathPeriod);
    return 0.5 + 0.5 * raw * config.breathAmplitude;
  }

  /// Sinusoid normalised to -1..1.
  double _sin(double t, double period, {double phase = 0.0}) {
    return math.sin((2 * math.pi * t) / period + phase);
  }

  /// Smile baseline biased by the current emotion.
  double _smileForEmotion(TutorEmotion emotion) {
    switch (emotion) {
      case TutorEmotion.happy:
        return 1.0;
      case TutorEmotion.encouraging:
        return 0.7;
      case TutorEmotion.neutral:
        return config.smileBaseline;
      case TutorEmotion.waiting:
        return config.smileBaseline + 0.1;
      case TutorEmotion.thinking:
        return 0.0;
      case TutorEmotion.confused:
        return -0.3;
      case TutorEmotion.focused:
        return 0.0;
    }
  }

  /// Blink envelope. Returns 1 = fully closed, 0 = open.
  ///
  /// Uses a deterministic pseudo-random schedule: divide time into
  /// `1 / blinkMeanInterval` slots per second, then for each slot
  /// deterministically pick whether a blink starts based on a hashed
  /// value. The actual blink waveform is a triangle: ramp up to 1 over
  /// `blinkDuration`, hold, ramp down.
  double _blink(double t) {
    final interval = config.blinkMeanInterval;
    final slotIndex = (t / interval).floor();
    // Deterministic per-slot jitter via multiplicative hash.
    final jitter = _hash01(slotIndex * 2654435761);
    final blinkStart = (slotIndex + jitter * 0.5) * interval;
    final blinkEnd = blinkStart + config.blinkDuration + config.blinkClosedHold;
    if (t < blinkStart || t > blinkEnd) return 0.0;
    final localT = t - blinkStart;
    final rampUp = config.blinkDuration;
    final hold = config.blinkClosedHold;
    if (localT < rampUp) {
      // Ramp up: 0 → 1.
      return localT / rampUp;
    } else if (localT < rampUp + hold) {
      return 1.0;
    } else {
      // Ramp down: 1 → 0.
      final downT = localT - rampUp - hold;
      return (1.0 - downT / rampUp).clamp(0.0, 1.0);
    }
  }

  /// Multiplicative hash → 0..1, deterministic across runs.
  double _hash01(int x) {
    final h = (x * 2654435761) & 0x7FFFFFFF;
    return h / 0x7FFFFFFF;
  }

  /// Per-phase multipliers (0..1) for each motion axis.
  _PhaseMultiplier _phaseMultiplier(VoicePhase phase) {
    switch (phase) {
      case VoicePhase.idle:
        return const _PhaseMultiplier(
          headScale: 1.0,
          bodyScale: 1.0,
          smileScale: 1.0,
          blinkScale: 1.0,
        );
      case VoicePhase.listening:
        // Attentive — head tilts more, smile slightly reduced.
        return const _PhaseMultiplier(
          headScale: 1.0,
          bodyScale: 0.7,
          smileScale: 0.8,
          blinkScale: 0.9,
        );
      case VoicePhase.transcribing:
        // Brief moment — basically idle with reduced motion.
        return const _PhaseMultiplier(
          headScale: 0.6,
          bodyScale: 0.5,
          smileScale: 0.7,
          blinkScale: 0.8,
        );
      case VoicePhase.thinking:
        // Slower blinks, head looks slightly up, smile neutral.
        return const _PhaseMultiplier(
          headScale: 0.5,
          bodyScale: 0.4,
          smileScale: 0.4,
          blinkScale: 0.6,
        );
      case VoicePhase.speaking:
        // Viseme timeline + emotion drive the mouth; idle keeps breathing
        // and a tiny body sway only.
        return const _PhaseMultiplier(
          headScale: 0.2,
          bodyScale: 0.5,
          smileScale: 0.0, // Mouth is driven by visemes — don't override.
          blinkScale: 0.7,
        );
    }
  }
}

/// Per-phase scaling for each idle axis.
class _PhaseMultiplier {
  final double headScale;
  final double bodyScale;
  final double smileScale;
  final double blinkScale;

  const _PhaseMultiplier({
    required this.headScale,
    required this.bodyScale,
    required this.smileScale,
    required this.blinkScale,
  });
}
