/// P1 task 6 — Placement AI 评估 result models.
///
/// After a 5-turn conversation the LLM emits a strict JSON verdict covering:
///   * five-dimension scores (0–100): vocabulary, fluency, grammar,
///     pronunciation, confidence
///   * an overall level tag: 'beginner' | 'intermediate' | 'advanced'
///   * a 4-week personalised learning path (one [LearningPathWeek] per week)
///
/// These models are plain DTOs — no behaviour beyond parsing + serialising —
/// so the placement screen, home screen, and any future plan screen share a
/// single source of truth.
library;

/// Five-dimension placement scores. Each value is 0–100.
class PlacementScores {
  final int vocabulary;
  final int fluency;
  final int grammar;
  final int pronunciation;
  final int confidence;

  const PlacementScores({
    required this.vocabulary,
    required this.fluency,
    required this.grammar,
    required this.pronunciation,
    required this.confidence,
  });

  /// Label keys for the radar chart + table. Order is fixed so the radar
  /// polygon stays stable across rebuilds.
  static const List<String> dimensionKeys = [
    'placement.score_vocab',
    'placement.score_fluency',
    'placement.score_grammar',
    'placement.score_pronunciation',
    'placement.score_confidence',
  ];

  /// Score values in the same order as [dimensionKeys].
  List<int> get values => [
        vocabulary,
        fluency,
        grammar,
        pronunciation,
        confidence,
      ];

  /// Arithmetic mean rounded — used as the headline number on the result
  /// screen + persisted as `user_level`'s numeric companion.
  int get overall =>
      ((vocabulary + fluency + grammar + pronunciation + confidence) / 5)
          .round();

  factory PlacementScores.fromMap(Map<String, dynamic> map) {
    int parse(Object? v) {
      if (v is int) return v.clamp(0, 100);
      if (v is num) return v.toInt().clamp(0, 100);
      if (v is String) return int.tryParse(v)?.clamp(0, 100) ?? 50;
      return 50;
    }

    return PlacementScores(
      vocabulary: parse(map['vocabulary']),
      fluency: parse(map['fluency']),
      grammar: parse(map['grammar']),
      pronunciation: parse(map['pronunciation']),
      confidence: parse(map['confidence']),
    );
  }

  Map<String, dynamic> toMap() => {
        'vocabulary': vocabulary,
        'fluency': fluency,
        'grammar': grammar,
        'pronunciation': pronunciation,
        'confidence': confidence,
      };
}

/// A single week in the personalised 4-week learning path.
class LearningPathWeek {
  final int week;
  final String focus;
  final List<String> tasks;

  const LearningPathWeek({
    required this.week,
    required this.focus,
    required this.tasks,
  });

  factory LearningPathWeek.fromMap(Map<String, dynamic> map) {
    final rawTasks = map['tasks'];
    final tasks = <String>[];
    if (rawTasks is List) {
      for (final t in rawTasks) {
        if (t is String && t.trim().isNotEmpty) tasks.add(t.trim());
      }
    }
    return LearningPathWeek(
      week: (map['week'] as num?)?.toInt() ?? 1,
      focus: (map['focus'] as String?)?.trim() ?? '',
      tasks: tasks,
    );
  }

  Map<String, dynamic> toMap() => {
        'week': week,
        'focus': focus,
        'tasks': tasks,
      };
}

/// The full placement verdict — five-dim scores + level + 4-week path.
class PlacementResult {
  final PlacementScores scores;
  final String level; // 'beginner' | 'intermediate' | 'advanced'
  final List<LearningPathWeek> path;

  const PlacementResult({
    required this.scores,
    required this.level,
    required this.path,
  });

  factory PlacementResult.fromMap(Map<String, dynamic> map) {
    final pathRaw = map['path'];
    final path = <LearningPathWeek>[];
    if (pathRaw is List) {
      for (final w in pathRaw) {
        if (w is Map<String, dynamic>) {
          path.add(LearningPathWeek.fromMap(w));
        }
      }
    }
    // Pad / trim to exactly 4 weeks so the UI contract holds even if the
    // model returned 3 or 5.
    while (path.length < 4) {
      path.add(LearningPathWeek(
        week: path.length + 1,
        focus: '',
        tasks: const [],
      ));
    }
    if (path.length > 4) path.removeRange(4, path.length);

    var level = (map['level'] as String?)?.trim().toLowerCase() ?? '';
    if (level != 'beginner' && level != 'intermediate' && level != 'advanced') {
      // Derive from the overall score when the model omitted / mis-typed it.
      final overall = PlacementScores.fromMap(map).overall;
      level = overall < 40
          ? 'beginner'
          : (overall < 70 ? 'intermediate' : 'advanced');
    }
    return PlacementResult(
      scores: PlacementScores.fromMap(map),
      level: level,
      path: path,
    );
  }

  Map<String, dynamic> toMap() => {
        ...scores.toMap(),
        'level': level,
        'path': path.map((w) => w.toMap()).toList(),
      };
}
