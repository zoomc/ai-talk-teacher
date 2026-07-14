import 'package:flutter/material.dart';
import '../domain/daily_plan.dart';
import 'chat_repository.dart';

/// Phase-1 P0 #6 — builds [DailyPlan] for the current day.
///
/// The plan adapts to the user's state (active session, due SRS cards,
/// available scenarios) and always totals 5–10 minutes. It's intentionally
/// stateless + cheap: rebuilt on every home-screen refresh from the live
/// repository data, so it never goes stale.
class DailyPlanService {
  /// Build today's plan from the current user state.
  ///
  /// - [dueCount] — number of corrections due for SRS review right now.
  /// - [hasActiveSession] — true when a non-archived session is resumable.
  /// - [scenarioCount] — number of scenarios available (drives the
  ///   "try a scenario" step).
  /// - [now] — injectable for tests; defaults to [DateTime.now].
  DailyPlan buildForToday({
    required int dueCount,
    required bool hasActiveSession,
    required int scenarioCount,
    DateTime? now,
  }) {
    final today = (now ?? DateTime.now());
    final tasks = <DailyPlanTask>[];

    // 1. Voice health pre-flight (skip if a session is already running —
    //    the user is past the setup phase for today).
    if (!hasActiveSession) {
      tasks.add(const DailyPlanTask(
        id: 'voice_health',
        titleKey: 'plan.task.voice_health',
        subtitleKey: 'plan.task.voice_health_subtitle',
        icon: Icons.surround_sound_outlined,
        durationMinutes: 1,
        action: DailyPlanAction.openVoiceHealth,
      ));
    }

    // 2. SRS review of due corrections (only when there's something due).
    if (dueCount > 0) {
      tasks.add(DailyPlanTask(
        id: 'review',
        titleKey: 'plan.task.review',
        subtitleKey: 'plan.task.review_subtitle',
        icon: Icons.refresh,
        durationMinutes: 2,
        action: DailyPlanAction.openReview,
        badge: '$dueCount',
      ));
    }

    // 3. Sentence-by-sentence practice — always useful, low friction.
    tasks.add(const DailyPlanTask(
      id: 'practice',
      titleKey: 'plan.task.practice',
      subtitleKey: 'plan.task.practice_subtitle',
      icon: Icons.record_voice_over_outlined,
      durationMinutes: 3,
      action: DailyPlanAction.openPractice,
    ));

    // 4. A 3-minute free-talk or scenario roleplay to apply what was
    //    reviewed. When scenarios exist, nudge toward a roleplay because
    //    it's more focused than abstract free talk.
    tasks.add(DailyPlanTask(
      id: 'conversation',
      titleKey: 'plan.task.conversation',
      subtitleKey: 'plan.task.conversation_subtitle',
      icon: Icons.chat_bubble_outline,
      durationMinutes: 4,
      action: scenarioCount > 0
          ? DailyPlanAction.openScenarios
          : DailyPlanAction.startFreeTalk,
    ));

    return DailyPlan(date: today, tasks: tasks);
  }

  /// Convenience: build today's plan straight from a [ChatRepository].
  Future<DailyPlan> buildFromRepository(ChatRepository repo) async {
    final dueCount = await repo.getDueCorrectionCount();
    final active = await repo.getActiveSession();
    final scenarios = await repo.getAllScenarios();
    return buildForToday(
      dueCount: dueCount,
      hasActiveSession: active != null,
      scenarioCount: scenarios.length,
    );
  }
}
