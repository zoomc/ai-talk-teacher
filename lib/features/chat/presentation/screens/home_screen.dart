import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/chat_models.dart';

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _promptedForActiveSession = false;

  @override
  Widget build(BuildContext context) {
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
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
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
                                          'Continue your conversation',
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
                              label: 'Due for Review',
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
                              label: 'Total Corrections',
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

                  // Quick actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        'Quick Start',
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
      title: 'Free Talk',
      subtitle: 'Start a conversation about anything',
      color: AppColors.accentPrimary,
      onTap: () => _startNewSession(context),
      delayMs: 300,
    );
    add(
      icon: Icons.grid_view,
      title: 'Scenario Practice',
      subtitle: 'Practice real-life situations',
      color: AppColors.accentSecondary,
      onTap: () => context.go('/scenarios'),
      delayMs: 450,
    );
    add(
      icon: Icons.refresh,
      title: 'Review Mistakes',
      subtitle: 'Practice your weak points',
      color: AppColors.success,
      onTap: () => context.go('/review'),
      delayMs: 600,
    );
    add(
      icon: Icons.bar_chart,
      title: 'Learning Progress',
      subtitle: 'View your statistics and achievements',
      color: AppColors.warning,
      onTap: () => context.push('/progress'),
      delayMs: 750,
    );
    add(
      icon: Icons.history,
      title: 'Chat History',
      subtitle: 'Browse past conversations',
      color: AppColors.info,
      onTap: () => context.push('/history'),
      delayMs: 900,
    );

    // Phone: single column with vertical spacing (legacy look).
    // Tablet/desktop: responsive grid with spacing between cells.
    final cols = Responsive.gridColumnCount(context);
    if (cols == 1) {
      return Column(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            actions[i],
            if (i < actions.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final a in actions)
          SizedBox(
            width:
                (MediaQuery.of(context).size.width -
                    Responsive.screenHorizontalPadding(context) * 2 -
                    AppSpacing.md * (cols - 1) -
                    AppSpacing.lg * 2) /
                cols,
            child: a,
          ),
      ],
    );
  }

  Future<void> _startNewSession(BuildContext context) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(topic: 'Free Talk');
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  void _showContinueDialog(ChatSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTertiary,
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
