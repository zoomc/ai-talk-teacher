import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../../features/home/presentation/home_providers.dart';
import '../../../../features/home/presentation/widgets/calendar_heatmap.dart';
import '../../../../features/home/presentation/widgets/weekly_trend_chart.dart';
import '../../../../features/home/presentation/widgets/weak_area_card.dart';
import '../../data/learning_stats_service.dart';

final statsProvider = FutureProvider<LearningStats>((ref) async {
  return LearningStatsService().getStats();
});

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Refresh stats on first entry so the user sees latest data.
      // Do NOT call invalidate in build() — that causes an infinite rebuild
      // loop (invalidating triggers re-fetch, which triggers rebuild,
      // which re-invalidates). One-shot at init is sufficient.
      ref.invalidate(statsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(l.t('progress.title')),
      ),
      body: Container(
        decoration: BoxDecoration(
            gradient:
                Theme.of(context).brightness == Brightness.light
                    ? AppColors.lightGradientBg
                    : AppColors.gradientBg),
        child: SafeArea(
          // top:false would still leave the AppBar's top inset; using the
          // default SafeArea here is fine because AppBar already consumes
          // the top inset. We mainly need bottom:true so the "Start Review
          // Session" button + trailing xxl spacing don't hide behind the
          // home indicator on notched iPhones.
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: statsAsync.when(
                data: (stats) => _buildContent(context, stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading stats',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, LearningStats stats) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final heatmapAsync = ref.watch(heatmapDataProvider);
    final weekStatsAsync = ref.watch(currentWeekStatsProvider);
    final weakAreasAsync = ref.watch(weakAreasProvider);
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
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Overview cards — reflow via Wrap so on iPhone SE we get 2
          // columns, on iPad 3, on desktop 4. Previous fixed 2x2 Row
          // clipped large numbers on 320pt screens and under-used space
          // on iPad Pro.
          _StatGrid(stats: stats),
          const SizedBox(height: AppSpacing.xl),

          // 7-day activity chart — renders dailyActivity (messages + corrections
          // per day). Previously the field was queried but never shown in the
          // UI (P0-10): the chart closes the "data shown vs. data collected"
          // gap and gives the user a streak-like sense of daily practice.
          Text(l.t('progress.daily_activity'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: _ActivityChart(daily: stats.dailyActivity),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Mastery breakdown
          Text(
            'Mastery Breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Column(
              children: [
                _MasteryRow(
                  label: 'New',
                  count: stats.newCount,
                  total: stats.totalCorrections,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MasteryRow(
                  label: l.t('progress.learning'),
                  count: stats.learningCount,
                  total: stats.totalCorrections,
                  color: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MasteryRow(
                  label: l.t('progress.mastered'),
                  count: stats.masteredCount,
                  total: stats.totalCorrections,
                  color: AppColors.success,
                ),
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
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── Phase 5 — Calendar heatmap ──────────────────────
          Text(l.t('progress.calendar_heatmap'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: heatmapAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => Text(l.t('common.error_loading'),
                    style: TextStyle(color: AppColors.error)),
                data: (logs) => CalendarHeatmap(logs: logs),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Phase 5 — Weekly trend ──────────────────────────
          Text(l.t('progress.weekly_trend'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: weekStatsAsync.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => Text(l.t('common.error_loading'),
                    style: TextStyle(color: AppColors.error)),
                data: (stats) => WeeklyTrendChart(stats: stats),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Phase 5 — Weak areas ────────────────────────────
          Text(l.t('progress.weak_areas'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: weakAreasAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => Text(l.t('common.error_loading'),
                    style: TextStyle(color: AppColors.error)),
                data: (areas) {
                  if (areas.isEmpty) {
                    return Text(l.t('progress.no_weak_areas'),
                        style: TextStyle(color: AppColors.textSecondary));
                  }
                  return Column(
                    children: areas
                        .map((a) => WeakAreaCard(area: a, isLight: isLight))
                        .toList(),
                  );
                },
              ),
            ),
          ),
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

class _StatGrid extends StatelessWidget {
  final LearningStats stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = <_StatCard>[
      _StatCard(
        icon: Icons.chat,
        label: 'Sessions',
        value: '${stats.totalSessions}',
        color: AppColors.accentPrimary,
      ),
      _StatCard(
        icon: Icons.message,
        label: l.t('progress.total_messages'),
        value: '${stats.totalMessages}',
        color: AppColors.accentSecondary,
      ),
      _StatCard(
        icon: Icons.check_circle,
        label: l.t('progress.mastered'),
        value: '${stats.masteredCount}',
        color: AppColors.success,
      ),
      _StatCard(
        icon: Icons.schedule,
        label: l.t('progress.due_for_review'),
        value: '${stats.dueForReview}',
        color: AppColors.warning,
      ),
    ];

    final cols = Responsive.statCardColumnCount(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - AppSpacing.md * (cols - 1)) / cols;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final c in cards) SizedBox(width: cellWidth, child: c)],
        );
      },
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
          // FittedBox so big values like "12,345" shrink to fit narrow
          // 2-col phone cards instead of clipping or wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(color: color),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
              backgroundColor:
                  Theme.of(context).brightness == Brightness.light
                      ? AppColors.lightBgSurface
                      : AppColors.bgTertiary,
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// 7-day activity bar chart.
///
/// The repository only returns rows for days that have activity, so we
/// zero-fill missing days here to keep the X axis consistent. Bars are
/// stacked per day: messages (cyan) on top of corrections (warm orange)
/// so both series share the same vertical column instead of side-by-side
/// squashing on narrow phones.
class _ActivityChart extends StatelessWidget {
  final List<DailyActivity> daily;

  const _ActivityChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    // Build a 7-day window ending today, zero-filling any days with no
    // activity row from the source data.
    final today = DateTime.now();
    final byDate = {for (final d in daily) _dayKey(d.date): d};
    final days = List.generate(7, (i) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i));
      final matched = byDate[_dayKey(date)];
      return DailyActivity(
        date: date,
        messages: matched?.messages ?? 0,
        corrections: matched?.corrections ?? 0,
      );
    });

    final maxVal = days.fold<int>(
      0,
      (m, d) => d.messages + d.corrections > m ? d.messages + d.corrections : m,
    );
    // Avoid div-by-zero; min visual bar is 1.0 unit so a lone day with
    // activity still shows up clearly.
    final scaleMax = maxVal < 1 ? 1 : maxVal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _LegendDot(color: AppColors.accentSecondary, label: 'Messages'),
            const SizedBox(width: AppSpacing.md),
            _LegendDot(color: AppColors.warning, label: 'Corrections'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days
                .map((d) => Expanded(child: _DayBar(day: d, scaleMax: scaleMax)))
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: days
              .map(
                (d) => Expanded(
                  child: Text(
                    _shortWeekday(d.date.weekday),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: days
              .map(
                (d) => Expanded(
                  child: Text(
                    '${d.date.day}/${d.date.month}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _shortWeekday(int weekday) {
    // DateTime.weekday: Mon=1..Sun=7
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }
}

class _DayBar extends StatelessWidget {
  final DailyActivity day;
  final int scaleMax;

  const _DayBar({required this.day, required this.scaleMax});

  @override
  Widget build(BuildContext context) {
    final total = day.messages + day.corrections;
    // Bar total height as a fraction of the available 140px column.
    final totalFraction = scaleMax == 0 ? 0.0 : total / scaleMax;
    final msgFraction =
        total == 0 ? 0.0 : (day.messages / total) * totalFraction;
    final corrFraction =
        total == 0 ? 0.0 : (day.corrections / total) * totalFraction;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (total > 0)
            Tooltip(
              message:
                  '${day.messages} msg · ${day.corrections} corrections',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Messages on top (cyan)
                  if (msgFraction > 0)
                    Container(
                      width: double.infinity,
                      height: (msgFraction * 110).clamp(2.0, 110.0),
                      decoration: BoxDecoration(
                        color: AppColors.accentSecondary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  // Corrections stacked below (warm orange)
                  if (corrFraction > 0)
                    Container(
                      width: double.infinity,
                      height: (corrFraction * 110).clamp(2.0, 110.0),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.only(
                          topLeft: msgFraction > 0 ? Radius.zero : Radius.circular(4),
                          topRight: msgFraction > 0 ? Radius.zero : Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            // Empty day — show a faint baseline so the row alignment
            // stays consistent across the 7-day window.
            Container(
              width: double.infinity,
              height: 2,
              color: AppColors.glassBorder,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
