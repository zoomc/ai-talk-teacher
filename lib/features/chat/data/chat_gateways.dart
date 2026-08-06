import 'dart:convert';
import 'dart:typed_data';

import '../../../core/runtime/runtime_config.dart';
import '../../../core/runtime/simulation_runtime.dart';
import '../../avatar/domain/viseme_timeline.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/chat_models.dart';
import '../domain/session_summary.dart';
import 'llm_service.dart';
import 'llm_streaming.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import '../../../core/e2e/e2e_mock_services.dart';

/// A recoverable configuration error surfaced by Production gateways.
class GatewayConfigurationException implements Exception {
  final String service;
  const GatewayConfigurationException(this.service);

  @override
  String toString() => '$service provider is not configured';
}

abstract interface class LlmGateway {
  Stream<StreamChunk> streamMessage({
    required List<ChatMessage> history,
    required String systemPrompt,
    String? userMessage,
  });

  List<Correction> extractCorrections(String content);

  Future<SessionSummary> generateSummary({
    required String sessionId,
    required List<ChatMessage> history,
    required List<Correction> corrections,
  });
}

abstract interface class SttGateway {
  Future<String> transcribe(Uint8List audioData);
}

abstract interface class TtsGateway {
  Future<Uint8List> synthesize(String text);

  VisemeTimeline? visemesFor(String text) => null;
}

class ProductionLlmGateway implements LlmGateway {
  final ProfileRepository profiles;
  const ProductionLlmGateway(this.profiles);

  Future<LlmService> _service() async {
    final profile = await profiles.getActiveLlmProfile();
    if (profile == null) throw const GatewayConfigurationException('LLM');
    return LlmService(profile);
  }

  @override
  Stream<StreamChunk> streamMessage({
    required List<ChatMessage> history,
    required String systemPrompt,
    String? userMessage,
  }) async* {
    final service = await _service();
    yield* service.streamMessage(
      history: history,
      systemPrompt: systemPrompt,
      userMessage: userMessage,
    );
  }

  @override
  List<Correction> extractCorrections(String content) =>
      LlmService.parseCorrections(content);

  @override
  Future<SessionSummary> generateSummary({
    required String sessionId,
    required List<ChatMessage> history,
    required List<Correction> corrections,
  }) async {
    final service = await _service();
    return service.generateSummary(
      sessionId: sessionId,
      history: history,
      corrections: corrections,
    );
  }
}

class SimulationLlmGateway implements LlmGateway {
  final SimulationRuntime runtime;
  const SimulationLlmGateway(this.runtime);

  @override
  Stream<StreamChunk> streamMessage({
    required List<ChatMessage> history,
    required String systemPrompt,
    String? userMessage,
  }) async* {
    runtime.llmAttempts++;
    if (runtime.fixture.id == 'llm_retry' && runtime.llmAttempts == 1) {
      throw LlmException('Simulation transient LLM failure');
    }

    // E2E tests can override one turn through the bridge while retaining the
    // fixture for all other turns. The latest user text is the stable key
    // because the chat screen already persists it in history before calling
    // the gateway.
    final latestUserMessage = history.reversed
        .where((message) => message.role == MessageRole.user)
        .firstOrNull
        ?.content;
    final override = E2eMockServices.cannedLlmOverride(
      userMessage ?? latestUserMessage ?? systemPrompt,
    );
    if (override != null) {
      yield StreamChunk(delta: override);
      yield const StreamChunk(done: true);
      return;
    }

    final turn = runtime.currentTurn;
    for (final chunk in turn.llmChunks) {
      await simulationDelay(turn.chunkDelay);
      yield StreamChunk(delta: chunk);
    }
    yield StreamChunk(
      done: true,
      correctionsJson: turn.corrections.isEmpty
          ? null
          : _encodeCorrections(turn.corrections),
      emotionId: turn.emotion,
      gestureId: turn.gesture,
    );
    runtime.advanceTurn();
  }

  @override
  List<Correction> extractCorrections(String content) =>
      LlmService.parseCorrections(content);

  @override
  Future<SessionSummary> generateSummary({
    required String sessionId,
    required List<ChatMessage> history,
    required List<Correction> corrections,
  }) async {
    await simulationDelay(const Duration(milliseconds: 180));
    return SessionSummary(
      sessionId: sessionId,
      highlights:
          'You kept the conversation moving and expressed your ideas clearly.',
      improvements: [
        corrections.isEmpty
            ? 'Try one new transition phrase in your next turn.'
            : 'Review the most important correction once more.',
        'Add one detail to each answer to make it easier to continue the conversation.',
        'Use a short pause before a difficult sentence so your pronunciation stays clear.',
      ],
      nextSentence:
          'Next time, I would like to explain my idea in more detail.',
    );
  }

  String _encodeCorrections(List<Map<String, dynamic>> corrections) {
    // The production parser accepts the same JSON contract. Keep encoding in
    // the gateway so Demo never bypasses CorrectionRepository.
    return '[${corrections.map(_encodeCorrection).join(',')}]';
  }

  String _encodeCorrection(Map<String, dynamic> correction) {
    final fields = <String>[];
    for (final entry in correction.entries) {
      final value = entry.value;
      fields.add(
        '${jsonEncode(entry.key)}:${value is num ? value : jsonEncode(value.toString())}',
      );
    }
    return '{${fields.join(',')}}';
  }
}

class ProductionSttGateway implements SttGateway {
  final ProfileRepository profiles;
  const ProductionSttGateway(this.profiles);

  @override
  Future<String> transcribe(Uint8List audioData) async {
    final profile = await profiles.getActiveSttProfile();
    if (profile == null) throw const GatewayConfigurationException('STT');
    return SttService(profile).transcribe(audioData);
  }
}

class SimulationSttGateway implements SttGateway {
  final SimulationRuntime runtime;
  const SimulationSttGateway(this.runtime);

  @override
  Future<String> transcribe(Uint8List audioData) async {
    await simulationDelay(runtime.currentTurn.sttDelay);
    return runtime.currentTurn.sttText;
  }
}

class ProductionTtsGateway implements TtsGateway {
  final ProfileRepository profiles;
  const ProductionTtsGateway(this.profiles);

  @override
  Future<Uint8List> synthesize(String text) async {
    final profile = await profiles.getActiveTtsProfile();
    if (profile == null) throw const GatewayConfigurationException('TTS');
    return TtsService(profile).synthesize(text);
  }

  @override
  VisemeTimeline? visemesFor(String text) => null;
}

class SimulationTtsGateway implements TtsGateway {
  final SimulationRuntime runtime;
  const SimulationTtsGateway(this.runtime);

  @override
  Future<Uint8List> synthesize(String text) async {
    final turn = runtime.fixture.turns.firstWhere(
      (value) => value.ttsFails,
      orElse: () => runtime.currentTurn,
    );
    await simulationDelay(turn.ttsDelay);
    if (runtime.fixture.id == 'tts_failure' || turn.ttsFails) {
      throw TtsException('Simulation TTS failure (subtitles remain available)');
    }
    return simulationWavFor(text);
  }

  @override
  VisemeTimeline visemesFor(String text) => simulationVisemesFor(text);
}

/// Compile-time provider selection. Pages depend on these abstractions, not
/// on whether the current build uses a real Provider or a fixture.
class ChatGatewayFactory {
  static LlmGateway llm(
    ProfileRepository profiles,
    SimulationRuntime runtime,
  ) => RuntimeConfig.isSimulation
      ? SimulationLlmGateway(runtime)
      : ProductionLlmGateway(profiles);

  static SttGateway stt(
    ProfileRepository profiles,
    SimulationRuntime runtime,
  ) => RuntimeConfig.isSimulation
      ? SimulationSttGateway(runtime)
      : ProductionSttGateway(profiles);

  static TtsGateway tts(
    ProfileRepository profiles,
    SimulationRuntime runtime,
  ) => RuntimeConfig.isSimulation
      ? SimulationTtsGateway(runtime)
      : ProductionTtsGateway(profiles);
}
