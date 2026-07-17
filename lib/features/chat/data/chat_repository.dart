import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Transaction;

import '../../../core/database/database_helper.dart';
import '../domain/chat_models.dart';
import '../domain/phoneme_score.dart';
import '../domain/teacher_persona.dart';
import '../../home/domain/home_models.dart';
import '../../home/domain/progress_models.dart';

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
    // S7/S8 — when the archived session was a scenario roleplay, sync its
    // review-queue slot so the home dashboard surfaces "review this
    // scenario". Fetched before the UPDATE so we still see the original
    // row's scenario_id. Mirrors how `saveCorrection` seeds the correction
    // review_queue on insert.
    final session = await getSession(id);
    await db.update(
      'chat_sessions',
      {'status': 'archived', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    final sid = session?.scenarioId;
    if (sid != null && sid.isNotEmpty) {
      final avgScore = await getScenarioAverageScore(sid);
      await syncScenarioReviewQueue(
        scenarioId: sid,
        dueAt: DateTime.now(),
        lastScore: avgScore,
      );
    }
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
    // Wrap the correction update + review queue sync in a transaction so
    // a crash between the two never desyncs the queue from the table.
    await db.transaction((txn) async {
      await txn.update(
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
      await _syncReviewQueueTx(txn,
        correctionId: correction.id,
        dueAt: dueAt,
        intervalDays: correction.intervalDays,
        repetitions: correction.reviewCount,
        easeFactor: correction.easinessFactor,
      );
    });
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

  /// Count corrections flagged in the last [days] days, using a SQL COUNT
  /// instead of loading all rows into Dart. Powers the daily plan's "recent
  /// mistakes" drill task without pulling the full corrections table.
  Future<int> getRecentCorrectionCount({int days = 3}) async {
    final db = await DatabaseHelper.database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM corrections WHERE last_seen_at >= ?',
      [cutoff],
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

  /// Transactional variant of [syncReviewQueue] — inserts/replaces a review
  /// queue slot inside an existing transaction so the caller's correction
  /// update + queue sync are atomic. Mirrors the same SQL as [syncReviewQueue].
  Future<void> _syncReviewQueueTx(
    Transaction txn, {
    required String correctionId,
    required DateTime dueAt,
    int intervalDays = 0,
    int repetitions = 0,
    double easeFactor = 2.5,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = '${correctionId}_rq';
    await txn.insert('review_queue', {
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

  // ========== Scenario Items (S7/S8 v8) ==========

  /// Load the 5–8 structured core expressions for [scenarioId], ordered
  /// by their insertion id so the practice screen shows them in the seed
  /// order. Returns an empty list for scenarios that have no items yet.
  Future<List<ScenarioItem>> getScenarioItems(String scenarioId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'scenario_items',
      where: 'scenario_id = ?',
      whereArgs: [scenarioId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => ScenarioItem.fromMap(m)).toList();
  }

  /// Upsert a single [ScenarioItem]. Used by future content-management
  /// UI to add/edit expressions. Idempotent via INSERT OR REPLACE on the
  /// deterministic id.
  Future<void> upsertScenarioItem(ScenarioItem item) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'scenario_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Persist the user's latest 0–100 mastery score on a scenario item.
  /// Called after the practice screen rates an utterance. No-op when the
  /// item id doesn't exist (defensive — practice screens may run against
  /// a stale list).
  Future<void> updateScenarioItemScore(String itemId, int score) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'scenario_items',
      {'score': score.clamp(0, 100)},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Average mastery score across all items in [scenarioId]. 0 when the
  /// scenario has no items. Used by the home dashboard to surface "you're
  /// 60% through this scenario" and to seed [syncScenarioReviewQueue]'s
  /// `last_score` when a scenario conversation finishes.
  Future<int> getScenarioAverageScore(String scenarioId) async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery(
      'SELECT AVG(score) AS avg FROM scenario_items WHERE scenario_id = ?',
      [scenarioId],
    );
    final avg = (result.first['avg'] as num?)?.toDouble();
    if (avg == null) return 0;
    return avg.round().clamp(0, 100);
  }

  // ========== Teacher Personas (S7/S8 v8) ==========

  /// All teacher personas, ordered strict → encourage → humor (the seed
  /// insertion order) so the settings picker shows the canonical order.
  Future<List<TeacherPersona>> getAllTeacherPersonas() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('teacher_persona', orderBy: 'id ASC');
    return maps.map((m) => TeacherPersona.fromMap(m)).toList();
  }

  /// One teacher persona by id, or null when it doesn't exist.
  Future<TeacherPersona?> getTeacherPersona(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'teacher_persona',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TeacherPersona.fromMap(maps.first);
  }

  /// The user's currently-active persona id (stored in user_settings as
  /// `active_persona_id`). Returns null when the user hasn't picked one;
  /// the caller should fall back to a sensible default (encourage).
  Future<String?> getActiveTeacherPersonaId() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: ['active_persona_id'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  /// Persist the user's persona choice. The chat session builder reads
  /// this at conversation-start time to pick the system-prompt skeleton.
  Future<void> setActiveTeacherPersona(String id) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_settings',
      {'key': 'active_persona_id', 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The active persona, or the 'encourage' default when the user hasn't
  /// picked one. Falls back to the first persona in the table if the
  /// stored id points at a deleted row (defensive).
  Future<TeacherPersona> getActiveTeacherPersona() async {
    final activeId = await getActiveTeacherPersonaId();
    if (activeId != null) {
      final p = await getTeacherPersona(activeId);
      if (p != null) return p;
    }
    final all = await getAllTeacherPersonas();
    if (all.isNotEmpty) return all.first;
    // Last-resort synthetic persona — never happens in practice because
    // the v8 migration seeds 3 personas, but keeps the contract non-null.
    return TeacherPersona(
      id: 'persona_encourage',
      name: 'Ms. Lily',
      style: TeacherPersonaStyle.encourage,
      temp: 0.7,
      promptTemplate: '{scenario_prompt}',
    );
  }

  // ========== Scenario Review Queue (S7/S8 v8) ==========

  /// Upsert a scenario review-queue slot for [scenarioId], mirroring
  /// [dueAt] and the SM-2 state. Called when the user finishes a scenario
  /// conversation (and after each re-practice rating) so the home
  /// dashboard's "review this scenario" list stays in sync — the direct
  /// analogue of [syncReviewQueue] for corrections.
  ///
  /// `last_score` is the user's latest 0–100 mastery on the scenario
  /// (averaged from its scenario_items); the dashboard surfaces it as a
  /// progress hint.
  Future<void> syncScenarioReviewQueue({
    required String scenarioId,
    required DateTime dueAt,
    int intervalDays = 0,
    int repetitions = 0,
    double easeFactor = 2.5,
    int lastScore = 0,
  }) async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();
    // Deterministic id so re-syncing the same scenario replaces the slot
    // instead of creating duplicates (scenario_id is UNIQUE anyway, but
    // the explicit id keeps the row stable across re-syncs).
    final id = '${scenarioId}_srq';
    await db.insert('scenario_review_queue', {
      'id': id,
      'scenario_id': scenarioId,
      'due_at': dueAt.toIso8601String(),
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'last_score': lastScore,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a scenario's review-queue slot. Called if the user resets a
  /// scenario's progress so it falls out of the review rotation.
  Future<void> removeScenarioReviewQueue(String scenarioId) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      'scenario_review_queue',
      where: 'scenario_id = ?',
      whereArgs: [scenarioId],
    );
  }

  /// Fetch the [limit] most urgent scenario review-queue items, sorted by
  /// due_at ascending (most overdue first). Joins the scenarios table so
  /// the dashboard can render the name/icon without a second round-trip.
  /// Mirrors [getReviewQueueItems] for corrections.
  Future<List<ScenarioReviewQueueItem>> getScenarioReviewQueueItems({
    int limit = 5,
  }) async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT srq.id AS srq_id, srq.scenario_id AS srq_sid,
             srq.due_at AS srq_due, srq.created_at AS srq_created,
             srq.interval_days AS srq_interval, srq.repetitions AS srq_reps,
             srq.ease_factor AS srq_ef, srq.last_score AS srq_score,
             s.name AS s_name, s.icon AS s_icon, s.difficulty AS s_diff,
             s.goal AS s_goal
      FROM scenario_review_queue srq
      INNER JOIN scenarios s ON s.id = srq.scenario_id
      ORDER BY srq.due_at ASC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map((row) {
      return ScenarioReviewQueueItem(
        queue: ScenarioReviewQueue(
          id: row['srq_id'] as String,
          scenarioId: row['srq_sid'] as String,
          dueAt: DateTime.parse(row['srq_due'] as String),
          intervalDays: (row['srq_interval'] as int?) ?? 0,
          repetitions: (row['srq_reps'] as int?) ?? 0,
          easeFactor: (row['srq_ef'] as num?)?.toDouble() ?? 2.5,
          lastScore: (row['srq_score'] as int?) ?? 0,
          createdAt: DateTime.parse(row['srq_created'] as String),
        ),
        scenario: ScenarioRef(
          id: row['srq_sid'] as String,
          name: row['s_name'] as String,
          icon: row['s_icon'] as String,
          difficulty: row['s_diff'] as String,
          goal: row['s_goal'] as String?,
        ),
      );
    }).toList();
  }

  /// Count of scenario review-queue items due now (due_at <= now). Powers
  /// the dashboard's "scenarios to review" badge alongside the correction
  /// due count.
  Future<int> getDueScenarioReviewQueueCount() async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM scenario_review_queue WHERE due_at <= ?',
      [now],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ========== Content Settings (S7/S8 v8) ==========

  /// Whether structured scenario content is enabled on the home dashboard.
  /// Defaults to true (the spec ships content on by default; the user can
  /// disable it from Settings → Content Management).
  Future<bool> getContentEnabled() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: ['content_enabled'],
      limit: 1,
    );
    if (maps.isEmpty) return true;
    return (maps.first['value'] as String) == 'true';
  }

  Future<void> setContentEnabled(bool enabled) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_settings',
      {'key': 'content_enabled', 'value': enabled ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// How many scenarios the home dashboard recommends per day. Defaults
  /// to 3; clamped to 1–10 by the setter so a malformed stored value can
  /// never blow up the dashboard layout.
  Future<int> getDailyScenarioRecommendationCount() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: ['daily_scenario_count'],
      limit: 1,
    );
    if (maps.isEmpty) return 3;
    final n = int.tryParse(maps.first['value'] as String) ?? 3;
    return n.clamp(1, 10);
  }

  Future<void> setDailyScenarioRecommendationCount(int count) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_settings',
      {'key': 'daily_scenario_count', 'value': '${count.clamp(1, 10)}'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Scenarios the user hasn't started yet (no chat_session row), limited
  /// to [limit]. Powers the home dashboard's "today's recommended
  /// scenario" task and the structured-content strip. Falls back to all
  /// scenarios when every scenario has been started — the dashboard still
  /// wants something to show.
  Future<List<Scenario>> getRecommendedScenarios({int limit = 3}) async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT s.* FROM scenarios s
      WHERE s.id NOT IN (
        SELECT DISTINCT scenario_id FROM chat_sessions
        WHERE scenario_id IS NOT NULL
      )
      ORDER BY s.id ASC
      LIMIT ?
    ''',
      [limit],
    );
    if (rows.length < limit) {
      // Not enough untouched scenarios — top up with the earliest ones so
      // the dashboard always has [limit] cards to render.
      final all = await db.rawQuery(
        'SELECT * FROM scenarios ORDER BY id ASC LIMIT ?',
        [limit],
      );
      return all.map((m) => Scenario.fromMap(m)).toList();
    }
    return rows.map((m) => Scenario.fromMap(m)).toList();
  }

  // ========== Phase 5 — Pronunciation Reports ==========

  /// Save a pronunciation report for a session (idempotent upsert).
  Future<void> savePronunciationReport(PronunciationReport report) async {
    final db = await DatabaseHelper.database;
    await db.insert('pronunciation_reports', report.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Load the pronunciation report for a session, or null if none exists.
  Future<PronunciationReport?> getPronunciationReport(String sessionId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'pronunciation_reports',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PronunciationReport.fromMap(maps.first);
  }

  /// Recent pronunciation reports (newest first), for trend analysis.
  Future<List<PronunciationReport>> getRecentPronunciationReports({
    int limit = 10,
  }) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'pronunciation_reports',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => PronunciationReport.fromMap(m)).toList();
  }

  // ========== Phase 5 — Weak Areas ==========

  /// Upsert a weak area. When an area with the same (area_type, description)
  /// exists, increments its frequency and updates last_seen_at.
  Future<WeakArea> upsertWeakArea(WeakArea area) async {
    final db = await DatabaseHelper.database;
    final existing = await db.query(
      'weak_areas',
      where: 'area_type = ? AND description = ?',
      whereArgs: [area.areaType, area.description],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final current = WeakArea.fromMap(existing.first);
      final updated = current.copyWith(
        frequencyCount: current.frequencyCount + 1,
        lastSeenAt: DateTime.now(),
      );
      await db.update(
        'weak_areas',
        {
          'frequency_count': updated.frequencyCount,
          'last_seen_at': updated.lastSeenAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [current.id],
      );
      return updated;
    }
    await db.insert('weak_areas', area.toMap());
    return area;
  }

  /// All weak areas, ordered by frequency descending (most common first).
  Future<List<WeakArea>> getWeakAreas({int limit = 20}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'weak_areas',
      orderBy: 'frequency_count DESC, last_seen_at DESC',
      limit: limit,
    );
    return maps.map((m) => WeakArea.fromMap(m)).toList();
  }

  /// Weak areas filtered by type, for per-dimension analysis.
  Future<List<WeakArea>> getWeakAreasByType(String areaType,
      {int limit = 10}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'weak_areas',
      where: 'area_type = ?',
      whereArgs: [areaType],
      orderBy: 'frequency_count DESC',
      limit: limit,
    );
    return maps.map((m) => WeakArea.fromMap(m)).toList();
  }

  // ========== Phase 5 — Session Snapshots (Crash Recovery) ==========

  /// Save a session snapshot. Replaces any prior snapshot for the same
  /// session (we only keep the latest).
  Future<void> saveSessionSnapshot(SessionSnapshot snapshot) async {
    final db = await DatabaseHelper.database;
    await db.insert('session_snapshots', snapshot.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Load the latest snapshot for a session, or null if none exists.
  Future<SessionSnapshot?> getSessionSnapshot(String sessionId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'session_snapshots',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SessionSnapshot.fromMap(maps.first);
  }

  /// Delete a session snapshot (called when the session ends cleanly).
  Future<void> deleteSessionSnapshot(String sessionId) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      'session_snapshots',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // ========== Phase 5 — Expression Suggestions ==========

  /// Save an expression suggestion for a message.
  Future<void> saveExpressionSuggestion(
      ExpressionSuggestion suggestion) async {
    final db = await DatabaseHelper.database;
    await db.insert('expression_suggestions', suggestion.toMap());
  }

  /// Get expression suggestions for a session, newest first.
  Future<List<ExpressionSuggestion>> getExpressionSuggestions(
      String sessionId, {int limit = 10}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'expression_suggestions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => ExpressionSuggestion.fromMap(m)).toList();
  }

  /// Get the suggestion for a specific message.
  Future<ExpressionSuggestion?> getSuggestionForMessage(
      String messageId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'expression_suggestions',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExpressionSuggestion.fromMap(maps.first);
  }

  // ========== Phase 5 — Session Metadata ==========

  /// Upsert session metadata. Rows are UNIQUE on session_id so this
  /// replaces the whole row on conflict.
  Future<void> upsertSessionMetadata(SessionMetadata meta) async {
    final db = await DatabaseHelper.database;
    await db.insert('session_metadata', meta.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Load session metadata for a specific session.
  Future<SessionMetadata?> getSessionMetadata(String sessionId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'session_metadata',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SessionMetadata.fromMap(maps.first);
  }

  /// All session metadata rows, newest first, for the history list.
  Future<List<SessionMetadata>> getAllSessionMetadata({int limit = 50}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'session_metadata',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map((m) => SessionMetadata.fromMap(m)).toList();
  }

  /// Search session metadata by topic tag.
  Future<List<SessionMetadata>> searchSessionByTag(
      String tag, {int limit = 20}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'session_metadata',
      where: 'topic_tags LIKE ?',
      whereArgs: ['%$tag%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map((m) => SessionMetadata.fromMap(m)).toList();
  }
}
