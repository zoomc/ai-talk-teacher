import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/daily_plan_service.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/domain/daily_plan.dart';
import '../../onboarding/domain/placement_result.dart';
import '../../profile/data/profile_repository.dart';
import '../data/skill_mastery_service.dart';
import '../data/streak_service.dart';
import '../data/user_goal_service.dart';
import '../domain/home_models.dart';

/// S5/S6 — StreakService singleton. Wraps [chatRepoProvider] so the streak
/// logic stays out of the repository and the dashboard.
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref.watch(chatRepoProvider));
});

/// S5/S6 v7 — SkillMasteryService singleton. Wraps [chatRepoProvider] so
/// the mastery recompute + the dashboard read share one repository
/// instance. Called after each review rating to refresh the persisted
/// skill_mastery rows.
final skillMasteryServiceProvider = Provider<SkillMasteryService>((ref) {
  return SkillMasteryService(ref.watch(chatRepoProvider));
});

/// S5/S6 v7 — UserGoalService singleton. Wraps [chatRepoProvider] for the
/// same reason as [streakServiceProvider]: keep the goal logic out of the
/// repository and the dashboard.
final userGoalServiceProvider = Provider<UserGoalService>((ref) {
  return UserGoalService(ref.watch(chatRepoProvider));
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
///
/// S5/S6 v7 — when skill_mastery rows exist for skills under a given
/// dimension (e.g. 'grammar/subject-verb-agreement' rolls up under
/// 'grammar'), we blend the placement score with the average mastery
/// score for that dimension's skills. This makes the radar reflect actual
/// recent practice rather than just the placement-day snapshot + raw error
/// counts.
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

  // S5/S6 v7 — blend with skill_mastery averages per dimension. Each skill
  // id is prefixed with its dimension ('grammar/...', 'vocabulary/...',
  // 'pronunciation/...', 'fluency/...'). When the user has mastery rows
  // for a dimension, we average them and blend 50/50 with the placement
  // score so the radar reflects recent practice. Skills with no mastery
  // rows leave the placement score untouched.
  final masteryRows = await chatRepo.getAllSkillMastery();
  if (masteryRows.isNotEmpty) {
    int avgFor(String prefix) {
      final matches =
          masteryRows.where((m) => m.skillId.startsWith('$prefix/'));
      if (matches.isEmpty) return -1; // sentinel: no data for this dim
      final sum = matches.fold<int>(0, (acc, m) => acc + m.score);
      return (sum / matches.length).round();
    }

    int blend(int placement, int mastery) {
      // 50/50 blend — placement gives the baseline, mastery gives the
      // recent trajectory.
      return ((placement + mastery) / 2).round().clamp(5, 100);
    }

    final g = avgFor('grammar');
    if (g >= 0) grammar = blend(grammar, g);
    final v = avgFor('vocabulary');
    if (v >= 0) vocabulary = blend(vocabulary, v);
    final p = avgFor('pronunciation');
    if (p >= 0) pronunciation = blend(pronunciation, p);
    final f = avgFor('fluency');
    if (f >= 0) fluency = blend(fluency, f);
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
    final fluencyShare = count(CorrectionType.fluency) / total;

    grammar = (grammar - (grammarShare * 15).round()).clamp(5, 100);
    vocabulary = (vocabulary - (vocabShare * 15).round()).clamp(5, 100);
    pronunciation =
        (pronunciation - (pronShare * 15).round()).clamp(5, 100);
    // S5/S6 v7 — `fluency` is now a first-class correction type, so the
    // share-based penalty mirrors the other dimensions instead of being
    // approximated by total error volume.
    fluency = (fluency - (fluencyShare * 15).round()).clamp(5, 100);
  }

  return AbilityScores(
    pronunciation: pronunciation,
    grammar: grammar,
    vocabulary: vocabulary,
    fluency: fluency,
  );
});

/// S5/S6 v7 — all skill_mastery rows (weakest first). Powers the home
/// dashboard's per-skill mastery list under the ability radar.
final skillMasteryListProvider =
    FutureProvider<List<SkillMastery>>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getAllSkillMastery();
});

/// S5/S6 v7 — the user's active goal (most recent by created_at), or null
/// when the user hasn't set one yet. Powers the dashboard's goal section.
final userGoalProvider = FutureProvider<UserGoal?>((ref) async {
  final svc = ref.watch(userGoalServiceProvider);
  return svc.getActiveGoal();
});

/// S5/S6 v7 — scenarios recommended for the active goal. Falls back to a
/// few generic scenarios when the user has no goal. Powers the dashboard's
/// "recommended for your goal" strip.
final recommendedScenariosProvider =
    FutureProvider<List<Scenario>>((ref) async {
  // Depend on userGoalProvider so a goal change refreshes the list.
  ref.watch(userGoalProvider);
  final svc = ref.watch(userGoalServiceProvider);
  return svc.recommendScenarios(limit: 3);
});
