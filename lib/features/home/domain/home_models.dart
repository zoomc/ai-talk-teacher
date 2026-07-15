import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// S5/S6 — one row per calendar day the user engaged with the app.
///
/// `date` is a stable `YYYY-MM-DD` string (local time) so we can enforce
/// one-row-per-day uniqueness in SQLite without timezone drift. `streak`
/// is the consecutive-day count *as of this day* — denormalised so the
/// home dashboard can render the streak bar with a single cheap read
/// instead of scanning the whole table.
class PracticeLog {
  final String id;
  /// Local calendar date in `YYYY-MM-DD` format (no time / no tz).
  final String date;
  final int durationSeconds;
  /// True when the user hit the day's "completion" threshold (e.g. finished
  /// at least one review or sent at least one message). Drives the
  /// streak — a day only counts toward the streak when completed.
  final bool completed;
  final int streak;
  final DateTime createdAt;
  final DateTime updatedAt;

  PracticeLog({
    String? id,
    required this.date,
    this.durationSeconds = 0,
    this.completed = false,
    this.streak = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PracticeLog copyWith({
    int? durationSeconds,
    bool? completed,
    int? streak,
    DateTime? updatedAt,
  }) {
    return PracticeLog(
      id: id,
      date: date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      streak: streak ?? this.streak,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'duration_seconds': durationSeconds,
      'completed': completed ? 1 : 0,
      'streak': streak,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PracticeLog.fromMap(Map<String, dynamic> map) {
    return PracticeLog(
      id: map['id'] as String,
      date: map['date'] as String,
      durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      completed: ((map['completed'] as int?) ?? 0) == 1,
      streak: (map['streak'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Format a [DateTime] as a stable local `YYYY-MM-DD` string. We build
  /// it manually instead of relying on `toIso8601String()` because the
  /// latter includes sub-day components that break the one-row-per-day
  /// uniqueness constraint.
  static String formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// S5/S6 — one review-queue slot per correction, mirroring its next due
/// time so the home dashboard can surface "what to review next" sorted by
/// the forgetting window without re-deriving the SM-2 schedule.
///
/// S5/S6 v7 — carries the full SM-2 state (intervalDays / repetitions /
/// easeFactor) so the dashboard's "today's tasks" can be ordered by SM-2
/// progression (lower repetitions → earlier in the day's plan) without
/// joining back to the corrections table.
class ReviewQueue {
  final String id;
  final String correctionId;
  final DateTime dueAt;
  /// SM-2 interval in days. 0 for a brand-new correction, grows on each
  /// successful review.
  final int intervalDays;
  /// SM-2 repetition count. 0 until the first successful review; reset to
  /// 0 on a failed (quality < 3) review.
  final int repetitions;
  /// SM-2 easiness factor. Starts at 2.5, bounded to >= 1.3.
  final double easeFactor;
  final DateTime createdAt;

  ReviewQueue({
    String? id,
    required this.correctionId,
    required this.dueAt,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'correction_id': correctionId,
      'due_at': dueAt.toIso8601String(),
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReviewQueue.fromMap(Map<String, dynamic> map) {
    return ReviewQueue(
      id: map['id'] as String,
      correctionId: map['correction_id'] as String,
      dueAt: DateTime.parse(map['due_at'] as String),
      // v7 migration back-fills these for pre-existing rows; older maps
      // (e.g. from in-memory tests) won't have the keys → default values.
      intervalDays: (map['interval_days'] as int?) ?? 0,
      repetitions: (map['repetitions'] as int?) ?? 0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// S5/S6 — a review-queue slot joined with its parent correction. The home
/// dashboard's "待复习纠错列表" needs both the due time (for sort order) and
/// the correction text (for display), so this DTO carries both.
class ReviewQueueItem {
  final ReviewQueue queue;
  final CorrectionRef correction;

  const ReviewQueueItem({required this.queue, required this.correction});
}

/// Lightweight correction projection used by [ReviewQueueItem]. We only
/// need a few fields for the dashboard list, so we don't pull the whole
/// `Correction` row (which carries review-count / EF / etc. the dashboard
/// doesn't render).
class CorrectionRef {
  final String id;
  final String original;
  final String corrected;
  final String type; // 'grammar' | 'vocabulary' | 'pronunciation' | 'fluency'
  final int importance;

  const CorrectionRef({
    required this.id,
    required this.original,
    required this.corrected,
    required this.type,
    required this.importance,
  });
}

/// S5/S6 — four-dimension ability overview. Each value is 0–100. Derived
/// from the placement scores (if available) blended with correction-type
/// distribution so the radar reflects both initial level and recent
/// practice gaps.
class AbilityScores {
  final int pronunciation;
  final int grammar;
  final int vocabulary;
  final int fluency;

  const AbilityScores({
    required this.pronunciation,
    required this.grammar,
    required this.vocabulary,
    required this.fluency,
  });

  /// Label keys for the radar chart, in fixed order so the polygon stays
  /// stable across rebuilds.
  static const List<String> dimensionKeys = [
    'placement.score_pronunciation',
    'placement.score_grammar',
    'placement.score_vocab',
    'placement.score_fluency',
  ];

  /// Score values in the same order as [dimensionKeys].
  List<int> get values => [pronunciation, grammar, vocabulary, fluency];

  int get overall =>
      ((pronunciation + grammar + vocabulary + fluency) / 4).round();
}

/// S5/S6 v7 — one row per skill point (e.g. 'grammar/subject-verb-agreement').
///
/// `score` is 0–100 produced by [SkillMasteryService] from the latest 20
/// practice events on this skill, weighted by time-decay (newest = highest
/// weight). `level` is the human-readable bucket used by the home dashboard
/// to colour-code the skill list:
///   0–19   → 'new'
///   20–39  → 'learning'
///   40–69  → 'familiar'
///   70–89  → 'mastered'
///   90–100 → 'expert'
class SkillMastery {
  final String id;
  /// Stable skill identifier — the kebab-case tag from corrections.skill
  /// (e.g. 'grammar/subject-verb-agreement'). UNIQUE in the table.
  final String skillId;
  final int score;
  final String level;
  final DateTime updatedAt;

  SkillMastery({
    String? id,
    required this.skillId,
    required this.score,
    required this.level,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        updatedAt = updatedAt ?? DateTime.now();

  SkillMastery copyWith({
    int? score,
    String? level,
    DateTime? updatedAt,
  }) {
    return SkillMastery(
      id: id,
      skillId: skillId,
      score: score ?? this.score,
      level: level ?? this.level,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'skill_id': skillId,
      'score': score,
      'level': level,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SkillMastery.fromMap(Map<String, dynamic> map) {
    return SkillMastery(
      id: map['id'] as String,
      skillId: map['skill_id'] as String,
      score: (map['score'] as int?) ?? 0,
      level: (map['level'] as String?) ?? 'new',
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Bucket the numeric [score] into the human-readable level string. Kept
  /// as a static so [SkillMasteryService] can derive the level from a freshly
  /// computed score without duplicating the thresholds.
  static String levelFromScore(int score) {
    if (score >= 90) return 'expert';
    if (score >= 70) return 'mastered';
    if (score >= 40) return 'familiar';
    if (score >= 20) return 'learning';
    return 'new';
  }
}

/// S5/S6 v7 — the user's learning goal. The home dashboard reads the most
/// recent row (by `created_at`) as the "active" goal and uses it to
/// recommend scenarios + practice content.
///
/// `goalType` is one of: 'interview' | 'travel' | 'daily' | 'ielts'.
/// `target` is a free-text description the user can fill in (e.g.
/// "Silicon Valley engineering interview" or "Band 7 in IELTS speaking")
/// — kept optional so a user can pick a goal type without being forced to
/// write a target.
class UserGoal {
  final String id;
  final String goalType;
  final String target;
  final DateTime createdAt;

  UserGoal({
    String? id,
    required this.goalType,
    required this.target,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_type': goalType,
      'target': target,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserGoal.fromMap(Map<String, dynamic> map) {
    return UserGoal(
      id: map['id'] as String,
      goalType: map['goal_type'] as String,
      target: (map['target'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// S5/S6 v7 — the four supported goal types. Kept as a static const list
/// so the goal-picker dialog and the recommendation service share a single
/// source of truth. Order matches the spec
/// (interview / travel / daily / ielts).
class GoalType {
  static const String interview = 'interview';
  static const String travel = 'travel';
  static const String daily = 'daily';
  static const String ielts = 'ielts';

  static const List<String> all = [interview, travel, daily, ielts];

  /// Validate a stored goal_type string. Returns the input if it's one of
  /// the known values, otherwise `daily` (the safe default).
  static String normalize(String? raw) {
    if (raw == null) return daily;
    return all.contains(raw) ? raw : daily;
  }

  /// i18n key for the human-readable name of [goalType].
  static String labelKey(String goalType) {
    switch (goalType) {
      case interview:
        return 'goal.type_interview';
      case travel:
        return 'goal.type_travel';
      case ielts:
        return 'goal.type_ielts';
      case daily:
      default:
        return 'goal.type_daily';
    }
  }

  /// Scenario category most aligned with [goalType] — used by the home
  /// dashboard's "recommended for your goal" section. Mirrors the
  /// `category` column in the scenarios table.
  static String preferredCategory(String goalType) {
    switch (goalType) {
      case interview:
        return 'career';
      case travel:
        return 'travel';
      case ielts:
        return 'general';
      case daily:
      default:
        return 'daily';
    }
  }
}

/// S7/S8 — one scenario review-queue slot, mirroring the S5/S6
/// [ReviewQueue] pattern but for scenarios. When the user finishes a
/// scenario conversation, a slot is upserted with the SM-2 state so the
/// home dashboard can surface "review this scenario" alongside correction
/// reviews. Kept in a separate table (`scenario_review_queue`) so the
/// existing review_queue's NOT NULL UNIQUE on correction_id stays intact.
class ScenarioReviewQueue {
  final String id;
  final String scenarioId;
  final DateTime dueAt;
  /// SM-2 interval in days. 0 for a freshly finished scenario, grows on
  /// each successful re-practice.
  final int intervalDays;
  /// SM-2 repetition count. 0 until the first successful re-practice.
  final int repetitions;
  /// SM-2 easiness factor. Starts at 2.5, bounded to >= 1.3.
  final double easeFactor;
  /// The user's latest 0–100 mastery score on this scenario (averaged
  /// from its scenario_items scores at finish time). 0 means not scored.
  final int lastScore;
  final DateTime createdAt;

  ScenarioReviewQueue({
    String? id,
    required this.scenarioId,
    required this.dueAt,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.lastScore = 0,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scenario_id': scenarioId,
      'due_at': dueAt.toIso8601String(),
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'last_score': lastScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScenarioReviewQueue.fromMap(Map<String, dynamic> map) {
    return ScenarioReviewQueue(
      id: map['id'] as String,
      scenarioId: map['scenario_id'] as String,
      dueAt: DateTime.parse(map['due_at'] as String),
      intervalDays: (map['interval_days'] as int?) ?? 0,
      repetitions: (map['repetitions'] as int?) ?? 0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      lastScore: (map['last_score'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// S7/S8 — a scenario review-queue slot joined with its parent scenario.
/// The home dashboard's "待复习场景" list needs both the due time (for sort
/// order) and the scenario name/icon (for display), so this DTO carries
/// both — mirroring [ReviewQueueItem].
class ScenarioReviewQueueItem {
  final ScenarioReviewQueue queue;
  final ScenarioRef scenario;

  const ScenarioReviewQueueItem({required this.queue, required this.scenario});
}

/// S7/S8 — lightweight scenario projection used by
/// [ScenarioReviewQueueItem] and the dashboard's recommended-scenario
/// strip. We only need a few fields for display, so we don't pull the
/// whole `Scenario` row (which carries the full system_prompt + items).
class ScenarioRef {
  final String id;
  final String name;
  final String icon;
  final String difficulty;
  final String? goal;

  const ScenarioRef({
    required this.id,
    required this.name,
    required this.icon,
    required this.difficulty,
    this.goal,
  });
}
