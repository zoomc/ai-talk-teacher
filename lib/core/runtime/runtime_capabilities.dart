import 'runtime_config.dart';

/// Mode-level capabilities exposed to UI and controllers.
///
/// Provider readiness is still checked at request time in Production. In
/// Simulation, all AI capabilities are deterministic and require no profile.
final class RuntimeCapabilities {
  final bool llmReady;
  final bool sttReady;
  final bool ttsReady;
  final bool recordingReady;
  final bool avatarReady;
  final bool requiresConfiguration;
  final bool supportsStreaming;
  final bool supportsViseme;
  final bool supportsAudioAmplitude;
  final bool externalNetworkAllowed;

  const RuntimeCapabilities({
    required this.llmReady,
    required this.sttReady,
    required this.ttsReady,
    required this.recordingReady,
    required this.avatarReady,
    required this.requiresConfiguration,
    required this.supportsStreaming,
    required this.supportsViseme,
    required this.supportsAudioAmplitude,
    required this.externalNetworkAllowed,
  });

  factory RuntimeCapabilities.forConfig() {
    if (RuntimeConfig.isSimulation) {
      return const RuntimeCapabilities(
        llmReady: true,
        sttReady: true,
        ttsReady: true,
        recordingReady: true,
        avatarReady: true,
        requiresConfiguration: false,
        supportsStreaming: true,
        supportsViseme: true,
        supportsAudioAmplitude: true,
        externalNetworkAllowed: false,
      );
    }
    return const RuntimeCapabilities(
      llmReady: false,
      sttReady: false,
      ttsReady: false,
      recordingReady: true,
      avatarReady: true,
      requiresConfiguration: true,
      supportsStreaming: true,
      supportsViseme: true,
      supportsAudioAmplitude: true,
      externalNetworkAllowed: true,
    );
  }
}
