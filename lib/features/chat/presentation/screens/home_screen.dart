import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../data/daily_plan_service.dart';
import '../../domain/chat_models.dart';
import '../../domain/daily_plan.dart';

final activeSessionProvider = FutureProvider<ChatSession?>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getActiveSession();
});

final dueCorrectionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getDueCorrectionCount();
});

final totalCorrectionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getCorrectionCount();
});

/// Phase-1 P0 #6 — Today's Plan provider. Built fresh on every home-screen
/// load from live repository state (due corrections, active session,
/// scenario count). Re-fetches when the chat repo's data changes (e.g.
/// after the user finishes a session and the active session is archived).
final dailyPlanProvider =
    FutureProvider<DailyPlan>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return DailyPlanService().buildFromRepository(repo);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _promptedForActiveSession = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final activeSession = ref.watch(activeSessionProvider);
    final dueCount = ref.watch(dueCorrectionCountProvider);
    final totalCount = ref.watch(totalCorrectionCountProvider);

    activeSession.whenData((session) {
      if (session != null && !_promptedForActiveSession && mounted) {
        _promptedForActiveSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showContinueDialog(session);
        });
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightGradientBg
              : AppColors.gradientBg,
        ),
        child: SafeArea(
          child: Center(
            // Constrain content on wide screens so cards / text stay
            // readable on desktop browsers instead of stretching.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradientPrimary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(begin: const Offset(0.8, 0.8)),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SpeakFlow',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                              Text(
                                'AI English Speaking Practice',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Continue session card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: activeSession.when(
                        data: (session) {
                          if (session != null) {
                            return GlassCard(
                              glowColor: AppColors.accentPrimary,
                              onTap: () => context.push('/chat/${session.id}'),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPrimary.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.t('home.continue_practice'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          session.topic ?? 'Free Talk',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        loading: () => const ShimmerBox(
                          width: double.infinity,
                          height: 80,
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // Stats cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.error_outline,
                              label: l.t('progress.due_for_review'),
                              value: dueCount.when(
                                data: (v) => '$v',
                                loading: () => '...',
                                error: (_, _) => '0',
                              ),
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.check_circle_outline,
                              label: l.t('progress.total_corrections'),
                              value: totalCount.when(
                                data: (v) => '$v',
                                loading: () => '...',
                                error: (_, _) => '0',
                              ),
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Phase-1 P0 #6: Today's Plan ──────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        l.t('plan.title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _DailyPlanSection(
                        plan: ref.watch(dailyPlanProvider),
                        onTap: (action) => _handlePlanAction(context, action),
                      ),
                    ),
                  ),

                  // Quick actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        l.t('home.quick_actions'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _QuickActionGrid(),
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
    );
  }

  Widget _quickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required int delayMs,
  }) {
    return _QuickActionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      onTap: onTap,
    ).animate().fadeIn(delay: delayMs.ms).slideX(begin: -0.1);
  }

  Widget _QuickActionGrid() {
    final l = AppLocalizations.of(context);
    final actions = <Widget>[];

    void add({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
      required int delayMs,
    }) {
      actions.add(
        _quickActionItem(
          icon: icon,
          title: title,
          subtitle: subtitle,
          color: color,
          onTap: onTap,
          delayMs: delayMs,
        ),
      );
    }

    add(
      icon: Icons.chat_bubble_outline,
      title: l.t('home.free_talk'),
      subtitle: l.t('home.free_talk_subtitle'),
      color: AppColors.accentPrimary,
      onTap: () => _startNewSession(context),
      delayMs: 300,
    );
    add(
      icon: Icons.grid_view,
      title: l.t('home.scenarios'),
      subtitle: l.t('home.scenarios_subtitle'),
      color: AppColors.accentSecondary,
      onTap: () => context.go('/scenarios'),
      delayMs: 450,
    );
    add(
      icon: Icons.refresh,
      title: l.t('home.review'),
      subtitle: l.t('home.review_subtitle'),
      color: AppColors.success,
      onTap: () => context.go('/review'),
      delayMs: 600,
    );
    add(
      icon: Icons.bar_chart,
      title: l.t('home.progress'),
      subtitle: l.t('home.progress_subtitle'),
      color: AppColors.warning,
      onTap: () => context.push('/progress'),
      delayMs: 750,
    );
    add(
      icon: Icons.history,
      title: l.t('home.history'),
      subtitle: l.t('home.history_subtitle'),
      color: AppColors.info,
      onTap: () => context.push('/history'),
      delayMs: 900,
    );

    // Use LayoutBuilder so the card width is derived from the actual
    // constraints (which already account for the MainShell / Center /
    // ConstrainedBox chain) instead of MediaQuery.sizeOf(context).width
    // — the latter returned the full screen width and made the grid
    // silently collapse to fewer columns on iPad/desktop (the cards were
    // wider than the available column, so Wrap dropped them).
    //
    // Note: do NOT subtract screenHorizontalPadding again — the outer
    // Padding(EdgeInsets.all(AppSpacing.lg)) wrapper around this grid
    // has already reserved that horizontal space, so constraints.maxWidth
    // is the on-screen width available for cards.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = Responsive.gridColumnCount(context);
        if (cols == 1) {
          return Column(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                actions[i],
                if (i < actions.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        final cellWidth =
            (constraints.maxWidth - AppSpacing.md * (cols - 1)) / cols;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final a in actions) SizedBox(width: cellWidth, child: a),
          ],
        );
      },
    );
  }

  Future<void> _startNewSession(BuildContext context) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(topic: 'Free Talk');
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  /// Phase-1 P0 #6 — dispatch a daily-plan task tap to its destination.
  /// `startFreeTalk` is special-cased because it creates a new session
  /// rather than navigating to an existing route.
  void _handlePlanAction(BuildContext context, DailyPlanAction action) {
    switch (action) {
      case DailyPlanAction.startFreeTalk:
        _startNewSession(context);
        break;
      case DailyPlanAction.openReview:
        context.push('/review');
        break;
      case DailyPlanAction.openPractice:
        context.push('/practice');
        break;
      case DailyPlanAction.openScenarios:
        context.push('/scenarios');
        break;
      case DailyPlanAction.openVoiceHealth:
        context.push('/voice-health');
        break;
    }
  }

  void _showContinueDialog(ChatSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightBgSecondary
            : AppColors.bgTertiary,
        title: const Text('Welcome back!'),
        content: Text(
          'Continue your conversation about "${session.topic ?? 'Free Talk'}" or start a new topic?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('New Topic'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/chat/${session.id}');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Phase-1 P0 #6 — Today's Plan section.
///
/// Renders a vertical list of micro-tasks with a header showing the total
/// estimated minutes. Each task is a tappable GlassCard; tapping dispatches
/// the action back to the home screen (which owns navigation + session
/// creation). Loading / error / empty states are handled inline so a
/// transient repo failure never breaks the home screen.
class _DailyPlanSection extends StatelessWidget {
  final AsyncValue<DailyPlan> plan;
  final ValueChanged<DailyPlanAction> onTap;

  const _DailyPlanSection({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
              _DailyPlanTaskCard(
                task: p.tasks[i],
                index: i + 1,
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

class _DailyPlanTaskCard extends StatelessWidget {
  final DailyPlanTask task;
  final int index;
  final VoidCallback onTap;

  const _DailyPlanTaskCard({
    required this.task,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // Step number badge — gives the sequence a clear visual order.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
          // Trailing: duration + optional due-count badge.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (task.badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
}
