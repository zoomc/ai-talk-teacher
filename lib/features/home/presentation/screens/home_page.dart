import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../chat/domain/chat_models.dart';
import '../../../chat/domain/daily_plan.dart';
import '../../../chat/domain/teacher_persona.dart';
import '../../../onboarding/presentation/widgets/placement_radar_chart.dart';
import '../../domain/home_models.dart';
import '../home_providers.dart';

/// S5/S6 — the home learning dashboard.
///
/// Replaces the legacy [HomeScreen] with a richer board: streak progress
/// bar, today's prioritised tasks, ability overview radar, pending-review
/// queue, and three big quick-action buttons. The dashboard is the app's
/// default landing page (`/`); ChatScreen is now a push destination.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lowBandwidth = ref.watch(lowBandwidthProvider);
    final streak = ref.watch(currentStreakProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: lowBandwidth
              ? (isLight ? AppColors.lightFlatBg : AppColors.darkFlatBg)
              : null,
          gradient: lowBandwidth
              ? null
              : (isLight ? AppColors.lightGradientBg : AppColors.gradientBg),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: RefreshIndicator(
                onRefresh: () => _refreshAll(ref),
                child: CustomScrollView(
                  slivers: [
                    // ── Header ──────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradientPrimary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                              ),
                              child: const Icon(Icons.mic,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting(l),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  Text(
                                    l.t('dashboard.subtitle'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Streak flame badge
                            _StreakBadge(streak: streak),
                          ],
                        ),
                      ),
                    ),

                    // ── Streak progress bar ─────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _StreakProgressBar(),
                      ),
                    ),

                    // ── Quick action buttons (3 big) ────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: _QuickActionButtons(
                          onConversation: () => _startConversation(context),
                          onReview: () => _openReview(context),
                          onPronunciation: () =>
                              _openPronunciation(context),
                        ),
                      ),
                    ),

                    // ── Goal + recommended scenarios ─────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                        child: _GoalSection(
                          onStartScenario: (scenario) =>
                              _startScenario(context, scenario),
                        ),
                      ),
                    ),

                    // ── Today's tasks ───────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                        child: Text(
                          l.t('dashboard.today_tasks'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _TodayTasksSection(
                          onTap: (task) =>
                              _handlePlanAction(context, task),
                        ),
                      ),
                    ),

                    // ── Ability overview + review queue (side by side on
                    //     wide screens, stacked on phone) ────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide =
                                constraints.maxWidth >= 720;
                            if (wide) {
                              return Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: _AbilityOverviewSection()),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                      child: _ReviewQueueSection(
                                    onTap: () => context.push('/review'),
                                  )),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _AbilityOverviewSection(),
                                const SizedBox(height: AppSpacing.md),
                                _ReviewQueueSection(
                                  onTap: () => context.push('/review'),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // ── S7/S8 — Structured scenario content ─────────────
                    // Recommended scenarios strip + scenario review queue.
                    // Hidden entirely when the user disabled content in
                    // Settings → Content Management.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                        child: _StructuredContentSection(
                          onStartScenario: (scenario) =>
                              _startScenario(context, scenario),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _greeting(AppLocalizations l) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l.t('home.greeting_morning');
    if (hour < 18) return l.t('home.greeting_afternoon');
    return l.t('home.greeting_evening');
  }

  /// Invalidate all dashboard providers so the next frame re-fetches from
  /// the repository. Called on pull-to-refresh.
  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(currentStreakProvider);
    ref.invalidate(streakHistoryProvider);
    ref.invalidate(todayPracticeLogProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(dueReviewQueueCountProvider);
    ref.invalidate(dailyPlanProvider);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(abilityScoresProvider);
    // S5/S6 v7 — refresh goal + mastery-backed providers too.
    ref.invalidate(userGoalProvider);
    ref.invalidate(recommendedScenariosProvider);
    ref.invalidate(skillMasteryListProvider);
    // S7/S8 — refresh structured-content providers too.
    ref.invalidate(contentSettingsProvider);
    ref.invalidate(todayRecommendedScenariosProvider);
    ref.invalidate(scenarioReviewQueueProvider);
    ref.invalidate(dueScenarioReviewQueueCountProvider);
    ref.invalidate(activeTeacherPersonaProvider);
    // Wait for the invalidated providers to settle so the
    // RefreshIndicator dismisses only after the data is fresh.
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// "开始对话" — create a new free-talk session and record today's
  /// practice. The streak is bumped before navigation so the dashboard
  /// shows the new streak when the user returns. Streak failures are
  /// swallowed so a SQLite hiccup never blocks the user from chatting.
  Future<void> _startConversation(BuildContext context) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(topic: 'Free Talk');
    // Record practice: starting a conversation counts as a completed day.
    try {
      await ref.read(streakServiceProvider).recordPractice(
            durationSeconds: 0,
            completed: true,
          );
      ref.invalidate(currentStreakProvider);
      ref.invalidate(streakHistoryProvider);
      ref.invalidate(todayPracticeLogProvider);
    } catch (_) {
      // Streak recording is best-effort — don't block the chat session.
    }
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  /// "复习纠错" — push the review screen. Practice is recorded when the
  /// user actually rates a correction (wired in ReviewScreen), not on
  /// mere entry, so we don't inflate the streak for a bounce visit.
  void _openReview(BuildContext context) {
    context.push('/review');
  }

  /// "发音练习" — push the sentence-practice screen and record practice.
  /// Streak failures are swallowed so they don't block navigation.
  Future<void> _openPronunciation(BuildContext context) async {
    try {
      await ref.read(streakServiceProvider).recordPractice(
            durationSeconds: 0,
            completed: true,
          );
      ref.invalidate(currentStreakProvider);
      ref.invalidate(streakHistoryProvider);
    } catch (_) {
      // Streak recording is best-effort.
    }
    if (context.mounted) {
      context.push('/practice');
    }
  }

  /// S5/S6 v7 — start a conversation with a recommended scenario. Mirrors
  /// [ScenariosScreen._startScenario] but records today's practice so the
  /// streak is bumped when the user engages with a goal recommendation.
  Future<void> _startScenario(BuildContext context, Scenario scenario) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(
      topic: scenario.name,
      scenarioId: scenario.id,
    );
    try {
      await ref.read(streakServiceProvider).recordPractice(
            durationSeconds: 0,
            completed: true,
          );
      ref.invalidate(currentStreakProvider);
      ref.invalidate(streakHistoryProvider);
      ref.invalidate(todayPracticeLogProvider);
    } catch (_) {
      // Streak recording is best-effort.
    }
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  void _handlePlanAction(BuildContext context, DailyPlanTask task) {
    switch (task.action) {
      case DailyPlanAction.startFreeTalk:
        _startConversation(context);
        break;
      case DailyPlanAction.openReview:
        context.push('/review');
        break;
      case DailyPlanAction.openPractice:
        _openPronunciation(context);
        break;
      case DailyPlanAction.openScenarios:
        context.push('/scenarios');
        break;
      case DailyPlanAction.openVoiceHealth:
        context.push('/voice-health');
        break;
      case DailyPlanAction.startScenario:
        // S7/S8 — the plan carried a specific recommended scenario id;
        // look it up and jump straight into the conversation so the user
        // doesn't have to pick from the scenarios list.
        if (task.scenarioId != null && task.scenarioId!.isNotEmpty) {
          _startScenarioById(context, task.scenarioId!);
        } else {
          context.push('/scenarios');
        }
        break;
    }
  }

  /// S7/S8 — start a conversation with the scenario identified by [id].
  /// Used by the daily-plan `startScenario` action, which carries only the
  /// id (the plan is built before the dashboard has the Scenario objects).
  /// Falls back to the scenarios list if the id no longer exists.
  Future<void> _startScenarioById(BuildContext context, String id) async {
    final repo = ref.read(chatRepoProvider);
    final scenario = await repo.getScenario(id);
    if (scenario == null) {
      if (context.mounted) context.push('/scenarios');
      return;
    }
    if (context.mounted) _startScenario(context, scenario);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Streak badge (header)
// ─────────────────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final AsyncValue<int> streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return streak.when(
      data: (v) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 4),
            Text(
              '$v',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Streak progress bar (30 days, 7-day milestones)
// ─────────────────────────────────────────────────────────────────────────

class _StreakProgressBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final history = ref.watch(streakHistoryProvider);
    final currentStreak = ref.watch(currentStreakProvider);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.t('dashboard.streak_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                currentStreak.when(
                  data: (v) => Text(
                    l.tArg('dashboard.streak_days', {'n': '$v'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 30-day dot bar
            history.when(
              data: (logs) => _StreakDots(logs: logs),
              loading: () => const ShimmerBox(
                  width: double.infinity, height: 48),
              error: (_, _) => _StreakDots(logs: const []),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Milestone badges: 7 / 14 / 21 / 28
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final milestone in [7, 14, 21, 28])
                  _MilestoneBadge(
                    milestone: milestone,
                    reached: currentStreak.maybeWhen(
                      data: (v) => v >= milestone,
                      orElse: () => false,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakDots extends StatelessWidget {
  final List<PracticeLog> logs;
  const _StreakDots({required this.logs});

  @override
  Widget build(BuildContext context) {
    // Build a 30-cell grid keyed by date, oldest → newest left → right.
    final now = DateTime.now();
    final todayKey = PracticeLog.formatDateKey(now);
    final completedDays = <String, PracticeLog>{
      for (final log in logs) log.date: log,
    };

    final cells = List.generate(30, (i) {
      final day = now.subtract(Duration(days: 29 - i));
      final key = PracticeLog.formatDateKey(day);
      final log = completedDays[key];
      final isCompleted = log?.completed ?? false;
      final isToday = key == todayKey;
      return _StreakDot(
        completed: isCompleted,
        isToday: isToday,
        streak: log?.streak ?? 0,
      );
    });

    return Row(
      children: [
        for (int i = 0; i < cells.length; i++) ...[
          Expanded(child: cells[i]),
          if (i < cells.length - 1) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class _StreakDot extends StatelessWidget {
  final bool completed;
  final bool isToday;
  final int streak;
  const _StreakDot({
    required this.completed,
    required this.isToday,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.warning : AppColors.glassBgHover;
    final border = isToday
        ? Border.all(color: AppColors.accentPrimary, width: 1.5)
        : Border.all(color: Colors.transparent, width: 1.5);
    return Tooltip(
      message: isToday
          ? 'Today${completed ? " · 🔥$streak" : ""}'
          : (completed ? '🔥$streak' : ''),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: border,
        ),
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  final int milestone;
  final bool reached;
  const _MilestoneBadge({required this.milestone, required this.reached});

  @override
  Widget build(BuildContext context) {
    final color =
        reached ? AppColors.accentPrimary : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: reached ? 0.18 : 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: reached
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reached ? Icons.emoji_events : Icons.emoji_events_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$milestone',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Quick action buttons (3 big buttons)
// ─────────────────────────────────────────────────────────────────────────

class _QuickActionButtons extends ConsumerWidget {
  final VoidCallback onConversation;
  final VoidCallback onReview;
  final VoidCallback onPronunciation;

  const _QuickActionButtons({
    required this.onConversation,
    required this.onReview,
    required this.onPronunciation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final dueCount = ref.watch(dueReviewQueueCountProvider);

    return Row(
      children: [
        Expanded(
          child: _BigActionButton(
            icon: Icons.chat_bubble_outline,
            label: l.t('dashboard.action_conversation'),
            color: AppColors.accentPrimary,
            onTap: onConversation,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _BigActionButton(
            icon: Icons.refresh,
            label: l.t('dashboard.action_review'),
            color: AppColors.success,
            badge: dueCount.maybeWhen(
              data: (v) => v > 0 ? '$v' : null,
              orElse: () => null,
            ),
            onTap: onReview,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _BigActionButton(
            icon: Icons.record_voice_over_outlined,
            label: l.t('dashboard.action_pronunciation'),
            color: AppColors.accentSecondary,
            onTap: onPronunciation,
          ),
        ),
      ],
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      glowColor: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Today's tasks section
// ─────────────────────────────────────────────────────────────────────────

class _TodayTasksSection extends ConsumerWidget {
  final ValueChanged<DailyPlanTask> onTap;
  const _TodayTasksSection({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final plan = ref.watch(dailyPlanProvider);

    return plan.when(
      data: (p) {
        if (p.isEmpty) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l.t('plan.empty'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l.tArg('plan.total_minutes', {'n': '${p.totalMinutes}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < p.tasks.length; i++) ...[
              _TaskCard(
                task: p.tasks[i],
                onTap: () => onTap(p.tasks[i]),
              ),
              if (i < p.tasks.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
      loading: () => const ShimmerBox(width: double.infinity, height: 180),
      error: (_, _) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            l.t('plan.empty'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DailyPlanTask task;
  final VoidCallback onTap;
  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final priorityColor = _priorityColor(task.priority);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          // Priority pill
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              'P${task.priority}',
              style: TextStyle(
                color: priorityColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(task.icon, color: AppColors.accentPrimary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t(task.titleKey),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  l.t(task.subtitleKey),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (task.badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    task.badge!,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                l.tArg('plan.minutes', {'n': '${task.durationMinutes}'}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.accentPrimary;
      case 4:
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Ability overview radar
// ─────────────────────────────────────────────────────────────────────────

class _AbilityOverviewSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scores = ref.watch(abilityScoresProvider);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.t('dashboard.ability_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                scores.maybeWhen(
                  data: (s) => Text(
                    '${s.overall}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.accentPrimary,
                        ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            scores.when(
              data: (s) => PlacementRadarChart(
                values: s.values,
                labels: AbilityScores.dimensionKeys
                    .map((k) => l.t(k))
                    .toList(),
                color: AppColors.accentPrimary,
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l.t('common.empty'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Pending review queue
// ─────────────────────────────────────────────────────────────────────────

class _ReviewQueueSection extends ConsumerWidget {
  final VoidCallback onTap;
  const _ReviewQueueSection({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final queue = ref.watch(reviewQueueProvider);

    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.t('dashboard.review_queue_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            queue.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md),
                    child: Text(
                      l.t('review.nothing_due'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _ReviewQueueTile(item: items[i]),
                      if (i < items.length - 1)
                        const Divider(height: 1, color: AppColors.glassBorder),
                    ],
                  ],
                );
              },
              loading: () => const ShimmerBox(
                  width: double.infinity, height: 120),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md),
                child: Text(
                  l.t('common.empty'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewQueueTile extends StatelessWidget {
  final ReviewQueueItem item;
  const _ReviewQueueTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDue(item.queue.dueAt);
    final typeColor = _typeColor(item.correction.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: typeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.correction.corrected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                      ),
                ),
                Text(
                  item.correction.original,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            dueText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDue(DateTime dueAt) {
    final now = DateTime.now();
    final diff = dueAt.difference(now);
    if (diff.isNegative || diff.inHours == 0) return 'Now';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return '1d';
    return '${diff.inDays}d';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'grammar':
        return AppColors.error;
      case 'vocabulary':
        return AppColors.warning;
      case 'pronunciation':
        return AppColors.accentSecondary;
      case 'fluency':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Goal section + recommended scenarios (S5/S6 v7)
// ─────────────────────────────────────────────────────────────────────────

class _GoalSection extends ConsumerWidget {
  final ValueChanged<Scenario> onStartScenario;
  const _GoalSection({required this.onStartScenario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final goalAsync = ref.watch(userGoalProvider);
    final scenariosAsync = ref.watch(recommendedScenariosProvider);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + set/change button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 18, color: AppColors.accentPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      l.t('goal.section_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _openSetGoalDialog(context),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l.t('goal.set_goal')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Current goal or empty-state prompt
            goalAsync.when(
              data: (goal) {
                if (goal == null) {
                  return Text(
                    l.t('goal.no_goal'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  );
                }
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        l.t(GoalType.labelKey(goal.goalType)),
                        style: TextStyle(
                          color: AppColors.accentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (goal.target.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          goal.target,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.md),
            // Recommended scenarios strip
            Text(
              l.t('goal.recommended'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            scenariosAsync.when(
              data: (scenarios) {
                if (scenarios.isEmpty) {
                  return Text(
                    l.t('common.empty'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  );
                }
                return SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: scenarios.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final s = scenarios[i];
                      return _ScenarioChip(
                        scenario: s,
                        onTap: () => onStartScenario(s),
                      );
                    },
                  ),
                );
              },
              loading: () => const ShimmerBox(width: double.infinity, height: 80),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _openSetGoalDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _SetGoalDialog(),
    );
  }
}

class _ScenarioChip extends StatelessWidget {
  final Scenario scenario;
  final VoidCallback onTap;
  const _ScenarioChip({required this.scenario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(_iconFor(scenario.icon),
                    size: 16, color: AppColors.accentPrimary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    scenario.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              scenario.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'work':
      case 'interview':
        return Icons.work_outline;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'airport':
        return Icons.flight_takeoff;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'doctor':
        return Icons.local_hospital_outlined;
      case 'date':
        return Icons.favorite_outline;
      default:
        return Icons.chat_bubble_outline;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// S7/S8 — Structured content section (recommended scenarios + scenario
// review queue). Hidden entirely when the user disabled content in
// Settings → Content Management.
// ─────────────────────────────────────────────────────────────────────────

class _StructuredContentSection extends ConsumerWidget {
  final ValueChanged<Scenario> onStartScenario;
  const _StructuredContentSection({required this.onStartScenario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settingsAsync = ref.watch(contentSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        if (!settings.enabled) return const SizedBox.shrink();
        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: title + active persona hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 18, color: AppColors.accentPrimary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l.t('content.section_title'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    _ActivePersonaBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Recommended scenarios strip
                Text(
                  l.t('content.recommended_today'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _RecommendedScenariosStrip(onStartScenario: onStartScenario),
                const SizedBox(height: AppSpacing.md),
                // Scenario review queue
                _ScenarioReviewQueueList(),
              ],
            ),
          ),
        );
      },
      loading: () => const ShimmerBox(width: double.infinity, height: 120),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// S7/S8 — small badge showing the active teacher persona's name. Tapping
/// it is a no-op here (the persona is changed in Settings); kept purely
/// informational so the user knows which tutor style is active.
class _ActivePersonaBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final personaAsync = ref.watch(activeTeacherPersonaProvider);
    return personaAsync.when(
      data: (p) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline,
                size: 12, color: AppColors.accentSecondary),
            const SizedBox(width: 4),
            Text(
              l.t(TeacherPersonaStyle.labelKey(p.style)),
              style: TextStyle(
                color: AppColors.accentSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RecommendedScenariosStrip extends ConsumerWidget {
  final ValueChanged<Scenario> onStartScenario;
  const _RecommendedScenariosStrip({required this.onStartScenario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scenariosAsync = ref.watch(todayRecommendedScenariosProvider);
    return scenariosAsync.when(
      data: (scenarios) {
        if (scenarios.isEmpty) {
          return Text(
            l.t('common.empty'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          );
        }
        return SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: scenarios.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final s = scenarios[i];
              return _ScenarioChip(
                scenario: s,
                onTap: () => onStartScenario(s),
              );
            },
          ),
        );
      },
      loading: () => const ShimmerBox(width: double.infinity, height: 80),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// S7/S8 — list of scenarios due for review (mirrors the correction
/// review-queue list). Tapping a row starts the scenario conversation so
/// the user re-practices it; the SM-2 slot is rescheduled on finish.
class _ScenarioReviewQueueList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final queueAsync = ref.watch(scenarioReviewQueueProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('dashboard.scenario_review_title'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        queueAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Text(
                l.t('review.nothing_due'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _ScenarioReviewTile(item: items[i]),
                  if (i < items.length - 1)
                    const Divider(height: 1, color: AppColors.glassBorder),
                ],
              ],
            );
          },
          loading: () =>
              const ShimmerBox(width: double.infinity, height: 60),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ScenarioReviewTile extends ConsumerWidget {
  final ScenarioReviewQueueItem item;
  const _ScenarioReviewTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final dueText = _formatDue(item.queue.dueAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(item.scenario.icon,
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.scenario.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (item.queue.lastScore > 0)
                  Text(
                    l.tArg('content.last_score', {'n': '${item.queue.lastScore}'}),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              dueText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDue(DateTime dueAt) {
    final now = DateTime.now();
    final diff = dueAt.difference(now);
    if (diff.isNegative || diff.inHours == 0) return 'Now';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return '1d';
    return '${diff.inDays}d';
  }
}

/// Bottom-sheet-style dialog for picking a goal type + optional target text.
/// On save, persists the new goal via [UserGoalService.setGoal] and
/// invalidates [userGoalProvider] so the dashboard refreshes immediately.
class _SetGoalDialog extends ConsumerStatefulWidget {
  const _SetGoalDialog();

  @override
  ConsumerState<_SetGoalDialog> createState() => _SetGoalDialogState();
}

class _SetGoalDialogState extends ConsumerState<_SetGoalDialog> {
  String _selectedType = GoalType.interview;
  final _targetController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.t('goal.set_goal')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final type in GoalType.all)
                ChoiceChip(
                  label: Text(l.t(GoalType.labelKey(type))),
                  selected: _selectedType == type,
                  onSelected: (_) =>
                      setState(() => _selectedType = type),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _targetController,
            decoration: InputDecoration(
              labelText: l.t('goal.set_goal'),
              hintText: l.t('goal.target_hint'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            maxLength: 80,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.t('common.save')),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userGoalServiceProvider).setGoal(
            goalType: _selectedType,
            target: _targetController.text,
          );
      ref.invalidate(userGoalProvider);
      ref.invalidate(recommendedScenariosProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('goal.save_failed'))),
        );
      }
    }
  }
}
