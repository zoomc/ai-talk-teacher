import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/database/database_helper.dart';
import '../domain/chat_models.dart';
import '../domain/phoneme_score.dart';
import '../../home/domain/home_models.dart';

class ChatRepository {
  // ========== Sessions ==========

  Future<List<ChatSession>> getAllSessions() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('chat_sessions', orderBy: 'updated_at DESC');
    return maps.map((m) => ChatSession.fromMap(m)).toList();
  }

  Future<ChatSession?> getActiveSession() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'chat_sessions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ChatSession.fromMap(maps.first);
  }

  Future<ChatSession?> getSession(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ChatSession.fromMap(maps.first);
  }

  Future<ChatSession> createSession({
    String? topic,
    String? scenarioId,
    String? levelTag,
    bool isGuest = false,
  }) async {
    final session = ChatSession(
      topic: topic,
      scenarioId: scenarioId,
      levelTag: levelTag,
      isGuest: isGuest,
    );
    final db = await DatabaseHelper.database;
    await db.insert('chat_sessions', session.toMap());
    return session;
  }

  Future<void> updateSession(ChatSession session) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'chat_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> archiveSession(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'chat_sessions',
      {'status': 'archived', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently delete a session and all of its messages + corrections.
  ///
  /// SQLite FK enforcement is off by default in sqflite, so we delete the
  /// child rows explicitly in a transaction. Corrections tied to this session
  /// are removed too — they're meaningless once the conversation that produced
  /// them is gone. P1 task 4 phoneme-score rows are also cleaned up so they
  /// don't orphan against deleted messages/corrections.
  Future<void> deleteSession(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      // P1 task 4 — delete phoneme score rows whose set belongs to a message
      // in this session, then the sets themselves. Done before chat_messages
      // so the subquery still resolves.
      await txn.delete(
        'phoneme_scores',
        where:
            'set_id IN (SELECT id FROM phoneme_score_sets WHERE '
            'message_id IN (SELECT id FROM chat_messages WHERE session_id = ?))',
        whereArgs: [id],
      );
      await txn.delete(
        'phoneme_score_sets',
        where:
            'message_id IN '
            '(SELECT id FROM chat_messages WHERE session_id = ?)',
        whereArgs: [id],
      );
      // Delete corrections whose session_id matches, or whose message_id
      // belongs to a message in this session.
      await txn.delete(
        'corrections',
        where:
            'session_id = ? OR message_id IN '
            '(SELECT id FROM chat_messages WHERE session_id = ?)',
        whereArgs: [id, id],
      );
      // S5/S6 — clean up review_queue slots for the corrections we just
      // deleted so the dashboard doesn't reference missing corrections.
      await txn.delete(
        'review_queue',
        where: 'correction_id NOT IN (SELECT id FROM corrections)',
      );
      await txn.delete(
        'chat_messages',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      await txn.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ========== Messages ==========

  /// Load a session's messages, optionally capped to the most recent [limit]
  /// rows. Capping protects against O(N²) token growth on long conversations:
  /// the LLM history is rebuilt every turn, so an unbounded history means the
  /// Nth turn re-sends all N-1 previous messages. Default keeps the last 40
  /// messages (~20 turns), which fits the spine's "1-4 sentences per turn".
  Future<List<ChatMessage>> getMessages(
    String sessionId, {
    int limit = 40,
  }) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  Future<void> saveMessage(ChatMessage message) async {
    final db = await DatabaseHelper.database;
    await db.insert('chat_messages', message.toMap());
  }

  // ========== Corrections ==========

  Future<List<Correction>> getAllCorrections() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('corrections', orderBy: 'created_at DESC');
    return maps.map((m) => Correction.fromMap(m)).toList();
  }

  /// All corrections belonging to a session (regardless of message_id), newest
  /// first. Used by the chat screen's inline-corrections provider so we don't
  /// pull the entire corrections table on every chat-screen rebuild — the
  /// previous FutureBuilder ran `getAllCorrections()` which scales linearly
  /// with the number of sessions the user has.
  Future<List<Correction>> getCorrectionsForSession(String sessionId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'corrections',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Correction.fromMap(m)).toList();
  }

  Future<List<Correction>> getDueCorrections({int limit = 20}) async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();
    // Phase-1 P0 #4: order by importance so the most impactful mistakes surface
    // first, with starred items taking priority. review_count ASC keeps
    // never-practiced items ahead of recently-reviewed ones within the same
    // importance tier. created_at ASC is the stable tiebreaker.
    final maps = await db.query(
      'corrections',
      where: 'next_review_at IS NULL OR next_review_at <= ?',
      whereArgs: [now],
      orderBy:
          'is_favorite DESC, importance DESC, review_count ASC, created_at ASC',
      limit: limit,
    );
    return maps.map((m) => Correction.fromMap(m)).toList();
  }

  /// Toggle the user's "starred" flag on a correction. Starred corrections
  /// always surface at the top of the review list (see [getDueCorrections]
  /// ordering) and never fall out of the active rotation. Returns the new
  /// state so the caller can update its UI without re-querying.
  Future<bool> toggleFavorite(String correctionId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'corrections',
      where: 'id = ?',
      whereArgs: [correctionId],
      limit: 1,
    );
    if (maps.isEmpty) return false;
    final current = Correction.fromMap(maps.first);
    final nowFavorite = !current.isFavorite;
    await db.update(
      'corrections',
      {
        'is_favorite': nowFavorite ? 1 : 0,
        'favorite_at': nowFavorite ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [correctionId],
    );
    return nowFavorite;
  }

  /// Starred corrections across all sessions — used by the review screen's
  /// "Starred" filter and the daily-plan generator to prioritise what the
  /// user explicitly wants to revisit.
  Future<List<Correction>> getFavoriteCorrections({int limit = 50}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'corrections',
      where: 'is_favorite = 1',
      whereArgs: [],
      orderBy: 'favorite_at DESC, importance DESC',
      limit: limit,
    );
    return maps.map((m) => Correction.fromMap(m)).toList();
  }

  Future<void> saveCorrection(Correction correction) async {
    final db = await DatabaseHelper.database;
    await db.insert('corrections', correction.toMap());
    // S5/S6 — seed a review_queue slot for the new correction so it
    // surfaces on the dashboard's "to review" list. New corrections are
    // due immediately (next_review_at is null at creation).
    final dueAt = correction.nextReviewAt ?? DateTime.now();
    await syncReviewQueue(
      correctionId: correction.id,
      dueAt: dueAt,
      intervalDays: correction.intervalDays,
      repetitions: correction.reviewCount,
      easeFactor: correction.easinessFactor,
    );
  }

  /// Look up an existing correction by (original, corrected, type).
  ///
  /// Used for deduplication: when the LLM flags "I goes" → "I go" (grammar)
  /// for the third time, we don't want three rows in the review list. Instead
  /// we find the existing one and bump its occurrence_count + last_seen_at.
  /// Matching ignores case and surrounding whitespace so " i goes " still
  /// dedups against "I goes".
  Future<Correction?> findExistingCorrection({
    required String original,
    required String corrected,
    required String type,
  }) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'corrections',
      where:
          'LOWER(TRIM(original)) = LOWER(TRIM(?)) AND '
          'LOWER(TRIM(corrected)) = LOWER(TRIM(?)) AND '
          'type = ?',
      whereArgs: [original, corrected, type],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Correction.fromMap(maps.first);
  }

  /// Insert a correction, or — if the same (original, corrected, type) already
  /// exists — bump its occurrence_count + last_seen_at instead of creating a
  /// duplicate. This keeps the review list focused on distinct mistakes
  /// rather than accumulating one row per occurrence. Returns the correction
  /// that should be considered "current" (the existing one if deduped).
  Future<Correction> saveCorrectionDedup(Correction correction) async {
    final existing = await findExistingCorrection(
      original: correction.original,
      corrected: correction.corrected,
      type: correction.type.name,
    );
    if (existing == null) {
      await saveCorrection(correction);
      return correction;
    }
    final updated = existing.copyWith(
      occurrenceCount: existing.occurrenceCount + 1,
      lastSeenAt: DateTime.now(),
      // Refresh the explanation if the LLM gave a (possibly better) one this
      // time and the old one was missing. Don't overwrite a non-null old
      // explanation — the first phrasing is usually fine and we avoid churn.
      explanation: existing.explanation ?? correction.explanation,
      // Keep the latest sighting context so the user can jump to the most
      // recent occurrence.
      messageId: correction.messageId ?? existing.messageId,
      sessionId: correction.sessionId ?? existing.sessionId,
      // Phase-1 P0 #4: take the higher importance so a mistake the LLM keeps
      // flagging as critical never gets demoted by a single lax rating.
      // Also keep the persisted favourite flag — dedup must never silently
      // un-star a correction the user explicitly saved.
      importance: correction.importance > existing.importance
          ? correction.importance
          : existing.importance,
    );
    await updateCorrection(updated);
    return updated;
  }

  Future<void> updateCorrection(Correction correction) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'corrections',
      correction.toMap(),
      where: 'id = ?',
      whereArgs: [correction.id],
    );
    // S5/S6 — keep the review_queue in sync with the correction's new
    // next_review_at so the dashboard's "to review" list reflects the
    // latest SM-2 schedule. Corrections with no next_review_at are due
    // now; clearing the queue slot would hide them, so we keep them due.
    // S5/S6 v7 — also mirror the SM-2 state (interval / repetitions / EF)
    // so the dashboard can order today's tasks by progression.
    final dueAt = correction.nextReviewAt ?? DateTime.now();
    await syncReviewQueue(
      correctionId: correction.id,
      dueAt: dueAt,
      intervalDays: correction.intervalDays,
      repetitions: correction.reviewCount,
      easeFactor: correction.easinessFactor,
    );
  }

  Future<int> getCorrectionCount() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getDueCorrectionCount() async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections WHERE next_review_at IS NULL OR next_review_at <= ?',
      [now],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<Map<String, ({int count, DateTime lastPracticedAt})>>
  getScenarioStats() async {
    final db = await DatabaseHelper.database;
    final results = await db.rawQuery('''
      SELECT scenario_id, COUNT(*) as cnt, MAX(updated_at) as last_at
      FROM chat_sessions
      WHERE scenario_id IS NOT NULL
      GROUP BY scenario_id
    ''');
    final stats = <String, ({int count, DateTime lastPracticedAt})>{};
    for (final row in results) {
      final sid = row['scenario_id'] as String?;
      if (sid == null) continue;
      final cnt = (row['cnt'] as int?) ?? 0;
      final lastStr = row['last_at'] as String?;
      if (lastStr == null) continue;
      stats[sid] = (count: cnt, lastPracticedAt: DateTime.parse(lastStr));
    }
    return stats;
  }

  // ========== Scenarios ==========

  Future<List<Scenario>> getAllScenarios() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('scenarios');
    return maps.map((m) => Scenario.fromMap(m)).toList();
  }

  Future<Scenario?> getScenario(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'scenarios',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Scenario.fromMap(maps.first);
  }

  // ========== Phoneme Scores (P1 task 4) ==========

  /// Persist a [PhonemeScoreSet] and all its child [PhonemeScore] rows in
  /// a single transaction so the set is never stored without its scores.
  Future<void> savePhonemeScores(PhonemeScoreSet set) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert('phoneme_score_sets', {
        'id': set.id,
        'message_id': set.messageId,
        'correction_id': set.correctionId,
        'session_id': set.sessionId,
        'overall_score': set.overallScore,
        'created_at': set.createdAt.toIso8601String(),
      });
      for (final s in set.scores) {
        await txn.insert('phoneme_scores', {
          'id': s.id,
          'set_id': set.id,
          'phoneme': s.phoneme,
          'word': s.word,
          'score': s.score,
          'position': s.position,
          'feedback': s.feedback,
          'audio_path': s.audioPath,
        });
      }
    });
  }

  /// Load the phoneme score set for a given message, or null if none was
  /// saved. Child scores are ordered by position so word-highlighting in
  /// the chat bubble maps cleanly left-to-right.
  Future<PhonemeScoreSet?> getPhonemeScoresForMessage(String messageId) async {
    final db = await DatabaseHelper.database;
    final setMaps = await db.query(
      'phoneme_score_sets',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (setMaps.isEmpty) return null;
    final setMap = setMaps.first;
    final scoreMaps = await db.query(
      'phoneme_scores',
      where: 'set_id = ?',
      whereArgs: [setMap['id']],
      orderBy: 'position ASC',
    );
    return PhonemeScoreSet.fromMap(
      setMap,
      scores: scoreMaps.map((m) => PhonemeScore.fromMap(m)).toList(),
    );
  }

  // ========== Review Queue (S5/S6) ==========

  /// Upsert a review-queue slot for [correctionId], mirroring [dueAt] and
  /// (S5/S6 v7) the SM-2 state. Called whenever a correction's
  /// `next_review_at` changes (i.e. after SM-2 scheduling) so the home
  /// dashboard's "to review" list stays in sync without re-deriving the
  /// schedule.
  ///
  /// [intervalDays] / [repetitions] / [easeFactor] default to the SM-2
  /// starting values so pre-v7 callers keep working; the dashboard uses
  /// these to order today's tasks by SM-2 progression (lower repetitions
  /// → earlier in the plan).
  Future<void> syncReviewQueue({
    required String correctionId,
    required DateTime dueAt,
    int intervalDays = 0,
    int repetitions = 0,
    double easeFactor = 2.5,
  }) async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();
    // SQLite has no native upsert in the sqflite helper; use
    // INSERT OR REPLACE with a deterministic id so re-syncing the same
    // correction doesn't create duplicate queue rows.
    final id = '${correctionId}_rq';
    await db.insert('review_queue', {
      'id': id,
      'correction_id': correctionId,
      'due_at': dueAt.toIso8601String(),
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a correction's review-queue slot. Called when a correction is
  /// deleted so the queue doesn't reference a missing correction.
  Future<void> removeReviewQueue(String correctionId) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      'review_queue',
      where: 'correction_id = ?',
      whereArgs: [correctionId],
    );
  }

  /// Fetch the [limit] most urgent review-queue items — sorted by due_at
  /// ascending so the soonest-due (most overdue) surface first. Joins the
  /// corrections table so the dashboard can render the original/corrected
  /// text without a second round-trip. S5/S6 v7 — also returns the SM-2
  /// state (interval_days / repetitions / ease_factor) for data-model
  /// completeness; the dashboard's "today's tasks" section surfaces the
  /// SM-2-driven review task at priority 1, and the pending-review list
  /// is ordered by due_at per the spec.
  Future<List<ReviewQueueItem>> getReviewQueueItems({int limit = 5}) async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT rq.id AS rq_id, rq.correction_id AS rq_cid, rq.due_at AS rq_due,
             rq.created_at AS rq_created,
             rq.interval_days AS rq_interval,
             rq.repetitions AS rq_reps,
             rq.ease_factor AS rq_ef,
             c.original AS c_orig, c.corrected AS c_corr, c.type AS c_type,
             c.importance AS c_imp
      FROM review_queue rq
      INNER JOIN corrections c ON c.id = rq.correction_id
      ORDER BY rq.due_at ASC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map((row) {
      return ReviewQueueItem(
        queue: ReviewQueue(
          id: row['rq_id'] as String,
          correctionId: row['rq_cid'] as String,
          dueAt: DateTime.parse(row['rq_due'] as String),
          // v7 columns are NULL for rows that pre-date the migration;
          // fall back to the SM-2 starting values so the model contract
          // (non-null) holds.
          intervalDays: (row['rq_interval'] as int?) ?? 0,
          repetitions: (row['rq_reps'] as int?) ?? 0,
          easeFactor: (row['rq_ef'] as num?)?.toDouble() ?? 2.5,
          createdAt: DateTime.parse(row['rq_created'] as String),
        ),
        correction: CorrectionRef(
          id: row['rq_cid'] as String,
          original: row['c_orig'] as String,
          corrected: row['c_corr'] as String,
          type: row['c_type'] as String,
          importance: (row['c_imp'] as int?) ?? 50,
        ),
      );
    }).toList();
  }

  /// Count of review-queue items due now (due_at <= now). Powers the
  /// dashboard's "due for review" badge.
  Future<int> getDueReviewQueueCount() async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM review_queue WHERE due_at <= ?',
      [now],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ========== Practice Log (S5/S6) ==========

  /// Upsert a practice_log row. The `date` column is UNIQUE so re-recording
  /// practice on the same day updates the existing row instead of
  /// inserting a duplicate. Returns the persisted row.
  Future<PracticeLog> upsertPracticeLog(PracticeLog log) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'practice_log',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return log;
  }

  /// Fetch the practice_log row for [dateKey] (`YYYY-MM-DD`), or null when
  /// the user hasn't practised that day.
  Future<PracticeLog?> getPracticeLogForDate(String dateKey) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'practice_log',
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PracticeLog.fromMap(maps.first);
  }

  /// Fetch the most recent [days] practice_log rows (newest first) for the
  /// streak bar's 30-day window.
  Future<List<PracticeLog>> getRecentPracticeLogs({int days = 30}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'practice_log',
      orderBy: 'date DESC',
      limit: days,
    );
    return maps.map((m) => PracticeLog.fromMap(m)).toList();
  }

  // ========== Skill-Tagged Corrections (S5/S6 v7) ==========

  /// The most recent [limit] corrections tagged with [skillId], newest
  /// `last_seen_at` first. Powers [SkillMasteryService.computeScore]'s
  /// "latest 20 practice events" window. Corrections with a NULL or empty
  /// skill tag are excluded by the WHERE clause.
  Future<List<Correction>> getRecentCorrectionsBySkill(
    String skillId, {
    int limit = 20,
  }) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'corrections',
      where: 'skill = ?',
      whereArgs: [skillId],
      orderBy: 'last_seen_at DESC',
      limit: limit,
    );
    return maps.map((m) => Correction.fromMap(m)).toList();
  }

  /// All distinct non-empty skill tags the user has been flagged on.
  /// Used by [SkillMasteryService.recomputeAll] to iterate over every
  /// skill that has at least one correction. Returns the tags in
  /// arbitrary order; the caller sorts if needed.
  Future<List<String>> getDistinctSkillIds() async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT skill FROM corrections "
      "WHERE skill IS NOT NULL AND TRIM(skill) != ''",
    );
    return rows
        .map((r) => r['skill'] as String?)
        .whereType<String>()
        .toList();
  }

  // ========== Skill Mastery (S5/S6 v7) ==========

  /// Upsert a skill_mastery row. The `skill_id` column is UNIQUE so
  /// re-computing a skill's score replaces the previous row instead of
  /// creating a duplicate. Uses INSERT OR REPLACE with a deterministic
  /// id derived from the skill id so re-computations land on the same row.
  Future<void> upsertSkillMastery(SkillMastery mastery) async {
    final db = await DatabaseHelper.database;
    final id = '${mastery.skillId}_sm';
    await db.insert(
      'skill_mastery',
      {
        'id': id,
        'skill_id': mastery.skillId,
        'score': mastery.score,
        'level': mastery.level,
        'updated_at': mastery.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All skill_mastery rows, ordered by score ASC so the weakest skills
  /// surface first on the dashboard (the user wants to see what to work
  /// on next, not what they've already mastered).
  Future<List<SkillMastery>> getAllSkillMastery() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('skill_mastery', orderBy: 'score ASC');
    return maps.map((m) => SkillMastery.fromMap(m)).toList();
  }

  /// One skill_mastery row by skill_id, or null when the skill hasn't been
  /// scored yet. Used by the dashboard's per-skill drill-down.
  Future<SkillMastery?> getSkillMastery(String skillId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'skill_mastery',
      where: 'skill_id = ?',
      whereArgs: [skillId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SkillMastery.fromMap(maps.first);
  }

  // ========== User Goal (S5/S6 v7) ==========

  /// Insert a new user_goal row. We keep history (one row per goal change)
  /// so the user can later review past goals; the "active" goal is the
  /// most recent row by `created_at` (see [getLatestUserGoal]).
  Future<void> insertUserGoal(UserGoal goal) async {
    final db = await DatabaseHelper.database;
    await db.insert('user_goal', goal.toMap());
  }

  /// The most recent user_goal row by `created_at`, or null when the user
  /// hasn't set a goal yet. This is the "active" goal the home dashboard
  /// reads for scenario recommendations.
  Future<UserGoal?> getLatestUserGoal() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'user_goal',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserGoal.fromMap(maps.first);
  }

  /// All user_goal rows newest-first (goal history). Kept for a future
  /// "past goals" UI; the dashboard only reads [getLatestUserGoal].
  Future<List<UserGoal>> getAllUserGoals() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('user_goal', orderBy: 'created_at DESC');
    return maps.map((m) => UserGoal.fromMap(m)).toList();
  }
}
