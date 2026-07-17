/// Phase 5 — session continuity service.
///
/// Handles session save/restore (crash recovery), session metadata
/// management, and session summary generation. Works with the
/// `session_snapshots` and `session_metadata` tables.
library;

import '../../../core/database/database_helper.dart';
import '../domain/chat_models.dart';
import 'chat_repository.dart';

class SessionContinuityService {
  final ChatRepository _repo;

  SessionContinuityService(this._repo);

  // ==========================================================================
  // Save / Restore (Crash Recovery)
  // ==========================================================================

  /// Save a snapshot of the current session state. Call this periodically
  /// (e.g. after each AI reply) so the session can be restored on crash.
  Future<void> saveSnapshot(String sessionId, {String? contextSummary}) async {
    final lastMessages = await _repo.getMessages(sessionId, limit: 1);
    final lastId = lastMessages.isNotEmpty ? lastMessages.last.id : null;

    final snapshot = SessionSnapshot(
      sessionId: sessionId,
      lastMessageId: lastId,
      contextSummary: contextSummary,
    );
    await _repo.saveSessionSnapshot(snapshot);
  }

  /// Check whether a session has a recoverable snapshot.
  Future<bool> hasRecoverableSnapshot(String sessionId) async {
    final snapshot = await _repo.getSessionSnapshot(sessionId);
    return snapshot != null;
  }

  /// Get the last message id from a snapshot for restoring chat position.
  Future<String?> getLastMessageId(String sessionId) async {
    final snapshot = await _repo.getSessionSnapshot(sessionId);
    return snapshot?.lastMessageId;
  }

  /// Clear the snapshot after successful session end.
  Future<void> clearSnapshot(String sessionId) async {
    await _repo.deleteSessionSnapshot(sessionId);
  }

  // ==========================================================================
  // Session Metadata
  // ==========================================================================

  /// Update session metadata incrementally. Call after each message turn
  /// to keep duration / message count / correction count in sync.
  Future<void> updateSessionMeta(String sessionId) async {
    final messages = await _repo.getMessages(sessionId, limit: 1000);
    final corrections = await _repo.getCorrectionsForSession(sessionId);

    // Calculate approximate duration from first to last message
    int durationSeconds = 0;
    if (messages.length >= 2) {
      durationSeconds = messages.last
          .createdAt
          .difference(messages.first.createdAt)
          .inSeconds;
    }

    final existing = await _repo.getSessionMetadata(sessionId);
    final meta = (existing ?? SessionMetadata(sessionId: sessionId)).copyWith(
      durationSeconds: durationSeconds,
      messageCount: messages.length,
      correctionCount: corrections.length,
    );
    await _repo.upsertSessionMetadata(meta);
  }

  /// Try to auto-generate a summary for a session.
  /// Currently a placeholder — real summary generation integrates with
  /// the LLM service. For now we build a heuristic summary from available
  /// correction data.
  Future<String> generateSessionSummary(String sessionId) async {
    final messages = await _repo.getMessages(sessionId, limit: 40);
    final corrections = await _repo.getCorrectionsForSession(sessionId);
    final session = await _repo.getSession(sessionId);

    if (messages.isEmpty) return '';

    final topic = session?.topic ?? 'free talk';
    final turnCount = messages.length ~/ 2;
    final corrCount = corrections.length;

    final sb = StringBuffer();
    sb.write('Practiced "$topic" in $turnCount conversation turns');
    if (corrCount > 0) {
      sb.write(', received $corrCount corrections');

      // Categorize corrections by type for the summary
      final byType = <String, int>{};
      for (final c in corrections) {
        byType.update(c.type.name, (v) => v + 1, ifAbsent: () => 1);
      }
      final parts = byType.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      if (parts.isNotEmpty) {
        sb.write(' ($parts)');
      }
    }
    sb.write('.');
    return sb.toString();
  }

  /// Save an auto-generated summary to session metadata.
  Future<void> saveSessionSummary(String sessionId, {String? summary}) async {
    final text = summary ?? await generateSessionSummary(sessionId);
    if (text.isEmpty) return;

    final existing = await _repo.getSessionMetadata(sessionId);
    final meta = (existing ?? SessionMetadata(sessionId: sessionId)).copyWith(
      summary: text,
    );
    await _repo.upsertSessionMetadata(meta);
  }

  // ==========================================================================
  // History Browsing
  // ==========================================================================

  /// Get all sessions with enriched metadata for the history screen.
  /// Joins chat_sessions with session_metadata for a richer display.
  Future<List<({ChatSession session, SessionMetadata? meta})>>
      getEnrichedSessionHistory({int limit = 50}) async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT cs.*, sm.id AS sm_id, sm.duration_seconds AS sm_dur,
             sm.message_count AS sm_msg, sm.correction_count AS sm_corr,
             sm.summary AS sm_summary, sm.topic_tags AS sm_tags,
             sm.difficulty_level AS sm_diff, sm.updated_at AS sm_upd
      FROM chat_sessions cs
      LEFT JOIN session_metadata sm ON sm.session_id = cs.id
      ORDER BY cs.updated_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map((row) {
      final session = ChatSession.fromMap(row);
      SessionMetadata? meta;
      if (row['sm_id'] != null) {
        meta = SessionMetadata.fromMap({
          'id': row['sm_id'],
          'session_id': row['id'],
          'duration_seconds': row['sm_dur'] ?? 0,
          'message_count': row['sm_msg'] ?? 0,
          'correction_count': row['sm_corr'] ?? 0,
          'summary': row['sm_summary'],
          'topic_tags': row['sm_tags'],
          'difficulty_level': row['sm_diff'],
          'updated_at': row['sm_upd'] ?? row['updated_at'],
        });
      }
      return (session: session, meta: meta);
    }).toList();
  }

  /// Search sessions by text query (matches session topic or metadata summary).
  Future<List<ChatSession>> searchSessions(String query) async {
    final db = await DatabaseHelper.database;
    final pattern = '%$query%';
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT cs.* FROM chat_sessions cs
      LEFT JOIN session_metadata sm ON sm.session_id = cs.id
      WHERE cs.topic LIKE ? OR sm.summary LIKE ? OR sm.topic_tags LIKE ?
      ORDER BY cs.updated_at DESC
      LIMIT 50
      ''',
      [pattern, pattern, pattern],
    );
    return rows.map((m) => ChatSession.fromMap(m)).toList();
  }
}
