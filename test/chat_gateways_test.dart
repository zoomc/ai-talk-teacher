import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/core/runtime/simulation_runtime.dart';
import 'package:speakflow/features/chat/data/chat_gateways.dart';
import 'package:speakflow/features/chat/data/llm_service.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';

void main() {
  const history = <ChatMessage>[];

  test(
    'simulation LLM streams correction content through the production parser',
    () async {
      final runtime = SimulationRuntime()..selectFixture('grammar_correction');
      final gateway = SimulationLlmGateway(runtime);
      final chunks = await gateway
          .streamMessage(history: history, systemPrompt: 'coach')
          .toList();
      final content = chunks.map((chunk) => chunk.delta).join();
      final corrections = gateway.extractCorrections(
        '$content\n```corrections\n${chunks.last.correctionsJson ?? '[]'}\n```',
      );
      expect(content, contains('went to the park'));
      expect(corrections, hasLength(1));
      expect(corrections.single.importance, 90);
      expect(runtime.turnIndex, 0);
    },
  );

  test(
    'simulation LLM retry fixture fails once without advancing the turn',
    () async {
      final runtime = SimulationRuntime()..selectFixture('llm_retry');
      final gateway = SimulationLlmGateway(runtime);
      await expectLater(
        gateway.streamMessage(history: history, systemPrompt: 'coach').toList(),
        throwsA(isA<LlmException>()),
      );
      expect(runtime.turnIndex, 0);
      final chunks = await gateway
          .streamMessage(history: history, systemPrompt: 'coach')
          .toList();
      expect(chunks.last.done, isTrue);
    },
  );

  test(
    'simulation STT/TTS need no profile and TTS returns local WAV',
    () async {
      final runtime = SimulationRuntime();
      final stt = SimulationSttGateway(runtime);
      final tts = SimulationTtsGateway(runtime);
      expect(await stt.transcribe(Uint8List(0)), isNotEmpty);
      final audio = await tts.synthesize('hello');
      expect(String.fromCharCodes(audio.sublist(0, 4)), 'RIFF');
      expect(tts.visemesFor('hello'), isNotNull);
    },
  );
}
