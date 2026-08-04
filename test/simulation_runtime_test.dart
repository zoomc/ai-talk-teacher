import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/core/runtime/simulation_runtime.dart';
import 'package:speakflow/features/avatar/domain/viseme_mapping.dart';

void main() {
  test('catalog contains the complete deterministic fixture matrix', () {
    final ids = SimulationFixtures.values.map((fixture) => fixture.id).toSet();
    expect(
      ids,
      containsAll(<String>[
        'happy_path',
        'grammar_correction',
        'no_correction',
        'multi_turn',
        'interruption',
        'slow_stream',
        'stt_empty',
        'llm_retry',
        'tts_failure',
        'avatar_failure',
        'review_loop',
        'summary_loop',
      ]),
    );
  });

  test('fixture runtime resets and advances turn state deterministically', () {
    final runtime = SimulationRuntime()..selectFixture('multi_turn');
    expect(runtime.currentTurn.sttText, contains('Kyoto'));
    runtime.llmAttempts = 3;
    runtime.advanceTurn();
    expect(runtime.currentTurn.sttText, contains('temples'));
    expect(runtime.llmAttempts, 0);
    runtime.reset();
    expect(runtime.currentTurn.sttText, contains('Kyoto'));
    expect(runtime.llmAttempts, 0);
  });

  test('local audio has a valid PCM WAV header and viseme timeline', () {
    final bytes = simulationWavFor('hello');
    expect(bytes, isA<Uint8List>());
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    final timeline = simulationVisemesFor('hello');
    expect(timeline.duration, greaterThan(0));
    expect(timeline.cues, isNotEmpty);
    expect(timeline.cues.any((cue) => cue.viseme != RhubarbViseme.x), isTrue);
  });
}
