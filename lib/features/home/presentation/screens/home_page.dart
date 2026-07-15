import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../chat/domain/daily_plan.dart';
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
                          onTap: (action) =>
                              _handlePlanAction(context, action),
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

  void _handlePlanAction(BuildContext context, DailyPlanAction action) {
    switch (action) {
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
    }
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
  final ValueChanged<DailyPlanAction> onTap;
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
                onTap: () => onTap(p.tasks[i].action),
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
      default:
        return AppColors.textMuted;
    }
  }
}
