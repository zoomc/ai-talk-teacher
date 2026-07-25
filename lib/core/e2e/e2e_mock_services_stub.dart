// No-op stub for non-web platforms / non-E2E builds.
//
// All canned-response getters return null, signaling to services that
// they should proceed with real HTTP calls.
/// E2E mock services stub. Returns nulls (no mocking) on non-web / non-E2E.
class E2eMockServices {
  /// Whether mock mode is enabled (always false on non-web).
  static bool get enabled => false;

  /// Returns a canned LLM reply for the given prompt, or null.
  static String? cannedLlmReply(String prompt) => null;

  /// Returns the canned STT transcript, or null.
  static String? get cannedSttTranscript => null;

  /// Returns the canned TTS audio bytes (base64), or null.
  static String? get cannedTtsAudioBase64 => null;
}
