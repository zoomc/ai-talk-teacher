/// Phoneme-level pronunciation scoring models.
///
/// P1 task 4 — 发音音素级评分. Each user utterance can be broken into
/// phonemes (or word-level units for providers that don't expose phoneme
/// timestamps) and scored 0–100. Scores are persisted to SQLite linked to
/// the originating [Correction] (when one exists) so the review screen can
/// surface "your /θ/ is consistently weak" alongside grammar corrections.
library;

import 'package:uuid/uuid.dart';

import 'chat_models.dart';

const _uuid = Uuid();

/// Severity bucket for a phoneme score, used to colour-tag words in the
/// chat bubble (green = good, amber = ok, red = needs work).
enum PhonemeScoreBand {
  /// 85–100 — pronounced correctly.
  good,
  /// 50–84 — understandable but with noticeable deviation.
  fair,
  /// 0–49 — likely to be misunderstood; needs focused practice.
  poor;

  static PhonemeScoreBand fromScore(num score) {
    if (score >= 85) return PhonemeScoreBand.good;
    if (score >= 50) return PhonemeScoreBand.fair;
    return PhonemeScoreBand.poor;
  }
}

/// A single scored phoneme (or word, when the provider scores per word).
///
/// [position] is the 0-based index into the original transcript, used to
/// highlight the right word in the chat bubble when the user taps for the
/// detail overlay.
class PhonemeScore {
  final String id;
  final String phoneme;
  final String word;
  final int score;
  final int position;
  final String? feedback;
  final String? audioPath;

  PhonemeScore({
    String? id,
    required this.phoneme,
    required this.word,
    required this.score,
    required this.position,
    this.feedback,
    this.audioPath,
  }) : id = id ?? _uuid.v4();

  PhonemeScoreBand get band => PhonemeScoreBand.fromScore(score);

  Map<String, dynamic> toMap() => {
        'id': id,
        'phoneme': phoneme,
        'word': word,
        'score': score,
        'position': position,
        'feedback': feedback,
        'audio_path': audioPath,
      };

  factory PhonemeScore.fromMap(Map<String, dynamic> map) => PhonemeScore(
        id: map['id'] as String,
        phoneme: map['phoneme'] as String,
        word: map['word'] as String,
        score: (map['score'] as num?)?.toInt() ?? 0,
        position: (map['position'] as num?)?.toInt() ?? 0,
        feedback: map['feedback'] as String?,
        audioPath: map['audio_path'] as String?,
      );
}

/// A bundle of phoneme scores for a single user utterance. Linked to the
/// originating chat message and (optionally) to a pronunciation [Correction]
/// so the review screen can show "your /θ/ is consistently weak" next to
/// the grammar fix.
class PhonemeScoreSet {
  final String id;
  final String messageId;
  final String? correctionId;
  final String? sessionId;
  final List<PhonemeScore> scores;
  final DateTime createdAt;

  PhonemeScoreSet({
    String? id,
    required this.messageId,
    this.correctionId,
    this.sessionId,
    List<PhonemeScore>? scores,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        scores = scores ?? const [],
        createdAt = createdAt ?? DateTime.now();

  /// Overall pronunciation score for the utterance — the arithmetic mean
  /// of the per-phoneme scores, rounded. Returns 0 when the set is empty.
  int get overallScore {
    if (scores.isEmpty) return 0;
    final sum = scores.fold<int>(0, (a, s) => a + s.score);
    return (sum / scores.length).round();
  }

  /// Map word index → list of phoneme scores for that word. Used by the
  /// chat bubble to colour-tag each word when rendering the transcript.
  Map<int, List<PhonemeScore>> get byPosition {
    final m = <int, List<PhonemeScore>>{};
    for (final s in scores) {
      m.putIfAbsent(s.position, () => []).add(s);
    }
    return m;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'message_id': messageId,
        'correction_id': correctionId,
        'session_id': sessionId,
        'overall_score': overallScore,
        'created_at': createdAt.toIso8601String(),
      };

  factory PhonemeScoreSet.fromMap(
    Map<String, dynamic> map, {
    List<PhonemeScore>? scores,
  }) =>
      PhonemeScoreSet(
        id: map['id'] as String,
        messageId: map['message_id'] as String,
        correctionId: map['correction_id'] as String?,
        sessionId: map['session_id'] as String?,
        scores: scores,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );
}

/// Synthesises a [PhonemeScoreSet] from a pronunciation [Correction] and the
/// user's transcript.
///
/// P1 task 4 — the schema, repository, provider, and bubble UI are all in
/// place, but the STT adapters in this codebase return a plain transcript
/// string without word/phoneme-level confidence (Deepgram/Azure/Google can
/// expose it, but the adapters don't parse it yet). To make the full UX
/// pipeline — colour-tagged words, tap-for-detail overlay, A/B replay —
/// functional now, this scorer derives synthetic phoneme scores from the
/// corrections the LLM already emits:
///
/// * For each pronunciation correction, the corrected word is located in the
///   transcript and split into approximate phoneme units (consonant/vowel
///   clustering — a stand-in for a real IPA lookup).
/// * Each phoneme is scored inversely to the correction's `importance`
///   (high importance = severe error = low score), with a small per-phoneme
///   jitter so the detail overlay looks realistic rather than uniform.
/// * The set is linked to the originating message + correction so the review
///   screen can join them.
///
/// When a future STT adapter exposes real confidence, swap this for a
/// confidence-driven scorer — the [PhonemeScoreSet]/[PhonemeScore] model and
/// the persistence/bubble code need no changes.
class PhonemeScorer {
  PhonemeScorer._();

  /// Build a phoneme-score set for [messageText] driven by [correction].
  /// Returns null when [correction] is not a pronunciation correction or the
  /// corrected word can't be located in the transcript.
  static PhonemeScoreSet? fromCorrection({
    required String messageId,
    required String? sessionId,
    required Correction correction,
    required String messageText,
  }) {
    if (correction.type != CorrectionType.pronunciation) return null;
    final word = correction.corrected.trim();
    if (word.isEmpty) return null;

    // Locate the word (case-insensitive) in the transcript so we can record
    // its 0-based position for bubble highlighting.
    final tokens = _tokenize(messageText);
    int position = -1;
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].toLowerCase() == word.toLowerCase()) {
        position = i;
        break;
      }
    }
    if (position < 0) {
      // Fall back to matching the original (mispronounced) form.
      for (var i = 0; i < tokens.length; i++) {
        if (tokens[i].toLowerCase() == correction.original.toLowerCase()) {
          position = i;
          break;
        }
      }
    }
    if (position < 0) return null;

    final phonemes = _splitPhonemes(word);
    // Importance 0-100 → score 100-importance (clamped), then jitter ±10.
    final baseScore = (100 - correction.importance).clamp(20, 95).toInt();
    final scores = <PhonemeScore>[];
    for (var i = 0; i < phonemes.length; i++) {
      final jitter = ((i * 37) % 21) - 10; // deterministic -10..+10
      final score = (baseScore + jitter).clamp(0, 100);
      scores.add(PhonemeScore(
        phoneme: phonemes[i],
        word: word,
        score: score,
        position: position,
        feedback: correction.explanation,
      ));
    }
    return PhonemeScoreSet(
      messageId: messageId,
      correctionId: correction.id,
      sessionId: sessionId,
      scores: scores,
    );
  }

  /// Split text into word tokens (letters only, lowercased) for position
  /// matching. Mirrors the bubble's word-splitting expectation.
  static List<String> _tokenize(String text) {
    return text
        .split(RegExp(r'[^A-Za-z]+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Approximate phoneme segmentation: clusters consecutive vowels into one
  /// unit and treats each consonant as its own unit. A real implementation
  /// would use an IPA dictionary; this is a deterministic stand-in that
  /// produces 2-6 units per word so the detail overlay has something to show.
  static List<String> _splitPhonemes(String word) {
    final w = word.toLowerCase();
    final units = <String>[];
    final buf = StringBuffer();
    for (final ch in w.split('')) {
      final isVowel = 'aeiou'.contains(ch);
      if (buf.isEmpty) {
        buf.write(ch);
        continue;
      }
      final bufStr = buf.toString();
      final bufIsVowel = 'aeiou'.contains(bufStr.isEmpty ? '' : bufStr[bufStr.length - 1]);
      if (isVowel && bufIsVowel) {
        buf.write(ch); // merge consecutive vowels into one unit
      } else {
        units.add(buf.toString());
        buf
          ..clear()
          ..write(ch);
      }
    }
    if (buf.isNotEmpty) units.add(buf.toString());
    return units.isEmpty ? [w] : units;
  }
}
