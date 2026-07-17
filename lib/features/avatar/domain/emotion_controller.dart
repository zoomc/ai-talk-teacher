/// Phase 3 — emotion state machine with smooth easing transitions.
///
/// The avatar's emotion (happy / encouraging / thinking / …) drives a set
/// of facial parameters: mouth form, eye smile, brow height, cheek blush.
/// Snap-changing these whenever an LLM emotion marker arrives looks
/// mechanical, so this controller lerps the parameter set from the previous
/// emotion's values to the new emotion's values over a short transition
/// window (~250ms by default — slow enough to read as "the face relaxes
/// into a smile", fast enough not to lag behind the spoken reply).
///
/// Pure-Dart, time-driven: pass `elapsed` and the current target emotion,
/// get back a parameter → value map keyed by [Live2DParamId]. The widget
/// layer ticks a `Ticker` and merges the result with the idle frame.
library;

import 'dart:math' as math;

import '../../../features/avatar/domain/live2d_model.dart';
import '../../../features/chat/domain/tutor_emotion.dart';

/// A snapshot of the emotion-driven facial parameters. Same shape as
/// [IdleFrame] but conceptually different: this is the emotion "layer"
/// that the avatar composes on top of the idle layer.
class EmotionFrame {
  final Map<String, double> values;
  const EmotionFrame(this.values);

  static const EmotionFrame empty = EmotionFrame(<String, double>{});

  double value(String id, {double fallback = 0.0}) =>
      values[id] ?? fallback;

  @override
  String toString() => 'EmotionFrame(${values.length} params)';
}

/// Per-emotion parameter "pose" — the target values the controller eases
/// toward when this emotion becomes active. Values are tuned for the
/// canonical Cubism parameter ranges.
class EmotionPose {
  /// Mouth form: -1 = frown, 0 = neutral, +1 = full smile.
  final double mouthForm;

  /// Eye smile arc: 0 = neutral, +1 = closed-eye happy arc.
  final double eyeSmile;

  /// Brow Y offset (both brows): -1 = lowered, +1 = raised.
  final double browY;

  /// Cheek blush: 0 = none, 1 = full.
  final double cheek;

  /// Head pitch bias (added on top of idle pitch). Positive = look up.
  final double headPitchBias;

  /// Head roll bias (added on top of idle roll). Positive = tilt right.
  final double headRollBias;

  const EmotionPose({
    required this.mouthForm,
    required this.eyeSmile,
    required this.browY,
    required this.cheek,
    this.headPitchBias = 0.0,
    this.headRollBias = 0.0,
  });

  /// Linear interpolate between this pose and [other] by [t] (0..1).
  EmotionPose lerp(EmotionPose other, double t) {
    return EmotionPose(
      mouthForm: _lerp(mouthForm, other.mouthForm, t),
      eyeSmile: _lerp(eyeSmile, other.eyeSmile, t),
      browY: _lerp(browY, other.browY, t),
      cheek: _lerp(cheek, other.cheek, t),
      headPitchBias: _lerp(headPitchBias, other.headPitchBias, t),
      headRollBias: _lerp(headRollBias, other.headRollBias, t),
    );
  }

  Map<String, double> toParameterMap() => {
        Live2DParamId.mouthForm: mouthForm,
        Live2DParamId.eyeSmile: eyeSmile,
        Live2DParamId.browLY: browY,
        Live2DParamId.browRY: browY,
        Live2DParamId.cheek: cheek,
        // Head pose biases are returned separately so the caller can add
        // them on top of the idle pose instead of overwriting it.
      };

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Default pose table for the seven [TutorEmotion] values. Tuned so the
/// `neutral` pose is calm and every other pose reads at a glance.
const Map<TutorEmotion, EmotionPose> kDefaultEmotionPoses = {
  TutorEmotion.neutral: EmotionPose(
    mouthForm: 0.0,
    eyeSmile: 0.0,
    browY: 0.0,
    cheek: 0.0,
  ),
  TutorEmotion.happy: EmotionPose(
    mouthForm: 1.0,
    eyeSmile: 0.9,
    browY: 0.2,
    cheek: 0.4,
  ),
  TutorEmotion.thinking: EmotionPose(
    mouthForm: -0.1,
    eyeSmile: 0.0,
    browY: 0.3,
    cheek: 0.0,
    headPitchBias: -0.15,
  ),
  TutorEmotion.encouraging: EmotionPose(
    mouthForm: 0.7,
    eyeSmile: 0.6,
    browY: 0.15,
    cheek: 0.3,
  ),
  TutorEmotion.confused: EmotionPose(
    mouthForm: -0.4,
    eyeSmile: 0.0,
    browY: 0.4,
    cheek: 0.0,
    headRollBias: 0.1,
  ),
  TutorEmotion.focused: EmotionPose(
    mouthForm: 0.0,
    eyeSmile: 0.0,
    browY: -0.3,
    cheek: 0.0,
    headPitchBias: 0.1,
  ),
  TutorEmotion.waiting: EmotionPose(
    mouthForm: 0.3,
    eyeSmile: 0.3,
    browY: 0.1,
    cheek: 0.1,
    headRollBias: 0.05,
  ),
};

/// Easing curves supported by [EmotionController]. Currently a small but
/// useful set; the default is [easeOutCubic] because it has a fast attack
/// (the new expression starts arriving immediately) and a soft tail (the
/// last bit of the smile eases in gently).
enum EmotionEasing {
  /// Linear — only useful as a baseline in tests.
  linear,
  /// Quadratic ease-in-out — symmetric, slightly soft.
  easeInOutQuad,
  /// Cubic ease-out — fast attack, soft tail. Default.
  easeOutCubic,
}

double _applyEasing(double t, EmotionEasing easing) {
  switch (easing) {
    case EmotionEasing.linear:
      return t.clamp(0.0, 1.0);
    case EmotionEasing.easeInOutQuad:
      final c = t.clamp(0.0, 1.0);
      return c < 0.5 ? 2 * c * c : 1 - math.pow(-2 * c + 2, 2) / 2;
    case EmotionEasing.easeOutCubic:
      final c = t.clamp(0.0, 1.0);
      return 1.0 - math.pow(1 - c, 3);
  }
}

/// Configuration knobs for the emotion controller.
class EmotionControllerConfig {
  /// Transition duration between two emotions, in seconds.
  final double transitionDuration;

  /// Easing curve applied across the transition window.
  final EmotionEasing easing;

  /// Pose table — callers can override to ship a custom per-emotion look
  /// (e.g. a "stoic" tutor profile that's less expressive).
  final Map<TutorEmotion, EmotionPose> poses;

  const EmotionControllerConfig({
    this.transitionDuration = 0.25,
    this.easing = EmotionEasing.easeOutCubic,
    this.poses = kDefaultEmotionPoses,
  });

  static const EmotionControllerConfig defaults = EmotionControllerConfig();
}

/// Time-driven emotion state machine. Holds the *previous* and *target*
/// emotions plus the time the transition started, so [sample] can compute
/// the current pose without callbacks.
class EmotionController {
  final EmotionControllerConfig config;

  TutorEmotion _current;
  TutorEmotion _previous;
  double _transitionStartSeconds;

  EmotionController({
    TutorEmotion initial = TutorEmotion.neutral,
    this.config = EmotionControllerConfig.defaults,
  })  : _current = initial,
        _previous = initial,
        _transitionStartSeconds = 0.0;

  /// The emotion the controller is currently easing toward. Setting this
  /// triggers a new transition starting at the next [sample] call.
  TutorEmotion get current => _current;

  /// The emotion the controller was at *before* the current transition
  /// started. Useful for logging / debugging.
  TutorEmotion get previous => _previous;

  /// Switch to [target]. If [target] equals the current emotion, this is a
  /// no-op (avoids restarting the transition window). Pass [nowSeconds] so
  /// the controller can stamp the transition start time relative to the
  /// caller's clock — the same clock must be passed to [sample].
  void setEmotion(TutorEmotion target, {double? nowSeconds}) {
    if (target == _current) return;
    _previous = _current;
    _current = target;
    _transitionStartSeconds = nowSeconds ?? _transitionStartSeconds;
  }

  /// Compute the current blended pose at [elapsed]. [elapsed] is the same
  /// clock the caller uses for [setEmotion]'s `nowSeconds`.
  EmotionFrame sample(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;

    final fromPose = config.poses[_previous] ?? kDefaultEmotionPoses[_previous]!;
    final toPose = config.poses[_current] ?? kDefaultEmotionPoses[_current]!;

    final dt = t - _transitionStartSeconds;
    if (dt >= config.transitionDuration || config.transitionDuration <= 0) {
      // Transition complete — snap to target pose.
      return EmotionFrame(toPose.toParameterMap()
        ..[Live2DParamId.angleY] = toPose.headPitchBias
        ..[Live2DParamId.angleZ] = toPose.headRollBias);
    }
    if (dt <= 0) {
      // Before the transition started — at the previous pose.
      return EmotionFrame(fromPose.toParameterMap()
        ..[Live2DParamId.angleY] = fromPose.headPitchBias
        ..[Live2DParamId.angleZ] = fromPose.headRollBias);
    }

    final rawT = dt / config.transitionDuration;
    final easedT = _applyEasing(rawT, config.easing);
    final blended = fromPose.lerp(toPose, easedT);

    return EmotionFrame(blended.toParameterMap()
      ..[Live2DParamId.angleY] = blended.headPitchBias
      ..[Live2DParamId.angleZ] = blended.headRollBias);
  }
}
