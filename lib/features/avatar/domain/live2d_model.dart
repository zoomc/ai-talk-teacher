/// Live2D Cubism model descriptor and standard parameter IDs.
///
/// This file is the *framework* half of Phase 3 task 1: it defines the data
/// model for loading a Live2D Cubism model (`.model3.json` + `.moc3` +
/// textures + motions + expressions) and the canonical Cubism parameter IDs
/// that the rhubarb viseme → mouth-shape mapping (see [VisemeMapping]) and
/// the idle animation controller (see [IdleAnimationController]) drive.
///
/// The actual native Cubism rendering is delegated to a platform binding that
/// is *not yet bundled* — by design, per the project plan in `project.md`:
/// "生产级 Live2D 需要定稿原画的分层 PSD 和 Cubism 绑定产物（.moc3 /
/// motions）。Live2D 模型本体需外部制作（推荐外包 Live2D 画师），框架代码
/// 先行。" When a model + binding land, only [Live2DLoader.tryLoad] needs to
/// be flipped from "no model registered" to "load + return [Live2DModel]".
///
/// Standard parameter IDs mirror Live2D Cubism SDK's `CubismDefaultParameterId`
/// so a future binding has nothing to rename.
library;

/// Standard Live2D Cubism parameter IDs (canonical names used by every
/// Live2D model that follows the official template).
///
/// Keeping these as constants — not magic strings — means the rhubarb
/// mapping table and the idle controller reference the same identifiers the
/// Cubism SDK ships with, so a future native binding can subscribe to
/// parameter updates by these exact IDs without translation.
abstract final class Live2DParamId {
  // ── Mouth ───────────────────────────────────────────────────────────────
  /// Mouth open amount (0 = closed, 1 = fully open). The primary lip-sync
  /// driver — both the rhubarb viseme timeline and the TTS amplitude stream
  /// feed this parameter.
  static const String mouthOpenY = 'ParamMouthOpenY';

  /// Mouth form (-1 = frown, 0 = neutral, 1 = smile). Used for emotion
  /// expressions: happy/encouraging → +1; confused → -0.5.
  static const String mouthForm = 'ParamMouthForm';

  /// Asymmetric mouth form (left/right) — used for smirks. Optional; some
  /// models don't expose it.
  static const String mouthFormL = 'ParamMouthFormL';
  static const String mouthFormR = 'ParamMouthFormR';

  // ── Eyes ────────────────────────────────────────────────────────────────
  /// Left eye open amount (0 = closed, 1 = open). Blinks drive both eyes to 0
  /// for ~120 ms then back to 1.
  static const String eyeLOpen = 'ParamEyeLOpen';
  /// Right eye open amount (0 = closed, 1 = open).
  static const String eyeROpen = 'ParamEyeROpen';

  /// Eye smile (0 = neutral, 1 = happy/closed-eye smile arc). Used by the
  /// `happy` emotion to draw the cheerful upturned closed-eye look.
  static const String eyeSmile = 'ParamEyeSmile';

  /// Eyebrow Y position. Negative = lowered (focused/angry); positive =
  /// raised (surprised/curious).
  static const String browLY = 'ParamBrowLY';
  static const String browRY = 'ParamBrowRY';

  /// Eyebrow form (0 = neutral, 1 = worried, -1 = angry).
  static const String browLForm = 'ParamBrowLForm';
  static const String browRForm = 'ParamBrowRForm';

  /// Eyebrow angle — both eyebrows together (-1 = inner up / worried, 1 =
  /// inner down / focused).
  static const String browLAngle = 'ParamBrowLAngle';
  static const String browRAngle = 'ParamBrowRAngle';

  // ── Head pose ──────────────────────────────────────────────────────────
  /// Head angle X (yaw, -30..30). Negative = turn left; positive = turn right.
  /// Drives the idle "look around" micro-animation.
  static const String angleX = 'ParamAngleX';
  /// Head angle Y (pitch, -30..30). Negative = look down; positive = look up.
  static const String angleY = 'ParamAngleY';
  /// Head angle Z (roll, -30..30). Negative = tilt left; positive = tilt right.
  static const String angleZ = 'ParamAngleZ';

  /// Eye iris X (look direction, -1..1).
  static const String eyeBallX = 'ParamEyeBallX';
  /// Eye iris Y (look direction, -1..1).
  static const String eyeBallY = 'ParamEyeBallY';

  // ── Body / breathing ──────────────────────────────────────────────────
  /// Body angle X (yaw, -10..10). Idle sway drives this slowly.
  static const String bodyAngleX = 'ParamBodyAngleX';
  /// Body angle Z (roll, -10..10).
  static const String bodyAngleZ = 'ParamBodyAngleZ';
  /// Breath cycle (0..1) — a slow sine the model uses to scale the chest +
  /// shoulders. The idle controller drives this at ~3 s period.
  static const String breath = 'ParamBreath';

  // ── Emotion extras ────────────────────────────────────────────────────
  /// Cheek blush (0 = none, 1 = full). Used by `happy`/`encouraging`.
  static const String cheek = 'ParamCheek';
  /// Tears (0 = none, 1 = crying). Unused by default tutors.
  static const String tears = 'ParamTears';
}

/// Reference to a single Live2D texture file (.png) declared in the model.
class Live2DTextureRef {
  final String relativePath;
  const Live2DTextureRef(this.relativePath);
}

/// Reference to a motion file (.motion3.json) keyed by name + trigger.
class Live2DMotionRef {
  final String name;
  final String relativePath;
  /// Trigger source from the .model3.json — `Idle` (loop idle), `TapBody`,
  /// `TapHead`, custom (e.g. `Greet`). The idle controller only plays `Idle`.
  final String trigger;
  const Live2DMotionRef({
    required this.name,
    required this.relativePath,
    required this.trigger,
  });
}

/// Reference to an expression file (.exp3.json) keyed by name. The emotion
/// controller fades between these via the Cubism SDK's expression weight
/// parameter when the LLM emotion marker changes.
class Live2DExpressionRef {
  final String name;
  final String relativePath;
  const Live2DExpressionRef({required this.name, required this.relativePath});
}

/// In-memory representation of a parsed `.model3.json` manifest.
///
/// All paths are resolved relative to the manifest's parent directory by
/// [Live2DLoader] before the model is handed to the renderer.
class Live2DModel {
  /// Manifest file path inside assets (e.g. `assets/live2d/tutor/tutor.model3.json`).
  final String manifestPath;

  /// Resolved absolute path of the `.moc3` binary (the actual mesh + physics).
  final String moc3Path;

  /// Resolved texture paths (in z-order — first draws on top).
  final List<Live2DTextureRef> textures;

  /// Resolved physics file path (`.physics3.json`), if any.
  final String? physicsPath;

  /// Resolved pose file path (`.pose3.json`), if any.
  final String? posePath;

  /// Resolved display info (`.cdi3.json`) — gives human-readable names to
  /// parameter IDs, only used for tooling. Optional.
  final String? cdiPath;

  /// Motions declared by the manifest, grouped by trigger.
  final List<Live2DMotionRef> motions;

  /// Expressions declared by the manifest (one per emotional state).
  final List<Live2DExpressionRef> expressions;

  /// Model display name from `Name` in the manifest.
  final String displayName;

  /// Cubism SDK version the model targets (`3` or `4`). v4 supports
  /// breathing, opacity, and parameter blending modes v3 doesn't.
  final int version;

  const Live2DModel({
    required this.manifestPath,
    required this.moc3Path,
    required this.textures,
    required this.motions,
    required this.expressions,
    required this.displayName,
    required this.version,
    this.physicsPath,
    this.posePath,
    this.cdiPath,
  });

  /// Pick the first idle motion (trigger == "Idle"), if any. The idle
  /// controller prefers a model-authored idle motion over its own sine-driven
  /// parameter values when one is available.
  Live2DMotionRef? get idleMotion {
    for (final m in motions) {
      if (m.trigger == 'Idle') return m;
    }
    return null;
  }

  /// Look up an expression by name (case-insensitive). Returns null when the
  /// model has no matching expression — callers fall back to direct parameter
  /// writes via the emotion controller.
  Live2DExpressionRef? expression(String name) {
    final lower = name.toLowerCase();
    for (final e in expressions) {
      if (e.name.toLowerCase() == lower) return e;
    }
    return null;
  }
}
