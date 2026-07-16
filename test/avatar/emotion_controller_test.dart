import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/avatar/domain/emotion_controller.dart';
import 'package:speakflow/features/avatar/domain/live2d_model.dart';
import 'package:speakflow/features/chat/domain/tutor_emotion.dart';

void main() {
  group('EmotionController', () {
    test('initial state is the initial emotion passed in', () {
      final c = EmotionController(initial: TutorEmotion.happy);
      expect(c.current, TutorEmotion.happy);
      expect(c.previous, TutorEmotion.happy);
    });

    test('setEmotion updates current and stamps previous', () {
      final c = EmotionController(initial: TutorEmotion.neutral);
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      expect(c.current, TutorEmotion.happy);
      expect(c.previous, TutorEmotion.neutral);
    });

    test('setEmotion to the same emotion is a no-op', () {
      final c = EmotionController(initial: TutorEmotion.happy);
      c.setEmotion(TutorEmotion.happy, nowSeconds: 1.0);
      expect(c.previous, TutorEmotion.happy);
    });

    test('sample before transition window returns previous pose', () {
      final c = EmotionController(initial: TutorEmotion.neutral);
      c.setEmotion(TutorEmotion.happy, nowSeconds: 1.0);
      // Sample at t=0.5 — before the transition started at t=1.0.
      final f = c.sample(const Duration(milliseconds: 500));
      // Should be the neutral pose — mouthForm ~ 0, eyeSmile ~ 0.
      expect(f.value(Live2DParamId.mouthForm), closeTo(0.0, 0.05));
      expect(f.value(Live2DParamId.eyeSmile), closeTo(0.0, 0.05));
    });

    test('sample after transition completes returns target pose', () {
      final c = EmotionController(initial: TutorEmotion.neutral);
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      // Default transition duration is 0.25s. Sample at t=1.0.
      final f = c.sample(const Duration(seconds: 1));
      // Happy pose: mouthForm ~ 1.0, eyeSmile ~ 0.9.
      expect(f.value(Live2DParamId.mouthForm), closeTo(1.0, 0.05));
      expect(f.value(Live2DParamId.eyeSmile), closeTo(0.9, 0.05));
      // Cheek should be enabled.
      expect(f.value(Live2DParamId.cheek), closeTo(0.4, 0.05));
    });

    test('sample during transition is a blend between the two poses', () {
      final c = EmotionController(initial: TutorEmotion.neutral);
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      // Default transition = 0.25s. Sample at t=0.125 — half way through.
      final f = c.sample(const Duration(milliseconds: 125));
      // With easeOutCubic, t=0.5 raw → easedT ~ 0.875, so the value should
      // be ~0.875 of the way from neutral (0) to happy (1).
      final v = f.value(Live2DParamId.mouthForm);
      expect(v, greaterThan(0.4));
      expect(v, lessThan(1.0));
    });

    test('linear easing produces an exact midpoint at t=0.5', () {
      final c = EmotionController(
        initial: TutorEmotion.neutral,
        config: const EmotionControllerConfig(
          transitionDuration: 1.0,
          easing: EmotionEasing.linear,
        ),
      );
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      final f = c.sample(const Duration(milliseconds: 500));
      // neutral mouthForm = 0, happy = 1 → midpoint = 0.5.
      expect(f.value(Live2DParamId.mouthForm), closeTo(0.5, 1e-9));
    });

    test('easeInOutQuad produces a smooth, monotonic transition', () {
      final c = EmotionController(
        initial: TutorEmotion.neutral,
        config: const EmotionControllerConfig(
          transitionDuration: 1.0,
          easing: EmotionEasing.easeInOutQuad,
        ),
      );
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      var prev = 0.0;
      for (var i = 1; i <= 10; i++) {
        final f = c.sample(Duration(milliseconds: i * 100));
        final v = f.value(Live2DParamId.mouthForm);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
      expect(prev, closeTo(1.0, 1e-9));
    });

    test('custom poses override the defaults', () {
      final c = EmotionController(
        initial: TutorEmotion.neutral,
        config: EmotionControllerConfig(
          poses: {
            TutorEmotion.neutral:
                const EmotionPose(mouthForm: 0, eyeSmile: 0, browY: 0, cheek: 0),
            TutorEmotion.happy: const EmotionPose(
                mouthForm: 0.5, eyeSmile: 0.5, browY: 0, cheek: 0),
          },
        ),
      );
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      final f = c.sample(const Duration(seconds: 1));
      expect(f.value(Live2DParamId.mouthForm), closeTo(0.5, 1e-9));
    });

    test('unknown emotion falls back to default poses', () {
      // When the config has no entry for the previous/target emotion, the
      // controller falls back to kDefaultEmotionPoses.
      final c = EmotionController(
        initial: TutorEmotion.neutral,
        config: const EmotionControllerConfig(
          poses: {}, // empty — fall back to defaults
        ),
      );
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      final f = c.sample(const Duration(seconds: 1));
      // Default happy pose has mouthForm=1.0.
      expect(f.value(Live2DParamId.mouthForm), closeTo(1.0, 1e-9));
    });

    test('head pose biases are emitted as angleY / angleZ values', () {
      final c = EmotionController(initial: TutorEmotion.thinking);
      final f = c.sample(const Duration(seconds: 1));
      // Thinking pose has headPitchBias = -0.15.
      expect(f.value(Live2DParamId.angleY), closeTo(-0.15, 1e-9));
    });

    test('waiting emotion is supported and produces a smile baseline', () {
      final c = EmotionController(initial: TutorEmotion.neutral);
      c.setEmotion(TutorEmotion.waiting, nowSeconds: 0.0);
      final f = c.sample(const Duration(seconds: 1));
      // Waiting pose: mouthForm = 0.3, eyeSmile = 0.3.
      expect(f.value(Live2DParamId.mouthForm), closeTo(0.3, 1e-9));
      expect(f.value(Live2DParamId.eyeSmile), closeTo(0.3, 1e-9));
    });

    test('zero transition duration snaps immediately', () {
      final c = EmotionController(
        initial: TutorEmotion.neutral,
        config: const EmotionControllerConfig(transitionDuration: 0),
      );
      c.setEmotion(TutorEmotion.happy, nowSeconds: 0.0);
      final f = c.sample(const Duration(microseconds: 1));
      expect(f.value(Live2DParamId.mouthForm), closeTo(1.0, 1e-9));
    });
  });

  group('EmotionPose.lerp', () {
    test('interpolates every field', () {
      const a = EmotionPose(
          mouthForm: 0, eyeSmile: 0, browY: 0, cheek: 0);
      const b = EmotionPose(
          mouthForm: 1, eyeSmile: 1, browY: 1, cheek: 1,
          headPitchBias: 1, headRollBias: 1);
      final mid = a.lerp(b, 0.5);
      expect(mid.mouthForm, 0.5);
      expect(mid.eyeSmile, 0.5);
      expect(mid.browY, 0.5);
      expect(mid.cheek, 0.5);
      expect(mid.headPitchBias, 0.5);
      expect(mid.headRollBias, 0.5);
    });
  });

  group('EmotionFrame', () {
    test('value falls back when param is missing', () {
      const f = EmotionFrame({'a': 1.0});
      expect(f.value('a'), 1.0);
      expect(f.value('missing'), 0.0);
      expect(f.value('missing', fallback: -1.0), -1.0);
    });
  });
}
