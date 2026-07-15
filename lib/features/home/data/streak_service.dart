import '../../chat/data/chat_repository.dart';
import '../domain/home_models.dart';

/// S5/S6 — streak tracking on top of the `practice_log` table.
///
/// A "streak" is the number of consecutive calendar days (ending today or
/// yesterday) on which the user completed at least one practice activity.
/// The streak is denormalised onto each `practice_log` row so the home
/// dashboard can render the current streak with a single cheap read.
///
/// Rules:
///   - Practising today extends yesterday's streak by 1 (or starts a new
///     streak at 1 if yesterday wasn't completed).
///   - Skipping a full day breaks the streak; the next practice starts at 1.
///   - The dashboard caps the visible window at 30 days with a 7-day
///     milestone badge every 7 days (7 / 14 / 21 / 28).
class StreakService {
  final ChatRepository _repo;

  StreakService(this._repo);

  /// Record a practice event for today: upsert the day's practice_log row,
  /// bumping `duration_seconds` by [durationSeconds] and computing the new
  /// streak. Set [completed] to true when the user finished a full practice
  /// activity (sent a message, rated a correction, etc.) — only completed
  /// days count toward the streak.
  ///
  /// Returns the persisted [PracticeLog] for today.
  Future<PracticeLog> recordPractice({
    int durationSeconds = 0,
    bool completed = true,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final dateKey = PracticeLog.formatDateKey(today);
    final existing = await _repo.getPracticeLogForDate(dateKey);

    // Accumulate duration across multiple sessions in the same day.
    final newDuration = (existing?.durationSeconds ?? 0) + durationSeconds;
    // Once completed, the day stays completed (we never un-complete).
    final isCompleted = completed || (existing?.completed ?? false);

    final newStreak = await _computeStreak(existing, today, isCompleted);

    final log = PracticeLog(
      id: existing?.id,
      date: dateKey,
      durationSeconds: newDuration,
      completed: isCompleted,
      streak: newStreak,
      createdAt: existing?.createdAt,
      updatedAt: today,
    );
    return _repo.upsertPracticeLog(log);
  }

  /// Compute the streak for today given the existing row + completion flag.
  ///
  /// - If the row already existed and was completed today, keep its streak
  ///   (already counted — don't double-increment on repeat practice).
  /// - If this is the first completion today, look at yesterday's row:
  ///   completed yesterday → streak = yesterday.streak + 1; else streak = 1.
  Future<int> _computeStreak(
    PracticeLog? existing,
    DateTime today,
    bool completed,
  ) async {
    if (!completed) return existing?.streak ?? 0;
    if (existing != null && existing.completed) return existing.streak;

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = PracticeLog.formatDateKey(yesterday);
    final yesterdayLog = await _repo.getPracticeLogForDate(yesterdayKey);
    if (yesterdayLog != null && yesterdayLog.completed) {
      return yesterdayLog.streak + 1;
    }
    return 1;
  }

  /// Get the current streak (today's or yesterday's `streak` value, since
  /// the streak is "consecutive days ending today or yesterday"). Returns
  /// 0 when the user hasn't practised in the last 2 days.
  Future<int> getCurrentStreak({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = PracticeLog.formatDateKey(today);
    final todayLog = await _repo.getPracticeLogForDate(todayKey);
    if (todayLog != null && todayLog.completed) return todayLog.streak;

    // If today isn't completed yet, the streak from yesterday is still
    // "active" (the user hasn't broken it yet today).
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = PracticeLog.formatDateKey(yesterday);
    final yesterdayLog = await _repo.getPracticeLogForDate(yesterdayKey);
    if (yesterdayLog != null && yesterdayLog.completed) {
      return yesterdayLog.streak;
    }
    return 0;
  }

  /// Fetch the last [days] practice_log rows for the streak bar window.
  /// Returns rows newest-first; the dashboard reverses them for display.
  Future<List<PracticeLog>> getStreakHistory({int days = 30}) {
    return _repo.getRecentPracticeLogs(days: days);
  }

  /// Whether the user has reached a 7-day milestone (7 / 14 / 21 / 28).
  /// Drives the milestone badge on the streak bar.
  bool isMilestone(int streak) {
    if (streak <= 0) return false;
    return streak % 7 == 0;
  }
}
