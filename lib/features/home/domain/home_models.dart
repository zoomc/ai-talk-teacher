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
class ReviewQueue {
  final String id;
  final String correctionId;
  final DateTime dueAt;
  final DateTime createdAt;

  ReviewQueue({
    String? id,
    required this.correctionId,
    required this.dueAt,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'correction_id': correctionId,
      'due_at': dueAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReviewQueue.fromMap(Map<String, dynamic> map) {
    return ReviewQueue(
      id: map['id'] as String,
      correctionId: map['correction_id'] as String,
      dueAt: DateTime.parse(map['due_at'] as String),
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
  final String type; // 'grammar' | 'vocabulary' | 'pronunciation'
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
