import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/tutor_emotion.dart';

void main() {
  group('TutorEmotion', () {
    test('id is the lowercase name for every value', () {
      for (final e in TutorEmotion.values) {
        expect(e.id, e.name.toLowerCase());
      }
    });

    test('includes the Phase 3 `waiting` value', () {
      expect(TutorEmotion.values, contains(TutorEmotion.waiting));
    });

    test('fromId round-trips every id', () {
      for (final e in TutorEmotion.values) {
        expect(TutorEmotionX.fromId(e.id), e);
      }
    });

    test('fromId is case-insensitive', () {
      expect(TutorEmotionX.fromId('HAPPY'), TutorEmotion.happy);
      expect(TutorEmotionX.fromId('Waiting'), TutorEmotion.waiting);
    });

    test('fromId returns null for unknown ids', () {
      expect(TutorEmotionX.fromId('curious'), isNull);
      expect(TutorEmotionX.fromId(''), isNull);
    });

    test('isActive is true for every emotion except neutral', () {
      expect(TutorEmotion.neutral.isActive, isFalse);
      for (final e in TutorEmotion.values) {
        if (e == TutorEmotion.neutral) continue;
        expect(e.isActive, isTrue, reason: '$e should be active');
      }
    });
  });

  group('parseEmotionMarker', () {
    test('parses a bracketed [emotion:id] marker', () {
      expect(parseEmotionMarker('Hello [emotion:happy] world'),
          TutorEmotion.happy);
      expect(parseEmotionMarker('[emotion:thinking] Hmm...'),
          TutorEmotion.thinking);
      expect(parseEmotionMarker('Reply [emotion:waiting]'),
          TutorEmotion.waiting);
    });

    test('parses a parenthesised (emotion:id) marker', () {
      expect(parseEmotionMarker('Hi (emotion:encouraging)!'),
          TutorEmotion.encouraging);
    });

    test('returns the first marker when multiple are present', () {
      expect(parseEmotionMarker('[emotion:happy] then [emotion:thinking]'),
          TutorEmotion.happy);
    });

    test('is case-insensitive on the keyword and id', () {
      expect(parseEmotionMarker('[EMOTION:Happy]'), TutorEmotion.happy);
      expect(parseEmotionMarker('[Emotion:WAITING]'), TutorEmotion.waiting);
    });

    test('tolerates whitespace inside the marker', () {
      expect(parseEmotionMarker('[emotion: happy ]'), TutorEmotion.happy);
      expect(parseEmotionMarker('[ emotion : focused ]'),
          TutorEmotion.focused);
    });

    test('returns null when no marker is present', () {
      expect(parseEmotionMarker('Hello world'), isNull);
      expect(parseEmotionMarker(''), isNull);
      expect(parseEmotionMarker('Great job!'), isNull);
    });

    test('returns null when the marker has an unknown id', () {
      expect(parseEmotionMarker('[emotion:curious]'), isNull);
      expect(parseEmotionMarker('[emotion:]'), isNull);
    });
  });

  group('stripEmotionMarkers', () {
    test('removes a single marker', () {
      expect(stripEmotionMarkers('Hello [emotion:happy] world'), 'Hello world');
    });

    test('removes multiple markers', () {
      expect(stripEmotionMarkers('[emotion:happy]A [emotion:thinking]B'),
          'A B');
    });

    test('removes both bracket and paren forms', () {
      expect(stripEmotionMarkers('(emotion:happy) Hi'), 'Hi');
    });

    test('collapses the double-space left behind', () {
      final out = stripEmotionMarkers('Hi [emotion:happy] there');
      expect(out, 'Hi there');
      expect(out.contains('  '), isFalse);
    });

    test('trims leading/trailing whitespace', () {
      expect(stripEmotionMarkers('  [emotion:happy] Hello  '), 'Hello');
    });

    test('is a no-op when no marker is present', () {
      expect(stripEmotionMarkers('Hello world'), 'Hello world');
    });

    test('is a no-op on empty string', () {
      expect(stripEmotionMarkers(''), '');
    });
  });

  group('emotionFromText', () {
    test('prefers an explicit LLM marker over keyword matching', () {
      // Without the marker, "hmm" would trigger thinking; the marker should
      // override it to happy.
      expect(emotionFromText('hmm [emotion:happy]'), TutorEmotion.happy);
    });

    test('falls back to keyword matching when no marker is present', () {
      expect(emotionFromText('Great job!'), TutorEmotion.happy);
      expect(emotionFromText('Hmm, let me think...'), TutorEmotion.thinking);
      expect(emotionFromText('Keep going!'), TutorEmotion.encouraging);
      expect(emotionFromText('Can you repeat that?'), TutorEmotion.confused);
      expect(emotionFromText('Focus on this part.'), TutorEmotion.focused);
    });

    test('returns neutral when nothing matches', () {
      expect(emotionFromText('Hello there.'), TutorEmotion.neutral);
      expect(emotionFromText(''), TutorEmotion.neutral);
    });
  });

  group('emotionFromAmplitude', () {
    test('overrides neutral→happy on high amplitude', () {
      expect(emotionFromAmplitude(0.9, TutorEmotion.neutral),
          TutorEmotion.happy);
    });

    test('overrides neutral→thinking on low amplitude', () {
      expect(emotionFromAmplitude(0.05, TutorEmotion.neutral),
          TutorEmotion.thinking);
    });

    test('preserves non-neutral base regardless of amplitude', () {
      expect(emotionFromAmplitude(0.9, TutorEmotion.happy),
          TutorEmotion.happy);
      expect(emotionFromAmplitude(0.05, TutorEmotion.encouraging),
          TutorEmotion.encouraging);
    });

    test('keeps neutral in the mid-range', () {
      expect(emotionFromAmplitude(0.4, TutorEmotion.neutral),
          TutorEmotion.neutral);
    });
  });

  group('kDefaultEmotionMappings', () {
    test('covers at least one keyword per non-neutral emotion', () {
      final emotions = kDefaultEmotionMappings.map((m) => m.emotion).toSet();
      for (final e in TutorEmotion.values) {
        if (e == TutorEmotion.neutral || e == TutorEmotion.waiting) continue;
        expect(emotions, contains(e),
            reason: '$e should have at least one keyword mapping');
      }
    });
  });
}
