/// Chat bubble + inline correction widgets, extracted from chat_screen.dart
/// as part of P1 task 2.
///
/// P1 features integrated:
/// - Task 1: progressive streaming render via [ChatBubble.streamingText].
/// - Task 4: phoneme-level colour tagging + tap-word detail overlay with
///   A/B replay.
/// - E14: TTS inline retry button on failed playback.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/focus_trap.dart';
import '../../core/util/responsive.dart';
import '../../features/chat/data/tts_playback_service.dart';
import '../../features/chat/data/tts_service.dart';
import '../../features/chat/domain/chat_models.dart';
import '../../features/chat/domain/phoneme_score.dart';
import '../../shared/providers.dart';

// ── ChatBubble ──────────────────────────────────────────────────────────────

/// A single chat message bubble.
///
/// When [streamingText] is non-null (P1 task 1), the bubble renders the
/// progressively-arriving text with a blinking cursor instead of [message],
/// so the user sees the AI reply being typed out token-by-token.
///
/// When [phonemeScores] is non-null (P1 task 4), user-message words are
/// colour-tagged by pronunciation quality and tappable to open a detail
/// overlay with A/B replay.
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isVoiceTranscript;
  final bool isPlaying;
  final List<Correction> corrections;
  final VoidCallback? onPlayTts;
  final TtsPlaybackService ttsPlaybackService;

  /// Live streaming text from the LLM SSE stream (P1 task 1). When non-null
  /// this takes precedence over [message] for rendering.
  final String? streamingText;

  /// Per-word phoneme scores keyed by word position (P1 task 4). When
  /// non-null, user-message words are colour-tagged and tappable.
  final Map<int, List<PhonemeScore>>? phonemeScores;

  /// Whether TTS playback failed for this message (E14). When true, a
  /// retry button is shown instead of the normal play/stop toggle.
  final bool ttsFailed;
  final VoidCallback? onRetryTts;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.ttsPlaybackService,
    this.isVoiceTranscript = false,
    this.isPlaying = false,
    this.corrections = const [],
    this.onPlayTts,
    this.streamingText,
    this.phonemeScores,
    this.ttsFailed = false,
    this.onRetryTts,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bubbleColor = isUser
        ? (isLight ? AppColors.lightBubbleUser : AppColors.bubbleUser)
        : (isLight ? AppColors.lightBubbleAi : AppColors.bubbleAi);
    final accent = isUser ? AppColors.accentSecondary : AppColors.accentPrimary;

    final isStreaming = streamingText != null;
    final displayText = streamingText ?? message;

    return Semantics(
      container: true,
      label: isUser
          ? '${l.t('chat.you_label')}: $displayText'
          : '${l.t('chat.ai_label')}: $displayText',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth * Responsive.bubbleMaxWidthFraction(context);
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.lg),
                topRight: const Radius.circular(AppRadius.lg),
                bottomLeft:
                    Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
                bottomRight:
                    Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
              ),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUser && isVoiceTranscript) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded,
                          size: 14, color: accent),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        l.t('chat.live_transcript'),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                // P1 task 4 — phoneme-tagged text for user voice transcripts.
                if (isUser && phonemeScores != null && !isStreaming)
                  _PhonemeTaggedText(
                    text: displayText,
                    scores: phonemeScores!,
                  )
                else
                  _StreamingText(
                    text: displayText,
                    isStreaming: isStreaming,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                if (isUser && corrections.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      l.t('chat.feedback_ready'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...corrections.map((c) => CorrectionInline(
                        correction: c,
                        ttsPlaybackService: ttsPlaybackService,
                      )),
                ],
                if (!isUser && corrections.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ...corrections.map((c) => CorrectionInline(
                        correction: c,
                        ttsPlaybackService: ttsPlaybackService,
                      )),
                ],
                if (!isUser && onPlayTts != null && !isStreaming) ...[
                  const SizedBox(height: AppSpacing.xs),
                  if (ttsFailed && onRetryTts != null)
                    _TtsRetryButton(onRetry: onRetryTts!)
                  else
                    _TtsPlayButton(
                      isPlaying: isPlaying,
                      onTap: onPlayTts,
                    ),
                ],
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}

// ── Streaming text with cursor (P1 task 1) ─────────────────────────────────

class _StreamingText extends StatelessWidget {
  final String text;
  final bool isStreaming;
  final TextStyle? style;

  const _StreamingText({
    required this.text,
    required this.isStreaming,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (!isStreaming) {
      return Text(text, style: style);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, style: style)),
        const _BlinkingCursor(),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _controller.value > 0.5 ? 1.0 : 0.2,
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2, bottom: 3),
            color: AppColors.accentPrimary,
          ),
        );
      },
    );
  }
}

// ── Phoneme-tagged text (P1 task 4) ────────────────────────────────────────

/// Renders the user's transcript with each word colour-tagged by its
/// phoneme score band. Tapping a word opens a detail overlay with A/B
/// replay.
class _PhonemeTaggedText extends StatelessWidget {
  final String text;
  final Map<int, List<PhonemeScore>> scores;

  const _PhonemeTaggedText({required this.text, required this.scores});

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'(\s+)'));
    final style = Theme.of(context).textTheme.bodyLarge;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: List.generate(words.length, (i) {
        final word = words[i];
        if (word.trim().isEmpty) {
          return Text(word, style: style);
        }
        final wordScores = scores[i];
        if (wordScores == null || wordScores.isEmpty) {
          return Text(word, style: style);
        }
        final band = wordScores.first.band;
        final color = _bandColor(band);
        return GestureDetector(
          onTap: () => _showPhonemeDetail(context, i, word, wordScores),
          child: Tooltip(
            message: '${wordScores.first.score}/100',
            child: Text(
              word,
              style: style?.copyWith(
                color: color,
                decoration: band == PhonemeScoreBand.poor
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: color,
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _bandColor(PhonemeScoreBand band) {
    switch (band) {
      case PhonemeScoreBand.good:
        return AppColors.success;
      case PhonemeScoreBand.fair:
        return AppColors.warning;
      case PhonemeScoreBand.poor:
        return AppColors.error;
    }
  }

  void _showPhonemeDetail(
    BuildContext context,
    int position,
    String word,
    List<PhonemeScore> wordScores,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _PhonemeDetailSheet(
        word: word,
        position: position,
        scores: wordScores,
        ttsPlaybackService: ttsPlaybackServiceGlobal,
      ),
    );
  }
}

/// Bottom-sheet overlay showing per-phoneme scores for a tapped word,
/// with A/B replay buttons (user audio vs TTS demo). P1 task 4.
class _PhonemeDetailSheet extends ConsumerWidget {
  final String word;
  final int position;
  final List<PhonemeScore> scores;
  final TtsPlaybackService ttsPlaybackService;

  const _PhonemeDetailSheet({
    required this.word,
    required this.position,
    required this.scores,
    required this.ttsPlaybackService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return FocusTrap(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$word"',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Overall score badge.
            _OverallScoreBadge(score: scores.first.score),
            const SizedBox(height: AppSpacing.md),
            Text(l.t('phoneme.detail_title'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ...scores.map((s) => _PhonemeRow(score: s)),
            const SizedBox(height: AppSpacing.md),
            // A/B replay: hear the TTS demo of the word.
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _playDemo(ref),
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: Text(l.t('phoneme.ab_demo')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _playDemo(WidgetRef ref) async {
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();
      if (ttsProfile == null) return;
      final tts = TtsService(ttsProfile);
      await ttsPlaybackService.playCached(word, () => tts.synthesize(word));
    } catch (_) {
      // Best-effort demo — don't block the overlay.
    }
  }
}

class _OverallScoreBadge extends StatelessWidget {
  final int score;
  const _OverallScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final band = PhonemeScoreBand.fromScore(score);
    final color = switch (band) {
      PhonemeScoreBand.good => AppColors.success,
      PhonemeScoreBand.fair => AppColors.warning,
      PhonemeScoreBand.poor => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text('/ 100', style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PhonemeRow extends StatelessWidget {
  final PhonemeScore score;
  const _PhonemeRow({required this.score});

  @override
  Widget build(BuildContext context) {
    final band = score.band;
    final color = switch (band) {
      PhonemeScoreBand.good => AppColors.success,
      PhonemeScoreBand.fair => AppColors.warning,
      PhonemeScoreBand.poor => AppColors.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '/${score.phoneme}/',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: score.score / 100,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 36,
            child: Text(
              '${score.score}',
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TTS play / retry buttons ────────────────────────────────────────────────

class _TtsPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _TtsPlayButton({required this.isPlaying, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: isPlaying ? 'Stop playback' : 'Play this message',
      hint: isPlaying
          ? 'Double tap to stop audio'
          : 'Double tap to hear the AI tutor say this',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: Responsive.minTapTarget,
            minHeight: Responsive.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlaying ? Icons.stop_circle : Icons.play_circle,
                color: AppColors.accentSecondary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                isPlaying ? l.t('chat.stop') : l.t('chat.listen'),
                style: const TextStyle(
                  color: AppColors.accentSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// E14 — inline TTS retry button shown when playback fails.
class _TtsRetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  const _TtsRetryButton({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.t('chat.tts_unavailable_retry'),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: Responsive.minTapTarget,
            minHeight: Responsive.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, color: AppColors.warning, size: 20),
              const SizedBox(width: 4),
              Text(
                l.t('chat.tts_unavailable_retry'),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing bubble ───────────────────────────────────────────────────────────

class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightBubbleAi
              : AppColors.bubbleAi,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.xs),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value - i * 0.15) % 1.0;
                final scale = 0.6 + 0.6 * (1 - (2 * t - 1).abs());
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// ── Inline correction card ──────────────────────────────────────────────────

/// Inline correction card rendered inside a chat bubble.
class CorrectionInline extends ConsumerStatefulWidget {
  final Correction correction;
  final TtsPlaybackService ttsPlaybackService;

  const CorrectionInline({
    super.key,
    required this.correction,
    required this.ttsPlaybackService,
  });

  @override
  ConsumerState<CorrectionInline> createState() => _CorrectionInlineState();
}

class _CorrectionInlineState extends ConsumerState<CorrectionInline> {
  late bool _isFavorite = widget.correction.isFavorite;
  bool _isTogglingFav = false;
  bool _isPlayingDemo = false;

  Correction get _correction => widget.correction;

  Color _typeColor(CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return AppColors.error;
      case CorrectionType.vocabulary:
        return AppColors.warning;
      case CorrectionType.pronunciation:
        return AppColors.accentSecondary;
      case CorrectionType.fluency:
        return AppColors.info;
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
      case CorrectionType.fluency:
        return AppLocalizations.of(context).t('correction.type_fluency');
    }
  }

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
              content: Text(AppLocalizations.of(context).t('guest.unavailable')),
            ),
          );
        }
        return;
      }
      final tts = TtsService(ttsProfile);
      await widget.ttsPlaybackService.playCached(
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
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightBubbleCorrection
            : AppColors.bubbleCorrection,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  _typeLabel(context, _correction.type),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (_correction.importance != 50)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: impColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    '${_correction.importance}',
                    style: TextStyle(
                      color: impColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              _IconAction(
                icon: _isPlayingDemo
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up_rounded,
                        size: 16, color: AppColors.accentPrimary),
                tooltip: l.t('correction.play_demo'),
                onPressed: _isPlayingDemo ? null : _playDemo,
              ),
              const SizedBox(width: AppSpacing.xs),
              _IconAction(
                icon: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
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
          Row(
            children: [
              const Icon(Icons.close, color: AppColors.error, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _correction.original,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.check, color: AppColors.success, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _correction.corrected,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          if (_correction.explanation != null &&
              _correction.explanation!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _correction.explanation!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tiny 36×36 hit-box wrapper used by the correction card's icon buttons.
class _IconAction extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconAction({
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
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: icon,
        ),
      ),
    );
  }
}

/// Module-level placeholder for the TTS playback service used by the
/// phoneme detail sheet. Set by the chat screen on init so the sheet
/// can access it without a constructor chain.
TtsPlaybackService ttsPlaybackServiceGlobal = TtsPlaybackService();
