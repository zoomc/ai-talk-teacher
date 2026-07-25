import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/chat_models.dart';
import '../../../project_space/domain/project_models.dart';
import '../../../project_space/presentation/widgets/join_project_sheet.dart';

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
    try {
      final stats = await ref.read(chatRepoProvider).getScenarioStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      // Stats are best-effort decoration; keep any previously loaded stats
      // so the list remains usable. Surface a subtle toast on debug builds.
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tArg('scenarios.stats_error', {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _startScenario(Scenario scenario) async {
    final repo = ref.read(chatRepoProvider);
    try {
      // BL-047: carry scenario metadata into the session so the chat layer
      // knows the difficulty, category, and objective. levelTag maps the
      // scenario difficulty to the session's level tag.
      final session = await repo.createSession(
        topic: scenario.name,
        scenarioId: scenario.id,
        levelTag: scenario.difficulty,
      );
      if (mounted) {
        context.push('/chat/${session.id}');
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tArg('scenarios.start_error', {'error': '$e'}))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(scenariosProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            gradient:
                Theme.of(context).brightness == Brightness.light
                    ? AppColors.lightGradientBg
                    : AppColors.gradientBg),
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
                          Text(
                            l.t('scenarios.title'),
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l.t('scenarios.subtitle'),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
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
                              l.t('scenarios.category.$category'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          // Responsive height — was fixed 184 which could
                          // clip the optional 2 stats rows + a 2-line name
                          // on small screens. Bump up on tablets where the
                          // cards are wider and labels wrap less.
                          SizedBox(
                            height: Responsive.isPhone(context) ? 188 : 210,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              itemCount: scenarios.length,
                              itemBuilder: (context, index) {
                                final scenario = scenarios[index];
                                return _ScenarioCard(
                                  scenario: scenario,
                                  stats: _stats[scenario.id],
                                  onTap: () => _startScenario(scenario),
                                  onLongPress: () async {
                                    final linked = await JoinProjectSheet.show(
                                      context,
                                      contentType: ProjectContentType.scenario,
                                      contentId: scenario.id,
                                    );
                                    if (linked && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(
                                            AppLocalizations.of(context)
                                                .t('projects.join.title'))),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    );
                  }),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l.t('scenarios.error_loading'),
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
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
  final VoidCallback? onLongPress;

  const _ScenarioCard({
    required this.scenario,
    required this.stats,
    required this.onTap,
    this.onLongPress,
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

  String _relativeTime(BuildContext context, AppLocalizations l, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return l.t('history.today').toLowerCase();
    if (diff.inDays == 1) return l.t('history.yesterday').toLowerCase();
    if (diff.inDays < 7) {
      return l.tArg('history.days_ago', {'days': '${diff.inDays}'});
    }
    return DateFormat.Md(Localizations.localeOf(context).toString()).format(dt);
  }

  String _localizedDifficulty(AppLocalizations l, String difficulty) {
    return l.t('scenarios.difficulty.$difficulty');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final diffColor = _difficultyColor(scenario.difficulty);

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GlassCard(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(scenario.icon, style: const TextStyle(fontSize: 32)),
                  const Spacer(),
                  if (onLongPress != null)
                    Icon(
                      Icons.folder_copy_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
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
                  _localizedDifficulty(l, scenario.difficulty),
                  style: TextStyle(
                    color: diffColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
                        l.tArg('scenarios.practiced_count', {
                          'count': '${stats!.count}',
                        }),
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
                    Icon(Icons.history, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l.tArg('scenarios.last_practiced', {
                          'when': _relativeTime(context, l, stats!.lastPracticedAt),
                        }),
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
