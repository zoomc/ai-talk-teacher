import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/runtime/runtime_capabilities.dart';
import '../core/runtime/runtime_config.dart';
import '../core/runtime/simulation_runtime.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/domain/profile_models.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/data/chat_gateways.dart';
import '../features/project_space/data/project_repository.dart';

final profileRepoProvider = Provider((ref) => ProfileRepository());
final chatRepoProvider = Provider((ref) => ChatRepository());
final projectRepoProvider = Provider((ref) => ProjectRepository());

final runtimeConfigProvider = Provider((ref) => RuntimeConfig.mode);

final runtimeCapabilitiesProvider = Provider<RuntimeCapabilities>(
  (ref) => RuntimeCapabilities.forConfig(),
);

final simulationRuntimeProvider = Provider<SimulationRuntime>(
  (ref) => SimulationRuntime(),
);

/// The fixture picker is intentionally only read by Demo UI and Simulation
/// gateways. It is not a runtime switch: changing it cannot turn Production
/// into Demo because APP_MODE is compile-time fixed.
final simulationFixtureProvider = StateProvider<String>(
  (ref) => SimulationFixtures.happyPath.id,
);

final llmGatewayProvider = Provider<LlmGateway>((ref) {
  final runtime = ref.watch(simulationRuntimeProvider);
  final fixtureId = ref.watch(simulationFixtureProvider);
  if (runtime.fixture.id != fixtureId) runtime.selectFixture(fixtureId);
  return ChatGatewayFactory.llm(ref.watch(profileRepoProvider), runtime);
});

final sttGatewayProvider = Provider<SttGateway>((ref) {
  final runtime = ref.watch(simulationRuntimeProvider);
  final fixtureId = ref.watch(simulationFixtureProvider);
  if (runtime.fixture.id != fixtureId) runtime.selectFixture(fixtureId);
  return ChatGatewayFactory.stt(ref.watch(profileRepoProvider), runtime);
});

final ttsGatewayProvider = Provider<TtsGateway>((ref) {
  final runtime = ref.watch(simulationRuntimeProvider);
  final fixtureId = ref.watch(simulationFixtureProvider);
  if (runtime.fixture.id != fixtureId) runtime.selectFixture(fixtureId);
  return ChatGatewayFactory.tts(ref.watch(profileRepoProvider), runtime);
});

/// Global theme mode state. Initialized in main() from the persisted
/// `theme` user setting (via ProviderScope.overrides) so the very first
/// frame uses the user's saved preference. The settings screen updates
/// this provider when the user picks a new theme — MaterialApp rebuilds
/// immediately, no app restart needed (P1-8).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Global interface-locale state. Initialized in main() with the
/// resolution: persisted `app_language` setting > browser language
/// (auto-detected on web) > `AppLocale.zh` (spec: "如果检测不到就是默认
/// 中文"). The settings screen updates this provider when the user picks
/// a language — MaterialApp rebuilds immediately with the new locale.
final localeProvider = StateProvider<AppLocale>((ref) => AppLocale.zh);

/// Phase-1 P0 #8 — global low-bandwidth mode. When true, heavy visual
/// effects (3D Live2D avatar, ambient ripples, etc.) are suppressed to
/// save data + battery on metered / slow connections. Initialized in main()
/// from the persisted `low_bandwidth` setting so the first frame already
/// respects the user's choice; the settings screen flips this and the
/// chat panel rebuilds to drop the avatar.
final lowBandwidthProvider = StateProvider<bool>((ref) => false);

/// BL-077 — active service profiles. Consumers that depend on the current
/// LLM / STT / TTS profile can watch these providers; activating a
/// different profile in ServiceConfigScreen invalidates them so the UI
/// and services pick up the new active profile on the next request.
final activeLlmProfileProvider = FutureProvider<LlmProfile?>((ref) async {
  final repo = ref.watch(profileRepoProvider);
  return repo.getActiveLlmProfile();
});

final activeSttProfileProvider = FutureProvider<SttProfile?>((ref) async {
  final repo = ref.watch(profileRepoProvider);
  return repo.getActiveSttProfile();
});

final activeTtsProfileProvider = FutureProvider<TtsProfile?>((ref) async {
  final repo = ref.watch(profileRepoProvider);
  return repo.getActiveTtsProfile();
});
