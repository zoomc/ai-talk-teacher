import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../features/avatar/domain/viseme_mapping.dart';
import '../../features/avatar/domain/viseme_timeline.dart';

/// A deterministic business fixture. It describes events rather than merely
/// returning a string, so Demo exercises the same persistence and parsing
/// paths as Production.
class SimulationTurn {
  final String sttText;
  final Duration sttDelay;
  final List<String> llmChunks;
  final Duration chunkDelay;
  final List<Map<String, dynamic>> corrections;
  final String emotion;
  final String gesture;
  final Duration ttsDelay;
  final bool ttsFails;

  const SimulationTurn({
    required this.sttText,
    required this.llmChunks,
    this.sttDelay = Duration.zero,
    this.chunkDelay = const Duration(milliseconds: 120),
    this.corrections = const [],
    this.emotion = 'encouraging',
    this.gesture = 'gentle_nod',
    this.ttsDelay = const Duration(milliseconds: 100),
    this.ttsFails = false,
  });

  String get responseText => llmChunks.join();
}

class SimulationFixture {
  final String id;
  final String title;
  final List<SimulationTurn> turns;

  const SimulationFixture({
    required this.id,
    required this.title,
    required this.turns,
  });
}

/// Shared state for Simulation LLM/STT/TTS gateways.
class SimulationRuntime {
  SimulationFixture fixture = SimulationFixtures.happyPath;
  int turnIndex = 0;
  int llmAttempts = 0;

  void selectFixture(String id) {
    fixture = SimulationFixtures.byId(id);
    turnIndex = 0;
    llmAttempts = 0;
  }

  SimulationTurn get currentTurn =>
      fixture.turns[math.min(turnIndex, fixture.turns.length - 1)];

  void advanceTurn() {
    if (turnIndex < fixture.turns.length - 1) {
      turnIndex++;
      llmAttempts = 0;
    }
  }

  void reset() {
    turnIndex = 0;
    llmAttempts = 0;
  }
}

abstract final class SimulationFixtures {
  static const happyPath = SimulationFixture(
    id: 'happy_path',
    title: 'Normal free conversation',
    turns: [
      SimulationTurn(
        sttText: 'I went to a small cafe near my office yesterday.',
        llmChunks: ['That sounds lovely! ', 'What did you order at the cafe?'],
      ),
    ],
  );

  static const grammarCorrection = SimulationFixture(
    id: 'grammar_correction',
    title: 'Grammar correction',
    turns: [
      SimulationTurn(
        sttText: 'Yesterday I go to the park.',
        llmChunks: [
          'That sounds like a nice day! ',
          'A more natural sentence is: Yesterday I went to the park.',
        ],
        corrections: [
          {
            'type': 'grammar',
            'original': 'Yesterday I go to the park.',
            'corrected': 'Yesterday I went to the park.',
            'explanation': 'Use the past tense after “yesterday.”',
            'importance': 90,
            'skill': 'past-tense',
          },
        ],
      ),
    ],
  );

  static const multiTurn = SimulationFixture(
    id: 'multi_turn',
    title: 'Three-turn conversation',
    turns: [
      SimulationTurn(
        sttText: 'I am planning a trip to Kyoto.',
        llmChunks: [
          'Kyoto is beautiful. ',
          'What would you like to see there?',
        ],
      ),
      SimulationTurn(
        sttText: 'I want to visit old temples and try local food.',
        llmChunks: [
          'That sounds delicious. ',
          'Which dish are you most curious about?',
        ],
      ),
      SimulationTurn(
        sttText: 'I would love to try ramen and matcha desserts.',
        llmChunks: [
          'Great choices! ',
          'You will have plenty to talk about on your trip.',
        ],
      ),
    ],
  );

  static const noCorrection = SimulationFixture(
    id: 'no_correction',
    title: 'No correction needed',
    turns: [
      SimulationTurn(
        sttText: 'I have been practicing a little every day.',
        llmChunks: [
          'That consistency is excellent. ',
          'What feels easier now than it did last week?',
        ],
      ),
    ],
  );

  static const slowStream = SimulationFixture(
    id: 'slow_stream',
    title: 'Slow streaming response',
    turns: [
      SimulationTurn(
        sttText: 'Can you give me a little advice?',
        chunkDelay: Duration(milliseconds: 550),
        llmChunks: [
          'Of course. ',
          'Take a breath, ',
          'speak clearly, ',
          'and trust your ideas.',
        ],
      ),
    ],
  );

  static const interruption = SimulationFixture(
    id: 'interruption',
    title: 'Interrupt a long answer',
    turns: [
      SimulationTurn(
        sttText: 'Tell me a longer story so I can interrupt you.',
        chunkDelay: Duration(milliseconds: 650),
        llmChunks: [
          'Here is a longer answer. ',
          'I will keep speaking for a moment, ',
          'but you can press stop whenever you want. ',
          'The next turn should still be safe to start.',
        ],
      ),
    ],
  );

  static const llmRetry = SimulationFixture(
    id: 'llm_retry',
    title: 'Transient LLM failure and retry',
    turns: [
      SimulationTurn(
        sttText: 'Please make the first answer attempt fail once.',
        llmChunks: [
          'The retry recovered cleanly. ',
          'Which part of the conversation should we continue?',
        ],
      ),
    ],
  );

  static const avatarFailure = SimulationFixture(
    id: 'avatar_failure',
    title: 'Avatar fallback state',
    turns: [
      SimulationTurn(
        sttText: 'Show the conversation even if the avatar renderer fails.',
        llmChunks: [
          'The conversation remains usable. ',
          'The tutor can fall back to the lightweight 2D renderer.',
        ],
      ),
    ],
  );

  static const reviewLoop = SimulationFixture(
    id: 'review_loop',
    title: 'Correction into review',
    turns: [
      SimulationTurn(
        sttText: 'Yesterday I go to the market and buyed some fruit.',
        llmChunks: [
          'Nice story. ',
          'A more natural version is: Yesterday I went to the market and bought some fruit.',
        ],
        corrections: [
          {
            'type': 'grammar',
            'original': 'Yesterday I go to the market and buyed some fruit.',
            'corrected':
                'Yesterday I went to the market and bought some fruit.',
            'explanation': 'Use irregular past-tense forms for both verbs.',
            'importance': 95,
            'skill': 'past-tense',
          },
        ],
      ),
    ],
  );

  static const summaryLoop = SimulationFixture(
    id: 'summary_loop',
    title: 'Three turns into summary',
    turns: [
      SimulationTurn(
        sttText: 'I want to become more confident at work.',
        llmChunks: ['That is a useful goal. ', 'What situation feels hardest?'],
      ),
      SimulationTurn(
        sttText: 'Speaking up in meetings is the hardest part.',
        llmChunks: [
          'Try preparing one sentence in advance. ',
          'What could you say first?',
        ],
      ),
      SimulationTurn(
        sttText: 'I could share one small update before asking a question.',
        llmChunks: [
          'That is a strong plan. ',
          'Small, repeatable steps build confidence.',
        ],
        corrections: [
          {
            'type': 'fluency',
            'original':
                'I could share one small update before asking a question.',
            'corrected':
                'I could share a small update before asking a question.',
            'explanation':
                'The article is optional here, so the shorter phrasing sounds more natural.',
            'importance': 45,
            'skill': 'natural-phrasing',
          },
        ],
      ),
    ],
  );

  static const ttsFailure = SimulationFixture(
    id: 'tts_failure',
    title: 'TTS failure with readable subtitles',
    turns: [
      SimulationTurn(
        sttText: 'Please test a speech failure.',
        llmChunks: ['The subtitles remain available even when audio fails.'],
        ttsFails: true,
      ),
    ],
  );

  static const sttEmpty = SimulationFixture(
    id: 'stt_empty',
    title: 'Empty STT result',
    turns: [
      SimulationTurn(
        sttText: '',
        llmChunks: ['I did not catch that. Please try again.'],
      ),
    ],
  );

  static const values = [
    happyPath,
    grammarCorrection,
    multiTurn,
    noCorrection,
    slowStream,
    interruption,
    llmRetry,
    ttsFailure,
    sttEmpty,
    avatarFailure,
    reviewLoop,
    summaryLoop,
  ];

  static SimulationFixture byId(String id) =>
      values.firstWhere((fixture) => fixture.id == id, orElse: () => happyPath);
}

/// Generates a small, valid PCM WAV without network or third-party audio.
/// This is a real playable audio asset synthesized locally for Demo runs.
Uint8List simulationWavFor(String text) {
  const sampleRate = 16000;
  final seconds = (1.4 + text.length / 55).clamp(1.4, 4.5);
  final sampleCount = (sampleRate * seconds).round();
  final dataSize = sampleCount * 2;
  final bytes = ByteData(44 + dataSize);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final envelope = math.sin(math.pi * (t / seconds)).clamp(0.0, 1.0);
    final syllable = 0.5 + 0.5 * math.sin(t * 8.5);
    final sample =
        (12000 *
                envelope *
                (0.18 + 0.18 * syllable) *
                math.sin(t * (170 + 25 * math.sin(t * 2))))
            .round();
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

VisemeTimeline simulationVisemesFor(String text) {
  final duration = (1.4 + text.length / 55).clamp(1.4, 4.5).toDouble();
  final codes = <RhubarbViseme>[
    RhubarbViseme.x,
    RhubarbViseme.f,
    RhubarbViseme.g,
    RhubarbViseme.h,
    RhubarbViseme.b,
    RhubarbViseme.x,
  ];
  final step = duration / codes.length;
  return VisemeTimeline(
    duration: duration,
    cues: [
      for (var i = 0; i < codes.length; i++)
        VisemeCue(start: i * step, viseme: codes[i]),
    ],
  );
}

Future<void> simulationDelay(Duration delay) async {
  if (delay > Duration.zero) await Future<void>.delayed(delay);
}
