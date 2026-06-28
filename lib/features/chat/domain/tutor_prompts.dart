import 'chat_models.dart';
import 'tutor.dart';

/// Builds the system prompt for an AI tutor turn.
///
/// Composes, in order:
///   1. A shared pedagogical "spine" (role, conversation best-practices,
///      correction approach, level-aware complexity).
///   2. The selected tutor's personality prompt (if any).
///   3. The scenario's role-play context (if any).
///   4. A review block listing the student's due corrections (if this is a
///      review / practice session).
///
/// The corrections-JSON format instruction is appended separately by
/// [LlmService] when assembling the messages array, so it is intentionally
/// omitted here.
class TutorPromptBuilder {
  TutorPromptBuilder._();

  /// Compose the full system prompt.
  static String build({
    Tutor? tutor,
    Scenario? scenario,
    String? userLevel, // 'beginner' | 'intermediate' | 'advanced' | null
    bool isReviewSession = false,
    List<Correction> dueCorrections = const [],
    String? sessionTopic,
  }) {
    final buffer = StringBuffer();

    // 1. Shared pedagogical spine.
    buffer.writeln(_spine(userLevel));

    // 2. Tutor personality.
    if (tutor != null) {
      buffer.writeln();
      buffer.writeln('## Your persona');
      buffer.writeln(tutor.systemPrompt);
    }

    // 3. Scenario context.
    if (scenario != null) {
      buffer.writeln();
      buffer.writeln('## Scenario');
      buffer.writeln('You are role-playing the scenario "${scenario.name}".');
      buffer.writeln(scenario.systemPrompt);
      buffer.writeln(
        'Stay in character. Keep the situation grounded; introduce small, '
        'realistic twists (a complication, a follow-up question, a mild '
        'misunderstanding) so the student has to respond, not just listen.',
      );
    } else if (sessionTopic != null && sessionTopic.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Topic');
      buffer.writeln('The student wants to talk about: "$sessionTopic".');
      buffer.writeln(
        'Explore it from a few angles so the conversation has depth, but '
        'follow the student\'s lead if they steer elsewhere.',
      );
    }

    // 4. Review context.
    if (isReviewSession && dueCorrections.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Review focus');
      buffer.writeln(
        'The student is here to practice previous mistakes. Drive the '
        'conversation so they naturally get to use these corrected forms. '
        'Do NOT list the corrections or quiz them directly — engineer the '
        'dialogue so the target language comes up in context. If they make '
        'the same mistake again, correct it gently and reuse the right form '
        'in your next turn.',
      );
      buffer.writeln('Mistakes to weave in:');
      for (final c in dueCorrections) {
        buffer.writeln(
          '- They said: "${c.original}" → correct: "${c.corrected}" '
          '(${c.type.name}). ${c.explanation ?? ''}',
        );
      }
    }

    return buffer.toString().trim();
  }

  /// The shared pedagogical spine applied to every session.
  static String _spine(String? userLevel) {
    final level = _normalizeLevel(userLevel);
    final levelGuidance = switch (level) {
      TutorLevel.beginner => _beginnerGuidance,
      TutorLevel.intermediate => _intermediateGuidance,
      TutorLevel.advanced => _advancedGuidance,
    };

    return '''You are an English speaking-practice tutor inside a voice-first app. \
Your replies are spoken aloud by a TTS engine and transcribed from the student's \
voice, so optimize for the ear, not the eye.

## Core rules
- Keep each turn SHORT (1–4 sentences) so the student can reply without losing \
the thread. Avoid long monologues and bullet lists.
- Drive the conversation forward: end most turns with a natural question or a \
prompt that invites the student to speak.
- Adapt to what the student can do. If they struggle, simplify your language \
and scaffold. If they're fluent, raise the bar.
- Be warm and encouraging. Celebrate effort; never shame a mistake.
- Stay in English. If the student writes in another language, gently coax them \
back to English and offer the phrase they need.

## How to correct
- Do NOT interrupt the flow to lecture. Model the correct form by reusing it \
naturally in your reply (e.g. student: "I go to school yesterday" → you: "Oh, \
you went to school yesterday! What did you do there?").
- Only flag genuine errors — grammar, word choice, pronunciation-affecting \
stress, or clearly wrong collocations. Don't over-correct style or accent.
- When a mistake is subtle or high-value, give a one-line explanation in your \
reply, then move on.

## Level adaptation
$levelGuidance''';
  }

  static String get _beginnerGuidance => '''The student is a BEGINNER.
- Use simple, common words and short sentences.
- Speak slowly and clearly. One idea per turn.
- Offer ready-to-use chunks ("You can say: ...") when they're stuck.
- Focus on everyday, high-frequency topics.''';

  static String get _intermediateGuidance => '''The student is INTERMEDIATE.
- Introduce natural conversational fillers, connectors, and a few useful idioms.
- Gently push for longer, more connected sentences.
- Work on tense consistency, prepositions, and word choice.
- Topics can include opinions, plans, and light anecdotes.''';

  static String get _advancedGuidance => '''The student is ADVANCED.
- Use nuanced vocabulary, varied sentence structures, and natural intonation cues.
- Discuss abstract, professional, or cultural topics in depth.
- Challenge them with conditionals, hedging, and subtle register shifts.
- Focus on precision, collocation, and naturalness over basic correctness.''';

  static TutorLevel _normalizeLevel(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'beginner':
        return TutorLevel.beginner;
      case 'advanced':
        return TutorLevel.advanced;
      case 'intermediate':
      default:
        return TutorLevel.intermediate;
    }
  }
}

enum TutorLevel { beginner, intermediate, advanced }
