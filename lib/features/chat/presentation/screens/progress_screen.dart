import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../data/learning_stats_service.dart';

final statsProvider = FutureProvider<LearningStats>((ref) async {
  return LearningStatsService().getStats();
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Learning Progress'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.contentMaxWidth(context),
          ),
          child: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: statsAsync.when(
          data: (stats) => _buildContent(context, stats),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, LearningStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Track your English learning journey',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Overview cards
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.chat,
                label: 'Sessions',
                value: '${stats.totalSessions}',
                color: AppColors.accentPrimary,
              )),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _StatCard(
                icon: Icons.message,
                label: 'Messages',
                value: '${stats.totalMessages}',
                color: AppColors.accentSecondary,
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.check_circle,
                label: 'Mastered',
                value: '${stats.masteredCount}',
                color: AppColors.success,
              )),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _StatCard(
                icon: Icons.schedule,
                label: 'Due for Review',
                value: '${stats.dueForReview}',
                color: AppColors.warning,
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Mastery breakdown
          Text('Mastery Breakdown', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Column(
              children: [
                _MasteryRow(label: 'New', count: stats.newCount, total: stats.totalCorrections, color: AppColors.error),
                const SizedBox(height: AppSpacing.sm),
                _MasteryRow(label: 'Learning', count: stats.learningCount, total: stats.totalCorrections, color: AppColors.warning),
                const SizedBox(height: AppSpacing.sm),
                _MasteryRow(label: 'Mastered', count: stats.masteredCount, total: stats.totalCorrections, color: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Error types
          if (stats.correctionsByType.isNotEmpty) ...[
            Text('Error Types', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              child: Column(
                children: stats.correctionsByType.entries.map((entry) {
                  Color color;
                  switch (entry.key) {
                    case 'grammar':
                      color = AppColors.error;
                      break;
                    case 'vocabulary':
                      color = AppColors.warning;
                      break;
                    case 'pronunciation':
                      color = AppColors.accentSecondary;
                      break;
                    default:
                      color = AppColors.textSecondary;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Action button
          ElevatedButton.icon(
            onPressed: () => context.go('/review'),
            icon: const Icon(Icons.refresh),
            label: const Text('Start Review Session'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _MasteryRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.bgTertiary,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 40,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
