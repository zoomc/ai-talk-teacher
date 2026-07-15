import 'package:flutter/material.dart';

/// Phase-1 P0 #6 — Today's Plan.
///
/// A short (5–10 min) sequence of micro-tasks the user can run end-to-end
/// from the home screen. The plan is rebuilt deterministically per day
/// (seeded by the date) so it doesn't reshuffle on every rebuild, and it
/// adapts to the user's current state — e.g. the review step only appears
/// when there are due corrections, the warm-up skips when an active
/// session is already running.
class DailyPlan {
  final DateTime date;
  final List<DailyPlanTask> tasks;

  const DailyPlan({required this.date, required this.tasks});

  int get totalMinutes =>
      tasks.fold(0, (sum, t) => sum + t.durationMinutes);

  bool get isEmpty => tasks.isEmpty;
}

/// One step in the daily plan.
class DailyPlanTask {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final int durationMinutes;
  final DailyPlanAction action;

  /// Optional badge text shown on the trailing side, e.g. "5 due".
  final String? badge;

  /// S5/S6 — priority 1 (highest) to 5 (lowest). Drives sort order and the
  /// priority pill colour on the dashboard's "今日任务" card. Lower number =
  /// more urgent (e.g. due corrections rank above a free-talk warm-up).
  final int priority;

  /// S7/S8 — the scenario id this task starts, when [action] is
  /// [DailyPlanAction.startScenario]. Null for all other actions. Carried
  /// on the task (rather than looked up at tap time) so the dashboard's
  /// "today's recommended scenario" is stable across rebuilds and the
  /// home page can navigate straight into the conversation.
  final String? scenarioId;

  const DailyPlanTask({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.durationMinutes,
    required this.action,
    this.badge,
    this.priority = 3,
    this.scenarioId,
  });
}

/// What happens when the user taps a plan task. The home screen interprets
/// each value — keeping the action declarative lets the plan service stay
/// free of BuildContext / navigation concerns.
enum DailyPlanAction {
  /// Start a fresh free-talk chat session (home._startNewSession).
  startFreeTalk,

  /// Push /review — SRS correction review.
  openReview,

  /// Push /practice — sentence-by-sentence practice mode.
  openPractice,

  /// Push /scenarios — pick a scenario to roleplay.
  openScenarios,

  /// Push /voice-health — pre-flight mic/network/STT/TTS check.
  openVoiceHealth,

  /// S7/S8 — start a conversation with a specific recommended scenario.
  /// The scenario id is carried on the [DailyPlanTask] (`scenarioId`).
  /// The home page reads it and jumps straight into the chat, mirroring
  /// the goal-recommendation strip's `_startScenario` flow.
  startScenario,
}
