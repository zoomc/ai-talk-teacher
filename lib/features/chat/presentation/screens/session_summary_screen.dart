import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../data/llm_service.dart';
import '../../data/tts_playback_service.dart';
import '../../data/tts_service.dart';
import '../../domain/session_summary.dart';

/// Phase-1 P0 #5 — post-class summary screen.
///
/// Loads a session's transcript + corrections, asks the LLM for a structured
/// summary (highlights, 3 improvements, 1 next-sentence), and renders it in
/// three cards. The user can play the next-sentence aloud via TTS so they
/// hear the model pronunciation before their next conversation.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionSummaryScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  SessionSummary? _summary;
  bool _isLoading = true;
  String? _error;
  final TtsPlaybackService _ttsPlaybackService = TtsPlaybackService();
  bool _isPlayingSentence = false;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _ttsPlaybackService.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final chatRepo = ref.read(chatRepoProvider);
      final llmProfile = await profileRepo.getActiveLlmProfile();
      final messages = await chatRepo.getMessages(widget.sessionId, limit: 60);
      final corrections =
          await chatRepo.getCorrectionsForSession(widget.sessionId);
      if (llmProfile == null) {
        setState(() {
          _isLoading = false;
          _error = _l.t('guest.unavailable');
        });
        return;
      }
      if (messages.length < 2) {
        setState(() {
          _isLoading = false;
          _error = _l.t('summary.no_session');
        });
        return;
      }
      final summary = await LlmService(llmProfile).generateSummary(
        sessionId: widget.sessionId,
        history: messages,
        corrections: corrections,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _l.tArg('summary.error', {});
        });
      }
    }
  }

  /// Play the "next sentence" via TTS so the user hears model pronunciation.
  Future<void> _playNextSentence() async {
    final sentence = _summary?.nextSentence;
    if (sentence == null || sentence.isEmpty || _isPlayingSentence) return;
    setState(() => _isPlayingSentence = true);
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();
      if (ttsProfile == null) {
        _snack(_l.t('guest.unavailable'));
        return;
      }
      final tts = TtsService(ttsProfile);
      await _ttsPlaybackService.playCached(
        sentence,
        () => tts.synthesize(sentence),
      );
    } catch (e) {
      debugPrint('summary playNextSentence failed: $e');
      _snack(_l.t('summary.error'));
    } finally {
      if (mounted) setState(() => _isPlayingSentence = false);
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
              : (isLight ? AppColors.lightGradientBg : AppColors.gradientBg),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: _buildBody(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(_l.t('summary.generating'),
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: Text(_l.t('common.try_again')),
              ),
            ],
          ),
        ),
      );
    }
    final s = _summary;
    if (s == null || s.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_satisfied_alt,
                  size: 56, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              Text(_l.t('summary.empty_highlight'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.xl),
              _backHomeButton(context),
            ],
          ),
        ),
      );
    }
    return _buildSummary(context, s);
  }

  Widget _buildSummary(BuildContext context, SessionSummary s) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
                tooltip: _l.t('summary.close'),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(_l.t('summary.title'),
                    style: Theme.of(context).textTheme.displayLarge),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Highlights
                _SummaryCard(
                  icon: Icons.star_rounded,
                  color: AppColors.success,
                  title: _l.t('summary.highlights'),
                  body: s.highlights,
                ),
                const SizedBox(height: AppSpacing.md),
                // Improvements (3 numbered items)
                GlassCard(
                  glowColor: AppColors.warning,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up_rounded,
                              color: AppColors.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Text(_l.t('summary.improvements'),
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (int i = 0; i < s.improvements.length; i++) ...[
                        _ImprovementRow(
                            index: i + 1, text: s.improvements[i]),
                        if (i < s.improvements.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Next sentence
                GlassCard(
                  glowColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: AppColors.accentPrimary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(_l.t('summary.next_sentence'),
                                style: const TextStyle(
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                          if (s.nextSentence.isNotEmpty)
                            IconButton(
                              icon: _isPlayingSentence
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.volume_up_rounded),
                              onPressed:
                                  _isPlayingSentence ? null : _playNextSentence,
                              tooltip: _l.t('practice.tap_demo'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        s.nextSentence,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _backHomeButton(context),
        ),
      ],
    );
  }

  Widget _backHomeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.home_outlined),
        label: Text(_l.t('summary.back_home')),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ImprovementRow extends StatelessWidget {
  final int index;
  final String text;
  const _ImprovementRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text.isEmpty ? '—' : text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
