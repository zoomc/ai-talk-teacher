import 'chat_models.dart';
import 'tutor.dart';

/// Builds the system prompt for an AI tutor turn.
///
/// Composes, in order:
///   1. A shared pedagogical "spine" (role, conversation best-practices,
///      correction approach + the corrections-JSON output contract, level-aware
///      complexity).
///   2. The selected tutor's personality prompt (if any).
///   3. The scenario's role-play context (if any).
///   4. A review block listing the student's due corrections (if this is a
///      review / practice session).
///
/// The corrections-JSON output contract lives INSIDE the spine (not appended
/// separately by [LlmService] each turn). Reasons:
///   - It removes the previous duplicate (spine "How to correct" + LlmService
///     JSON spec said overlapping things and sometimes contradicted each other
///     about whether explanations go inline or in JSON).
///   - Keeping the system prompt byte-identical across turns lets providers
///     that do prefix prompt caching (e.g. DeepSeek) reuse the cached prefix
///     and skip charging for those tokens again.
class TutorPromptBuilder {
  TutorPromptBuilder._();

  /// Compose the full system prompt.
  ///
  /// [correctionStrength] controls how aggressively the tutor flags errors.
  /// Maps to the user-facing "Correction Strength" setting (gentle / moderate /
  /// strict). Defaults to 'moderate'.
  static String build({
    Tutor? tutor,
    Scenario? scenario,
    String? userLevel, // 'beginner' | 'intermediate' | 'advanced' | null
    bool isReviewSession = false,
    List<Correction> dueCorrections = const [],
    String? sessionTopic,
    String correctionStrength = 'moderate',
  }) {
    final buffer = StringBuffer();

    // 1. Shared pedagogical spine (includes correction approach + JSON contract
    //    scaled by correctionStrength).
    buffer.writeln(_spine(userLevel, correctionStrength));

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
  static String _spine(String? userLevel, String correctionStrength) {
    final level = _normalizeLevel(userLevel);
    final levelGuidance = switch (level) {
      TutorLevel.beginner => _beginnerGuidance,
      TutorLevel.intermediate => _intermediateGuidance,
      TutorLevel.advanced => _advancedGuidance,
    };
    final correctionGuidance = _correctionGuidance(correctionStrength);

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
- Do NOT interrupt the flow to lecture, and do NOT speak the explanation aloud. \
Model the correct form by reusing it naturally in your reply (e.g. student: \
"I go to school yesterday" → you: "Oh, you went to school yesterday! What did \
you do there?").
$correctionGuidance
- Put structured error feedback ONLY in the corrections JSON block at the end \
of your reply (see "Output format" below). Keep your spoken reply natural — \
the student will see the structured explanation in the UI card, so you don't \
need to repeat it in speech.

## Output format
Reply in two parts:
1. Your natural spoken reply to the student.
2. (Only if you noticed errors) A fenced corrections block at the very end, \
formatted EXACTLY like this:
```corrections
[
  {"original": "what the student said", "corrected": "correct version", "type": "grammar|vocabulary|pronunciation|fluency", "importance": 75, "explanation": "brief one-line explanation", "skill": "grammar/subject-verb-agreement"}
]
```
- "original" must be a short verbatim snippet of what the student actually \
said (not a paraphrase).
- "type" must be exactly one of: grammar, vocabulary, pronunciation, fluency.
  Use "fluency" for disfluencies, fillers, false starts, and run-on \
  sentences that aren't strictly grammar or word-choice errors.
- "importance" is an integer 0-100 scoring how much this error matters for \
the student's progress right now. 90-100 = errors that block understanding \
or repeat high-frequency patterns; 50-89 = clear errors worth fixing soon; \
0-49 = minor nitpicks. The review list is sorted by this, so be honest and \
reserve 90+ for the errors that genuinely matter most.
- "skill" is a short kebab-case tag identifying the underlying skill point, \
formatted as "<type>/<specific-point>" — e.g. \
"grammar/subject-verb-agreement", "vocabulary/collocation", \
"pronunciation/th-digraph", "fluency/filler-words". Be specific enough that \
the same mistake maps to the same skill tag across turns; the home dashboard \
rolls these up into a per-skill mastery score. Omit the field only when you \
genuinely can't classify the skill point.
- If there were no errors, do NOT include the corrections block at all.
- Keep the block at the END of the reply so the spoken part stays clean.

## Level adaptation
$levelGuidance''';
  }

  /// Strength-specific guidance appended to the "How to correct" section.
  /// Lets the user's "Correction Strength" setting (gentle / moderate / strict)
  /// actually influence tutor behavior. Previously the setting was saved but
  /// never read by the prompt builder.
  static String _correctionGuidance(String strength) {
    switch (strength.toLowerCase()) {
      case 'gentle':
        return '''- GENTLE mode: only flag errors that clearly block understanding. Let minor style, article, and preposition slips go — the goal is to keep the student talking confidently.''';
      case 'strict':
        return '''- STRICT mode: flag every error including minor grammar, word choice, collocation, and preposition issues. Still keep your spoken reply natural and brief — corrections go in the JSON block, not a lecture.''';
      case 'moderate':
      default:
        return '''- MODERATE mode: flag clear grammar, vocabulary, and pronunciation-affecting errors. Skip nitpicks on style or regional accent.''';
    }
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
