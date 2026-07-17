/// Phase 3 — unified avatar stage.
///
/// Single widget that composes every Phase 3 building block into the live
/// face the user sees in the chat screen:
///
///   ┌───────────────────────────────────────────────────────────────────┐
///   │  Live2D model?  │  Renderer used                                 │
///   ├─────────────────┼────────────────────────────────────────────────┤
///   │  yes (future)   │  Native Cubism binding (not yet shipped)       │
///   │  no  (today)    │  Existing `tutor-hero-v1.png` placeholder +   │
///   │                 │  parameter-driven mouth overlay               │
///   └───────────────────────────────────────────────────────────────────┘
///
/// The widget is *parameter-set driven*: every frame the idle controller,
/// emotion controller, and viseme timeline player all emit a parameter →
/// value map keyed by [Live2DParamId]; the stage merges them (speaking
/// overrides idle for the mouth, idle + emotion compose for everything
/// else) and hands the merged set to whichever renderer is active. When a
/// native Live2D binding lands, only the `_renderLive2D` branch needs to be
/// flipped from `throw UnimplementedError()` to "drive the binding".
///
/// Fallback rendering path uses the existing [VirtualCharacter] painter
/// helpers (`visemeForChar`) so the user-visible mouth motion stays exactly
/// as good as it was before Phase 3, with the new idle + emotion motion
/// added on top.
library;

import 'dart:async';
import 'package:flutter/scheduler.dart';

import 'package:flutter/material.dart';

import '../../../avatar/data/live2d_loader.dart';
import '../../../avatar/data/viseme_timeline_player.dart';
import '../../../avatar/domain/emotion_controller.dart';
import '../../../avatar/domain/idle_animation.dart';
import '../../../avatar/domain/live2d_model.dart';
import '../../../avatar/domain/viseme_mapping.dart';
import '../../../avatar/domain/viseme_timeline.dart';
import '../../../chat/domain/tutor_emotion.dart';
import '../../../../shared/voice_phase.dart';
import '../../../../shared/widgets/virtual_character.dart'
    show CharacterState, Viseme, VirtualCharacter;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Phase (4-state) used by the avatar stage. Mirrors [VoicePhase] but kept
/// as its own enum so the avatar module doesn't pull in [VoicePhase] from
/// `shared` (which would create an import cycle in tests). The chat screen
/// converts between the two via [AvatarPhase.fromVoicePhase].
enum AvatarPhase {
  idle,
  listening,
  thinking,
  speaking;

  static AvatarPhase fromVoicePhase(VoicePhase phase) {
    switch (phase) {
      case VoicePhase.idle:
        return AvatarPhase.idle;
      case VoicePhase.listening:
      case VoicePhase.transcribing:
        // Transcribing looks the same as listening from the avatar's point
        // of view — both are "user is talking / we're processing their
        // voice".
        return AvatarPhase.listening;
      case VoicePhase.thinking:
        return AvatarPhase.thinking;
      case VoicePhase.speaking:
        return AvatarPhase.speaking;
    }
  }

  /// Convert from the legacy [CharacterState] enum used by the chat screen.
  /// Kept so the chat screen can adopt the avatar stage without immediately
  /// migrating off [CharacterState].
  static AvatarPhase fromCharacterState(CharacterState state) {
    switch (state) {
      case CharacterState.idle:
        return AvatarPhase.idle;
      case CharacterState.listening:
        return AvatarPhase.listening;
      case CharacterState.thinking:
        return AvatarPhase.thinking;
      case CharacterState.speaking:
        return AvatarPhase.speaking;
    }
  }

  VoicePhase toVoicePhase() {
    switch (this) {
      case AvatarPhase.idle:
        return VoicePhase.idle;
      case AvatarPhase.listening:
        return VoicePhase.listening;
      case AvatarPhase.thinking:
        return VoicePhase.thinking;
      case AvatarPhase.speaking:
        return VoicePhase.speaking;
    }
  }
}

/// The unified avatar widget. Drop-in replacement for the previous
/// `_TutorLive2DPortrait` widget in [ChatScreen].
///
/// Inputs:
///  - [phase]: current conversation phase (idle / listening / thinking /
///    speaking). Drives the idle controller's per-phase multipliers and
///    decides whether the viseme timeline / amplitude stream should drive
///    the mouth.
///  - [emotion]: current target emotion. Eased in over ~250ms by the
///    [EmotionController].
///  - [speakingText]: visible text the tutor is speaking. Used as a
///    fallback for the legacy `visemeForChar` mouth shape when no Rhubarb
///    viseme timeline has been supplied via [AvatarStageState.setVisemeTimeline].
///  - [amplitudeStream]: optional TTS amplitude stream (0..1). When no
///    Rhubarb timeline is active, this drives `mouthOpenY` directly so the
///    mouth opens roughly with the spoken volume.
///  - [tutorName]: name shown in the status pill.
///
/// The stage is a [StatefulWidget] so it can own a [Ticker] for the
/// idle + emotion + viseme sampling loop. The widget is self-contained —
/// it does not depend on Riverpod so it can be reused outside the chat
/// screen (e.g. onboarding, voice-health check) without providers.
class AvatarStage extends StatefulWidget {
  final AvatarPhase phase;
  final TutorEmotion emotion;
  final String? speakingText;
  final Stream<double>? amplitudeStream;
  final String tutorName;

  /// Optional: fixed-size box the avatar renders inside. When `null`,
  /// the stage fills its parent.
  final double? panelWidth;
  final double? panelHeight;

  const AvatarStage({
    super.key,
    required this.phase,
    required this.tutorName,
    this.emotion = TutorEmotion.neutral,
    this.speakingText,
    this.amplitudeStream,
    this.panelWidth,
    this.panelHeight,
  });

  @override
  State<AvatarStage> createState() => AvatarStageState();
}

/// Public state class so the chat screen can push a viseme timeline in
/// once Rhubarb finishes analysing the TTS audio.
class AvatarStageState extends State<AvatarStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final IdleAnimationController _idle;
  late final EmotionController _emotion;
  late final VisemeTimelinePlayer _visemePlayer;

  /// Live2D model descriptor — `null` means "no model shipped yet, use the
  /// placeholder fallback". Probed once in [initState] via [Live2DLoader].
  Live2DModel? _live2dModel;

  /// Latest amplitude sample (0..1) from the TTS playback service, or `0`
  /// when no stream is connected / the latest value is stale.
  double _latestAmplitude = 0.0;
  StreamSubscription<double>? _ampSub;

  /// Elapsed time since the stage mounted. Used as the clock for the idle
  /// and emotion controllers so they produce deterministic, time-based
  /// output.
  Duration _elapsed = Duration.zero;

  /// Time at which the current speaking turn started (in elapsed time).
  /// Used to sample the viseme timeline at the right offset. Reset every
  /// time the phase transitions into [AvatarPhase.speaking].
  Duration? _speakingStartedAt;

  /// Whether a real Rhubarb viseme timeline has been loaded via
  /// [setVisemeTimeline]. Distinguishes "no timeline yet" from "timeline
  /// loaded but all-silence".
  bool _hasActiveTimeline = false;

  /// Current merged parameter set, recomputed every tick.
  Map<String, double> _merged = const {};

  @override
  void initState() {
    super.initState();
    _idle = IdleAnimationController();
    _emotion = EmotionController();
    _visemePlayer = VisemeTimelinePlayer(VisemeTimeline.empty);
    _ticker = createTicker(_onTick);
    _ticker.start();
    _probeForLive2DModel();
    _subscribeAmplitude();
    if (widget.phase == AvatarPhase.speaking) {
      _speakingStartedAt = Duration.zero;
    }
  }

  @override
  void didUpdateWidget(covariant AvatarStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion) {
      // Stamp the transition at the current elapsed time so the easing
      // window starts now.
      final t = _elapsed.inMicroseconds / 1e6;
      _emotion.setEmotion(widget.emotion, nowSeconds: t);
    }
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _subscribeAmplitude();
    }
    if (oldWidget.phase != widget.phase) {
      if (widget.phase == AvatarPhase.speaking) {
        // Speaking just started — reset the viseme clock so the timeline
        // samples from t=0.
        _speakingStartedAt = _elapsed;
      } else if (oldWidget.phase == AvatarPhase.speaking) {
        // Speaking ended — clear the timeline + amplitude.
        _speakingStartedAt = null;
        _latestAmplitude = 0.0;
        _hasActiveTimeline = false;
        _visemePlayer.stop();
      }
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _visemePlayer.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    _recompute();
  }

  void _recompute() {
    final phase = widget.phase.toVoicePhase();
    final idleFrame = _idle.sample(
      _elapsed,
      phase: phase,
      emotion: widget.emotion,
    );
    final emotionFrame = _emotion.sample(_elapsed);

    final isSpeaking = widget.phase == AvatarPhase.speaking;
    VisemeFrame? visemeFrame;
    if (isSpeaking && _hasActiveTimeline && _speakingStartedAt != null) {
      final tSec = (_elapsed - _speakingStartedAt!).inMicroseconds / 1e6;
      visemeFrame = _visemePlayer.sampleAt(tSec);
      if (visemeFrame.ended) {
        // Timeline finished — drop it so the amplitude fallback can take
        // over for any trailing audio.
        _hasActiveTimeline = false;
        visemeFrame = null;
      }
    }

    // Merge: idle is the base, emotion overrides its parameters, then the
    // speaking mouth params (mouthOpenY, mouthForm) override the emotion's.
    final merged = <String, double>{}
      ..addAll(idleFrame.values)
      ..addAll(emotionFrame.values);

    if (visemeFrame != null) {
      // The viseme shape's mouthOpenY/mouthForm *replace* the idle/emotion
      // mouth params while speaking — the viseme timeline is authoritative
      // during TTS playback.
      merged[Live2DParamId.mouthOpenY] = visemeFrame.mouthShape.mouthOpenY;
      // mouthForm is blended: viseme provides a base, emotion biases it.
      final blendedForm = (visemeFrame.mouthShape.mouthForm +
              (emotionFrame.value(Live2DParamId.mouthForm) * 0.3))
          .clamp(-1.0, 1.0);
      merged[Live2DParamId.mouthForm] = blendedForm;
    } else if (isSpeaking) {
      // No Rhubarb timeline available — drive mouthOpenY from the
      // amplitude stream.
      final amp = _latestAmplitude;
      merged[Live2DParamId.mouthOpenY] = amp.clamp(0.0, 1.0);
    }

    if (mounted) {
      setState(() {
        _merged = merged;
      });
    }
  }

  void _subscribeAmplitude() {
    _ampSub?.cancel();
    final stream = widget.amplitudeStream;
    if (stream == null) {
      _latestAmplitude = 0.0;
      return;
    }
    _ampSub = stream.listen((level) {
      _latestAmplitude = level;
    });
  }

  Future<void> _probeForLive2DModel() async {
    // Probe is async because [AssetManifest.load] is async. We don't need
    // to setState on completion — the renderer reads `_live2dModel` every
    // build, so the next tick picks up the new value.
    try {
      final model = await const Live2DLoader().tryLoadDefault();
      if (mounted) {
        setState(() => _live2dModel = model);
      }
    } catch (_) {
      // Any probe failure → stay on the placeholder fallback. The avatar
      // must never block the chat from rendering.
    }
  }

  /// Public API: push a viseme timeline produced by Rhubarb. The stage
  /// starts sampling it immediately. Call this when TTS playback starts
  /// and the rhubarb service has returned an analysis for the audio.
  ///
  /// The viseme clock is anchored to when the speaking *phase* began (set
  /// in [didUpdateWidget]), NOT to when this method is called. Rhubarb
  /// analysis is async and lands after TTS has already started playing;
  /// restarting the viseme clock here would make the mouth lag the audio
  /// by the full analysis latency. If [setVisemeTimeline] is somehow called
  /// before the speaking phase began (defensive), the clock is anchored
  /// to now via `??=`.
  void setVisemeTimeline(VisemeTimeline timeline) {
    _visemePlayer.replaceTimeline(timeline);
    _visemePlayer.start();
    _hasActiveTimeline = true;
    _speakingStartedAt ??= _elapsed;
  }

  /// Public API: clear the current viseme timeline. Call when TTS playback
  /// ends so the avatar stops trying to drive the mouth from a stale
  /// timeline.
  void clearVisemeTimeline() {
    _visemePlayer.stop();
    _hasActiveTimeline = false;
    _speakingStartedAt = null;
  }

  /// Whether the stage has detected a bundled Live2D model. Exposed for
  /// tests so they can assert that the fallback path was taken when no
  /// model is shipped.
  bool get hasLive2DModel => _live2dModel != null;

  @override
  Widget build(BuildContext context) {
    final child = _buildStageContent();
    final labelled = Semantics(
      liveRegion: true,
      label: '${widget.tutorName} · ${_phaseLabel(context)}',
      child: child,
    );
    return labelled;
  }

  Widget _buildStageContent() {
    if (_live2dModel != null) {
      // Future: native Cubism binding drives the model with `_merged`.
      // For now fall through to the placeholder renderer — the framework
      // is in place so flipping the switch later is a one-line change.
      return _renderFallback();
    }
    return _renderFallback();
  }

  Widget _renderFallback() {
    // The placeholder renderer composes the same image the chat screen
    // was already using, plus a parameter-driven mouth overlay. The
    // overlay reads `mouthOpenY` and `mouthForm` from `_merged` so the
    // Rhubarb timeline / amplitude stream / emotion all flow into the
    // same shape.
    final isSpeaking = widget.phase == AvatarPhase.speaking;
    final text = widget.speakingText ?? '';
    final hasSpeech = isSpeaking && text.isNotEmpty;

    final mouthOpenY = _merged[Live2DParamId.mouthOpenY] ??
        (isSpeaking ? _latestAmplitude : 0.0);
    final mouthForm = _merged[Live2DParamId.mouthForm] ?? 0.0;

    // Determine which painter viseme to draw — Rhubarb's frame carries a
    // painter viseme name when available, otherwise fall back to the
    // legacy `visemeForChar` lookup so the legacy mouth overlay still
    // animates.
    final Viseme painterViseme;
    if (hasSpeech) {
      Viseme? rhubarbViseme;
      if (_hasActiveTimeline && _speakingStartedAt != null) {
        final tSec = (_elapsed - _speakingStartedAt!).inMicroseconds / 1e6;
        final frame = _visemePlayer.sampleAt(tSec);
        if (!frame.ended) {
          rhubarbViseme = visemeToPainter(frame.viseme);
        }
      }
      if (rhubarbViseme != null) {
        painterViseme = rhubarbViseme;
      } else {
        painterViseme =
            VirtualCharacter.visemeForChar(text, _legacyVisemeIndex(text));
      }
    } else {
      painterViseme = Viseme.closed;
    }

    // Subtle vertical sway driven by the breath parameter — keeps the
    // placeholder image feeling alive even before a Live2D model ships.
    final breath = _merged[Live2DParamId.breath] ?? 0.5;
    final swayOffset = (breath - 0.5) * 6.0; // ±3px

    // Head roll tilts the whole portrait a touch.
    final rollDeg = (_merged[Live2DParamId.angleZ] ?? 0.0) * 8.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: Offset(0, swayOffset - 3),
          child: Transform.rotate(
            angle: rollDeg * 3.14159265 / 180.0,
            child: Transform.scale(
              scale: isSpeaking ? 1.012 : 1.0,
              child: Image.asset(
                'assets/images/tutor-hero-v1.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.22),
                errorBuilder: (_, _, _) => _renderImageFallback(),
              ),
            ),
          ),
        ),
        if (hasSpeech)
          Align(
            alignment: const Alignment(0.10, 0.10),
            child: _ParameterisedMouthOverlay(
              viseme: painterViseme,
              openAmount: mouthOpenY,
              smileAmount: mouthForm,
            ),
          ),
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _AvatarStageStatus(
            name: widget.tutorName,
            phase: widget.phase,
          ),
        ),
      ],
    );
  }

  /// Plain coloured panel rendered when the placeholder image asset is
  /// missing (e.g. during tests). Keeps the avatar always visible.
  Widget _renderImageFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgSecondary,
            AppColors.bgPrimary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.face,
          size: 96,
          color: AppColors.accentPrimaryLight,
        ),
      ),
    );
  }

  int _legacyVisemeIndex(String text) {
    // Slowly advance the viseme pointer so the legacy mouth shape changes
    // while speaking — mirrors the previous `_TutorLive2DPortrait`
    // behaviour (one viseme per ~92ms tick).
    final tickMs = (_elapsed.inMilliseconds ~/ 92).clamp(0, 1 << 30);
    if (text.isEmpty) return 0;
    return tickMs % text.length;
  }

  String _phaseLabel(BuildContext context) {
    // Inline minimal label — avoids pulling AppLocalizations through here.
    // The chat screen wraps the stage in its own Semantics anyway, so this
    // is a best-effort fallback for screens that don't.
    switch (widget.phase) {
      case AvatarPhase.idle:
        return 'Ready';
      case AvatarPhase.listening:
        return 'Listening';
      case AvatarPhase.thinking:
        return 'Thinking';
      case AvatarPhase.speaking:
        return 'Speaking';
    }
  }
}

/// Mouth overlay that takes a viseme + continuous open/smile amounts. When
/// the viseme is from the legacy `VirtualCharacter.visemeForChar` table,
/// the discrete viseme defines the basic shape; the continuous amounts
/// modulate the size so amplitude / viseme-timeline data still produces
/// smooth motion on top of the discrete viseme.
class _ParameterisedMouthOverlay extends StatelessWidget {
  final Viseme viseme;
  final double openAmount;
  final double smileAmount;

  const _ParameterisedMouthOverlay({
    required this.viseme,
    required this.openAmount,
    required this.smileAmount,
  });

  @override
  Widget build(BuildContext context) {
    final rounded = {
      Viseme.roundedSmall,
      Viseme.roundedLarge,
      Viseme.pucker,
    }.contains(viseme);
    final wide = {
      Viseme.wideOpen,
      Viseme.wide,
      Viseme.wideFlat,
      Viseme.smileOpen,
    }.contains(viseme);
    final open = {
      Viseme.mediumOpen,
      Viseme.wideOpen,
      Viseme.roundedLarge,
      Viseme.oval,
      Viseme.openTeeth,
    }.contains(viseme);

    // Continuous modulation: amplitude widens/heightens the mouth beyond
    // the viseme's base shape.
    final openBoost = (openAmount * 6.0).clamp(0.0, 8.0);
    final smileBoost = (smileAmount * 4.0).clamp(-2.0, 6.0);

    final width = (rounded ? 18.0 : (wide ? 36.0 : 28.0)) + smileBoost;
    final height = (open ? 12.0 : 6.0) + openBoost;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF9B3F58)
            .withValues(alpha: open ? 0.75 : 0.5),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: const Color(0xFFE997AD).withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _AvatarStageStatus extends StatelessWidget {
  final String name;
  final AvatarPhase phase;
  const _AvatarStageStatus({required this.name, required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      AvatarPhase.idle => ('Ready', AppColors.accentPrimary),
      AvatarPhase.listening => ('Listening', AppColors.accentSecondary),
      AvatarPhase.thinking => ('Thinking', AppColors.warning),
      AvatarPhase.speaking => ('Speaking', AppColors.success),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$name · $label',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
