/// Riverpod providers shared by the split chat widgets.
///
/// Extracted from chat_screen.dart as part of P1 task 2 (chat_screen split).
/// Keeping these in one place lets ChatMessageList, ChatBubble, and the
/// ChatScreen container all watch / invalidate the same provider instances
/// without circular imports.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/domain/chat_models.dart';
import '../../features/chat/domain/phoneme_score.dart';
import '../../shared/providers.dart';

/// All messages for a session, newest last. Invalidated by the chat screen
/// after saving a user or AI message so the list refreshes.
final messagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, sessionId) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getMessages(sessionId);
});

/// Per-session corrections grouped by message id, for inline display.
/// Invalidated together with [messagesProvider] after new corrections are saved.
final correctionsByMessageProvider =
    FutureProvider.family<Map<String, List<Correction>>, String>(
        (ref, sessionId) async {
  final repo = ref.watch(chatRepoProvider);
  final all = await repo.getCorrectionsForSession(sessionId);
  final map = <String, List<Correction>>{};
  for (final c in all) {
    final key = c.messageId;
    if (key == null) continue;
    map.putIfAbsent(key, () => []).add(c);
  }
  return map;
});

/// P1 task 4 — phoneme score sets keyed by message id, for word-level
/// colour tagging in the chat bubble. Loaded lazily per session and
/// invalidated when new scores are saved.
final phonemeScoresProvider =
    FutureProvider.family<Map<String, PhonemeScoreSet>, String>(
        (ref, sessionId) async {
  final repo = ref.watch(chatRepoProvider);
  final messages = await repo.getMessages(sessionId);
  final map = <String, PhonemeScoreSet>{};
  for (final msg in messages) {
    final set = await repo.getPhonemeScoresForMessage(msg.id);
    if (set != null) map[msg.id] = set;
  }
  return map;
});
