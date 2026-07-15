import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/daily_plan_service.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/domain/daily_plan.dart';
import '../../onboarding/domain/placement_result.dart';
import '../../profile/data/profile_repository.dart';
import '../data/streak_service.dart';
import '../domain/home_models.dart';

/// S5/S6 — StreakService singleton. Wraps [chatRepoProvider] so the streak
/// logic stays out of the repository and the dashboard.
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref.watch(chatRepoProvider));
});

/// Today's practice log row (null when the user hasn't practised today).
/// Used by the streak bar to highlight "today" and by the dashboard to
/// show today's accumulated practice duration.
final todayPracticeLogProvider = FutureProvider<PracticeLog?>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  final todayKey = PracticeLog.formatDateKey(DateTime.now());
  return repo.getPracticeLogForDate(todayKey);
});

/// Current streak count (consecutive completed days ending today or
/// yesterday). Powers the headline number on the streak bar.
final currentStreakProvider = FutureProvider<int>((ref) async {
  final svc = ref.watch(streakServiceProvider);
  return svc.getCurrentStreak();
});

/// Last 30 days of practice_log rows for the streak bar. Newest-first; the
/// UI reverses to oldest-first for left-to-right display.
final streakHistoryProvider =
    FutureProvider<List<PracticeLog>>((ref) async {
  final svc = ref.watch(streakServiceProvider);
  return svc.getStreakHistory(days: 30);
});

/// The 5 most urgent review-queue items, sorted by due_at ascending (most
/// overdue first). Powers the dashboard's "待复习纠错列表".
final reviewQueueProvider =
    FutureProvider<List<ReviewQueueItem>>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getReviewQueueItems(limit: 5);
});

/// Count of due review-queue items — drives the badge on the "复习纠错"
/// quick-action button and the streak-bar header.
final dueReviewQueueCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getDueReviewQueueCount();
});

/// Today's dynamic plan (1–5 prioritised tasks). Rebuilt on every
/// dashboard refresh from live repository state.
final dailyPlanProvider = FutureProvider<DailyPlan>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return DailyPlanService().buildFromRepository(repo);
});

/// Active chat session (resumable). Surfaces a "continue practice" card on
/// the dashboard when present.
final activeSessionProvider = FutureProvider<ChatSession?>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getActiveSession();
});

/// Four-dimension ability scores (pronunciation / grammar / vocabulary /
/// fluency). Derived from the placement scores (if available) blended with
/// the correction-type distribution so the radar reflects both initial
/// level and recent practice gaps.
final abilityScoresProvider = FutureProvider<AbilityScores>((ref) async {
  final profileRepo = ref.watch(profileRepoProvider);
  final chatRepo = ref.watch(chatRepoProvider);

  // Base scores from placement (default to 50 across the board when the
  // user skipped placement or hasn't been assessed yet).
  var pronunciation = 50;
  var grammar = 50;
  var vocabulary = 50;
  var fluency = 50;

  final pathJson = await profileRepo.getLearningPath();
  if (pathJson != null && pathJson.isNotEmpty) {
    try {
      final decoded = jsonDecode(pathJson);
      if (decoded is Map<String, dynamic>) {
        final scores = PlacementScores.fromMap(decoded);
        pronunciation = scores.pronunciation;
        grammar = scores.grammar;
        vocabulary = scores.vocabulary;
        fluency = scores.fluency;
      }
    } catch (_) {
      // Malformed JSON — fall back to defaults.
    }
  }

  // Blend with correction-type distribution: a higher concentration of a
  // given error type means that dimension is weaker. We nudge the score
  // down by up to 15 points proportional to the error-type share, so the
  // radar reflects where the user actually struggles rather than just the
  // placement-day snapshot.
  final corrections = await chatRepo.getAllCorrections();
  if (corrections.isNotEmpty) {
    final total = corrections.length;
    int count(CorrectionType t) =>
        corrections.where((c) => c.type == t).length;
    final grammarShare = count(CorrectionType.grammar) / total;
    final vocabShare = count(CorrectionType.vocabulary) / total;
    final pronShare = count(CorrectionType.pronunciation) / total;

    grammar = (grammar - (grammarShare * 15).round()).clamp(5, 100);
    vocabulary = (vocabulary - (vocabShare * 15).round()).clamp(5, 100);
    pronunciation =
        (pronunciation - (pronShare * 15).round()).clamp(5, 100);
    // Fluency isn't directly tied to a correction type; nudge it down
    // slightly with overall error volume (more errors = less fluent).
    final errorPenalty = (total / 50).clamp(0.0, 1.0) * 10;
    fluency = (fluency - errorPenalty.round()).clamp(5, 100);
  }

  return AbilityScores(
    pronunciation: pronunciation,
    grammar: grammar,
    vocabulary: vocabulary,
    fluency: fluency,
  );
});
