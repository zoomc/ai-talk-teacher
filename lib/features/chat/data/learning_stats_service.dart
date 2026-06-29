import '../../../core/database/database_helper.dart';

class LearningStats {
  final int totalSessions;
  final int totalMessages;
  final int totalCorrections;
  final int masteredCount;
  final int learningCount;
  final int newCount;
  final int dueForReview;
  final Map<String, int> correctionsByType;
  final List<DailyActivity> dailyActivity;

  LearningStats({
    required this.totalSessions,
    required this.totalMessages,
    required this.totalCorrections,
    required this.masteredCount,
    required this.learningCount,
    required this.newCount,
    required this.dueForReview,
    required this.correctionsByType,
    required this.dailyActivity,
  });
}

class DailyActivity {
  final DateTime date;
  final int messages;
  final int corrections;

  DailyActivity({
    required this.date,
    required this.messages,
    required this.corrections,
  });
}

class LearningStatsService {
  Future<LearningStats> getStats() async {
    final db = await DatabaseHelper.database;

    // Total sessions
    final sessionResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chat_sessions',
    );
    final totalSessions = (sessionResult.first['count'] as int?) ?? 0;

    // Total messages
    final messageResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chat_messages',
    );
    final totalMessages = (messageResult.first['count'] as int?) ?? 0;

    // Corrections by status
    final now = DateTime.now().toIso8601String();
    final correctionResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections',
    );
    final totalCorrections = (correctionResult.first['count'] as int?) ?? 0;

    final masteredResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections WHERE review_count >= 5',
    );
    final masteredCount = (masteredResult.first['count'] as int?) ?? 0;

    final learningResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections WHERE review_count > 0 AND review_count < 5',
    );
    final learningCount = (learningResult.first['count'] as int?) ?? 0;

    final newResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections WHERE review_count = 0',
    );
    final newCount = (newResult.first['count'] as int?) ?? 0;

    final dueResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections WHERE next_review_at IS NULL OR next_review_at <= ?',
      [now],
    );
    final dueForReview = (dueResult.first['count'] as int?) ?? 0;

    // Corrections by type
    final typeResults = await db.rawQuery(
      'SELECT type, COUNT(*) as count FROM corrections GROUP BY type',
    );
    final correctionsByType = <String, int>{};
    for (final row in typeResults) {
      correctionsByType[row['type'] as String] = (row['count'] as int?) ?? 0;
    }

    // Daily activity (last 7 days): messages + corrections per day.
    // Previously `corrections` was hardcoded to 0, making the field dead
    // data. Now we run a second query and merge by date so the progress
    // chart can show both messages sent and errors logged per day.
    final dailyMsgResults = await db.rawQuery('''
      SELECT DATE(created_at) as date, COUNT(*) as count
      FROM chat_messages
      WHERE created_at >= DATE('now', '-7 days')
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    ''');

    final dailyCorrResults = await db.rawQuery('''
      SELECT DATE(last_seen_at) as date, COUNT(*) as count
      FROM corrections
      WHERE last_seen_at >= DATE('now', '-7 days')
      GROUP BY DATE(last_seen_at)
    ''');

    final corrByDate = <String, int>{};
    for (final row in dailyCorrResults) {
      corrByDate[row['date'] as String] = (row['count'] as int?) ?? 0;
    }

    final dailyActivity = <DailyActivity>[];
    for (final row in dailyMsgResults) {
      final dateStr = row['date'] as String;
      dailyActivity.add(
        DailyActivity(
          date: DateTime.parse(dateStr),
          messages: (row['count'] as int?) ?? 0,
          corrections: corrByDate[dateStr] ?? 0,
        ),
      );
    }

    return LearningStats(
      totalSessions: totalSessions,
      totalMessages: totalMessages,
      totalCorrections: totalCorrections,
      masteredCount: masteredCount,
      learningCount: learningCount,
      newCount: newCount,
      dueForReview: dueForReview,
      correctionsByType: correctionsByType,
      dailyActivity: dailyActivity,
    );
  }
}
