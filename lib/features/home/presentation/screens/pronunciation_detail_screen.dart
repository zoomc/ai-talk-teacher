/// Phase 5 — Pronunciation detail screen.
///
/// Shows per-phoneme scores with colour coding (green = good, amber = fair,
/// red = poor), common pronunciation errors, and a trend chart of recent
/// pronunciation scores across sessions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../features/chat/domain/phoneme_score.dart';
import '../../domain/progress_models.dart';
import '../home_providers.dart';

class PronunciationDetailScreen extends ConsumerWidget {
  final String sessionId;

  const PronunciationDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final reportAsync = ref.watch(pronunciationReportProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: Text(l.t('progress.pronunciation_detail'))),
      body: Container(
        decoration: BoxDecoration(
          gradient: isLight ? AppColors.lightGradientBg : AppColors.gradientBg,
        ),
        child: reportAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '${l.t('common.error_loading')}: $e',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
          data: (report) {
            if (report == null) {
              return Center(
                child: Text(l.t('progress.no_pronunciation_data')),
              );
            }
            return _buildReport(context, l, report, isLight);
          },
        ),
      ),
    );
  }

  Widget _buildReport(
    BuildContext context,
    AppLocalizations l,
    PronunciationReport report,
    bool isLight,
  ) {
    // Use the existing PhonemeScoreBand for consistent colour coding
    final band = PhonemeScoreBand.fromScore(report.overallPhonemeScore);
    final bandColor = _bandColor(band, isLight);
    final bandLabel = _bandLabel(band);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Overall score card ────────────────────────────────
          _ScoreCard(
            overallScore: report.overallPhonemeScore,
            bandColor: bandColor,
            bandLabel: bandLabel,
            goodPct: report.goodPercentage,
            fairPct: report.fairPercentage,
            poorPct: report.poorPercentage,
            isLight: isLight,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Per-phoneme breakdown ─────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('progress.phoneme_breakdown'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (report.phonemeBreakdown.isEmpty)
                  Text(
                    l.t('progress.no_phoneme_data'),
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...report.phonemeBreakdown.entries.map((entry) {
                    final pBand =
                        PhonemeScoreBand.fromScore(entry.value.avgScore);
                    return _PhonemeRow(
                      phoneme: entry.key,
                      avgScore: entry.value.avgScore,
                      count: entry.value.count,
                      band: pBand,
                      isLight: isLight,
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Common errors ─────────────────────────────────────
          if (report.commonErrors.isNotEmpty)
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('progress.common_errors'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...report.commonErrors.map((error) => _ErrorRow(
                        error: error,
                        isLight: isLight,
                      )),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // ── Trend chart (placeholder with recent scores) ──────
          _PronunciationTrendChart(sessionId: report.sessionId),
        ],
      ),
    );
  }

  Color _bandColor(PhonemeScoreBand band, bool isLight) {
    switch (band) {
      case PhonemeScoreBand.good:
        return AppColors.success;
      case PhonemeScoreBand.fair:
        return AppColors.warning;
      case PhonemeScoreBand.poor:
        return AppColors.error;
    }
  }

  String _bandLabel(PhonemeScoreBand band) {
    switch (band) {
      case PhonemeScoreBand.good:
        return 'Good';
      case PhonemeScoreBand.fair:
        return 'Fair';
      case PhonemeScoreBand.poor:
        return 'Needs Work';
    }
  }
}

/// Overall score card with ring-style visualization.
class _ScoreCard extends StatelessWidget {
  final double overallScore;
  final Color bandColor;
  final String bandLabel;
  final double goodPct;
  final double fairPct;
  final double poorPct;
  final bool isLight;

  const _ScoreCard({
    required this.overallScore,
    required this.bandColor,
    required this.bandLabel,
    required this.goodPct,
    required this.fairPct,
    required this.poorPct,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: overallScore / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.glassBorder,
                  valueColor: AlwaysStoppedAnimation(bandColor),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      overallScore.toStringAsFixed(0),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      bandLabel,
                      style: TextStyle(
                        color: bandColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniBar(
                    label: l.t('progress.good'),
                    pct: goodPct,
                    color: AppColors.success),
                const SizedBox(height: AppSpacing.xs),
                _MiniBar(
                    label: l.t('progress.fair'),
                    pct: fairPct,
                    color: AppColors.warning),
                const SizedBox(height: AppSpacing.xs),
                _MiniBar(
                    label: l.t('progress.needs_work'),
                    pct: poorPct,
                    color: AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;

  const _MiniBar({
    required this.label,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 36,
          child: Text(
            '${pct.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Per-phoneme score row with colour-coded indicator.
class _PhonemeRow extends StatelessWidget {
  final String phoneme;
  final double avgScore;
  final int count;
  final PhonemeScoreBand band;
  final bool isLight;

  const _PhonemeRow({
    required this.phoneme,
    required this.avgScore,
    required this.count,
    required this.band,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _bandColor(band, isLight),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            child: Text(
              '/$phoneme/',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: avgScore / 100,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(_bandColor(band, isLight)),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 36,
            child: Text(
              avgScore.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Text(
            '×$count',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _bandColor(PhonemeScoreBand b, bool light) {
    switch (b) {
      case PhonemeScoreBand.good:
        return AppColors.success;
      case PhonemeScoreBand.fair:
        return AppColors.warning;
      case PhonemeScoreBand.poor:
        return AppColors.error;
    }
  }
}

/// Common error row.
class _ErrorRow extends StatelessWidget {
  final PhonemeErrorEntry error;
  final bool isLight;

  const _ErrorRow({required this.error, required this.isLight});

  @override
  Widget build(BuildContext context) {
    final band = PhonemeScoreBand.fromScore(error.score);
    final color = switch (band) {
      PhonemeScoreBand.good => AppColors.success,
      PhonemeScoreBand.fair => AppColors.warning,
      PhonemeScoreBand.poor => AppColors.error,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.volume_up, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '/${error.phoneme}/',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' in '),
                  TextSpan(
                    text: error.word,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${error.score}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder pronunciation trend chart. Shows a simple dot for each
/// recent pronunciation report score, connected by a line.
class _PronunciationTrendChart extends ConsumerWidget {
  final String sessionId;

  const _PronunciationTrendChart({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reportsAsync = ref.watch(recentPronunciationReportsProvider);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('progress.pronunciation_trend'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            child: reportsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) =>
                  Center(child: Text(l.t('common.error_loading'))),
              data: (reports) {
                if (reports.length < 2) {
                  return Center(
                    child: Text(
                      l.t('progress.trend_insufficient_data'),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return CustomPaint(
                  painter: _TrendLinePainter(
                    scores: reports
                        .take(10)
                        .map((r) => r.overallPhonemeScore)
                        .toList()
                        .reversed
                        .toList(),
                    goodColor: AppColors.success,
                    fairColor: AppColors.warning,
                    poorColor: AppColors.error,
                  ),
                  size: const Size(double.infinity, 100),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple line chart painter showing pronunciation score trend.
class _TrendLinePainter extends CustomPainter {
  final List<double> scores;
  final Color goodColor;
  final Color fairColor;
  final Color poorColor;

  _TrendLinePainter({
    required this.scores,
    required this.goodColor,
    required this.fairColor,
    required this.poorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    final dx = size.width / (scores.length - 1).clamp(1, scores.length);
    final points = <Offset>[];

    for (var i = 0; i < scores.length; i++) {
      final x = i * dx;
      final y = size.height -
          (scores[i] / 100) * (size.height - 16) -
          8;
      points.add(Offset(x, y));
    }

    // Draw connecting lines in segments by color zone
    for (var i = 0; i < points.length - 1; i++) {
      final avgScore = (scores[i] + scores[i + 1]) / 2;
      final color = avgScore >= 85
          ? goodColor
          : avgScore >= 50
              ? fairColor
              : poorColor;
      paint.color = color;
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw dots
    for (var i = 0; i < points.length; i++) {
      final color = scores[i] >= 85
          ? goodColor
          : scores[i] >= 50
              ? fairColor
              : poorColor;
      dotPaint.color = color;
      canvas.drawCircle(points[i], 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) =>
      scores != oldDelegate.scores;
}
