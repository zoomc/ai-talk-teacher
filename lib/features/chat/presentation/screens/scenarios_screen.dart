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

class ScenariosScreen extends ConsumerWidget {
  const ScenariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenarios = ref.watch(scenariosProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: scenarios.when(
            data: (list) {
              // Group by category
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
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              itemCount: scenarios.length,
                              itemBuilder: (context, index) {
                                final scenario = scenarios[index];
                                return _ScenarioCard(
                                  scenario: scenario,
                                  onTap: () => _startScenario(context, ref, scenario),
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

  Future<void> _startScenario(BuildContext context, WidgetRef ref, Scenario scenario) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(
      topic: scenario.name,
      scenarioId: scenario.id,
    );
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }
}

class _ScenarioCard extends StatelessWidget {
  final Scenario scenario;
  final VoidCallback onTap;

  const _ScenarioCard({required this.scenario, required this.onTap});

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
            ],
          ),
        ),
      ),
    );
  }
}
