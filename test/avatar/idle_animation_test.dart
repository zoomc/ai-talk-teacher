import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/avatar/domain/idle_animation.dart';
import 'package:speakflow/features/avatar/domain/live2d_model.dart';
import 'package:speakflow/features/chat/domain/tutor_emotion.dart';
import 'package:speakflow/shared/voice_phase.dart';

void main() {
  group('IdleAnimationController', () {
    late IdleAnimationController controller;

    setUp(() {
      controller = IdleAnimationController();
    });

    test('produces every required Live2D parameter on each frame', () {
      final frame = controller.sample(const Duration(seconds: 1));
      expect(frame.values, contains(Live2DParamId.breath));
      expect(frame.values, contains(Live2DParamId.angleX));
      expect(frame.values, contains(Live2DParamId.angleY));
      expect(frame.values, contains(Live2DParamId.angleZ));
      expect(frame.values, contains(Live2DParamId.bodyAngleX));
      expect(frame.values, contains(Live2DParamId.mouthForm));
      expect(frame.values, contains(Live2DParamId.eyeSmile));
      expect(frame.values, contains(Live2DParamId.eyeLOpen));
      expect(frame.values, contains(Live2DParamId.eyeROpen));
    });

    test('breath parameter stays in the 0..1 range', () {
      for (var t = 0; t < 60; t++) {
        final frame = controller.sample(Duration(seconds: t));
        final breath = frame.values[Live2DParamId.breath]!;
        expect(breath, greaterThanOrEqualTo(0.0));
        expect(breath, lessThanOrEqualTo(1.0));
      }
    });

    test('breath parameter oscillates around 0.5', () {
      // Sample at half-period offsets — the values should bracket 0.5.
      final at0 = controller
          .sample(const Duration(milliseconds: 0))
          .values[Live2DParamId.breath]!;
      final atHalf = controller
          .sample(
              Duration(milliseconds: (3300 / 2).round()))
          .values[Live2DParamId.breath]!;
      expect((at0 - 0.5).abs(), lessThan(0.1));
      expect((atHalf - 0.5).abs(), lessThan(0.1));
      // At least one side should be above 0.5 and one below over a full
      // period — breath must move, not stay flat.
      final samples = List.generate(33, (i) {
        return controller
            .sample(Duration(milliseconds: i * 100))
            .values[Live2DParamId.breath]!;
      });
      expect(samples.any((v) => v > 0.5), isTrue);
      expect(samples.any((v) => v < 0.5), isTrue);
    });

    test('head angles stay in -1..1 (normalised ±30deg)', () {
      for (var t = 0; t < 60; t++) {
        final f = controller.sample(Duration(seconds: t));
        for (final id in [
          Live2DParamId.angleX,
          Live2DParamId.angleY,
          Live2DParamId.angleZ,
        ]) {
          final v = f.values[id]!;
          expect(v, greaterThanOrEqualTo(-1.0));
          expect(v, lessThanOrEqualTo(1.0));
        }
      }
    });

    test('eyes are open (1.0) outside a blink window', () {
      // Pick a time we know is between blinks (e.g. t=0.05s — just past the
      // initial blink slot which starts somewhere in 0..3.5s).
      final f = controller.sample(const Duration(milliseconds: 50));
      expect(f.values[Live2DParamId.eyeLOpen], greaterThan(0.5));
      expect(f.values[Live2DParamId.eyeROpen], greaterThan(0.5));
    });

    test('both eyes close together during a blink', () {
      // Both eyes should always be equal — blinks drive both eyes together.
      for (var t = 0; t < 60; t++) {
        final f = controller.sample(Duration(seconds: t));
        expect(f.values[Live2DParamId.eyeLOpen],
            equals(f.values[Live2DParamId.eyeROpen]),
            reason: 'left and right eye should blink together');
      }
    });

    test('a blink occurs at some point within a 5s window', () {
      // At least one frame in the first 5s should have eyes mostly closed.
      var sawClosed = false;
      for (var ms = 0; ms < 5000; ms += 10) {
        final f = controller.sample(Duration(milliseconds: ms));
        if (f.values[Live2DParamId.eyeLOpen]! < 0.3) {
          sawClosed = true;
          break;
        }
      }
      expect(sawClosed, isTrue,
          reason: 'a blink should fire within the 5s window');
    });

    test('output is deterministic — same input → same frame', () {
      final a = controller.sample(const Duration(seconds: 3, milliseconds: 14));
      final b = controller.sample(const Duration(seconds: 3, milliseconds: 14));
      expect(a.values, equals(b.values));
    });

    test('happy emotion biases mouthForm toward +1', () {
      final neutral = controller.sample(const Duration(seconds: 2),
          emotion: TutorEmotion.neutral);
      final happy = controller.sample(const Duration(seconds: 2),
          emotion: TutorEmotion.happy);
      expect(happy.values[Live2DParamId.mouthForm]!,
          greaterThan(neutral.values[Live2DParamId.mouthForm]!));
    });

    test('speaking phase zeroes the smile scale', () {
      // During speaking the mouth is driven by the viseme timeline; the
      // idle smile contribution should be 0.
      final speaking = controller.sample(const Duration(seconds: 2),
          phase: VoicePhase.speaking, emotion: TutorEmotion.happy);
      expect(speaking.values[Live2DParamId.mouthForm], 0.0);
    });

    test('idle phase produces non-zero smile', () {
      final idle = controller.sample(const Duration(seconds: 2),
          phase: VoicePhase.idle, emotion: TutorEmotion.neutral);
      expect(idle.values[Live2DParamId.mouthForm]!,
          greaterThan(0.0));
    });

    test('listening phase tilts head (positive roll offset)', () {
      final idle = controller.sample(const Duration(seconds: 2),
          phase: VoicePhase.idle);
      final listening = controller.sample(const Duration(seconds: 2),
          phase: VoicePhase.listening);
      // The roll offset adds +0.05 to listening, so listening roll should
      // be greater than idle roll (when other factors are similar).
      expect(listening.values[Live2DParamId.angleZ]!,
          greaterThanOrEqualTo(idle.values[Live2DParamId.angleZ]!));
    });

    test('IdleFrame.value falls back to default for missing params', () {
      const f = IdleFrame({'a': 1.0});
      expect(f.value('a'), 1.0);
      expect(f.value('missing', fallback: 9.9), 9.9);
    });

    test('IdleFrame.empty has no values', () {
      expect(IdleFrame.empty.values, isEmpty);
    });

    test('custom config influences head yaw amplitude', () {
      final ctrl = IdleAnimationController(
        config: const IdleAnimationConfig(
          headYawAmplitudeDeg: 30.0, // full ±30 degrees → ±1 normalised
          headYawPeriod: 4.0,
        ),
      );
      // At quarter period, sin = 1 → head yaw = 1.0.
      final f = ctrl.sample(const Duration(seconds: 1));
      expect((f.values[Live2DParamId.angleX]! - 1.0).abs(), lessThan(0.05));
    });
  });

  group('IdleAnimationConfig', () {
    test('defaults are non-zero and finite', () {
      const c = IdleAnimationConfig.defaults;
      expect(c.breathPeriod, greaterThan(0));
      expect(c.blinkMeanInterval, greaterThan(0));
      expect(c.blinkDuration, greaterThan(0));
      expect(c.headYawAmplitudeDeg, greaterThan(0));
      expect(c.smileBaseline, greaterThanOrEqualTo(0));
    });

    test('every field is settable', () {
      const c = IdleAnimationConfig(
        breathPeriod: 5,
        breathAmplitude: 0.1,
        blinkMeanInterval: 2,
        blinkDuration: 0.1,
        blinkClosedHold: 0.02,
        headYawAmplitudeDeg: 10,
        headYawPeriod: 10,
        headPitchAmplitudeDeg: 5,
        headPitchPeriod: 12,
        headRollAmplitudeDeg: 2,
        headRollPeriod: 14,
        smileBaseline: 0.3,
        eyeSmileBaseline: 0.2,
        bodyYawAmplitudeDeg: 1,
        bodyYawPeriod: 6,
      );
      expect(c.breathPeriod, 5);
      expect(c.smileBaseline, 0.3);
    });
  });
}
