import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../chat/domain/tutor_emotion.dart';
import '../../../../shared/widgets/virtual_character.dart' show Viseme;

/// Render state for the built-in, asset-free 2D tutor.
enum LayeredTutorState { idle, listening, thinking, speaking }

/// A real layered 2D upper-body tutor drawn from independently controlled
/// vector parts. It intentionally does not use a single PNG plus a mouth
/// sticker: head, hair, shoulders, arms, eyes, lids, brows, cheeks and mouth
/// are painted separately and receive state/viseme parameters independently.
class LayeredTutorAvatar extends StatelessWidget {
  final Map<String, double> parameters;
  final LayeredTutorState state;
  final TutorEmotion emotion;
  final TutorGestureCue gesture;
  final Viseme viseme;
  final bool reduceMotion;

  const LayeredTutorAvatar({
    super.key,
    required this.parameters,
    required this.state,
    required this.emotion,
    this.gesture = TutorGestureCue.idle,
    required this.viseme,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _LayeredTutorPainter(
        parameters: parameters,
        state: state,
        emotion: emotion,
        gesture: gesture,
        viseme: viseme,
        reduceMotion: reduceMotion,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _LayeredTutorPainter extends CustomPainter {
  final Map<String, double> parameters;
  final LayeredTutorState state;
  final TutorEmotion emotion;
  final TutorGestureCue gesture;
  final Viseme viseme;
  final bool reduceMotion;

  _LayeredTutorPainter({
    required this.parameters,
    required this.state,
    required this.emotion,
    required this.gesture,
    required this.viseme,
    required this.reduceMotion,
  });

  double _p(String key, [double fallback = 0]) => parameters[key] ?? fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 320, size.height / 380);
    final offsetX = (size.width - 320 * scale) / 2;
    final offsetY = (size.height - 380 * scale) / 2;
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    final breath = reduceMotion ? 0.5 : _p('ParamBreath', 0.5);
    final sway = reduceMotion ? 0.0 : _p('ParamBodyAngleX') * 5;
    final headYaw = reduceMotion ? 0.0 : _p('ParamAngleX') * 6;
    final headRoll = reduceMotion ? 0.0 : _p('ParamAngleZ') * 0.14;
    final chestLift = (breath - 0.5) * 8;

    _paintBackdrop(canvas);
    _paintBody(canvas, chestLift, sway);
    _paintArms(canvas, chestLift, sway);
    canvas.save();
    final gestureRoll = switch (gesture) {
      TutorGestureCue.confused => 0.08,
      TutorGestureCue.greeting => -0.03,
      _ => 0.0,
    };
    final gestureYaw = gesture == TutorGestureCue.shakeHead
        ? math.sin(_p('ParamAngleX') * math.pi) * 4
        : 0.0;
    canvas.translate(headYaw + gestureYaw, chestLift * 0.35);
    canvas.rotate(headRoll + gestureRoll);
    _paintNeckAndHead(canvas);
    _paintHairBack(canvas);
    _paintFace(canvas);
    _paintHairFront(canvas);
    canvas.restore();
    canvas.restore();
  }

  void _paintBackdrop(Canvas canvas) {
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x556C5CE7), Color(0x000A0E1A)],
      ).createShader(const Rect.fromLTWH(36, 12, 248, 290));
    canvas.drawOval(const Rect.fromLTWH(38, 18, 244, 286), glow);
  }

  void _paintBody(Canvas canvas, double lift, double sway) {
    final body = Paint()..color = const Color(0xFF283C68);
    final trim = Paint()
      ..color = AppColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(78 + sway, 360)
      ..quadraticBezierTo(82 + sway, 278 + lift, 125 + sway, 246 + lift)
      ..quadraticBezierTo(160 + sway, 232 + lift, 195 + sway, 246 + lift)
      ..quadraticBezierTo(238 + sway, 278 + lift, 242 + sway, 360)
      ..close();
    canvas.drawPath(path, body);
    canvas.drawPath(path, trim);

    final shirt = Paint()..color = const Color(0xFFE7EEF9);
    final collar = Path()
      ..moveTo(137 + sway, 248 + lift)
      ..lineTo(160 + sway, 280 + lift)
      ..lineTo(183 + sway, 248 + lift)
      ..lineTo(194 + sway, 360)
      ..lineTo(126 + sway, 360)
      ..close();
    canvas.drawPath(collar, shirt);
    canvas.drawLine(
      Offset(160 + sway, 280 + lift),
      Offset(160 + sway, 360),
      trim,
    );
  }

  void _paintArms(Canvas canvas, double lift, double sway) {
    final skin = Paint()
      ..color = const Color(0xFFF0B995)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    final sleeve = Paint()
      ..color = const Color(0xFF283C68)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 25;

    if (state == LayeredTutorState.thinking) {
      canvas.drawLine(const Offset(92, 320), const Offset(126, 226), sleeve);
      canvas.drawLine(const Offset(126, 226), const Offset(137, 198), skin);
      canvas.drawLine(const Offset(228, 320), const Offset(202, 286), sleeve);
    } else if (state == LayeredTutorState.speaking &&
        gesture == TutorGestureCue.thumbsUp) {
      canvas.drawLine(const Offset(92, 320), const Offset(74, 350), sleeve);
      canvas.drawLine(const Offset(229, 318), const Offset(258, 252), sleeve);
      canvas.drawLine(const Offset(258, 252), const Offset(264, 224), skin);
    } else if (state == LayeredTutorState.speaking &&
        (gesture == TutorGestureCue.explain ||
            gesture == TutorGestureCue.openHand ||
            gesture == TutorGestureCue.greeting)) {
      canvas.drawLine(const Offset(92, 320), const Offset(58, 265), sleeve);
      canvas.drawLine(const Offset(58, 265), const Offset(38, 242), skin);
      canvas.drawLine(const Offset(229, 318), const Offset(246, 350), sleeve);
    } else if (state == LayeredTutorState.speaking &&
        (emotion == TutorEmotion.encouraging ||
            emotion == TutorEmotion.happy)) {
      canvas.drawLine(
        Offset(91 + sway, 318 + lift),
        Offset(55 + sway, 258 + lift),
        sleeve,
      );
      canvas.drawLine(
        Offset(55 + sway, 258 + lift),
        Offset(44 + sway, 236 + lift),
        skin,
      );
      canvas.drawLine(
        Offset(229 + sway, 318 + lift),
        Offset(265 + sway, 276 + lift),
        sleeve,
      );
      canvas.drawLine(
        Offset(265 + sway, 276 + lift),
        Offset(277 + sway, 252 + lift),
        skin,
      );
    } else {
      canvas.drawLine(
        Offset(91 + sway, 318 + lift),
        Offset(74 + sway, 350),
        sleeve,
      );
      canvas.drawLine(
        Offset(229 + sway, 318 + lift),
        Offset(246 + sway, 350),
        sleeve,
      );
    }
  }

  void _paintNeckAndHead(Canvas canvas) {
    final skin = Paint()..color = const Color(0xFFF0B995);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(142, 205, 36, 62),
        const Radius.circular(14),
      ),
      skin,
    );
    final face = Paint()..color = const Color(0xFFF7C7A4);
    canvas.drawOval(const Rect.fromLTWH(94, 62, 132, 174), face);
    final ear = Paint()..color = const Color(0xFFE8A985);
    canvas.drawOval(const Rect.fromLTWH(88, 130, 20, 40), ear);
    canvas.drawOval(const Rect.fromLTWH(212, 130, 20, 40), ear);
  }

  void _paintHairBack(Canvas canvas) {
    final hair = Paint()..color = const Color(0xFF5B3A4B);
    final path = Path()
      ..moveTo(92, 144)
      ..quadraticBezierTo(64, 70, 112, 34)
      ..quadraticBezierTo(160, 2, 208, 34)
      ..quadraticBezierTo(256, 70, 228, 170)
      ..lineTo(207, 204)
      ..lineTo(100, 204)
      ..close();
    canvas.drawPath(path, hair);
  }

  void _paintFace(Canvas canvas) {
    final eyeOpenL = _p('ParamEyeLOpen', 1).clamp(0.0, 1.0);
    final eyeOpenR = _p('ParamEyeROpen', 1).clamp(0.0, 1.0);
    final eyeX = _p('ParamEyeBallX').clamp(-1.0, 1.0) * 3;
    final eyeY = _p('ParamEyeBallY').clamp(-1.0, 1.0) * 2;
    final browY = _p('ParamBrowLY') * 5;
    final eyeWhite = Paint()..color = Colors.white.withValues(alpha: 0.96);
    final iris = Paint()..color = const Color(0xFF365B82);
    final brow = Paint()
      ..color = const Color(0xFF5B3A4B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final lid = Paint()
      ..color = const Color(0xFFB7686D)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    _paintEye(
      canvas,
      const Offset(133, 134),
      eyeOpenL,
      eyeX,
      eyeY,
      eyeWhite,
      iris,
      lid,
    );
    _paintEye(
      canvas,
      const Offset(187, 134),
      eyeOpenR,
      eyeX,
      eyeY,
      eyeWhite,
      iris,
      lid,
    );
    canvas.drawLine(Offset(112, 107 + browY), Offset(148, 101 + browY), brow);
    canvas.drawLine(Offset(172, 101 + browY), Offset(208, 107 + browY), brow);

    final nose = Paint()
      ..color = const Color(0xFFC47767)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(160, 136)
        ..quadraticBezierTo(153, 166, 160, 171)
        ..quadraticBezierTo(166, 173, 169, 169),
      nose,
    );
    _paintCheeks(canvas);
    _paintMouth(canvas);
  }

  void _paintEye(
    Canvas canvas,
    Offset center,
    double open,
    double dx,
    double dy,
    Paint white,
    Paint iris,
    Paint lid,
  ) {
    final height = 16 * open.clamp(0.05, 1.0);
    final eyeRect = Rect.fromCenter(
      center: center.translate(0, dy),
      width: 29,
      height: height,
    );
    canvas.drawOval(eyeRect, white);
    if (open > 0.18) {
      canvas.drawCircle(center.translate(dx, dy), 5.2, iris);
      canvas.drawCircle(
        center.translate(dx - 1, dy - 1.5),
        1.6,
        Paint()..color = Colors.white,
      );
    }
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, dy), width: 31, height: 21),
      math.pi,
      math.pi,
      false,
      lid,
    );
    if (open < 0.35) {
      canvas.drawLine(
        Offset(center.dx - 12, center.dy + 1),
        Offset(center.dx + 12, center.dy + 1),
        lid,
      );
    }
  }

  void _paintCheeks(Canvas canvas) {
    final cheek = _p('ParamCheek').clamp(0.0, 1.0);
    if (cheek <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFFE98191).withValues(alpha: 0.22 + cheek * 0.25);
    canvas.drawOval(const Rect.fromLTWH(105, 166, 28, 12), paint);
    canvas.drawOval(const Rect.fromLTWH(187, 166, 28, 12), paint);
  }

  void _paintMouth(Canvas canvas) {
    // A timeline or amplitude parameter wins when it is available. The
    // text-driven viseme passed by AvatarStage remains the last-resort
    // fallback for providers that expose neither, so the default 2D teacher
    // never silently becomes a static closed-mouth portrait.
    final parameterOpen = _p('ParamMouthOpenY').clamp(0.0, 1.0);
    final parameterForm = _p('ParamMouthForm').clamp(-1.0, 1.0);
    final fallback = _fallbackMouthShape(viseme);
    final open = math.max(parameterOpen, fallback.$1).clamp(0.0, 1.0);
    final form = parameterOpen > 0.02
        ? parameterForm
        : ((parameterForm * 0.35) + (fallback.$2 * 0.65)).clamp(-1.0, 1.0);
    final mouth = Paint()..color = const Color(0xFF9B3F58);
    final lip = Paint()
      ..color = const Color(0xFFE997AD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final width = 28 + form * 7;
    final height = 4 + open * 22;
    final rect = Rect.fromCenter(
      center: const Offset(160, 190),
      width: width,
      height: height,
    );
    canvas.drawOval(rect, mouth);
    if (open > 0.35) {
      final teeth = Paint()..color = const Color(0xFFFFF7EF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + 3,
            rect.top + 2,
            rect.width - 6,
            math.min(7, rect.height / 2),
          ),
          const Radius.circular(4),
        ),
        teeth,
      );
    }
    canvas.drawArc(rect.inflate(1), math.pi * 0.08, math.pi * 0.84, false, lip);
  }

  (double, double) _fallbackMouthShape(Viseme value) => switch (value) {
    Viseme.closed => (0.0, 0.0),
    Viseme.slightOpen => (0.12, 0.0),
    Viseme.smallOpen => (0.25, 0.0),
    Viseme.mediumOpen => (0.42, -0.05),
    Viseme.wideOpen => (0.86, 0.0),
    Viseme.roundedSmall => (0.30, -0.55),
    Viseme.roundedLarge => (0.68, -0.45),
    Viseme.wide => (0.22, 0.75),
    Viseme.flat => (0.10, -0.25),
    Viseme.smile => (0.04, 0.75),
    Viseme.smileOpen => (0.38, 0.85),
    Viseme.frown => (0.05, -0.75),
    Viseme.pucker => (0.27, -0.85),
    Viseme.teeth => (0.22, 0.55),
    Viseme.tongueUp => (0.18, 0.0),
    Viseme.tongueOut => (0.42, 0.0),
    Viseme.biteLip => (0.28, 0.45),
    Viseme.openTeeth => (0.58, 0.55),
    Viseme.oval => (0.60, -0.30),
    Viseme.wideFlat => (0.30, 0.65),
  };

  void _paintHairFront(Canvas canvas) {
    final hair = Paint()..color = const Color(0xFF6D4558);
    final path = Path()
      ..moveTo(94, 110)
      ..quadraticBezierTo(88, 34, 160, 26)
      ..quadraticBezierTo(232, 34, 226, 110)
      ..quadraticBezierTo(205, 76, 191, 70)
      ..quadraticBezierTo(173, 92, 137, 84)
      ..quadraticBezierTo(116, 80, 94, 110)
      ..close();
    canvas.drawPath(path, hair);
    final highlight = Paint()
      ..color = const Color(0xFFB9798D).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(111, 38, 94, 58),
      math.pi * 1.1,
      math.pi * 0.7,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _LayeredTutorPainter oldDelegate) =>
      oldDelegate.parameters != parameters ||
      oldDelegate.state != state ||
      oldDelegate.emotion != emotion ||
      oldDelegate.gesture != gesture ||
      oldDelegate.viseme != viseme ||
      oldDelegate.reduceMotion != reduceMotion;
}
