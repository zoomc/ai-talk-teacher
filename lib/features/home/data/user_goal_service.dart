import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../domain/home_models.dart';

/// S5/S6 v7 — user-goal CRUD + scenario recommendations.
///
/// The "active" goal is the most recent row in the `user_goal` table (by
/// `created_at`). The home dashboard reads it via [getActiveGoal] and uses
/// [recommendScenarios] to surface goal-aligned practice content above the
/// generic scenario list.
///
/// Goal → scenario mapping:
///   interview → category 'career'  (job_interview, business_meeting)
///   travel    → category 'travel'  (airport, restaurant, shopping)
///   ielts     → category 'general' (free_talk, date) — IELTS speaking
///               rewards general fluency over role-specific vocab.
///   daily     → category 'daily'   (restaurant, shopping, doctor, date)
///
/// When the user hasn't set a goal yet, [getActiveGoal] returns null and
/// the dashboard falls back to showing all scenarios (no filter).
class UserGoalService {
  final ChatRepository _repo;

  UserGoalService(this._repo);

  /// Set a new active goal. Persists a new row (we keep goal history so the
  /// user can see past goals later); the most recent row by `created_at` is
  /// considered active. [goalType] is normalised via [GoalType.normalize].
  /// [target] is an optional free-text description; empty string is fine.
  Future<UserGoal> setGoal({
    required String goalType,
    String target = '',
    DateTime? now,
  }) async {
    final normalised = GoalType.normalize(goalType);
    final goal = UserGoal(
      goalType: normalised,
      target: target.trim(),
      createdAt: now ?? DateTime.now(),
    );
    await _repo.insertUserGoal(goal);
    return goal;
  }

  /// The active goal (most recent by `created_at`), or null when the user
  /// hasn't set one yet. Used by the home dashboard's goal section + the
  /// scenario recommendation.
  Future<UserGoal?> getActiveGoal() async {
    return _repo.getLatestUserGoal();
  }

  /// Recommend scenarios for the active goal. Returns up to [limit]
  /// scenarios whose category matches the goal's preferred category; falls
  /// back to all scenarios when the user has no goal or when the preferred
  /// category has no matches (so the dashboard never shows an empty list).
  Future<List<Scenario>> recommendScenarios({
    int limit = 3,
    UserGoal? activeGoal,
  }) async {
    final all = await _repo.getAllScenarios();
    final goal = activeGoal ?? await getActiveGoal();
    if (goal == null) {
      // No goal set → no filter. Return the first [limit] scenarios so the
      // dashboard has something to show.
      return all.take(limit).toList();
    }
    final preferredCategory = GoalType.preferredCategory(goal.goalType);
    final matches =
        all.where((s) => s.category == preferredCategory).toList();
    if (matches.isEmpty) {
      // Goal category has no scenarios (e.g. a future goal type) — fall
      // back to all scenarios rather than showing an empty recommendation.
      return all.take(limit).toList();
    }
    return matches.take(limit).toList();
  }
}
