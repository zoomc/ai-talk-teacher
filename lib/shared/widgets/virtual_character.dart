import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/app_localizations.dart';

/// AI Virtual Character Widget.
///
/// Renders a real, painter-drawn human-like avatar (no emoji) with:
///   - 20 mouth shapes (visemes) — see [Viseme]
///   - 20 body gestures / poses — see [Gesture]
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

  /// Public + static so the 3D avatar widget can reuse the exact same
  /// text→viseme mapping without duplicating the catalogue.
  static Viseme visemeForChar(String text, int i) =>
      _VirtualCharacterState.visemeForChar(text, i);

  /// Public + static for the same reason as [visemeForChar] — shared
  /// between the painter fallback and the 3D avatar.
  static Gesture gestureForKeyword(String text) =>
      _VirtualCharacterState.gestureForKeyword(text);
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
        // Gentle natural smile at rest.
        _viseme = Viseme.smile;
        _setGesture(Gesture.idle, loop: false);
        _lastScheduledText = null;
        break;
      case CharacterState.listening:
        _visemeController.stop();
        // Attentive: slightly open mouth + head tilted toward the speaker.
        _viseme = Viseme.slightOpen;
        _setGesture(Gesture.tiltLeft, loop: true);
        _lastScheduledText = null;
        break;
      case CharacterState.thinking:
        _visemeController.stop();
        // Biting lip + hand-on-chin thinking pose, looping.
        _viseme = Viseme.biteLip;
        _setGesture(Gesture.thinkPose, loop: true);
        _lastScheduledText = null;
        break;
      case CharacterState.speaking:
        // Pick a gesture from text keywords once; stepper drives visemes.
        final t = text ?? '';
        _setGesture(gestureForKeyword(t), loop: true);
        if (t.isEmpty) {
          // No text — gentle smile-open pattern (teeth visible, friendly).
          _viseme = Viseme.smileOpen;
          _visemeController.stop();
          _lastScheduledText = null;
        } else if (t != _lastScheduledText) {
          _lastScheduledText = t;
          _visemeCharIndex = 0;
          _viseme = visemeForChar(t, 0);
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
        _viseme = visemeForChar(t, _visemeCharIndex);
      });
    }
  }

  void _setGesture(Gesture g, {required bool loop}) {
    if (_gesture == g && _gestureController.isAnimating) return;
    _gesture = g;
    _gestureController.stop();
    if (g == Gesture.idle) {
      // idle is rendered as a static, value=0 pose — no animation needed.
      _gestureController.value = 0;
      return;
    }
    // Per-gesture duration table (ms). Bigger / heavier motions get longer
    // cycles; quick ticks (shake, clap, peaceSign) stay snappy.
    final int ms;
    switch (g) {
      case Gesture.bounce:
        ms = 1100;
        break;
      case Gesture.shake:
        ms = 700;
        break;
      case Gesture.nod:
        ms = 1400;
        break;
      case Gesture.deepNod:
        ms = 1500;
        break;
      case Gesture.clap:
        ms = 900;
        break;
      case Gesture.shrug:
        ms = 1200;
        break;
      case Gesture.lookUp:
        ms = 1600;
        break;
      case Gesture.lookDown:
        ms = 1600;
        break;
      case Gesture.tiltLeft:
        ms = 2000;
        break;
      case Gesture.tiltRight:
        ms = 2000;
        break;
      case Gesture.handOnHip:
        ms = 1300;
        break;
      case Gesture.crossArms:
        ms = 1300;
        break;
      case Gesture.peaceSign:
        ms = 1000;
        break;
      // ── Extended gesture durations ──
      case Gesture.thumbsUp:
        ms = 1000;
        break;
      case Gesture.bow:
        ms = 1500;
        break;
      case Gesture.adjustHair:
        ms = 1200;
        break;
      case Gesture.lookAround:
        ms = 1800;
        break;
      case Gesture.stretch:
        ms = 2000;
        break;
      case Gesture.yawn:
        ms = 2500;
        break;
      case Gesture.wink:
        ms = 800;
        break;
      // wave, tiltHead, raiseHand, pointUp, thinkPose, openPalm — default.
      case Gesture.wave:
      case Gesture.tiltHead:
      case Gesture.raiseHand:
      case Gesture.pointUp:
      case Gesture.thinkPose:
      case Gesture.openPalm:
      case Gesture.idle: // unreachable (handled above) — kept for exhaustiveness.
        ms = 1000;
        break;
    }
    _gestureController.duration = Duration(milliseconds: ms);
    if (loop) {
      _gestureController.repeat(reverse: true);
    } else {
      _gestureController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    // The viseme advance is wired through an anonymous status-listener
    // closure (see initState), so there's no named listener to remove
    // here — `_visemeController.dispose()` below cleans up all attached
    // listeners automatically.
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
    final l = AppLocalizations.of(context);
    switch (widget.state) {
      case CharacterState.idle:
        return l.t('chat.ready');
      case CharacterState.listening:
        return l.t('chat.listening');
      case CharacterState.thinking:
        return l.t('chat.thinking');
      case CharacterState.speaking:
        return l.t('chat.speaking');
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
  ///
  /// Public + static so the 3D avatar widget can reuse the exact same
  /// text→viseme mapping without duplicating the catalogue (the painter
  /// and the WebGL avatar share one source of truth for lip-sync).
  static Viseme visemeForChar(String text, int i) {
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
  ///
  /// Public + static for the same reason as [visemeForChar] — shared
  /// between the painter fallback and the 3D avatar so keyword→gesture
  /// behaviour stays in sync.
  static Gesture gestureForKeyword(String text) {
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
    // ── R2 additions (10 new keyword → gesture mappings) ──
    if (has(['不知道', "don't know", 'don’t know', 'idk', '不清楚', '不懂'])) {
      return Gesture.shrug;
    }
    if (has(['好耶', 'yay', 'awesome', '太好了', '太棒了', '好棒'])) {
      return Gesture.clap;
    }
    if (has(['好的', 'ok', 'okay', 'sure', '行', '好嘞', '没问题'])) {
      return Gesture.peaceSign;
    }
    if (has(['等等', 'wait', 'hold on', '稍等', '等一下'])) {
      return Gesture.handOnHip;
    }
    if (has(['嗯哼', 'uh-huh', 'uh huh', 'mmhmm', '嗯啊', '嗯嗯'])) {
      return Gesture.tiltRight;
    }
    if (has(['哇', 'wow', 'whoa', 'woah', '天啊', '哇哦'])) {
      return Gesture.lookUp;
    }
    if (has(['抱歉', 'sorry', 'apologize', '对不起', '不好意思'])) {
      return Gesture.lookDown;
    }
    if (has(['感谢配合', 'thanks for your cooperation', '谢谢配合', '多谢配合'])) {
      return Gesture.deepNod;
    }
    if (has(['听着', 'listen', 'hey', '注意', '听好'])) {
      return Gesture.tiltLeft;
    }
    if (has(['必须', 'must', 'definitely', 'absolutely', '一定', '肯定'])) {
      return Gesture.crossArms;
    }
    // ── Extended keyword → gesture mappings ──
    if (has(['赞', 'good job', 'nice', '干得好', '干得漂亮', 'well done'])) {
      return Gesture.thumbsUp;
    }
    if (has(['谢谢观看', '谢幕', '再见', 'bye', 'goodbye', 'farewell'])) {
      return Gesture.bow;
    }
    if (has(['加油', 'come on', '你行的', 'you can', 'clap'])) {
      return Gesture.clap;
    }
    if (has(['累了', '困了', 'tired', 'yawn', '哈欠'])) {
      return Gesture.yawn;
    }
    if (has(['伸个懒腰', 'stretch', '放松'])) {
      return Gesture.stretch;
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

// ── Gesture catalogue (27) ─────────────────────────────────────────────────
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
  tiltLeft, // 向左歪头（聆听）
  tiltRight, // 向右歪头（应和）
  shrug, // 耸肩（不知道）
  clap, // 鼓掌
  peaceSign, // 比 ✌
  handOnHip, // 单手叉腰
  crossArms, // 双手交叉
  lookUp, // 抬头看上方（惊叹）
  lookDown, // 低头（抱歉/害羞）
  deepNod, // 深深点头（致谢配合）
  // ── Extended gestures ──
  thumbsUp, // 竖大拇指
  bow, // 鞠躬
  adjustHair, // 撸头发
  lookAround, // 环顾
  stretch, // 伸懒腰
  yawn, // 打哈欠
  wink, // 眨眼
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

    // ── Compute gesture-driven offsets (all 20 gestures) ──
    // progress 0..0.5..1 with sine for smooth ping-pong.
    final p = gestureProgress;
    final swing = math.sin(p * math.pi); // 0..1..0
    double headDx = 0, headDy = 0, bodyDy = 0, tiltRad = 0;
    double leftHandDy = 0, rightHandDy = 0;
    double leftHandDx = 0, rightHandDx = 0;
    double gazeDy = 0; // iris vertical offset for lookUp / lookDown
    // shoulderLift: shoulder-line vertical offset (negative = up). Applied
    // ONCE and consistently — to the torso shoulder line, the arm's shoulder
    // anchor, the arm's hand endpoint, and the hand dot — all with the SAME
    // sign via shoulderBaseY / handBaseY, so the shoulder+arm+hand assembly
    // rises/falls as a unit. (R1 had no shoulderLift and a bodyDy-only
    // breathing model; R2 adds it for the shrug gesture and a subtle
    // breathing shoulder rise. There is no double-add and no sign mismatch.)
    double shoulderLift = 0;
    switch (gesture) {
      case Gesture.idle:
        bodyDy = (breath - 1) * size.width * 0.5; // tiny breathing
        shoulderLift = (breath - 1) * size.width * 0.8; // subtle shoulder rise
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
      case Gesture.tiltLeft:
        // Attentive lean toward the viewer's left (listening pose).
        tiltRad = -0.16 + swing * 0.03;
        break;
      case Gesture.tiltRight:
        tiltRad = 0.16 - swing * 0.03;
        break;
      case Gesture.shrug:
        // Shoulders rise, head dips slightly — "I don't know".
        shoulderLift = -swing * size.width * 0.05;
        headDy = -swing * size.width * 0.015;
        tiltRad = (swing - 0.5) * 0.06;
        break;
      case Gesture.clap:
        // Both hands meet in front, slightly raised.
        leftHandDx = size.width * 0.16 - swing * size.width * 0.10;
        rightHandDx = -size.width * 0.16 + swing * size.width * 0.10;
        leftHandDy = -size.width * 0.10 - swing * size.width * 0.02;
        rightHandDy = -size.width * 0.10 - swing * size.width * 0.02;
        break;
      case Gesture.peaceSign:
        // Right hand up beside the face (✌).
        rightHandDy = -size.width * 0.22;
        rightHandDx = size.width * 0.10;
        tiltRad = -swing * 0.04;
        break;
      case Gesture.handOnHip:
        // Right hand back to the hip, elbow out.
        rightHandDx = -size.width * 0.14;
        rightHandDy = -size.width * 0.06;
        break;
      case Gesture.crossArms:
        // Both hands crossed over the chest.
        leftHandDx = size.width * 0.14;
        rightHandDx = -size.width * 0.14;
        leftHandDy = -size.width * 0.10;
        rightHandDy = -size.width * 0.10;
        break;
      case Gesture.lookUp:
        gazeDy = -size.width * 0.018;
        headDy = -swing * size.width * 0.012;
        break;
      case Gesture.lookDown:
        gazeDy = size.width * 0.018;
        headDy = swing * size.width * 0.012;
        break;
      case Gesture.deepNod:
        headDy = swing * size.width * 0.05;
        break;
      // ── Extended gesture cases ──
      case Gesture.thumbsUp:
        rightHandDy = -size.width * 0.28;
        rightHandDx = size.width * 0.08;
        break;
      case Gesture.bow:
        bodyDy = swing * size.width * 0.06;
        headDy = swing * size.width * 0.08;
        break;
      case Gesture.adjustHair:
        rightHandDy = -size.width * 0.35;
        rightHandDx = -size.width * 0.04;
        break;
      case Gesture.lookAround:
        headDx = (swing - 0.5) * size.width * 0.12;
        break;
      case Gesture.stretch:
        leftHandDy = -swing * size.width * 0.30;
        rightHandDy = -swing * size.width * 0.30;
        leftHandDx = -size.width * 0.08;
        rightHandDx = size.width * 0.08;
        break;
      case Gesture.yawn:
        headDy = size.width * 0.04;
        tiltRad = 0.05;
        break;
      case Gesture.wink:
        tiltRad = 0.06;
        headDx = size.width * 0.02;
        break;
    }

    // ── Head geometry (needed early for back-hair sheet) ──
    final headCenter = Offset(
      cx + headDx,
      cy + headDy - size.width * 0.02,
    );
    final headR = r * 0.52;
    const hairColor = Color(0xFF3D2C5F);

    // ── Ground ellipse shadow (semi-transparent, at the base) ──
    final groundY = cy + r * 0.92 + bodyDy * 0.3;
    final groundPaint = Paint()
      ..color = const Color(0xFF1A0E2E).withValues(alpha: 0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY),
        width: r * 1.05,
        height: r * 0.22,
      ),
      groundPaint,
    );

    // ── Back hair sheet (drawn first, behind torso/head) ──
    // Long feminine hair framing the head and flowing past the shoulders.
    final backHairPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;
    final backHairPath = Path()
      ..moveTo(headCenter.dx - headR * 0.95, headCenter.dy - headR * 0.20)
      ..quadraticBezierTo(
        headCenter.dx - headR * 1.30,
        headCenter.dy + headR * 0.5,
        headCenter.dx - headR * 1.05,
        headCenter.dy + headR * 1.55,
      )
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.50,
        headCenter.dy + headR * 1.70,
        headCenter.dx,
        headCenter.dy + headR * 1.60,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.50,
        headCenter.dy + headR * 1.70,
        headCenter.dx + headR * 1.05,
        headCenter.dy + headR * 1.55,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 1.30,
        headCenter.dy + headR * 0.5,
        headCenter.dx + headR * 0.95,
        headCenter.dy - headR * 0.20,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.85,
        headCenter.dy - headR * 1.15,
        headCenter.dx,
        headCenter.dy - headR * 1.10,
      )
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.85,
        headCenter.dy - headR * 1.15,
        headCenter.dx - headR * 0.95,
        headCenter.dy - headR * 0.20,
      )
      ..close();
    canvas.drawPath(backHairPath, backHairPaint);

    // ── Torso (LinearGradient cream → lavender + chest curve + V-neck) ──
    final torsoTop = cy + r * 0.45;
    // shoulderLift applied ONCE here (shoulder baseline); the torso BOTTOM
    // uses only bodyDy, so a shrug stretches the torso slightly (correct).
    final shoulderBaseY = torsoTop + bodyDy + shoulderLift;
    final torsoBottomY = cy + r + bodyDy;
    final torsoRect = Rect.fromLTRB(
      cx - r * 0.55,
      shoulderBaseY,
      cx + r * 0.55,
      torsoBottomY,
    );
    final torsoPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFF5E6D3), // cream
          const Color(0xFFD9C7EE), // soft lavender
          const Color(0xFFB8A8E0), // deeper lavender
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(torsoRect);
    final torsoPath = Path()
      ..moveTo(cx - r * 0.55, shoulderBaseY + r * 0.05)
      ..quadraticBezierTo(
        cx - r * 0.40,
        shoulderBaseY - r * 0.05,
        cx - r * 0.18,
        shoulderBaseY - r * 0.02,
      )
      ..lineTo(cx + r * 0.18, shoulderBaseY - r * 0.02)
      ..quadraticBezierTo(
        cx + r * 0.40,
        shoulderBaseY - r * 0.05,
        cx + r * 0.55,
        shoulderBaseY + r * 0.05,
      )
      ..lineTo(cx + r * 0.55, torsoBottomY)
      ..lineTo(cx - r * 0.55, torsoBottomY)
      ..close();
    canvas.drawPath(torsoPath, torsoPaint);

    // Chest curve (soft shading under the collarbones).
    final chestPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final chestPath = Path()
      ..moveTo(cx - r * 0.35, shoulderBaseY + r * 0.06)
      ..quadraticBezierTo(
        cx,
        shoulderBaseY + r * 0.22,
        cx + r * 0.35,
        shoulderBaseY + r * 0.06,
      )
      ..lineTo(cx + r * 0.30, shoulderBaseY + r * 0.30)
      ..quadraticBezierTo(
        cx,
        shoulderBaseY + r * 0.18,
        cx - r * 0.30,
        shoulderBaseY + r * 0.30,
      )
      ..close();
    canvas.drawPath(chestPath, chestPaint);

    // V-neck collar (accent stroke).
    final vneckPaint = Paint()
      ..color = accent.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round;
    final vneckPath = Path()
      ..moveTo(cx - r * 0.18, shoulderBaseY - r * 0.02)
      ..lineTo(cx, shoulderBaseY + r * 0.22)
      ..lineTo(cx + r * 0.18, shoulderBaseY - r * 0.02);
    canvas.drawPath(vneckPath, vneckPaint);

    // ── Arms (drawn before head so they sit behind) ──
    // shoulderLift carried ONCE via shoulderBaseY (shoulder anchor) and
    // handBaseY (hand anchor) — both include it with the same sign, so the
    // whole arm lifts with the shoulder. No double-add.
    final armPaint = Paint()
      ..color = const Color(0xFFC9B6E4) // lavender sleeve
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;
    final handBaseY = torsoTop + r * 0.55 + bodyDy + shoulderLift;
    canvas.drawLine(
      Offset(cx - r * 0.45, shoulderBaseY),
      Offset(cx - r * 0.55 + leftHandDx, handBaseY + leftHandDy),
      armPaint,
    );
    canvas.drawLine(
      Offset(cx + r * 0.45, shoulderBaseY),
      Offset(cx + r * 0.55 + rightHandDx, handBaseY + rightHandDy),
      armPaint,
    );

    // Accent cuffs on sleeves (small rings near the wrists).
    final cuffPaint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.022
      ..strokeCap = StrokeCap.round;
    final leftCuffY = handBaseY + leftHandDy - size.width * 0.05;
    final rightCuffY = handBaseY + rightHandDy - size.width * 0.05;
    canvas.drawLine(
      Offset(cx - r * 0.54 + leftHandDx, leftCuffY),
      Offset(cx - r * 0.56 + leftHandDx, leftCuffY + size.width * 0.03),
      cuffPaint,
    );
    canvas.drawLine(
      Offset(cx + r * 0.54 + rightHandDx, rightCuffY),
      Offset(cx + r * 0.56 + rightHandDx, rightCuffY + size.width * 0.03),
      cuffPaint,
    );

    // Save layer for head rotation (tilt).
    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(tiltRad);
    canvas.translate(-headCenter.dx, -headCenter.dy);

    // ── Neck + jaw shadow ──
    final neckPaint = Paint()
      ..color = const Color(0xFFE8B58E); // skin shadow
    final neckPath = Path()
      ..moveTo(headCenter.dx - headR * 0.20, headCenter.dy + headR * 0.82)
      ..lineTo(headCenter.dx + headR * 0.20, headCenter.dy + headR * 0.82)
      ..lineTo(headCenter.dx + headR * 0.24, headCenter.dy + headR * 1.08)
      ..lineTo(headCenter.dx - headR * 0.24, headCenter.dy + headR * 1.08)
      ..close();
    canvas.drawPath(neckPath, neckPaint);
    // Jaw shadow (soft crescent under the chin).
    final jawShadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final jawPath = Path()
      ..moveTo(headCenter.dx - headR * 0.30, headCenter.dy + headR * 0.78)
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy + headR * 1.02,
        headCenter.dx + headR * 0.30,
        headCenter.dy + headR * 0.78,
      )
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy + headR * 0.88,
        headCenter.dx - headR * 0.30,
        headCenter.dy + headR * 0.78,
      )
      ..close();
    canvas.drawPath(jawPath, jawShadowPaint);

    // ── Ears (with conch inner detail) ──
    final earPaint = Paint()
      ..color = const Color(0xFFF0C09A)
      ..style = PaintingStyle.fill;
    final earConchPaint = Paint()
      ..color = const Color(0xFFD8A079)
      ..style = PaintingStyle.fill;
    final earL = Offset(headCenter.dx - headR * 0.85, headCenter.dy + headR * 0.05);
    final earR = Offset(headCenter.dx + headR * 0.85, headCenter.dy + headR * 0.05);
    canvas.drawOval(
      Rect.fromCenter(center: earL, width: headR * 0.22, height: headR * 0.34),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: earR, width: headR * 0.22, height: headR * 0.34),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: earL, width: headR * 0.10, height: headR * 0.18),
      earConchPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: earR, width: headR * 0.10, height: headR * 0.18),
      earConchPaint,
    );

    // ── Face base (RadialGradient skin: highlight → base → shadow) ──
    final faceRect = Rect.fromCenter(
      center: headCenter,
      width: headR * 1.7,
      height: headR * 1.9,
    );
    final skinPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.9,
        colors: [
          const Color(0xFFFAD4B8), // highlight
          const Color(0xFFF5C8A4), // base
          const Color(0xFFE8B58E), // shadow
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(faceRect);
    canvas.drawOval(faceRect, skinPaint);

    // ── Front hair: cap + side bangs + highlight strands ──
    final hairPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;
    // Top cap.
    final hairCap = Path()
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
    canvas.drawPath(hairCap, hairPaint);
    // Side bangs (asymmetric, feminine sweep).
    final bangsPath = Path()
      ..moveTo(headCenter.dx - headR * 0.90, headCenter.dy - headR * 0.18)
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.40,
        headCenter.dy - headR * 0.55,
        headCenter.dx - headR * 0.05,
        headCenter.dy - headR * 0.30,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.20,
        headCenter.dy - headR * 0.45,
        headCenter.dx + headR * 0.55,
        headCenter.dy - headR * 0.10,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.30,
        headCenter.dy - headR * 0.05,
        headCenter.dx + headR * 0.05,
        headCenter.dy + headR * 0.02,
      )
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.30,
        headCenter.dy - headR * 0.05,
        headCenter.dx - headR * 0.90,
        headCenter.dy - headR * 0.18,
      )
      ..close();
    canvas.drawPath(bangsPath, hairPaint);
    // Highlight strands (a couple of lighter streaks).
    final hairHighlightPaint = Paint()
      ..color = const Color(0xFF6B4F8E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.008
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(headCenter.dx - headR * 0.55, headCenter.dy - headR * 0.75),
      Offset(headCenter.dx - headR * 0.30, headCenter.dy - headR * 0.35),
      hairHighlightPaint,
    );
    canvas.drawLine(
      Offset(headCenter.dx + headR * 0.50, headCenter.dy - headR * 0.72),
      Offset(headCenter.dx + headR * 0.25, headCenter.dy - headR * 0.30),
      hairHighlightPaint,
    );

    // ── Eyes ──
    final eyeY = headCenter.dy - headR * 0.05;
    final eyeDx = headR * 0.32;
    final isThinking = state == CharacterState.thinking;
    final isListening = state == CharacterState.listening;
    _drawEye(
      canvas,
      Offset(headCenter.dx - eyeDx, eyeY),
      headR * 0.10,
      isThinking,
      isListening,
      gazeDy,
    );
    _drawEye(
      canvas,
      Offset(headCenter.dx + eyeDx, eyeY),
      headR * 0.10,
      isThinking,
      isListening,
      gazeDy,
    );

    // ── Brow arch (subtle feminine arcs above eyes) ──
    final browY = headCenter.dy - headR * 0.22;
    final browPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.013
      ..strokeCap = StrokeCap.round;
    final leftBrow = Path()
      ..moveTo(headCenter.dx - eyeDx - headR * 0.16,
          browY + (isThinking ? headR * 0.04 : headR * 0.01))
      ..quadraticBezierTo(
        headCenter.dx - eyeDx,
        browY - headR * 0.08 - (isThinking ? headR * 0.04 : 0),
        headCenter.dx - eyeDx + headR * 0.16,
        browY + headR * 0.01,
      );
    canvas.drawPath(leftBrow, browPaint);
    final rightBrow = Path()
      ..moveTo(headCenter.dx + eyeDx - headR * 0.16, browY + headR * 0.01)
      ..quadraticBezierTo(
        headCenter.dx + eyeDx,
        browY - headR * 0.08 - (isThinking ? headR * 0.04 : 0),
        headCenter.dx + eyeDx + headR * 0.16,
        browY + (isThinking ? headR * 0.04 : headR * 0.01),
      );
    canvas.drawPath(rightBrow, browPaint);

    // ── Nose (wing + nostril dots) ──
    final nosePaint = Paint()
      ..color = const Color(0xFFE0AC8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.010
      ..strokeCap = StrokeCap.round;
    final nosePath = Path()
      ..moveTo(headCenter.dx, headCenter.dy + headR * 0.02)
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.06,
        headCenter.dy + headR * 0.20,
        headCenter.dx - headR * 0.02,
        headCenter.dy + headR * 0.24,
      )
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy + headR * 0.26,
        headCenter.dx + headR * 0.02,
        headCenter.dy + headR * 0.24,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.06,
        headCenter.dy + headR * 0.20,
        headCenter.dx,
        headCenter.dy + headR * 0.02,
      );
    canvas.drawPath(nosePath, nosePaint);
    // Nostril dots.
    final nostrilPaint = Paint()..color = const Color(0xFFC98A6A);
    canvas.drawCircle(
      Offset(headCenter.dx - headR * 0.025, headCenter.dy + headR * 0.235),
      size.width * 0.006,
      nostrilPaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + headR * 0.025, headCenter.dy + headR * 0.235),
      size.width * 0.006,
      nostrilPaint,
    );

    // ── Cheek blush (semi-transparent pink) ──
    final blushPaint = Paint()
      ..color = const Color(0xFFFF8A8A).withValues(alpha: 0.32);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - headR * 0.55, headCenter.dy + headR * 0.32),
        width: headR * 0.32,
        height: headR * 0.20,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx + headR * 0.55, headCenter.dy + headR * 0.32),
        width: headR * 0.32,
        height: headR * 0.20,
      ),
      blushPaint,
    );

    // ── Mouth (viseme-driven) + chin shadow ──
    final mouthCenter = Offset(headCenter.dx, headCenter.dy + headR * 0.45);
    _drawMouth(canvas, mouthCenter, headR * 0.35);
    // Chin shadow (soft, under the lower lip).
    final chinShadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(mouthCenter.dx, mouthCenter.dy + headR * 0.16),
        width: headR * 0.34,
        height: headR * 0.10,
      ),
      chinShadowPaint,
    );

    canvas.restore();

    // ── Hands (drawn last, on top) — radial palm + finger separators ──
    final leftHandPos =
        Offset(cx - r * 0.55 + leftHandDx, handBaseY + leftHandDy);
    final rightHandPos =
        Offset(cx + r * 0.55 + rightHandDx, handBaseY + rightHandDy);
    _drawHand(canvas, leftHandPos, size.width * 0.05);
    _drawHand(canvas, rightHandPos, size.width * 0.05);
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    double radius,
    bool thinking,
    bool listening,
    double gazeDy,
  ) {
    if (thinking) {
      // Closed eye — curved arc (happy/squint).
      final paint = Paint()
        ..color = const Color(0xFF2A1F45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.55
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 1.1),
        math.pi,
        math.pi,
        false,
        paint,
      );
      return;
    }
    // Sclera (white) — slightly taller when listening (attention).
    final scleraH = listening ? radius * 2.2 : radius * 1.9;
    final scleraW = listening ? radius * 2.4 : radius * 2.1;
    final scleraPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: scleraW, height: scleraH),
      scleraPaint,
    );
    // Upper eyelash line (dark, thick arc over the top of the sclera).
    final lashPaint = Paint()
      ..color = const Color(0xFF2A1F45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.42
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: center, width: scleraW, height: scleraH),
      math.pi,
      math.pi * 0.95,
      false,
      lashPaint,
    );
    // Iris (RadialGradient brown).
    final irisR = radius * 0.95;
    final irisCenter = Offset(center.dx, center.dy + gazeDy);
    final irisPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          const Color(0xFF8B5A2B), // light brown rim
          const Color(0xFF6B4423), // mid
          const Color(0xFF3D2410), // deep
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: irisCenter, radius: irisR));
    canvas.drawCircle(irisCenter, irisR, irisPaint);
    // Pupil.
    final pupilPaint = Paint()..color = const Color(0xFF1A0E08);
    canvas.drawCircle(irisCenter, irisR * 0.45, pupilPaint);
    // Dual reflection points (white sparkles) — the "pretty eye" sparkle.
    final hl = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(
      Offset(irisCenter.dx - irisR * 0.35, irisCenter.dy - irisR * 0.35),
      irisR * 0.30,
      hl,
    );
    canvas.drawCircle(
      Offset(irisCenter.dx + irisR * 0.30, irisCenter.dy + irisR * 0.30),
      irisR * 0.16,
      hl,
    );
    // Lower eyelash (thin).
    final lowerLashPaint = Paint()
      ..color = const Color(0xFF2A1F45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: center,
        width: scleraW * 0.95,
        height: scleraH * 0.95,
      ),
      0,
      math.pi * 0.9,
      false,
      lowerLashPaint,
    );
  }

  /// Draw a hand with a radial-gradient palm + finger separator lines.
  void _drawHand(Canvas canvas, Offset center, double radius) {
    final palmPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.9,
        colors: [
          const Color(0xFFFAD4B8), // highlight
          const Color(0xFFF5C8A4), // base
          const Color(0xFFE8B58E), // shadow
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, palmPaint);
    // Finger separator lines (thin grooves fanning across the palm).
    final fingerPaint = Paint()
      ..color = const Color(0xFFD8A079)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius * 0.35, center.dy - radius * 0.7),
      Offset(center.dx - radius * 0.35, center.dy - radius * 0.1),
      fingerPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.8),
      Offset(center.dx, center.dy - radius * 0.1),
      fingerPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.35, center.dy - radius * 0.7),
      Offset(center.dx + radius * 0.35, center.dy - radius * 0.1),
      fingerPaint,
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
    // Lip gloss: a soft white sheen on the lower lip for a glossy finish.
    final glossPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + h * 0.18),
        width: w * 0.30,
        height: h * 0.12,
      ),
      glossPaint,
    );
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
