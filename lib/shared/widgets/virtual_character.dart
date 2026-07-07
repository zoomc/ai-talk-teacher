import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// AI Virtual Character Widget.
///
/// Renders a real, painter-drawn human-like avatar (no emoji) with:
///   - 20 mouth shapes (visemes) — see [Viseme]
///   - 10 body gestures / poses — see [Gesture]
///   - text-driven viseme + gesture matching when [speakingText] is set
///   - state-driven default behaviour for [idle] / [listening] / [thinking]
///     / [speaking]
///
/// Public API is backward compatible with the previous emoji-based widget:
/// callers may still pass [tutorAvatar] (ignored) and [tutorName] (used as
/// the rendered label and as a fallback initial). New optional fields
/// [speakingText] drive lip-sync.
class VirtualCharacter extends StatefulWidget {
  final String tutorName;
  // Kept for API compatibility — no longer rendered as an emoji.
  final String tutorAvatar;
  final CharacterState state;
  final Color accentColor;

  /// Diameter of the character circle in pixels.
  final double size;

  /// Whether to render the name + state pill below the avatar.
  final bool showLabel;

  /// Optional text the avatar is currently "speaking". When non-empty and
  /// [state] is [CharacterState.speaking], visemes are picked per character
  /// at ~90ms cadence and the gesture is matched against keyword rules.
  final String? speakingText;

  const VirtualCharacter({
    super.key,
    required this.tutorName,
    required this.tutorAvatar,
    this.state = CharacterState.idle,
    this.accentColor = AppColors.accentPrimary,
    this.size = 120,
    this.showLabel = true,
    this.speakingText,
  });

  @override
  State<VirtualCharacter> createState() => _VirtualCharacterState();
}

class _VirtualCharacterState extends State<VirtualCharacter>
    with TickerProviderStateMixin {
  // Continuous animations.
  late final AnimationController _breathController;
  late final AnimationController _glowController;
  // Gesture one-shot / loop.
  late final AnimationController _gestureController;
  // Viseme stepper while speaking.
  late final AnimationController _visemeController;

  late Animation<double> _breathAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _gestureAnim;

  // Current painted viseme / gesture.
  Viseme _viseme = Viseme.closed;
  Gesture _gesture = Gesture.idle;
  int _visemeCharIndex = 0;

  // Last text we scheduled, to avoid restarting the stepper every frame.
  String? _lastScheduledText;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _breathAnim = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    _breathController.repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnim = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    // glow is started on demand in _applyState — idle stays dim to save
    // frames (breath below still runs to keep the character feeling alive).

    _gestureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _gestureAnim = CurvedAnimation(
      parent: _gestureController,
      curve: Curves.easeInOut,
    );

    _visemeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    // Drive viseme advances off the completed status tick (once per 90ms
    // cycle) instead of addListener, which fires every animation frame and
    // would otherwise cycle visemes far too fast + repaint each frame.
    _visemeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _advanceViseme();
    });

    _applyState(widget.state, widget.speakingText);
  }

  @override
  void didUpdateWidget(covariant VirtualCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stateChanged = oldWidget.state != widget.state;
    final textChanged = oldWidget.speakingText != widget.speakingText;
    if (stateChanged || textChanged) {
      _applyState(widget.state, widget.speakingText);
    }
  }

  void _applyState(CharacterState state, String? text) {
    // glow only runs when the character is active — idle stays dim so we
    // don't repaint a decorative pulse every frame while idle/off-screen.
    if (state == CharacterState.idle) {
      _glowController.stop();
    } else if (!_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    }
    switch (state) {
      case CharacterState.idle:
        _visemeController.stop();
        _viseme = Viseme.closed;
        _setGesture(Gesture.idle, loop: false);
        _lastScheduledText = null;
        break;
      case CharacterState.listening:
        _visemeController.stop();
        _viseme = Viseme.slightOpen;
        _setGesture(Gesture.nod, loop: true);
        _lastScheduledText = null;
        break;
      case CharacterState.thinking:
        _visemeController.stop();
        _viseme = Viseme.biteLip;
        _setGesture(Gesture.thinkPose, loop: true);
        _lastScheduledText = null;
        break;
      case CharacterState.speaking:
        // Pick a gesture from text keywords once; stepper drives visemes.
        final t = text ?? '';
        _setGesture(_gestureForKeyword(t), loop: true);
        if (t.isEmpty) {
          // No text — gentle open/close pattern.
          _viseme = Viseme.mediumOpen;
          _visemeController.stop();
          _lastScheduledText = null;
        } else if (t != _lastScheduledText) {
          _lastScheduledText = t;
          _visemeCharIndex = 0;
          _viseme = _visemeForChar(t, 0);
          _visemeController.repeat();
        }
        break;
    }
  }

  void _advanceViseme() {
    if (widget.state != CharacterState.speaking) return;
    final t = widget.speakingText ?? '';
    if (t.isEmpty) return;
    _visemeCharIndex = (_visemeCharIndex + 1) % t.length;
    if (mounted) {
      setState(() {
        _viseme = _visemeForChar(t, _visemeCharIndex);
      });
    }
  }

  void _setGesture(Gesture g, {required bool loop}) {
    if (_gesture == g && _gestureController.isAnimating) return;
    _gesture = g;
    _gestureController.stop();
    if (g == Gesture.idle) {
      _gestureController.value = 0;
      return;
    }
    _gestureController.duration = Duration(
      milliseconds: g == Gesture.bounce
          ? 1100
          : g == Gesture.shake
              ? 700
              : g == Gesture.nod
                  ? 1400
                  : 1000,
    );
    if (loop) {
      _gestureController.repeat(reverse: true);
    } else {
      _gestureController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _visemeController.removeListener(_advanceViseme);
    _breathController.dispose();
    _glowController.dispose();
    _gestureController.dispose();
    _visemeController.dispose();
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
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathController,
        _glowController,
        _gestureController,
        _visemeController,
      ]),
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(),
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
      },
    );
  }

  Widget _buildAvatar() {
    final size = widget.size;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _stateColor.withValues(alpha: 0.08),
        boxShadow: [
          BoxShadow(
            color: _stateColor.withValues(alpha: _glowAnim.value),
            blurRadius: 28,
            spreadRadius: widget.state == CharacterState.listening ? 8 : 0,
          ),
        ],
      ),
      child: Transform.scale(
        scale: _breathAnim.value,
        child: CustomPaint(
          size: Size.square(size),
          painter: _CharacterPainter(
            viseme: _viseme,
            gesture: _gesture,
            gestureProgress: _gestureAnim.value,
            breath: _breathAnim.value,
            state: widget.state,
            accent: widget.accentColor,
            initial: _initialOf(widget.tutorName),
          ),
        ),
      ),
    );
  }

  Widget _buildStatePill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stateColor,
              boxShadow: widget.state != CharacterState.idle
                  ? [
                      BoxShadow(
                        color: _stateColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
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

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String _initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed[0].toUpperCase();
  }

  /// Map a single character (at index [i] in [text]) to a [Viseme].
  Viseme _visemeForChar(String text, int i) {
    if (i >= text.length) return Viseme.closed;
    final ch = text[i].toLowerCase();
    // Skip whitespace keeps the previous shape briefly; pick a neutral.
    if (ch == ' ' || ch == '\t' || ch == '\n') return Viseme.slightOpen;
    // Punctuation → close.
    if ('.,;:!?。，；：！？'.contains(ch)) return Viseme.closed;
    // Vowels.
    switch (ch) {
      case 'a':
      case 'A':
      case '啊':
      case '阿':
      case '呀':
        return Viseme.roundedLarge;
      case 'e':
      case 'E':
      case '额':
      case '诶':
        return Viseme.wide;
      case 'i':
      case 'I':
      case '衣':
      case '意':
        return Viseme.wide;
      case 'o':
      case 'O':
      case '哦':
      case '噢':
        return Viseme.roundedSmall;
      case 'u':
      case 'U':
      case '呜':
      case '乌':
        return Viseme.pucker;
      // Common consonants cluster.
      case 'm':
      case 'b':
      case 'p':
        return Viseme.closed;
      case 'f':
      case 'v':
        return Viseme.biteLip;
      case 'l':
      case 'n':
      case 't':
      case 'd':
        return Viseme.tongueUp;
      case 's':
      case 'z':
      case 'c':
        return Viseme.teeth;
      case 'r':
        return Viseme.tongueUp;
      case 'th':
        return Viseme.tongueOut;
    }
    // CJK fallbacks — most Han characters are open-mouthed.
    if (ch.codeUnitAt(0) > 0x2E80) {
      // Rough CJK range; alternate between medium / oval / open.
      final m = i % 3;
      return m == 0
          ? Viseme.mediumOpen
          : m == 1
              ? Viseme.oval
              : Viseme.smallOpen;
    }
    return Viseme.smallOpen;
  }

  /// Map text content to a body gesture using keyword rules (CN + EN).
  Gesture _gestureForKeyword(String text) {
    final t = text.toLowerCase();
    bool has(List<String> kws) => kws.any((k) => t.contains(k));
    if (has(['你好', 'hello', 'hi', 'welcome', '欢迎', '嗨'])) {
      return Gesture.wave;
    }
    if (has(['对', 'yes', 'right', 'correct', '没错', '是的'])) {
      return Gesture.nod;
    }
    if (has(['嗯', 'hmm', 'let me think', '我想想', '想想', 'maybe', '也许'])) {
      return Gesture.thinkPose;
    }
    if (has(['看', 'look', 'see', 'point', '那边', '这里'])) {
      return Gesture.pointUp;
    }
    if (has(['谢谢', 'thank', '感谢', 'appreciate'])) {
      return Gesture.openPalm;
    }
    if (has(['不', 'no', 'nope', '不是', '不行', "don't"])) {
      return Gesture.shake;
    }
    if (has(['great', 'awesome', '太棒', '棒', 'excellent', 'wow'])) {
      return Gesture.raiseHand;
    }
    return Gesture.bounce;
  }
}

// ── Viseme catalogue (20) ──────────────────────────────────────────────────
//
// Each value is a distinct mouth shape the painter knows how to draw.
enum Viseme {
  closed, // 闭合 (rest / breathing)
  slightOpen, // 微开
  smallOpen, // 小开
  mediumOpen, // 中开
  wideOpen, // 大开
  roundedSmall, // 圆小 (like "o")
  roundedLarge, // 圆大 (like "a")
  wide, // 宽 (like "i"/"e")
  flat, // 扁平
  smile, // 微笑
  smileOpen, // 笑而露齿
  frown, // 撇嘴
  pucker, // 噘嘴
  teeth, // 露齿 (s/z)
  tongueUp, // 舌抵上颚 (l/n/t/d)
  tongueOut, // 伸舌 (th)
  biteLip, // 咬唇 (f/v)
  openTeeth, // 张口露齿
  oval, // 椭圆
  wideFlat, // 宽扁
}

// ── Gesture catalogue (10) ─────────────────────────────────────────────────
enum Gesture {
  idle, // 默认（双手下垂或交叠）
  wave, // 挥手
  nod, // 点头
  tiltHead, // 歪头
  raiseHand, // 举手
  pointUp, // 指向上方
  thinkPose, // 手托下巴思考
  openPalm, // 张开手掌（欢迎）
  shake, // 摇头
  bounce, // 小幅上下浮动
}

// ── Painter ────────────────────────────────────────────────────────────────
class _CharacterPainter extends CustomPainter {
  final Viseme viseme;
  final Gesture gesture;
  final double gestureProgress; // 0..1
  final double breath; // ~0.985..1.015
  final CharacterState state;
  final Color accent;
  final String initial;

  _CharacterPainter({
    required this.viseme,
    required this.gesture,
    required this.gestureProgress,
    required this.breath,
    required this.state,
    required this.accent,
    required this.initial,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // ── Background disk: radial gradient with accent glow ──
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          accent.withValues(alpha: 0.28),
          accent.withValues(alpha: 0.08),
          const Color(0x06000000),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // Subtle ring border (iOS26 flat).
    final ringPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012;
    canvas.drawCircle(Offset(cx, cy), r * 0.98, ringPaint);

    // ── Compute gesture-driven offsets ──
    // progress 0..0.5..1 with sine for smooth ping-pong.
    final p = gestureProgress;
    final swing = math.sin(p * math.pi); // 0..1..0
    double headDx = 0, headDy = 0, bodyDy = 0, tiltRad = 0;
    double leftHandDy = 0, rightHandDy = 0;
    double leftHandDx = 0, rightHandDx = 0;
    switch (gesture) {
      case Gesture.idle:
        bodyDy = (breath - 1) * size.width * 0.5; // tiny breathing
        break;
      case Gesture.wave:
        rightHandDx = swing * size.width * 0.10;
        rightHandDy = -swing * size.width * 0.18;
        tiltRad = swing * 0.05;
        break;
      case Gesture.nod:
        headDy = swing * size.width * 0.025;
        break;
      case Gesture.tiltHead:
        tiltRad = (swing - 0.5) * 0.18;
        break;
      case Gesture.raiseHand:
        rightHandDy = -swing * size.width * 0.30;
        rightHandDx = swing * size.width * 0.05;
        break;
      case Gesture.pointUp:
        rightHandDy = -size.width * 0.22 - swing * size.width * 0.05;
        rightHandDx = size.width * 0.06;
        break;
      case Gesture.thinkPose:
        rightHandDx = -size.width * 0.08;
        rightHandDy = -size.width * 0.06;
        tiltRad = 0.08;
        break;
      case Gesture.openPalm:
        leftHandDy = swing * size.width * 0.04;
        rightHandDy = swing * size.width * 0.04;
        leftHandDx = -size.width * 0.05 - swing * size.width * 0.03;
        rightHandDx = size.width * 0.05 + swing * size.width * 0.03;
        break;
      case Gesture.shake:
        headDx = (swing - 0.5) * size.width * 0.08;
        break;
      case Gesture.bounce:
        bodyDy = -swing * size.width * 0.04;
        headDy = -swing * size.width * 0.02;
        break;
    }

    // ── Shoulders / torso (simplified) ──
    final torsoTop = cy + r * 0.45;
    final shoulderPaint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final torsoPath = Path()
      ..moveTo(cx - r * 0.55, torsoTop + bodyDy)
      ..quadraticBezierTo(
        cx - r * 0.40,
        torsoTop - r * 0.05 + bodyDy,
        cx - r * 0.18,
        torsoTop - r * 0.02 + bodyDy,
      )
      ..lineTo(cx + r * 0.18, torsoTop - r * 0.02 + bodyDy)
      ..quadraticBezierTo(
        cx + r * 0.40,
        torsoTop - r * 0.05 + bodyDy,
        cx + r * 0.55,
        torsoTop + bodyDy,
      )
      ..lineTo(cx + r * 0.55, cy + r + bodyDy)
      ..lineTo(cx - r * 0.55, cy + r + bodyDy)
      ..close();
    canvas.drawPath(torsoPath, shoulderPaint);

    // ── Arms (drawn before head so they sit behind) ──
    final armPaint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    // Left arm baseline down.
    canvas.drawLine(
      Offset(cx - r * 0.45, torsoTop + bodyDy),
      Offset(cx - r * 0.55 + leftHandDx, torsoTop + r * 0.55 + bodyDy + leftHandDy),
      armPaint,
    );
    // Right arm — modified by gesture.
    canvas.drawLine(
      Offset(cx + r * 0.45, torsoTop + bodyDy),
      Offset(cx + r * 0.55 + rightHandDx, torsoTop + r * 0.55 + bodyDy + rightHandDy),
      armPaint,
    );

    // ── Head ──
    final headCenter = Offset(
      cx + headDx,
      cy + headDy - size.width * 0.02,
    );
    final headR = r * 0.52;

    // Save layer for head rotation (tilt).
    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(tiltRad);
    canvas.translate(-headCenter.dx, -headCenter.dy);

    // Neck (small connector).
    final neckPaint = Paint()
      ..color = const Color(0xFFE8B58E); // skin shadow
    final neckPath = Path()
      ..moveTo(headCenter.dx - headR * 0.18, headCenter.dy + headR * 0.85)
      ..lineTo(headCenter.dx + headR * 0.18, headCenter.dy + headR * 0.85)
      ..lineTo(headCenter.dx + headR * 0.20, headCenter.dy + headR * 1.05)
      ..lineTo(headCenter.dx - headR * 0.20, headCenter.dy + headR * 1.05)
      ..close();
    canvas.drawPath(neckPath, neckPaint);

    // Face base (skin).
    final skinPaint = Paint()
      ..color = const Color(0xFFF5C8A4)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: headR * 1.7, height: headR * 1.9),
      skinPaint,
    );

    // Hair (top cap).
    final hairPaint = Paint()
      ..color = const Color(0xFF3D2C5F)
      ..style = PaintingStyle.fill;
    final hairPath = Path()
      ..moveTo(headCenter.dx - headR * 0.92, headCenter.dy - headR * 0.15)
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.85,
        headCenter.dy - headR * 1.15,
        headCenter.dx,
        headCenter.dy - headR * 1.05,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.85,
        headCenter.dy - headR * 1.15,
        headCenter.dx + headR * 0.92,
        headCenter.dy - headR * 0.15,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.55,
        headCenter.dy - headR * 0.55,
        headCenter.dx,
        headCenter.dy - headR * 0.40,
      )
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.55,
        headCenter.dy - headR * 0.55,
        headCenter.dx - headR * 0.92,
        headCenter.dy - headR * 0.15,
      )
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // ── Eyes ──
    final eyeY = headCenter.dy - headR * 0.05;
    final eyeDx = headR * 0.32;
    // State-based eye treatment.
    final isThinking = state == CharacterState.thinking;
    final isListening = state == CharacterState.listening;
    _drawEye(
      canvas,
      Offset(headCenter.dx - eyeDx, eyeY),
      headR * 0.10,
      isThinking,
      isListening,
    );
    _drawEye(
      canvas,
      Offset(headCenter.dx + eyeDx, eyeY),
      headR * 0.10,
      isThinking,
      isListening,
    );

    // ── Eyebrows ──
    final browY = headCenter.dy - headR * 0.22;
    final browPaint = Paint()
      ..color = const Color(0xFF3D2C5F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round;
    // Left brow.
    final leftBrow = Path()
      ..moveTo(headCenter.dx - eyeDx - headR * 0.14, browY + (isThinking ? headR * 0.04 : 0))
      ..quadraticBezierTo(
        headCenter.dx - eyeDx,
        browY - headR * 0.06 - (isThinking ? headR * 0.04 : 0),
        headCenter.dx - eyeDx + headR * 0.14,
        browY,
      );
    canvas.drawPath(leftBrow, browPaint);
    // Right brow.
    final rightBrow = Path()
      ..moveTo(headCenter.dx + eyeDx - headR * 0.14, browY)
      ..quadraticBezierTo(
        headCenter.dx + eyeDx,
        browY - headR * 0.06 - (isThinking ? headR * 0.04 : 0),
        headCenter.dx + eyeDx + headR * 0.14,
        browY + (isThinking ? headR * 0.04 : 0),
      );
    canvas.drawPath(rightBrow, browPaint);

    // ── Nose (subtle) ──
    final nosePaint = Paint()
      ..color = const Color(0xFFE0AC8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.010
      ..strokeCap = StrokeCap.round;
    final nosePath = Path()
      ..moveTo(headCenter.dx, headCenter.dy + headR * 0.02)
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.05,
        headCenter.dy + headR * 0.18,
        headCenter.dx,
        headCenter.dy + headR * 0.22,
      );
    canvas.drawPath(nosePath, nosePaint);

    // ── Mouth (viseme-driven) ──
    _drawMouth(
      canvas,
      Offset(headCenter.dx, headCenter.dy + headR * 0.45),
      headR * 0.35,
    );

    // ── Cheek blush (subtle warmth) ──
    final blushPaint = Paint()
      ..color = const Color(0xFFFF9E8A).withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - headR * 0.55, headCenter.dy + headR * 0.30),
        width: headR * 0.30,
        height: headR * 0.18,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx + headR * 0.55, headCenter.dy + headR * 0.30),
        width: headR * 0.30,
        height: headR * 0.18,
      ),
      blushPaint,
    );

    canvas.restore();

    // ── Hand dots (drawn last, on top) ──
    final handPaint = Paint()
      ..color = const Color(0xFFF5C8A4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(cx - r * 0.55 + leftHandDx, torsoTop + r * 0.55 + bodyDy + leftHandDy),
      size.width * 0.05,
      handPaint,
    );
    canvas.drawCircle(
      Offset(cx + r * 0.55 + rightHandDx, torsoTop + r * 0.55 + bodyDy + rightHandDy),
      size.width * 0.05,
      handPaint,
    );
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    double radius,
    bool thinking,
    bool listening,
  ) {
    if (thinking) {
      // Closed eye — curved arc.
      final paint = Paint()
        ..color = const Color(0xFF2A1F45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi,
        false,
        paint,
      );
      return;
    }
    final paint = Paint()
      ..color = const Color(0xFF2A1F45)
      ..style = PaintingStyle.fill;
    if (listening) {
      // Slightly wider eye (attention).
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radius * 2.4, height: radius * 2.0),
        paint,
      );
    } else {
      canvas.drawCircle(center, radius, paint);
    }
    // Specular highlight.
    final hl = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.35, center.dy - radius * 0.35),
      radius * 0.30,
      hl,
    );
  }

  /// Draw the mouth at [center] with reference half-width [w].
  void _drawMouth(Canvas canvas, Offset center, double w) {
    final lipPaint = Paint()
      ..color = const Color(0xFFB5534A)
      ..style = PaintingStyle.fill;
    final teethPaint = Paint()
      ..color = const Color(0xFFFFFFFF);
    final tonguePaint = Paint()
      ..color = const Color(0xFFD87878);
    final h = w * 0.55; // mouth height baseline

    Path makeOval(double hw, double hh) {
      return Path()
        ..addOval(Rect.fromCenter(center: center, width: hw * 2, height: hh * 2));
    }

    Path makeArc(double hw, double hh, bool upper) {
      final rect = Rect.fromCenter(center: center, width: hw * 2, height: hh * 2);
      return Path()..addArc(rect, upper ? math.pi : 0, math.pi);
    }

    switch (viseme) {
      case Viseme.closed:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.6, center.dy)
            ..quadraticBezierTo(
              center.dx,
              center.dy + w * 0.15,
              center.dx + w * 0.6,
              center.dy,
            ),
          lipPaint..style = PaintingStyle.stroke..strokeWidth = w * 0.18,
        );
        lipPaint.style = PaintingStyle.fill;
        break;
      case Viseme.slightOpen:
        canvas.drawPath(makeOval(w * 0.45, h * 0.18), lipPaint);
        break;
      case Viseme.smallOpen:
        canvas.drawPath(makeOval(w * 0.55, h * 0.32), lipPaint);
        break;
      case Viseme.mediumOpen:
        canvas.drawPath(makeOval(w * 0.65, h * 0.45), lipPaint);
        break;
      case Viseme.wideOpen:
        canvas.drawPath(makeOval(w * 0.75, h * 0.70), lipPaint);
        break;
      case Viseme.roundedSmall:
        canvas.drawPath(makeOval(w * 0.40, h * 0.50), lipPaint);
        break;
      case Viseme.roundedLarge:
        canvas.drawPath(makeOval(w * 0.60, h * 0.85), lipPaint);
        // Hint of tongue.
        canvas.drawPath(makeOval(w * 0.30, h * 0.30), tonguePaint);
        break;
      case Viseme.wide:
        canvas.drawPath(makeOval(w * 0.85, h * 0.25), lipPaint);
        break;
      case Viseme.flat:
        canvas.drawPath(makeOval(w * 0.70, h * 0.12), lipPaint);
        break;
      case Viseme.smile:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.7, center.dy + w * 0.05)
            ..quadraticBezierTo(
              center.dx,
              center.dy - w * 0.20,
              center.dx + w * 0.7,
              center.dy + w * 0.05,
            ),
          lipPaint..style = PaintingStyle.stroke..strokeWidth = w * 0.16,
        );
        lipPaint.style = PaintingStyle.fill;
        break;
      case Viseme.smileOpen:
        // Smile arc + teeth strip.
        final outer = Path()
          ..moveTo(center.dx - w * 0.75, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy - w * 0.30,
            center.dx + w * 0.75,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx,
            center.dy + w * 0.25,
            center.dx - w * 0.75,
            center.dy,
          )
          ..close();
        canvas.drawPath(outer, lipPaint);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.65, center.dy + w * 0.02)
            ..lineTo(center.dx + w * 0.65, center.dy + w * 0.02)
            ..lineTo(center.dx + w * 0.55, center.dy + w * 0.10)
            ..lineTo(center.dx - w * 0.55, center.dy + w * 0.10)
            ..close(),
          teethPaint,
        );
        break;
      case Viseme.frown:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.7, center.dy - w * 0.05)
            ..quadraticBezierTo(
              center.dx,
              center.dy + w * 0.20,
              center.dx + w * 0.7,
              center.dy - w * 0.05,
            ),
          lipPaint..style = PaintingStyle.stroke..strokeWidth = w * 0.16,
        );
        lipPaint.style = PaintingStyle.fill;
        break;
      case Viseme.pucker:
        canvas.drawPath(makeOval(w * 0.30, h * 0.45), lipPaint);
        break;
      case Viseme.teeth:
        // Small opening with visible upper teeth.
        canvas.drawPath(makeOval(w * 0.60, h * 0.30), lipPaint);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.50, center.dy - h * 0.10)
            ..lineTo(center.dx + w * 0.50, center.dy - h * 0.10)
            ..lineTo(center.dx + w * 0.50, center.dy - h * 0.02)
            ..lineTo(center.dx - w * 0.50, center.dy - h * 0.02)
            ..close(),
          teethPaint,
        );
        break;
      case Viseme.tongueUp:
        canvas.drawPath(makeOval(w * 0.55, h * 0.35), lipPaint);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.30, center.dy - h * 0.12)
            ..quadraticBezierTo(
              center.dx,
              center.dy - h * 0.30,
              center.dx + w * 0.30,
              center.dy - h * 0.12,
            )
            ..lineTo(center.dx + w * 0.30, center.dy - h * 0.05)
            ..lineTo(center.dx - w * 0.30, center.dy - h * 0.05)
            ..close(),
          tonguePaint,
        );
        break;
      case Viseme.tongueOut:
        canvas.drawPath(makeOval(w * 0.55, h * 0.40), lipPaint);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.20, center.dy)
            ..quadraticBezierTo(
              center.dx,
              center.dy + h * 0.30,
              center.dx + w * 0.20,
              center.dy,
            )
            ..lineTo(center.dx + w * 0.18, center.dy - h * 0.10)
            ..lineTo(center.dx - w * 0.18, center.dy - h * 0.10)
            ..close(),
          tonguePaint,
        );
        break;
      case Viseme.biteLip:
        // Upper lip thin, lower lip bitten — render as small horizontal bar
        // with a darker overlay.
        canvas.drawPath(makeOval(w * 0.55, h * 0.18), lipPaint);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.40, center.dy + h * 0.02)
            ..lineTo(center.dx + w * 0.40, center.dy + h * 0.02)
            ..lineTo(center.dx + w * 0.40, center.dy + h * 0.10)
            ..lineTo(center.dx - w * 0.40, center.dy + h * 0.10)
            ..close(),
          Paint()..color = const Color(0xFF7A3330),
        );
        break;
      case Viseme.openTeeth:
        canvas.drawPath(makeOval(w * 0.70, h * 0.55), lipPaint);
        // Upper + lower teeth strips.
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.55, center.dy - h * 0.18)
            ..lineTo(center.dx + w * 0.55, center.dy - h * 0.18)
            ..lineTo(center.dx + w * 0.50, center.dy - h * 0.08)
            ..lineTo(center.dx - w * 0.50, center.dy - h * 0.08)
            ..close(),
          teethPaint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - w * 0.50, center.dy + h * 0.08)
            ..lineTo(center.dx + w * 0.50, center.dy + h * 0.08)
            ..lineTo(center.dx + w * 0.55, center.dy + h * 0.18)
            ..lineTo(center.dx - w * 0.55, center.dy + h * 0.18)
            ..close(),
          teethPaint,
        );
        break;
      case Viseme.oval:
        canvas.drawPath(makeOval(w * 0.50, h * 0.60), lipPaint);
        break;
      case Viseme.wideFlat:
        canvas.drawPath(makeOval(w * 0.80, h * 0.20), lipPaint);
        break;
    }
    // Reset paint style for safety (paints are reused across frames).
    lipPaint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter old) {
    return old.viseme != viseme ||
        old.gesture != gesture ||
        old.gestureProgress != gestureProgress ||
        old.breath != breath ||
        old.state != state ||
        old.accent != accent ||
        old.initial != initial;
  }
}

enum CharacterState { idle, listening, thinking, speaking }
