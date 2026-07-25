// Web-only E2E mock services.
//
// When `--dart-define=E2E=true` is passed and `mockModeEnabled` is true
// (toggled via `window.speakflowE2E.setMockMode(true)`), these getters
// return canned LLM/STT/TTS responses so the services never issue HTTP.
//
// When `kE2E` is false (production build), this file is tree-shaken away.
// When `kE2E` is true but `mockModeEnabled` is false, getters return null
// and services proceed with real HTTP.

// Use a prefix import to avoid name collision with the static methods below.
import 'e2e_bridge_web.dart' as bridge
    show cannedLlmReply, cannedSttTranscript, cannedTtsAudioBase64, mockModeEnabled;

/// Web-only E2E mock services. Returns canned responses when mock mode is on.
class E2eMockServices {
  /// Whether mock mode is enabled (E2E flag + runtime toggle).
  static bool get enabled => bridge.mockModeEnabled;

  /// Returns a canned LLM reply for the given prompt, or null if mock
  /// mode is off.
  static String? cannedLlmReply(String prompt) =>
      bridge.mockModeEnabled ? bridge.cannedLlmReply(prompt) : null;

  /// Returns the canned STT transcript, or null if mock mode is off.
  static String? get cannedSttTranscript =>
      bridge.mockModeEnabled ? bridge.cannedSttTranscript : null;

  /// Returns the canned TTS audio bytes (base64), or null if mock mode is off.
  static String? get cannedTtsAudioBase64 =>
      bridge.mockModeEnabled ? bridge.cannedTtsAudioBase64 : null;
}
