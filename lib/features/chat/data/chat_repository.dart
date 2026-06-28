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
    final maps = await db.query('chat_sessions', where: 'status = ?', whereArgs: ['active'], orderBy: 'updated_at DESC', limit: 1);
    if (maps.isEmpty) return null;
    return ChatSession.fromMap(maps.first);
  }

  Future<ChatSession?> getSession(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('chat_sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return ChatSession.fromMap(maps.first);
  }

  Future<ChatSession> createSession({String? topic, String? scenarioId, String? levelTag}) async {
    final session = ChatSession(topic: topic, scenarioId: scenarioId, levelTag: levelTag);
    final db = await DatabaseHelper.database;
    await db.insert('chat_sessions', session.toMap());
    return session;
  }

  Future<void> updateSession(ChatSession session) async {
    final db = await DatabaseHelper.database;
    await db.update('chat_sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> archiveSession(String id) async {
    final db = await DatabaseHelper.database;
    await db.update('chat_sessions', {'status': 'archived', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  // ========== Messages ==========

  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('chat_messages', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'created_at ASC');
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

  Future<void> updateCorrection(Correction correction) async {
    final db = await DatabaseHelper.database;
    await db.update('corrections', correction.toMap(), where: 'id = ?', whereArgs: [correction.id]);
  }

  Future<int> getCorrectionCount() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM corrections');
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

  // ========== Scenarios ==========

  Future<List<Scenario>> getAllScenarios() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('scenarios');
    return maps.map((m) => Scenario.fromMap(m)).toList();
  }

  Future<Scenario?> getScenario(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('scenarios', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Scenario.fromMap(maps.first);
  }
}
