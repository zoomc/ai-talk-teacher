import '../../../core/database/database_helper.dart';
import '../domain/chat_models.dart';

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
  }) async {
    final session = ChatSession(
      topic: topic,
      scenarioId: scenarioId,
      levelTag: levelTag,
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
  /// them is gone.
  Future<void> deleteSession(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      // Delete corrections whose session_id matches, or whose message_id
      // belongs to a message in this session.
      await txn.delete(
        'corrections',
        where: 'session_id = ? OR message_id IN '
            '(SELECT id FROM chat_messages WHERE session_id = ?)',
        whereArgs: [id, id],
      );
      await txn.delete(
        'chat_messages',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'chat_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
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
    final maps = await db.query(
      'corrections',
      where: 'next_review_at IS NULL OR next_review_at <= ?',
      whereArgs: [now],
      orderBy: 'review_count ASC, created_at ASC',
      limit: limit,
    );
    return maps.map((m) => Correction.fromMap(m)).toList();
  }

  Future<void> saveCorrection(Correction correction) async {
    final db = await DatabaseHelper.database;
    await db.insert('corrections', correction.toMap());
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
      whereArgs: [
        original,
        corrected,
        type,
      ],
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
}
