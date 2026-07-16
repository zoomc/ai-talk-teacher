/// Phase 5 — learning progress service.
///
/// Provides weekly statistics aggregation, weak-area analysis from
/// corrections + skill mastery data, review-suggestion generation,
/// and pronunciation report building from the existing phoneme-score
/// infrastructure.
library;

import '../../../core/database/database_helper.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../domain/home_models.dart';
import '../domain/progress_models.dart';

class ProgressService {
  final ChatRepository _repo;

  ProgressService(this._repo);

  // ==========================================================================
  // Weekly Stats
  // ==========================================================================

  /// Aggregate stats for a week starting on [weekStart] (YYYY-MM-DD Monday).
  /// Scans practice_log, chat_messages, and corrections for the 7-day window.
  Future<WeeklyStats> getWeeklyStats(String weekStart) async {
    final db = await DatabaseHelper.database;
    final monday = DateTime.parse(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    final mondayStr = weekStart;
    final sundayStr = sunday.toIso8601String().substring(0, 10);

    // Duration from practice_log
    final durResult = await db.rawQuery(
      "SELECT COALESCE(SUM(duration_seconds), 0) AS total FROM practice_log "
      "WHERE date >= ? AND date <= ?",
      [mondayStr, sundayStr],
    );
    final totalDuration = (durResult.first['total'] as num?)?.toInt() ?? 0;

    // Session count
    final sessResult = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM chat_sessions "
      "WHERE DATE(created_at) >= ? AND DATE(created_at) <= ?",
      [mondayStr, sundayStr],
    );
    final sessionCount = (sessResult.first['count'] as int?) ?? 0;

    // Message count
    final msgResult = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM chat_messages "
      "WHERE DATE(created_at) >= ? AND DATE(created_at) <= ?",
      [mondayStr, sundayStr],
    );
    final messageCount = (msgResult.first['count'] as int?) ?? 0;

    // Correction count
    final corrResult = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM corrections "
      "WHERE DATE(last_seen_at) >= ? AND DATE(last_seen_at) <= ?",
      [mondayStr, sundayStr],
    );
    final correctionCount = (corrResult.first['count'] as int?) ?? 0;

    // Per-day breakdown
    final dailyMsg = await db.rawQuery(
      "SELECT DATE(created_at) AS date, COUNT(*) AS count "
      "FROM chat_messages "
      "WHERE DATE(created_at) >= ? AND DATE(created_at) <= ? "
      "GROUP BY DATE(created_at)",
      [mondayStr, sundayStr],
    );
    final dailyCorr = await db.rawQuery(
      "SELECT DATE(last_seen_at) AS date, COUNT(*) AS count "
      "FROM corrections "
      "WHERE DATE(last_seen_at) >= ? AND DATE(last_seen_at) <= ? "
      "GROUP BY DATE(last_seen_at)",
      [mondayStr, sundayStr],
    );
    final dailyDur = await db.rawQuery(
      "SELECT date, duration_seconds FROM practice_log "
      "WHERE date >= ? AND date <= ?",
      [mondayStr, sundayStr],
    );

    final msgByDate = <String, int>{};
    for (final r in dailyMsg) {
      msgByDate[r['date'] as String] = (r['count'] as int?) ?? 0;
    }
    final corrByDate = <String, int>{};
    for (final r in dailyCorr) {
      corrByDate[r['date'] as String] = (r['count'] as int?) ?? 0;
    }
    final durByDate = <String, int>{};
    for (final r in dailyDur) {
      durByDate[r['date'] as String] = (r['duration_seconds'] as int?) ?? 0;
    }

    final dailyStats = <DailyStats>[];
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final key = d.toIso8601String().substring(0, 10);
      dailyStats.add(DailyStats(
        date: d,
        durationSeconds: durByDate[key] ?? 0,
        messageCount: msgByDate[key] ?? 0,
        correctionCount: corrByDate[key] ?? 0,
      ));
    }

    return WeeklyStats(
      weekStart: weekStart,
      totalDurationSeconds: totalDuration,
      sessionCount: sessionCount,
      messageCount: messageCount,
      correctionCount: correctionCount,
      dailyStats: dailyStats,
    );
  }

  /// Current week Monday (ISO week start).
  static String currentWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysFromMonday));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  /// Previous week Monday.
  static String previousWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysFromMonday + 7));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // Calendar Heatmap Data
  // ==========================================================================

  /// Practice logs for the last [days] days (default 365 for full-year
  /// heatmap, but feed a smaller window like 60 for the dashboard).
  Future<List<PracticeLog>> getHeatmapData({int days = 60}) async {
    return _repo.getRecentPracticeLogs(days: days);
  }

  // ==========================================================================
  // Weak Area Analysis
  // ==========================================================================

  /// Analyze current corrections and skill mastery to surface weak areas.
  /// Scans corrections for recurring error patterns and upserts them into
  /// the `weak_areas` table. Returns the top [limit] weak areas.
  Future<List<WeakArea>> analyzeWeakAreas({int limit = 10}) async {
    final corrections = await _repo.getAllCorrections();
    final areaCounts = <String, Map<String, int>>{};

    for (final c in corrections) {
      final type = c.type.name;
      final desc = _describeError(c);
      areaCounts.putIfAbsent(type, () => {});
      areaCounts[type]!.update(desc, (v) => v + 1, ifAbsent: () => 1);
    }

    for (final typeEntry in areaCounts.entries) {
      for (final descEntry in typeEntry.value.entries) {
        await _repo.upsertWeakArea(WeakArea(
          areaType: typeEntry.key,
          description: descEntry.key,
          frequencyCount: descEntry.value,
        ));
      }
    }

    return _repo.getWeakAreas(limit: limit);
  }

  /// Generate review suggestions from weak areas and skill mastery.
  Future<List<ReviewSuggestion>> generateReviewSuggestions({int limit = 5}) async {
    final weakAreas = await _repo.getWeakAreas(limit: 10);
    final skillMastery = await _repo.getAllSkillMastery();
    final suggestions = <ReviewSuggestion>[];

    // Priority 1: Most frequent weak areas
    for (final area in weakAreas.take(3)) {
      suggestions.add(ReviewSuggestion(
        areaType: area.areaType,
        description: area.description,
        priority: 1,
        actionKey: 'progress.suggestion_practice_${area.areaType}',
      ));
    }

    // Priority 2: Lowest skill mastery scores
    final worstSkills = skillMastery
        .where((s) => s.score < 40)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    for (final skill in worstSkills.take(2)) {
      suggestions.add(ReviewSuggestion(
        areaType: skill.skillId.split('/').first,
        description: skill.skillId.split('/').last,
        priority: 2,
        actionKey: 'progress.suggestion_review_skill',
      ));
    }

    suggestions.sort((a, b) => a.priority.compareTo(b.priority));
    return suggestions.take(limit).toList();
  }

  /// Generate a human-readable error description from a [Correction].
  String _describeError(Correction c) {
    switch (c.type) {
      case CorrectionType.pronunciation:
        return 'Pronunciation: ${c.original} → ${c.corrected}';
      case CorrectionType.grammar:
        return 'Grammar: ${c.original} → ${c.corrected}';
      case CorrectionType.vocabulary:
        return 'Vocabulary: ${c.original} → ${c.corrected}';
      case CorrectionType.fluency:
        return 'Fluency: ${c.original} → ${c.corrected}';
    }
  }

  // ==========================================================================
  // Pronunciation Report Builder
  // ==========================================================================

  /// Build a pronunciation report for a session from its phoneme score sets.
  Future<PronunciationReport?> buildPronunciationReport(
      String sessionId) async {
    final db = await DatabaseHelper.database;

    // Fetch all phoneme score sets for this session
    final sets = await db.query(
      'phoneme_score_sets',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (sets.isEmpty) return null;

    final setIds = sets.map((s) => s['id'] as String).toList();
    if (setIds.isEmpty) return null;

    // Fetch all scores belonging to any set in this session
    final placeholders = setIds.map((_) => '?').join(',');
    final scores = await db.rawQuery(
      "SELECT * FROM phoneme_scores WHERE set_id IN ($placeholders)",
      setIds,
    );

    if (scores.isEmpty) return null;

    // Aggregate per-phoneme stats
    final phonemeSums = <String, ({double sum, int count})>{};
    int poor = 0, fair = 0, good = 0;
    final errorList = <PhonemeErrorEntry>[];

    for (final row in scores) {
      final phoneme = row['phoneme'] as String;
      final word = row['word'] as String? ?? '';
      final score = (row['score'] as num?)?.toDouble() ?? 0;

      final entry = phonemeSums.putIfAbsent(phoneme, () => (sum: 0, count: 0));
      phonemeSums[phoneme] = (
        sum: entry.sum + score,
        count: entry.count + 1,
      );

      if (score < 50) {
        poor++;
        if (word.isNotEmpty) {
          errorList.add(PhonemeErrorEntry(
            phoneme: phoneme,
            word: word,
            score: score.round(),
          ));
        }
      } else if (score < 85) {
        fair++;
      } else {
        good++;
      }
    }

    final total = scores.length;
    final overallSum =
        scores.fold<double>(0, (s, r) => s + ((r['score'] as num?)?.toDouble() ?? 0));
    final overall = total > 0 ? overallSum / total : 0.0;

    final breakdown = phonemeSums.map((k, v) => MapEntry(
          k,
          (avgScore: v.sum / v.count, count: v.count),
        ));

    // Sort errors by score ascending (worst first)
    errorList.sort((a, b) => a.score.compareTo(b.score));
    final topErrors = errorList.take(5).toList();

    final report = PronunciationReport(
      sessionId: sessionId,
      overallPhonemeScore: overall,
      phonemeBreakdown: breakdown,
      commonErrors: topErrors,
      totalPhonemesScored: total,
      poorCount: poor,
      fairCount: fair,
      goodCount: good,
    );

    await _repo.savePronunciationReport(report);
    return report;
  }
}
