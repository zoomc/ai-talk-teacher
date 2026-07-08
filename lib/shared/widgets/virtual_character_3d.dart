import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'virtual_character.dart';
import 'virtual_character_3d_platform.dart'
    if (dart.library.js_interop) 'virtual_character_3d_web.dart'
    if (dart.library.io) 'virtual_character_3d_mobile.dart'
    as platform;

/// 3D virtual character widget.
///
/// Renders a real, WebGL-based humanoid avatar (Ready Player Me female GLB
/// with ARKit + Oculus viseme morph targets) driven by Three.js, embedded
/// via [HtmlElementView] on web and `webview_flutter` on mobile/desktop —
/// see [platform.AvatarHost] for the per-platform plumbing.
///
/// Behaviour mirrors [VirtualCharacter] (the painter fallback): 20 visemes
/// stepped per character at ~90 ms while speaking, 20 gestures matched by
/// keyword, state-driven defaults for idle/listening/thinking. On top of
/// that, an optional [audioLevelStream] forwards TTS amplitude to the avatar
/// so the mouth tracks real audio (the JS side blends amplitude onto
/// `jawOpen`).
///
/// If the 3D pipeline can't initialise within a short grace period (no
/// WebGL, CDN unreachable, GLB load failure), the widget transparently
/// falls back to [VirtualCharacter] so the app is always usable.
class VirtualCharacter3D extends StatefulWidget {
  final String tutorName;
  // Kept for API parity with [VirtualCharacter]; unused by the 3D render.
  final String tutorAvatar;
  final CharacterState state;
  final Color accentColor;

  /// Diameter of the character circle in pixels.
  final double size;

  /// Whether to render the name + state pill below the avatar.
  final bool showLabel;

  /// Optional text the avatar is currently "speaking" — drives per-character
  /// viseme stepping and keyword gesture matching.
  final String? speakingText;

  /// Optional TTS amplitude stream (0..1). When provided, the avatar's jaw
  /// openness is blended with the live audio level for natural lip-sync.
  final Stream<double>? audioLevelStream;

  /// Optional Ready Player Me GLB URL override (per-tutor avatar). When null
  /// a default female avatar is used (see avatar.html).
  final String? avatarUrl;

  const VirtualCharacter3D({
    super.key,
    required this.tutorName,
    required this.tutorAvatar,
    this.state = CharacterState.idle,
    this.accentColor = AppColors.accentPrimary,
    this.size = 120,
    this.showLabel = true,
    this.speakingText,
    this.audioLevelStream,
    this.avatarUrl,
  });

  @override
  State<VirtualCharacter3D> createState() => _VirtualCharacter3DState();
}

enum _AvatarMode { loading, ready3d, fallback }

class _VirtualCharacter3DState extends State<VirtualCharacter3D> {
  late final platform.AvatarHost _host;
  _AvatarMode _mode = _AvatarMode.loading;

  // Viseme stepper (text-driven lip-sync), mirroring VirtualCharacter.
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
      _host.init(
        avatarUrl: widget.avatarUrl,
        onError: _onHostError,
      );
      if (!_host.isSupported) {
        _mode = _AvatarMode.fallback;
      } else {
        _startPolling();
      }
    } catch (_) {
      _mode = _AvatarMode.fallback;
    }
    _applyState();
    _attachAudio();
  }

  @override
  void didUpdateWidget(covariant VirtualCharacter3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stateChanged = oldWidget.state != widget.state;
    final textChanged = oldWidget.speakingText != widget.speakingText;
    if (stateChanged || textChanged) {
      _applyState();
    }
    if (oldWidget.audioLevelStream != widget.audioLevelStream) {
      _attachAudio();
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
    switch (s) {
      case CharacterState.idle:
        _host.setGesture('idle');
        _host.setViseme('closed');
        _stopViseme();
        break;
      case CharacterState.listening:
        _host.setGesture('nod');
        _host.setViseme('slightOpen');
        _stopViseme();
        break;
      case CharacterState.thinking:
        _host.setGesture('thinkPose');
        _host.setViseme('biteLip');
        _stopViseme();
        break;
      case CharacterState.speaking:
        _host.setGesture(VirtualCharacter.gestureForKeyword(text).name);
        if (text.isEmpty) {
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
    // Fallback (no WebGL / load failure / unsupported): painter avatar.
    if (_mode == _AvatarMode.fallback) {
      return VirtualCharacter(
        tutorName: widget.tutorName,
        tutorAvatar: widget.tutorAvatar,
        state: widget.state,
        accentColor: widget.accentColor,
        size: widget.size,
        showLabel: widget.showLabel,
        speakingText: widget.speakingText,
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
            // While loading, layer the painter behind the (still-loading)
            // 3D view so the user sees a live avatar immediately and the 3D
            // takes over once ready.
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_mode == _AvatarMode.loading)
                  VirtualCharacter(
                    tutorName: widget.tutorName,
                    tutorAvatar: widget.tutorAvatar,
                    state: widget.state,
                    accentColor: widget.accentColor,
                    size: size,
                    showLabel: false,
                    speakingText: widget.speakingText,
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
