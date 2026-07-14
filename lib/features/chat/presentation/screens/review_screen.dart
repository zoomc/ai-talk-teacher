import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../data/tts_playback_service.dart';
import '../../data/tts_service.dart';
import '../../domain/chat_models.dart';
import '../../../review/data/sm2_service.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<Correction> _corrections = [];
  bool _isLoading = true;
  // Tracks which correction ids are currently being submitted to prevent
  // double-taps on the rating buttons while the SM-2 update is in flight.
  final Set<String> _ratingInFlight = {};

  @override
  void initState() {
    super.initState();
    _loadCorrections();
  }

  Future<void> _loadCorrections() async {
    final repo = ref.read(chatRepoProvider);
    final corrections = await repo.getDueCorrections(limit: 50);
    if (mounted) {
      setState(() {
        _corrections = corrections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lowBandwidth = ref.watch(lowBandwidthProvider);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            // P0 #8 — flat color in low-bandwidth mode.
            color: lowBandwidth
                ? (isLight ? AppColors.lightFlatBg : AppColors.darkFlatBg)
                : null,
            gradient: lowBandwidth
                ? null
                : (isLight
                    ? AppColors.lightGradientBg
                    : AppColors.gradientBg)),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _corrections.isEmpty
              ? _buildEmptyState(context)
              : _buildReviewList(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'All caught up!',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.t('review.nothing_due'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Start Practicing'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flexible so the title Column shrinks instead of
                    // pushing the AI Review button off-screen on iPhone SE
                    // when the count line is long.
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('review.title'),
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${_corrections.length} ${l.t('review.due_now')}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      flex: 0,
                      child: ElevatedButton.icon(
                        onPressed: () => _startAIReview(context),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('AI Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Rate how well you remember each correction — the schedule adapts to your answer. Tap the card to practice it in a conversation.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final correction = _corrections[index];
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: _CorrectionCard(
                correction: correction,
                isSubmitting: _ratingInFlight.contains(correction.id),
                onTap: () => _practiceCorrection(context, correction),
                onRate: (quality) => _rateCorrection(correction, quality),
              ),
            );
          }, childCount: _corrections.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }

  Future<void> _startAIReview(BuildContext context) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(topic: 'AI Review Session');
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  Future<void> _practiceCorrection(
    BuildContext context,
    Correction correction,
  ) async {
    final repo = ref.read(chatRepoProvider);
    final session = await repo.createSession(
      topic: 'Practice: ${correction.original} → ${correction.corrected}',
    );
    if (context.mounted) {
      context.push('/chat/${session.id}');
    }
  }

  /// Rate a correction via the SM-2 algorithm.
  ///
  /// Quality mapping (SM-2 uses 0–5):
  ///   Again → 1 (failed: reset to 1-day interval, review count reset)
  ///   Hard  → 3 (passed but barely: shorter next interval)
  ///   Good  → 4 (passed comfortably: standard progression)
  ///   Easy  → 5 (passed easily: longer next interval)
  ///
  /// After scheduling + persisting, the card is removed from the visible
  /// "due now" list — the next review is in the future.
  Future<void> _rateCorrection(Correction correction, int quality) async {
    if (_ratingInFlight.contains(correction.id)) return;
    setState(() => _ratingInFlight.add(correction.id));

    try {
      final updated = Sm2Service.scheduleReview(correction, quality);
      await ref.read(chatRepoProvider).updateCorrection(updated);

      // Brief feedback so the user understands what just happened.
      if (mounted) {
        final l = AppLocalizations.of(context);
        final label = _ratingLabel(quality, l);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$label — ${l.tArg('review.next_review', {
                'when': Sm2Service.getNextReviewText(updated),
              })}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _corrections.removeWhere((c) => c.id == correction.id);
          _ratingInFlight.remove(correction.id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ratingInFlight.remove(correction.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rating: ${_safeError(e)}')),
        );
      }
    }
  }

  String _ratingLabel(int quality, AppLocalizations l) {
    switch (quality) {
      case 1:
        return l.t('review.rate_again');
      case 3:
        return l.t('review.rate_hard');
      case 4:
        return l.t('review.rate_good');
      case 5:
        return l.t('review.rate_easy');
      default:
        return 'Rated';
    }
  }

  String _safeError(Object e) {
    final s = e.toString();
    final i = s.indexOf(': ');
    return i >= 0 ? s.substring(i + 2) : s;
  }
}

class _CorrectionCard extends ConsumerStatefulWidget {
  final Correction correction;
  final VoidCallback onTap;
  /// Called with the SM-2 quality (1 / 3 / 4 / 5) when a rating button is tapped.
  final ValueChanged<int> onRate;
  final bool isSubmitting;

  const _CorrectionCard({
    required this.correction,
    required this.onTap,
    required this.onRate,
    this.isSubmitting = false,
  });

  @override
  ConsumerState<_CorrectionCard> createState() => _CorrectionCardState();
}

class _CorrectionCardState extends ConsumerState<_CorrectionCard> {
  final TtsPlaybackService _ttsPlayback = TtsPlaybackService();
  late bool _isFavorite = widget.correction.isFavorite;
  bool _isTogglingFav = false;
  bool _isPlayingDemo = false;

  Correction get _correction => widget.correction;

  @override
  void dispose() {
    _ttsPlayback.dispose();
    super.dispose();
  }

  Color _typeColor(CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return AppColors.error;
      case CorrectionType.vocabulary:
        return AppColors.warning;
      case CorrectionType.pronunciation:
        return AppColors.accentSecondary;
    }
  }

  String _typeLabel(BuildContext context, CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return AppLocalizations.of(context).t('correction.type_grammar');
      case CorrectionType.vocabulary:
        return AppLocalizations.of(context).t('correction.type_vocabulary');
      case CorrectionType.pronunciation:
        return AppLocalizations.of(context).t('correction.type_pronunciation');
    }
  }

  /// Phase-1 P0 #4 — importance → display color. Mirrors the chat-screen
  /// _CorrectionInline scheme so the user sees the same severity cue in
  /// both surfaces.
  Color _importanceColor(int importance) {
    if (importance >= 80) return AppColors.error;
    if (importance >= 50) return AppColors.warning;
    return AppColors.textMuted;
  }

  Future<void> _playDemo() async {
    if (_isPlayingDemo) return;
    setState(() => _isPlayingDemo = true);
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();
      if (ttsProfile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context).t('guest.unavailable')),
            ),
          );
        }
        return;
      }
      final tts = TtsService(ttsProfile);
      await _ttsPlayback.playCached(
        _correction.corrected,
        () => tts.synthesize(_correction.corrected),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlayingDemo = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFav) return;
    final previous = _isFavorite;
    setState(() {
      _isFavorite = !previous;
      _isTogglingFav = true;
    });
    try {
      final repo = ref.read(chatRepoProvider);
      final persisted = await repo.toggleFavorite(_correction.id);
      if (mounted) setState(() => _isFavorite = persisted);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = previous);
    } finally {
      if (mounted) setState(() => _isTogglingFav = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final typeColor = _typeColor(_correction.type);
    final impColor = _importanceColor(_correction.importance);

    return GlassCard(
      onTap: widget.isSubmitting ? null : widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap badges so they reflow on narrow widths instead of
          // overflowing when type + mastery + ×count + next-review all
          // compete for space on a 320pt screen.
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _typeLabel(context, _correction.type),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Color(
                    Sm2Service.getMasteryColor(_correction),
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  Sm2Service.getMasteryLevel(_correction),
                  style: TextStyle(
                    color: Color(Sm2Service.getMasteryColor(_correction)),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Phase-1 P0 #4 — importance pill, hidden when the LLM
              // didn't bother to score (default 50). Mirrors the
              // chat-screen card so the user sees the same cue in both
              // surfaces.
              if (_correction.importance != 50)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: impColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${_correction.importance}',
                    style: TextStyle(
                      color: impColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_correction.occurrenceCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '×${_correction.occurrenceCount}',
                    style: const TextStyle(
                      color: AppColors.accentPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                Sm2Service.getNextReviewText(_correction),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Original + demo + favorite actions row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.close, color: AppColors.error, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _correction.original,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.error,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              // Demo + favorite actions on the original row's trailing
              // edge so they don't push the corrected sentence down.
              _CardIconAction(
                icon: _isPlayingDemo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up_rounded,
                        size: 18, color: AppColors.accentPrimary),
                tooltip: l.t('correction.play_demo'),
                onPressed: _isPlayingDemo ? null : _playDemo,
              ),
              const SizedBox(width: AppSpacing.xs),
              _CardIconAction(
                icon: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 18,
                  color: _isFavorite
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                tooltip: _isFavorite
                    ? l.t('correction.unmark_favorite')
                    : l.t('correction.mark_favorite'),
                onPressed: _isTogglingFav ? null : _toggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Corrected
          Row(
            children: [
              const Icon(Icons.check, color: AppColors.success, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _correction.corrected,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_correction.explanation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _correction.explanation!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _RatingBar(onRate: widget.onRate, disabled: widget.isSubmitting),
        ],
      ),
    );
  }
}

/// Phase-1 P0 #4 — small icon action used inside the review card.
class _CardIconAction extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CardIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: icon,
        ),
      ),
    );
  }
}

/// The SM-2 rating bar: Again / Hard / Good / Easy.
///
/// These map to SM-2 quality scores 1 / 3 / 4 / 5. We deliberately skip 0
/// (complete blackout) and 2 (failed but recognized) because they're hard to
/// distinguish from "Again" in a 4-button UI, and the SM-2 interval formulas
/// only care about the boundary at quality >= 3 (pass) vs < 3 (fail).
class _RatingBar extends StatelessWidget {
  final ValueChanged<int> onRate;
  final bool disabled;

  const _RatingBar({required this.onRate, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: _ratingButton(context, label: l.t('review.rate_again'), quality: 1, color: AppColors.error)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _ratingButton(context, label: l.t('review.rate_hard'), quality: 3, color: AppColors.warning)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _ratingButton(context, label: l.t('review.rate_good'), quality: 4, color: AppColors.success)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _ratingButton(context, label: l.t('review.rate_easy'), quality: 5, color: AppColors.accentPrimary)),
      ],
    );
  }

  Widget _ratingButton(
    BuildContext context, {
    required String label,
    required int quality,
    required Color color,
  }) {
    return SizedBox(
      // 44pt meets the iOS HIG minimum touch target (was 36).
      height: Responsive.minTapTarget,
      child: OutlinedButton(
        onPressed: disabled ? null : () => onRate(quality),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          minimumSize: const Size.fromHeight(Responsive.minTapTarget),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
