/// Phase-1 P0 #7 — unified voice state.
///
/// A single source of truth for the voice-conversation lifecycle, shared by
/// every screen that drives a voice turn (chat, sentence practice, guest
/// trial, voice-health check). Previously each screen tracked its own ad-hoc
/// bool flags (`_isRecording`, `_isThinking`, …) and CharacterState enum,
/// which produced inconsistent labels / animations for the same phase and
/// made it impossible to add a "transcribing" step between listening and
/// thinking.
///
/// The full flow every turn goes through:
///
///   [idle] → [listening] → [transcribing] → [thinking] → [speaking] → [idle]
///    准备      聆听          转写             思考          播报
///
/// [transcribing] is the moment the recorded audio is being sent to the STT
/// service and turned into text. Splitting it out from "thinking" lets the
/// user see that the network round-trip is happening, not that the LLM is
/// silently stuck.
///
/// The [VoiceStatusIndicator] widget renders one consistent animation + label
/// + colour per phase, so a turn looks identical no matter which screen
/// started it.
enum VoicePhase {
  /// 准备 — idle / waiting for the user to start talking.
  idle,

  /// 聆听 — microphone is capturing the user's speech.
  listening,

  /// 转写 — recorded audio is being sent to / parsed by the STT service.
  transcribing,

  /// 思考 — the LLM is generating the tutor's reply.
  thinking,

  /// 播报 — the TTS audio is being played back to the user.
  speaking,
}

/// Extension helpers so call sites never hardcode phase metadata.
extension VoicePhaseX on VoicePhase {
  /// Whether the phase represents an active, non-idle voice turn. Used by
  /// callers to disable the mic / send button while a turn is in flight.
  bool get isActive => this != VoicePhase.idle;

  /// i18n key for the human-readable label of this phase. Kept here so the
  /// enum stays the single source of truth — adding a phase means updating
  /// exactly one switch.
  String get labelKey => switch (this) {
        VoicePhase.idle => 'chat.ready',
        VoicePhase.listening => 'chat.listening',
        VoicePhase.transcribing => 'chat.transcribing',
        VoicePhase.thinking => 'chat.thinking',
        VoicePhase.speaking => 'chat.speaking',
      };

  /// Stable ordering weight, used to derive a progress fraction across the
  /// turn (0 at idle, 1 at speaking) for the linear progress bar.
  double get progress => switch (this) {
        VoicePhase.idle => 0.0,
        VoicePhase.listening => 0.25,
        VoicePhase.transcribing => 0.5,
        VoicePhase.thinking => 0.75,
        VoicePhase.speaking => 1.0,
      };
}
