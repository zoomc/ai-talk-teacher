/// Phase 5 — Weekly trend chart widget.
///
/// Renders a bar chart of daily activity (messages + corrections) for a
/// given week, with optional comparison to the previous week.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/progress_models.dart';

class WeeklyTrendChart extends StatelessWidget {
  final WeeklyStats stats;

  /// Optional previous-week stats for comparison.
  final WeeklyStats? previousStats;

  const WeeklyTrendChart({
    super.key,
    required this.stats,
    this.previousStats,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = _maxValue();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary stats
        Row(
          children: [
            _StatChip(
                label: 'Active days', value: '${stats.activeDays}/7'),
            const SizedBox(width: AppSpacing.sm),
            _StatChip(
                label: 'Avg min',
                value: stats.avgDailyMinutes.toStringAsFixed(0)),
            const SizedBox(width: AppSpacing.sm),
            _StatChip(
                label: 'Corrections',
                value: '${stats.correctionCount}'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Bar chart
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _BarChartPainter(
              dailyStats: stats.dailyStats,
              dayLabels: dayLabels,
              maxValue: maxVal,
              barColor: AppColors.accentPrimary,
              secondaryBarColor:
                  previousStats != null
                      ? AppColors.accentSecondary
                      : null,
              isLight: isLight,
            ),
            size: Size(double.infinity, 140),
          ),
        ),
      ],
    );
  }

  double _maxValue() {
    double max = 10;
    for (final d in stats.dailyStats) {
      final total = d.messageCount + d.correctionCount;
      if (total > max) max = total.toDouble();
    }
    if (previousStats != null) {
      for (final d in previousStats!.dailyStats) {
        final total = d.messageCount + d.correctionCount;
        if (total > max) max = total.toDouble();
      }
    }
    return max;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassBorder.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the weekly bar chart.
class _BarChartPainter extends CustomPainter {
  final List<DailyStats> dailyStats;
  final List<String> dayLabels;
  final double maxValue;
  final Color barColor;
  final Color? secondaryBarColor;
  final bool isLight;

  _BarChartPainter({
    required this.dailyStats,
    required this.dayLabels,
    required this.maxValue,
    required this.barColor,
    this.secondaryBarColor,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyStats.isEmpty) return;

    final barWidth = (size.width / dailyStats.length) * 0.6;
    final gap = (size.width / dailyStats.length) * 0.4;
    final gridColor = AppColors.glassBorder.withValues(alpha: 0.3);
    final textColor = AppColors.textSecondary;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Draw horizontal gridlines (4 lines)
    for (var i = 0; i < 4; i++) {
      final y = size.height - (size.height * (i / 4));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final msgPaint = Paint()..color = barColor;
    final corrPaint = Paint()..color = AppColors.warning;

    for (var i = 0; i < dailyStats.length; i++) {
      final stat = dailyStats[i];
      final x = i * (barWidth + gap) + gap / 2;

      // Message bar (primary)
      final msgHeight =
          maxValue > 0 ? (stat.messageCount / maxValue) * (size.height - 16) : 0.0;
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          size.height - 8 - msgHeight,
          barWidth * 0.45,
          msgHeight,
        ),
        msgPaint,
      );

      // Correction bar (secondary, narrower)
      final corrHeight =
          maxValue > 0 ? (stat.correctionCount / maxValue) * (size.height - 16) : 0.0;
      if (corrHeight > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            x + barWidth * 0.5,
            size.height - 8 - corrHeight,
            barWidth * 0.45,
            corrHeight,
          ),
          corrPaint,
        );
      }

      // Day label
      final textSpan = TextSpan(
        text: dayLabels[i],
        style: TextStyle(color: textColor, fontSize: 9),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, size.height - 7));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) =>
      dailyStats != oldDelegate.dailyStats;
}
