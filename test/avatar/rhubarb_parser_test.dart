import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/avatar/data/rhubarb_parser.dart';
import 'package:speakflow/features/avatar/domain/viseme_mapping.dart';
import 'package:speakflow/features/avatar/domain/viseme_timeline.dart';

const _sampleJson = '''
{
  "metadata": { "soundFile": "tts.wav", "duration": 0.50 },
  "mouthCues": [
    { "start": 0.00, "end": 0.18, "value": "X" },
    { "start": 0.18, "end": 0.30, "value": "G" },
    { "start": 0.30, "end": 0.42, "value": "B" },
    { "start": 0.42, "end": 0.50, "value": "X" }
  ]
}
''';

void main() {
  group('parseRhubarbJson', () {
    test('parses a canonical rhubarb machine-readable output', () {
      final t = parseRhubarbJson(_sampleJson);
      expect(t.duration, closeTo(0.50, 1e-9));
      expect(t.cues.length, 4);
      expect(t.cues[0].start, 0.0);
      expect(t.cues[0].viseme, RhubarbViseme.x);
      expect(t.cues[1].viseme, RhubarbViseme.g);
      expect(t.cues[2].viseme, RhubarbViseme.b);
      expect(t.cues[3].viseme, RhubarbViseme.x);
    });

    test('preserves the audioHash field', () {
      final t = parseRhubarbJson(_sampleJson, audioHash: 'abc123');
      expect(t.audioHash, 'abc123');
    });

    test('returns empty timeline for malformed JSON', () {
      expect(parseRhubarbJson('not json').duration, 0);
      expect(parseRhubarbJson('{ broken').duration, 0);
    });

    test('returns empty timeline for non-object root', () {
      expect(parseRhubarbJson('42').duration, 0);
      expect(parseRhubarbJson('[]').duration, 0);
      expect(parseRhubarbJson('"string"').duration, 0);
    });

    test('falls back to silence cue when mouthCues is missing', () {
      const noCues = '{"metadata": {"duration": 1.5}}';
      final t = parseRhubarbJson(noCues);
      expect(t.duration, 1.5);
      expect(t.cues.length, 1);
      expect(t.cues.first.viseme, RhubarbViseme.x);
    });

    test('derives duration from last cue end when metadata is absent', () {
      const noMeta = '''
{
  "mouthCues": [
    { "start": 0.0, "end": 0.5, "value": "X" },
    { "start": 0.5, "end": 1.2, "value": "A" }
  ]
}
''';
      final t = parseRhubarbJson(noMeta);
      expect(t.duration, closeTo(1.2, 1e-9));
    });

    test('inserts a silence cue when the first cue starts > 0', () {
      const gapFirst = '''
{
  "metadata": {"duration": 1.0},
  "mouthCues": [
    { "start": 0.20, "end": 0.40, "value": "G" }
  ]
}
''';
      final t = parseRhubarbJson(gapFirst);
      expect(t.cues.first.start, 0.0);
      expect(t.cues.first.viseme, RhubarbViseme.x);
      expect(t.cues.length, 2);
    });

    test('skips cues with missing fields', () {
      const withBad = '''
{
  "metadata": {"duration": 1.0},
  "mouthCues": [
    { "start": 0.0, "end": 0.2, "value": "X" },
    { "start": 0.2 },                       // missing value
    { "end": 0.4, "value": "A" },           // missing start
    { "start": "bad", "value": "A" },       // bad start type
    { "start": 0.4, "end": 0.6, "value": "B" }
  ]
}
''';
      final t = parseRhubarbJson(withBad);
      expect(t.cues.length, 3);
      expect(t.cues[0].viseme, RhubarbViseme.x);
      expect(t.cues[1].viseme, RhubarbViseme.a);
      expect(t.cues[2].viseme, RhubarbViseme.b);
    });

    test('sorts out-of-order cues', () {
      const shuffled = '''
{
  "metadata": {"duration": 1.0},
  "mouthCues": [
    { "start": 0.4, "end": 0.6, "value": "B" },
    { "start": 0.0, "end": 0.2, "value": "X" },
    { "start": 0.2, "end": 0.4, "value": "A" }
  ]
}
''';
      final t = parseRhubarbJson(shuffled);
      expect(t.cues[0].start, 0.0);
      expect(t.cues[1].start, 0.2);
      expect(t.cues[2].start, 0.4);
    });
  });

  group('VisemeTimeline', () {
    test('empty factory has zero duration + single silence cue', () {
      expect(VisemeTimeline.empty.duration, 0);
      expect(VisemeTimeline.empty.cues.length, 1);
      expect(VisemeTimeline.empty.cues.first.viseme, RhubarbViseme.x);
    });

    test('hasSpeech is true only when non-silence visemes are present', () {
      expect(VisemeTimeline.empty.hasSpeech, isFalse);
      final silent = VisemeTimeline.silent(1.0);
      expect(silent.hasSpeech, isFalse);
      final spoken = VisemeTimeline(
        cues: [
          const VisemeCue(start: 0, viseme: RhubarbViseme.x),
          const VisemeCue(start: 0.5, viseme: RhubarbViseme.g),
        ],
        duration: 1.0,
      );
      expect(spoken.hasSpeech, isTrue);
    });

    test('cueAt returns the latest cue whose start <= t', () {
      final t = VisemeTimeline(
        cues: [
          const VisemeCue(start: 0, viseme: RhubarbViseme.x),
          const VisemeCue(start: 0.5, viseme: RhubarbViseme.g),
          const VisemeCue(start: 0.8, viseme: RhubarbViseme.b),
        ],
        duration: 1.0,
      );
      expect(t.cueAt(0).viseme, RhubarbViseme.x);
      expect(t.cueAt(0.49).viseme, RhubarbViseme.x);
      expect(t.cueAt(0.5).viseme, RhubarbViseme.g);
      expect(t.cueAt(0.79).viseme, RhubarbViseme.g);
      expect(t.cueAt(0.8).viseme, RhubarbViseme.b);
      expect(t.cueAt(0.95).viseme, RhubarbViseme.b);
      // Past end → still returns the final cue (graceful).
      expect(t.cueAt(2.0).viseme, RhubarbViseme.b);
    });

    test('cueAt returns silence for empty cue list', () {
      final empty = VisemeTimeline(
        cues: const [],
        duration: 1.0,
      );
      expect(empty.cueAt(0.5).viseme, RhubarbViseme.x);
    });

    test('nextCueAfter returns the next cue or null in the final cue', () {
      final t = VisemeTimeline(
        cues: [
          const VisemeCue(start: 0, viseme: RhubarbViseme.x),
          const VisemeCue(start: 0.5, viseme: RhubarbViseme.g),
          const VisemeCue(start: 0.8, viseme: RhubarbViseme.b),
        ],
        duration: 1.0,
      );
      expect(t.nextCueAfter(0), isNotNull);
      expect(t.nextCueAfter(0)!.viseme, RhubarbViseme.g);
      expect(t.nextCueAfter(0.6)!.viseme, RhubarbViseme.b);
      expect(t.nextCueAfter(0.9), isNull);
    });

    test('equality is by content', () {
      final a = VisemeTimeline(
        cues: const [
          VisemeCue(start: 0, viseme: RhubarbViseme.x),
          VisemeCue(start: 0.5, viseme: RhubarbViseme.g),
        ],
        duration: 1.0,
      );
      final b = VisemeTimeline(
        cues: const [
          VisemeCue(start: 0, viseme: RhubarbViseme.x),
          VisemeCue(start: 0.5, viseme: RhubarbViseme.g),
        ],
        duration: 1.0,
      );
      final c = VisemeTimeline(
        cues: const [
          VisemeCue(start: 0, viseme: RhubarbViseme.x),
          VisemeCue(start: 0.5, viseme: RhubarbViseme.b),
        ],
        duration: 1.0,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });
}
