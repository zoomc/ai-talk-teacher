import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/chat_models.dart';

final scenariosProvider = FutureProvider<List<Scenario>>((ref) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getAllScenarios();
});

typedef ScenarioStats = ({int count, DateTime lastPracticedAt});

class ScenariosScreen extends ConsumerStatefulWidget {
  const ScenariosScreen({super.key});

  @override
  ConsumerState<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends ConsumerState<ScenariosScreen> {
  Map<String, ScenarioStats> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await ref.read(chatRepoProvider).getScenarioStats();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  Future<void> _startScenario(Scenario scenario) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(
      topic: scenario.name,
      scenarioId: scenario.id,
    );
    if (mounted) {
      context.push('/chat/${session.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(scenariosProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: scenarios.when(
            data: (list) {
              final grouped = <String, List<Scenario>>{};
              for (final s in list) {
                grouped.putIfAbsent(s.category, () => []).add(s);
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scenarios', style: Theme.of(context).textTheme.displayLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Choose a real-life scenario to practice',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...grouped.entries.map((entry) {
                    final category = entry.key;
                    final scenarios = entry.value;
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              category[0].toUpperCase() + category.substring(1),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 184,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              itemCount: scenarios.length,
                              itemBuilder: (context, index) {
                                final scenario = scenarios[index];
                                return _ScenarioCard(
                                  scenario: scenario,
                                  stats: _stats[scenario.id],
                                  onTap: () => _startScenario(scenario),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    );
                  }),
                  const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final Scenario scenario;
  final ScenarioStats? stats;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
    required this.stats,
    required this.onTap,
  });

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return AppColors.success;
      case 'intermediate':
        return AppColors.warning;
      case 'advanced':
        return AppColors.error;
      default:
        return AppColors.accentSecondary;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor(scenario.difficulty);

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GlassCard(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scenario.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                scenario.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  scenario.difficulty[0].toUpperCase() + scenario.difficulty.substring(1),
                  style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              if (stats != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Practiced ${stats!.count} times',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Last: ${_relativeTime(stats!.lastPracticedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
