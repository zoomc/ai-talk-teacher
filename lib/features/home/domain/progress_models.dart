/// Phase 5 — learning progress and pronunciation report models.
///
/// Covers pronunciation reports (per-session phoneme analysis), weak-area
/// tracking (persistent problem spots), and weekly aggregation for the
/// progress dashboard (calendar heatmap, trend chart, review suggestions).
library;

import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ============================================================================
// Pronunciation Report
// ============================================================================

/// Per-session pronunciation quality summary, computed from the session's
/// phoneme-score data (existing `phoneme_score_sets` + `phoneme_scores`
/// tables) or from synthetic evaluation when no phoneme-level STT is
/// available.
class PronunciationReport {
  final String id;
  final String sessionId;
  final double overallPhonemeScore;

  /// Per-phoneme accuracy breakdown, keyed by IPA phoneme (e.g. /θ/, /ð/, /ɪ/).
  /// Each entry carries the average score (0–100) and occurrence count.
  final Map<String, ({double avgScore, int count})> phonemeBreakdown;

  /// Most common pronunciation errors in this session, ranked by frequency.
  ///
  /// Each entry has a `phoneme` (the target phoneme), `word` (the word it
  /// appeared in), and a `score` (average quality across occurrences).
  final List<PhonemeErrorEntry> commonErrors;

  /// Total number of phonemes scored in this session.
  final int totalPhonemesScored;

  /// Number of phonemes scored below 50 (poor).
  final int poorCount;

  /// Number of phonemes scored 50–84 (fair).
  final int fairCount;

  /// Number of phonemes scored 85+ (good).
  final int goodCount;

  final DateTime createdAt;

  PronunciationReport({
    String? id,
    required this.sessionId,
    required this.overallPhonemeScore,
    this.phonemeBreakdown = const {},
    this.commonErrors = const [],
    this.totalPhonemesScored = 0,
    this.poorCount = 0,
    this.fairCount = 0,
    this.goodCount = 0,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Percentage of good/fair/poor phonemes (0–100).
  double get goodPercentage =>
      totalPhonemesScored > 0
          ? (goodCount / totalPhonemesScored * 100)
          : 0;
  double get fairPercentage =>
      totalPhonemesScored > 0
          ? (fairCount / totalPhonemesScored * 100)
          : 0;
  double get poorPercentage =>
      totalPhonemesScored > 0
          ? (poorCount / totalPhonemesScored * 100)
          : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'overall_phoneme_score': overallPhonemeScore,
      'phoneme_breakdown': jsonEncode(
        phonemeBreakdown.map((k, v) => MapEntry<String, Map<String, dynamic>>(
              k,
              {'avg_score': v.avgScore, 'count': v.count},
            )),
      ),
      'common_errors': jsonEncode(commonErrors.map((e) => e.toJson()).toList()),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PronunciationReport.fromMap(Map<String, dynamic> map) {
    final breakdownRaw = map['phoneme_breakdown'];
    final errorsRaw = map['common_errors'];
    Map<String, ({double avgScore, int count})> breakdown = {};
    List<PhonemeErrorEntry> errors = [];

    if (breakdownRaw is String && breakdownRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(breakdownRaw) as Map<String, dynamic>;
        breakdown = decoded.map((k, v) {
          final entry = v as Map<String, dynamic>;
          return MapEntry(
            k,
            (
              avgScore: (entry['avg_score'] as num).toDouble(),
              count: (entry['count'] as int),
            ),
          );
        });
      } catch (_) {}
    }

    if (errorsRaw is String && errorsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(errorsRaw) as List<dynamic>;
        errors = decoded
            .map((e) => PhonemeErrorEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return PronunciationReport(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      overallPhonemeScore: (map['overall_phoneme_score'] as num?)?.toDouble() ?? 0,
      phonemeBreakdown: breakdown,
      commonErrors: errors,
      totalPhonemesScored: 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

/// One entry in a pronunciation report's common-errors list.
class PhonemeErrorEntry {
  final String phoneme;
  final String word;
  final int score;

  const PhonemeErrorEntry({
    required this.phoneme,
    required this.word,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'phoneme': phoneme,
        'word': word,
        'score': score,
      };

  factory PhonemeErrorEntry.fromJson(Map<String, dynamic> json) =>
      PhonemeErrorEntry(
        phoneme: json['phoneme'] as String,
        word: json['word'] as String,
        score: (json['score'] as num).toInt(),
      );
}

// ============================================================================
// Weak Area
// ============================================================================

/// A persistent weak point in the user's language ability.
///
/// `areaType` is one of 'phoneme', 'grammar', 'vocabulary', 'fluency'.
/// `description` is a human-readable phrase (e.g. "Mispronouncing /θ/ as /s/",
/// "Subject-verb agreement errors"). `frequencyCount` is how many times this
/// has been observed. `skillId` correlates to the `skill_mastery` table so
/// the home dashboard can show both the weak area and the numeric score.
class WeakArea {
  final String id;
  final String areaType;
  final String description;
  final int frequencyCount;
  final DateTime lastSeenAt;
  final String? skillId;
  final DateTime createdAt;

  WeakArea({
    String? id,
    required this.areaType,
    required this.description,
    this.frequencyCount = 1,
    DateTime? lastSeenAt,
    this.skillId,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        lastSeenAt = lastSeenAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  WeakArea copyWith({
    int? frequencyCount,
    DateTime? lastSeenAt,
  }) {
    return WeakArea(
      id: id,
      areaType: areaType,
      description: description,
      frequencyCount: frequencyCount ?? this.frequencyCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      skillId: skillId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'area_type': areaType,
      'description': description,
      'frequency_count': frequencyCount,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'skill_id': skillId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WeakArea.fromMap(Map<String, dynamic> map) {
    return WeakArea(
      id: map['id'] as String,
      areaType: map['area_type'] as String,
      description: map['description'] as String,
      frequencyCount: (map['frequency_count'] as int?) ?? 1,
      lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
      skillId: map['skill_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

// ============================================================================
// Weekly Stats
// ============================================================================

/// Aggregated learning statistics for a single week (Mon–Sun).
class WeeklyStats {
  /// YYYY-MM-DD of the Monday this week starts on.
  final String weekStart;

  /// Total practice duration in seconds across the week.
  final int totalDurationSeconds;

  /// Number of conversations started.
  final int sessionCount;

  /// Number of user messages sent.
  final int messageCount;

  /// Number of corrections received.
  final int correctionCount;

  /// Per-day breakdown (7 entries, Mon–Sun).
  final List<DailyStats> dailyStats;

  const WeeklyStats({
    required this.weekStart,
    this.totalDurationSeconds = 0,
    this.sessionCount = 0,
    this.messageCount = 0,
    this.correctionCount = 0,
    this.dailyStats = const [],
  });

  /// Average daily duration in minutes (for display).
  double get avgDailyMinutes =>
      dailyStats.isNotEmpty
          ? dailyStats.fold<int>(0, (s, d) => s + d.durationSeconds) /
              60 /
              dailyStats.length
          : 0;

  /// Number of days with at least one practice event.
  int get activeDays => dailyStats.where((d) => d.hasActivity).length;

  /// Whether the user practised on every day of this week.
  bool get isPerfectWeek => activeDays >= 7;
}

/// Per-day stats entry inside [WeeklyStats].
class DailyStats {
  final DateTime date;
  final int durationSeconds;
  final int messageCount;
  final int correctionCount;

  bool get hasActivity => durationSeconds > 0 || messageCount > 0;

  const DailyStats({
    required this.date,
    this.durationSeconds = 0,
    this.messageCount = 0,
    this.correctionCount = 0,
  });
}

// ============================================================================
// Review Suggestion
// ============================================================================

/// A review suggestion generated from weak-area analysis.
///
/// `areaType` matches [WeakArea.areaType].
/// `priority` is 1–5 (1 = most urgent).
/// `actionKey` is an i18n key for the suggested action text.
class ReviewSuggestion {
  final String areaType;
  final String description;
  final int priority;
  final String actionKey;
  final String? scenarioId;

  const ReviewSuggestion({
    required this.areaType,
    required this.description,
    required this.priority,
    required this.actionKey,
    this.scenarioId,
  });
}
