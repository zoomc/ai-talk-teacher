/// Phase 5 — Calendar heatmap widget for the progress dashboard.
///
/// Renders a compact grid of dots/cells representing daily practice
/// activity over a configurable lookback window. Each cell is coloured
/// by intensity (number of messages sent or duration practised).
/// Empty cells are transparent/light; missing days (future) are hidden.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/home_models.dart';

class CalendarHeatmap extends StatelessWidget {
  /// Practice logs for the lookback period, newest-first.
  final List<PracticeLog> logs;

  /// Number of columns to display. Keep under 12 to stay compact.
  final int columns;

  const CalendarHeatmap({
    super.key,
    required this.logs,
    this.columns = 7,
  });

  @override
  Widget build(BuildContext context) {
    // Build a date-keyed map of log entries
    final logByDate = <String, PracticeLog>{};
    for (final log in logs) {
      logByDate[log.date] = log;
    }

    // Generate the last N days' date keys in display order (oldest first)
    final now = DateTime.now();
    final totalCells = columns * 7; // rows = 7 (week days)
    final cells = <Widget>[];
    final cellSize = 14.0;
    final gap = 3.0;

    for (var i = totalCells - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _formatDateKey(date);
      final log = logByDate[key];
      final isFuture = date.isAfter(now);
      final intensity = _computeIntensity(log);

      cells.add(
        Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: isFuture
                ? Colors.transparent
                : _intensityColor(intensity),
            borderRadius: BorderRadius.circular(3),
          ),
          // Show minimal tooltip on long press
          child: isFuture
              ? const SizedBox.shrink()
              : Tooltip(
                  message: log != null
                      ? '$key: ${_formatDuration(log.durationSeconds)} • ${log.completed ? "completed" : "incomplete"}'
                      : '$key: no practice',
                  child: const SizedBox.expand(),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Less', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            ...List.generate(5, (i) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: _intensityColor(i),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            const SizedBox(width: 4),
            const Text('More', style: TextStyle(fontSize: 10)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Grid
        Wrap(
          spacing: gap,
          runSpacing: gap,
          direction: Axis.horizontal,
          children: cells,
        ),
      ],
    );
  }

  /// Compute intensity level 0–4 from a practice log entry.
  int _computeIntensity(PracticeLog? log) {
    if (log == null || !log.completed) return 0;
    final minutes = log.durationSeconds ~/ 60;
    if (minutes >= 30) return 4;
    if (minutes >= 15) return 3;
    if (minutes >= 5) return 2;
    return 1;
  }

  Color _intensityColor(int level) {
    switch (level) {
      case 0:
        return AppColors.glassBorder.withValues(alpha: 0.3);
      case 1:
        return AppColors.success.withValues(alpha: 0.3);
      case 2:
        return AppColors.success.withValues(alpha: 0.5);
      case 3:
        return AppColors.success.withValues(alpha: 0.7);
      case 4:
        return AppColors.success;
      default:
        return Colors.transparent;
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    if (min < 60) return '${min}m';
    return '${min ~/ 60}h${min % 60}m';
  }

  String _formatDateKey(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}
