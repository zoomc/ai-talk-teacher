import 'package:flutter/material.dart';
import '../domain/daily_plan.dart';
import 'chat_repository.dart';

/// Phase-1 P0 #6 — builds [DailyPlan] for the current day.
///
/// S5/S6 — the plan now adapts dynamically to the user's recent errors and
/// review window, producing 1–5 prioritised tasks. The plan is intentionally
/// stateless + cheap: rebuilt on every home-screen refresh from the live
/// repository data, so it never goes stale.
class DailyPlanService {
  /// Build today's plan from the current user state.
  ///
  /// - [dueCount] — number of corrections due for SRS review right now.
  /// - [hasActiveSession] — true when a non-archived session is resumable.
  /// - [scenarioCount] — number of scenarios available (drives the
  ///   "try a scenario" step).
  /// - [recentErrorCount] — number of corrections seen in the last 3 days
  ///   (drives a "review recent mistakes" task when the user is actively
  ///   making new errors).
  /// - [now] — injectable for tests; defaults to [DateTime.now].
  ///
  /// Priority scheme (1 = highest):
  ///   1. Due corrections review (when dueCount > 0)
  ///   2. Recent-mistake review (when recentErrorCount > 0)
  ///   3. Voice health pre-flight (when no active session)
  ///   4. Sentence-by-sentence practice
  ///   5. Free-talk / scenario conversation
  ///
  /// The plan always has at least 1 task and at most 5, per the S5/S6 spec.
  DailyPlan buildForToday({
    required int dueCount,
    required bool hasActiveSession,
    required int scenarioCount,
    int recentErrorCount = 0,
    DateTime? now,
  }) {
    final today = (now ?? DateTime.now());
    final tasks = <DailyPlanTask>[];

    // 1. SRS review of due corrections (only when there's something due).
    //    Highest priority — overdue reviews decay memory fastest.
    if (dueCount > 0) {
      tasks.add(DailyPlanTask(
        id: 'review',
        titleKey: 'plan.task.review',
        subtitleKey: 'plan.task.review_subtitle',
        icon: Icons.refresh,
        durationMinutes: 2,
        action: DailyPlanAction.openReview,
        badge: '$dueCount',
        priority: 1,
      ));
    }

    // 2. Recent-mistake drill — when the user has made new errors in the
    //    last 3 days, a focused review of those recent mistakes is more
    //    impactful than generic practice. Lower priority than due SRS cards
    //    (which are on a forgetting-curve deadline) but above warm-ups.
    if (recentErrorCount > 0 && tasks.length < 5) {
      tasks.add(DailyPlanTask(
        id: 'recent_errors',
        titleKey: 'plan.task.recent_errors',
        subtitleKey: 'plan.task.recent_errors_subtitle',
        icon: Icons.spellcheck_outlined,
        durationMinutes: 3,
        action: DailyPlanAction.openReview,
        badge: '$recentErrorCount',
        priority: 2,
      ));
    }

    // 3. Voice health pre-flight (skip if a session is already running —
    //    the user is past the setup phase for today).
    if (!hasActiveSession && tasks.length < 5) {
      tasks.add(const DailyPlanTask(
        id: 'voice_health',
        titleKey: 'plan.task.voice_health',
        subtitleKey: 'plan.task.voice_health_subtitle',
        icon: Icons.surround_sound_outlined,
        durationMinutes: 1,
        action: DailyPlanAction.openVoiceHealth,
        priority: 3,
      ));
    }

    // 4. Sentence-by-sentence practice — always useful, low friction.
    if (tasks.length < 5) {
      tasks.add(const DailyPlanTask(
        id: 'practice',
        titleKey: 'plan.task.practice',
        subtitleKey: 'plan.task.practice_subtitle',
        icon: Icons.record_voice_over_outlined,
        durationMinutes: 3,
        action: DailyPlanAction.openPractice,
        priority: 4,
      ));
    }

    // 5. A 3-minute free-talk or scenario roleplay to apply what was
    //    reviewed. When scenarios exist, nudge toward a roleplay because
    //    it's more focused than abstract free talk.
    if (tasks.length < 5) {
      tasks.add(DailyPlanTask(
        id: 'conversation',
        titleKey: 'plan.task.conversation',
        subtitleKey: 'plan.task.conversation_subtitle',
        icon: Icons.chat_bubble_outline,
        durationMinutes: 4,
        action: scenarioCount > 0
            ? DailyPlanAction.openScenarios
            : DailyPlanAction.startFreeTalk,
        priority: 5,
      ));
    }

    // Sort by priority (1 first) so the dashboard renders them in order.
    tasks.sort((a, b) => a.priority.compareTo(b.priority));

    return DailyPlan(date: today, tasks: tasks);
  }

  /// Convenience: build today's plan straight from a [ChatRepository].
  /// Fetches due-count, active-session, scenario-count, and recent-error
  /// count in one pass so the plan reflects live repository state.
  Future<DailyPlan> buildFromRepository(ChatRepository repo) async {
    final dueCount = await repo.getDueCorrectionCount();
    final active = await repo.getActiveSession();
    final scenarios = await repo.getAllScenarios();
    final recentErrors = await _getRecentErrorCount(repo);
    return buildForToday(
      dueCount: dueCount,
      hasActiveSession: active != null,
      scenarioCount: scenarios.length,
      recentErrorCount: recentErrors,
    );
  }

  /// Count corrections created in the last 3 days — drives the
  /// "recent mistakes" drill task. Uses a raw query so we don't pull full
  /// Correction rows just to count them.
  Future<int> _getRecentErrorCount(ChatRepository repo) async {
    // We can't access DatabaseHelper from here without a circular import,
    // so reuse the existing getAllCorrections path and filter in Dart.
    // The list is bounded by the user's total correction count (typically
    // < 200) so this is cheap enough for a dashboard refresh.
    final all = await repo.getAllCorrections();
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    return all.where((c) => c.lastSeenAt.isAfter(cutoff)).length;
  }
}
