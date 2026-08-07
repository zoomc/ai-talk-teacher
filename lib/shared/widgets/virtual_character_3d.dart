import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../features/chat/domain/tutor_emotion.dart';
import 'virtual_character.dart';
import 'virtual_character_3d_platform.dart'
    if (dart.library.js_interop) 'virtual_character_3d_web.dart'
    if (dart.library.io) 'virtual_character_3d_mobile.dart'
    as platform;

/// 3D virtual character widget.
///
/// Renders a real, WebGL-based humanoid avatar from the bundled self-hosted
/// Avatar V2 GLB with Oculus viseme morph targets, driven by Three.js and
/// TalkingHead. It is embedded via [HtmlElementView] on web and
/// `webview_flutter` on mobile/desktop — see [platform.AvatarHost] for the
/// per-platform plumbing.
///
/// The host receives only high-level phase, emotion, gesture, viseme and
/// audio-level messages. A real TTS viseme timeline is the primary mouth
/// clock; amplitude and text are only fallbacks when timing data is absent.
///
/// If the 3D pipeline can't initialise within a short grace period (no
/// WebGL, local GLB load failure), the widget transparently
/// falls back to [VirtualCharacter] so the app is always usable.
class VirtualCharacter3D extends StatefulWidget {
  final String tutorName;
  // Kept for API parity with [VirtualCharacter]; unused by the 3D render.
  final String tutorAvatar;
  final CharacterState state;
  final TutorEmotion emotion;
  final TutorGestureCue gesture;
  final Color accentColor;

  /// Diameter of the character circle in pixels.
  final double size;

  /// Whether to render the name + state pill below the avatar.
  final bool showLabel;

  /// Optional visible text the avatar is currently speaking. It is only used
  /// as the final mouth fallback when no audio timeline is available.
  final String? speakingText;

  /// Optional TTS amplitude stream (0..1). When provided, the avatar's jaw
  /// openness is blended with the live audio level for natural lip-sync.
  final Stream<double>? audioLevelStream;

  /// Optional GLB URL override (per-tutor avatar). When null the bundled
  /// Avatar V2 teacher is used (see avatar.html).
  final String? avatarUrl;

  /// Optional high-level viseme from a real TTS audio timeline. When set,
  /// this takes precedence over the legacy text fallback.
  final String? viseme;

  /// The same TTS bytes currently being played by the app. The Web runtime
  /// analyzes these bytes with HeadAudio without creating a second audible
  /// playback path.
  final Uint8List? speechAudio;
  final DateTime? speechStartedAt;

  const VirtualCharacter3D({
    super.key,
    required this.tutorName,
    required this.tutorAvatar,
    this.state = CharacterState.idle,
    this.emotion = TutorEmotion.neutral,
    this.gesture = TutorGestureCue.idle,
    this.accentColor = AppColors.accentPrimary,
    this.size = 120,
    this.showLabel = true,
    this.speakingText,
    this.audioLevelStream,
    this.avatarUrl,
    this.viseme,
    this.speechAudio,
    this.speechStartedAt,
  });

  @override
  State<VirtualCharacter3D> createState() => _VirtualCharacter3DState();
}

enum _AvatarMode { loading, ready3d, fallback }

class _VirtualCharacter3DState extends State<VirtualCharacter3D> {
  late final platform.AvatarHost _host;
  _AvatarMode _mode = _AvatarMode.loading;

  // Viseme stepper is the final fallback when no audio timeline is available.
  Timer? _visemeTimer;
  int _visemeCharIndex = 0;

  // Readiness polling.
  Timer? _pollTimer;
  int _pollTicks = 0;
  static const int _maxPollTicks = 20; // ~8 s @ 400 ms

  StreamSubscription<double>? _audioSub;

  @override
  void initState() {
    super.initState();
    try {
      _host = platform.AvatarHost();
      _host.init(avatarUrl: widget.avatarUrl, onError: _onHostError);
      if (!_host.isSupported) {
        _mode = _AvatarMode.fallback;
      } else {
        _startPolling();
      }
    } catch (_) {
      _mode = _AvatarMode.fallback;
    }
    _applyState();
    if (widget.speechAudio != null) {
      _host.setSpeechAudio(
        widget.speechAudio!,
        startedAt: widget.speechStartedAt,
      );
    }
    _attachAudio();
  }

  @override
  void didUpdateWidget(covariant VirtualCharacter3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stateChanged = oldWidget.state != widget.state;
    final emotionChanged = oldWidget.emotion != widget.emotion;
    final gestureChanged = oldWidget.gesture != widget.gesture;
    final visemeChanged = oldWidget.viseme != widget.viseme;
    final textChanged = oldWidget.speakingText != widget.speakingText;
    if (stateChanged || gestureChanged || textChanged) {
      _applyState();
    } else if (emotionChanged) {
      _host.setEmotion(widget.emotion.id);
    }
    if (visemeChanged &&
        !stateChanged &&
        !gestureChanged &&
        !textChanged &&
        widget.state == CharacterState.speaking &&
        widget.viseme != null) {
      _host.setViseme(widget.viseme!);
    }
    if (oldWidget.audioLevelStream != widget.audioLevelStream) {
      _attachAudio();
    }
    if (oldWidget.speechAudio != widget.speechAudio ||
        oldWidget.speechStartedAt != widget.speechStartedAt) {
      final audio = widget.speechAudio;
      if (audio != null) {
        _host.setSpeechAudio(audio, startedAt: widget.speechStartedAt);
      } else {
        _host.clearSpeechAudio();
      }
    }
  }

  void _onHostError() {
    if (!mounted) return;
    if (_mode != _AvatarMode.ready3d) {
      setState(() => _mode = _AvatarMode.fallback);
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      _pollTicks++;
      final ready = await _host.isReady();
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      if (ready) {
        _pollTimer?.cancel();
        setState(() => _mode = _AvatarMode.ready3d);
        // Re-apply current state now that the bridge can actually receive.
        _applyState();
      } else if (_pollTicks >= _maxPollTicks) {
        _pollTimer?.cancel();
        setState(() => _mode = _AvatarMode.fallback);
      }
    });
  }

  void _applyState() {
    final s = widget.state;
    final text = widget.speakingText ?? '';
    // Send the semantic state first so each host can reset stale gesture and
    // mouth state, then apply the more precise text/audio inputs below.
    _host.setState(s.name);
    _host.setEmotion(widget.emotion.id);
    final requestedGesture = widget.gesture.id;
    final gesture = requestedGesture == 'idle'
        ? switch (s) {
            CharacterState.idle => 'idle',
            CharacterState.listening => 'gentle_nod',
            CharacterState.thinking => 'confused',
            CharacterState.speaking => 'gentle_nod',
          }
        : requestedGesture;
    switch (s) {
      case CharacterState.idle:
        _host.setGesture(gesture);
        _host.setViseme('closed');
        _stopViseme();
        break;
      case CharacterState.listening:
        _host.setGesture(gesture);
        _host.setViseme('slightOpen');
        _stopViseme();
        break;
      case CharacterState.thinking:
        _host.setGesture(gesture);
        _host.setViseme('biteLip');
        _stopViseme();
        break;
      case CharacterState.speaking:
        // Semantic cues are supplied by the conversation layer. Do not infer
        // body language from visible reply text in the primary 3D path.
        _host.setGesture(gesture);
        if (widget.viseme != null) {
          _host.setViseme(widget.viseme!);
          _stopViseme();
        } else if (text.isEmpty) {
          _host.setViseme('mediumOpen');
          _stopViseme();
        } else {
          _visemeCharIndex = 0;
          _host.setViseme(VirtualCharacter.visemeForChar(text, 0).name);
          _startViseme();
        }
        break;
    }
  }

  void _startViseme() {
    _visemeTimer?.cancel();
    _visemeTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      final t = widget.speakingText ?? '';
      if (t.isEmpty || widget.state != CharacterState.speaking) {
        _stopViseme();
        return;
      }
      _visemeCharIndex = (_visemeCharIndex + 1) % t.length;
      _host.setViseme(VirtualCharacter.visemeForChar(t, _visemeCharIndex).name);
    });
  }

  void _stopViseme() {
    _visemeTimer?.cancel();
    _visemeTimer = null;
  }

  void _attachAudio() {
    _audioSub?.cancel();
    final stream = widget.audioLevelStream;
    if (stream == null) return;
    _audioSub = stream.listen((lv) {
      _host.setAudioLevel(lv.clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _visemeTimer?.cancel();
    _pollTimer?.cancel();
    _audioSub?.cancel();
    _host.dispose();
    super.dispose();
  }

  Color get _stateColor {
    switch (widget.state) {
      case CharacterState.idle:
        return AppColors.accentPrimary;
      case CharacterState.listening:
        return AppColors.accentSecondary;
      case CharacterState.thinking:
        return AppColors.accentPrimary;
      case CharacterState.speaking:
        return AppColors.success;
    }
  }

  String get _stateText {
    switch (widget.state) {
      case CharacterState.idle:
        return 'Ready';
      case CharacterState.listening:
        return 'Listening…';
      case CharacterState.thinking:
        return 'Thinking…';
      case CharacterState.speaking:
        return 'Speaking…';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If WebGL or the local asset is unavailable, keep the conversation
    // usable without presenting the old low-fidelity cartoon as production
    // output. The layered painter remains opt-in through AvatarStage for
    // tests/debugging.
    if (_mode == _AvatarMode.fallback) {
      return Container(
        width: widget.size + AppSpacing.lg * 2,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.accentColor.withValues(alpha: 0.2),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(color: widget.accentColor.withValues(alpha: 0.32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: widget.size * 0.42,
              color: widget.accentColor.withValues(alpha: 0.82),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.tutorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '3D unavailable · ${_stateText.replaceAll('…', '')}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
    }

    // 3D view + optional label pill. The platform view fills the circle and
    // the label is drawn by Flutter so it stays crisp and theme-aware.
    final size = widget.size;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            // Keep the loading surface visually consistent with Avatar V2;
            // the legacy painter is never shown in the 3D production path.
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_mode == _AvatarMode.loading)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.accentColor.withValues(alpha: 0.26),
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accentColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ClipOval(
                  child: _host.buildView(
                    context,
                    size: size,
                    showLabel: false,
                    tutorName: widget.tutorName,
                  ),
                ),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.tutorName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildStatePill(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatePill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: _stateColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: _stateColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stateColor,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _stateText,
            style: TextStyle(
              color: _stateColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
