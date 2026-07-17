import 'profile_models.dart';
import 'provider_catalog.dart';

/// Phase-1 P0 #1 — one-tap guest trial.
///
/// A brand-new user should be able to experience ~3 minutes of conversation
/// before configuring their own API keys. To make that possible the app ships
/// with a single built-in "guest" triplet of restricted LLM / STT / TTS
/// profiles. These profiles are:
///
///   * Read-only — the user cannot edit or delete them from the profile
///     manager; they only exist to back the guest session.
///   * Rate-limited — the relay they point to enforces a per-IP / per-key
///     quota, so the guest experience degrades gracefully instead of being
///     a free-for-all that could be abused.
///   * Clearly labelled — the profile `name` makes it obvious this is the
///     guest profile, so when the user opens the service-config screen they
///     understand why a profile they didn't create is "active".
///
/// The actual key material lives in [GuestProfileConfig.apiKey]. In production
/// this should point at a self-hosted relay that proxies to the real provider
/// and enforces the rate limit; the value shipped here is a placeholder that
/// the relay rejects, so a stock build fails closed (no silent free access).
class GuestProfileConfig {
  GuestProfileConfig._();

  /// Stable id used as the SQLite primary key for the guest LLM profile.
  /// Kept constant so re-inserting the guest profile is an upsert, not a
  /// duplicate-row insert.
  static const String llmProfileId = '__guest_llm__';
  static const String sttProfileId = '__guest_stt__';
  static const String ttsProfileId = '__guest_tts__';

  /// Snapshot of the user's active profile IDs captured when the guest trial
  /// starts. Persisted so `restoreNonGuestProfiles` can reactivate them when
  /// the trial ends. Null when no guest trial is in progress.
  static ({String? llmId, String? sttId, String? ttsId})? lastNonGuestProfileIds;

  /// Maximum conversation length for a guest trial, in minutes. Enforced by
  /// the chat screen: when a guest session exceeds this it is gently ended
  /// and the user is routed to the post-class summary + onboarding.
  static const int guestTrialMinutes = 3;

  /// Built-in guest LLM profile (read-only, restricted).
  ///
  /// Points at the OpenAI-compatible guest relay. The model name is a small,
  /// cheap, multilingual-capable chat model so the relay cost stays low.
  static LlmProfile get llm => LlmProfile(
        id: llmProfileId,
        name: 'SpeakFlow Guest (restricted)',
        providerId: LlmProviderCatalog.customId,
        baseUrl: GuestProfileConfig.guestLlmBaseUrl,
        apiKey: GuestProfileConfig.guestLlmApiKey,
        model: GuestProfileConfig.guestLlmModel,
        isActive: false,
      );

  /// Built-in guest STT profile. Uses the OpenAI-compatible Whisper surface
  /// exposed by the same guest relay so there's a single host to deploy.
  static SttProfile get stt => SttProfile(
        id: sttProfileId,
        name: 'SpeakFlow Guest STT (restricted)',
        providerId: SttProviderCatalog.customId,
        baseUrl: GuestProfileConfig.guestSttBaseUrl,
        apiKey: GuestProfileConfig.guestSttApiKey,
        model: 'whisper-1',
        language: 'en-US',
        isActive: false,
      );

  /// Built-in guest TTS profile. Same relay host as STT, OpenAI-compatible
  /// /audio/speech surface with the lightweight tts-1 model.
  static TtsProfile get tts => TtsProfile(
        id: ttsProfileId,
        name: 'SpeakFlow Guest TTS (restricted)',
        providerId: TtsProviderCatalog.customId,
        baseUrl: GuestProfileConfig.guestTtsBaseUrl,
        apiKey: GuestProfileConfig.guestTtsApiKey,
        model: 'tts-1',
        voiceId: 'alloy',
        voiceName: 'Alloy',
        speed: 1.0,
        isActive: false,
      );

  // ── Relay configuration ────────────────────────────────────────────────
  //
  // These are intentionally compile-time constants rather than settings so
  // they can be rotated by re-deploying the app. The shipped defaults point
  // at `https://guest.speakflow.app/v1` — a relay that operators stand up
  // alongside the public web build. The placeholder key is rejected by the
  // relay until the operator configures a real upstream key, so a stock
  // build fails closed.

  static const String guestLlmBaseUrl = 'https://guest.speakflow.app/v1';
  static const String guestSttBaseUrl = 'https://guest.speakflow.app/v1';
  static const String guestTtsBaseUrl = 'https://guest.speakflow.app/v1';

  /// Placeholder key — the guest relay accepts this only after an operator
  /// configures a real upstream provider key on the server side. Until then
  /// the relay returns 401 and the guest trial surfaces a friendly
  /// "guest service unavailable" message instead of silently working.
  static const String guestLlmApiKey = 'sf-guest-trial-demo-key';
  static const String guestSttApiKey = 'sf-guest-trial-demo-key';
  static const String guestTtsApiKey = 'sf-guest-trial-demo-key';

  static const String guestLlmModel = 'gpt-4o-mini';

  /// True if [id] is one of the built-in guest profile ids. Used by the
  /// repository to make guest profiles read-only (no edit / delete) and by
  /// the UI to badge them as "Guest".
  static bool isGuestLlmId(String id) => id == llmProfileId;
  static bool isGuestSttId(String id) => id == sttProfileId;
  static bool isGuestTtsId(String id) => id == ttsProfileId;
}
