/// Emotion-driven tutor expression model.
///
/// P1 task 5 — Emotion-driven 表情. The 2D tutor's expression is driven by
/// two signals:
///   1. TTS amplitude stream (already exposed by [TtsPlaybackService]) —
///      high amplitude → happy / encouraging; low + sustained → thinking.
///   2. Keyword triggers detected in the AI reply text — e.g. "Great job!"
///      → happy; "Hmm, let me think..." → thinking; "Can you repeat that?"
///      → confused.
///
/// The keyword → emotion mapping table is configurable via [EmotionMapping],
/// so tutors with different personalities can ship different mapping files
/// without touching the widget code.
library;

/// The six base tutor emotions. Each maps to a distinct facial expression
/// drawn by [VirtualCharacter] (or the 3D avatar) and to a state-pill colour.
enum TutorEmotion {
  /// Default — gentle smile, relaxed posture.
  neutral,
  /// Praising / celebrating a correct answer.
  happy,
  /// Considering the user's reply before responding.
  thinking,
  /// Encouraging the user to keep going after a mistake.
  encouraging,
  /// Didn't catch or understand the user — asks for clarification.
  confused,
  /// Deep focus on a hard correction or pronunciation breakdown.
  focused,
}

/// Extension helpers for [TutorEmotion] so widgets can pick colours and
/// labels without a switch statement at every call site.
extension TutorEmotionX on TutorEmotion {
  /// Whether this emotion should pulse the tutor's glow while active.
  bool get isActive => this != TutorEmotion.neutral;

  /// Stable id used to persist the user's custom keyword map.
  String get id {
    switch (this) {
      case TutorEmotion.neutral:
        return 'neutral';
      case TutorEmotion.happy:
        return 'happy';
      case TutorEmotion.thinking:
        return 'thinking';
      case TutorEmotion.encouraging:
        return 'encouraging';
      case TutorEmotion.confused:
        return 'confused';
      case TutorEmotion.focused:
        return 'focused';
    }
  }
}

/// A single keyword → emotion rule. The first matching rule (in declaration
/// order) wins, so specific phrases should be listed before generic ones.
class EmotionMapping {
  final String keyword;
  final TutorEmotion emotion;

  const EmotionMapping({required this.keyword, required this.emotion});
}

/// Default keyword → emotion table. Tutors can override this via their
/// [Tutor] profile (future work); for now it ships as a single shared map.
///
/// Keywords are matched case-insensitively as substrings of the AI reply.
/// Order matters — the first hit wins, so specific multi-word phrases
/// (like "great job") must precede single-word triggers ("great").
const List<EmotionMapping> kDefaultEmotionMappings = [
  EmotionMapping(keyword: 'great job', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'well done', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'excellent', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'perfect', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'awesome', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'amazing', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'fantastic', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'good job', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'nice work', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'wonderful', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'great', emotion: TutorEmotion.happy),
  EmotionMapping(keyword: 'keep going', emotion: TutorEmotion.encouraging),
  EmotionMapping(keyword: 'keep practicing', emotion: TutorEmotion.encouraging),
  EmotionMapping(keyword: "don't give up", emotion: TutorEmotion.encouraging),
  EmotionMapping(keyword: "don't worry", emotion: TutorEmotion.encouraging),
  EmotionMapping(keyword: 'almost', emotion: TutorEmotion.encouraging),
  EmotionMapping(keyword: 'let me think', emotion: TutorEmotion.thinking),
  EmotionMapping(keyword: 'hmm', emotion: TutorEmotion.thinking),
  EmotionMapping(keyword: 'let me see', emotion: TutorEmotion.thinking),
  EmotionMapping(keyword: 'thinking', emotion: TutorEmotion.thinking),
  EmotionMapping(keyword: 'can you repeat', emotion: TutorEmotion.confused),
  EmotionMapping(keyword: 'i didn\'t catch', emotion: TutorEmotion.confused),
  EmotionMapping(keyword: 'pardon', emotion: TutorEmotion.confused),
  EmotionMapping(keyword: 'sorry, what', emotion: TutorEmotion.confused),
  EmotionMapping(keyword: 'focus on', emotion: TutorEmotion.focused),
  EmotionMapping(keyword: 'pay attention', emotion: TutorEmotion.focused),
  EmotionMapping(keyword: 'let\'s work on', emotion: TutorEmotion.focused),
  EmotionMapping(keyword: 'practice this', emotion: TutorEmotion.focused),
];

/// Resolve the dominant emotion for an AI reply by scanning [text] against
/// [mappings]. Returns [TutorEmotion.neutral] when no keyword matches —
/// which is the correct default for short conversational replies.
TutorEmotion emotionFromText(
  String text, {
  List<EmotionMapping> mappings = kDefaultEmotionMappings,
}) {
  if (text.isEmpty) return TutorEmotion.neutral;
  final lower = text.toLowerCase();
  for (final rule in mappings) {
    if (lower.contains(rule.keyword)) return rule.emotion;
  }
  return TutorEmotion.neutral;
}

/// Map a TTS amplitude level (0..1) to an emotion override. Used while TTS
/// is playing to add micro-expression on top of the keyword-derived base.
/// High sustained amplitude → happy; very low → thinking; otherwise the
/// keyword-derived emotion is preserved.
TutorEmotion emotionFromAmplitude(double amplitude, TutorEmotion base) {
  if (base == TutorEmotion.neutral) {
    if (amplitude > 0.7) return TutorEmotion.happy;
    if (amplitude < 0.15) return TutorEmotion.thinking;
  }
  return base;
}
