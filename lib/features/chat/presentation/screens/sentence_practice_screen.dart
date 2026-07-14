import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/voice_phase.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/voice_status_indicator.dart';
import '../../data/recording_service.dart';
import '../../data/stt_service.dart';
import '../../data/tts_playback_service.dart';
import '../../data/tts_service.dart';
import '../../domain/chat_models.dart';

/// Phase-1 P0 #3 — sentence-by-sentence practice.
///
/// Loop: AI demo (TTS plays the target) → user reads along (mic records) →
/// show transcription vs target comparison → "say again" or "next". The
/// target sentences come from the user's saved corrections (the `corrected`
/// form), so practice is always grounded in real mistakes they've made.
///
/// Uses [VoiceStatusIndicator] so the voice phase animation matches the chat
/// screen (准备→聆听→转写→思考→播报) — one of the Phase-1 P0 #7 goals.
class SentencePracticeScreen extends ConsumerStatefulWidget {
  const SentencePracticeScreen({super.key});

  @override
  ConsumerState<SentencePracticeScreen> createState() =>
      _SentencePracticeScreenState();
}

class _SentencePracticeScreenState
    extends ConsumerState<SentencePracticeScreen> {
  final RecordingService _recordingService = RecordingService();
  final TtsPlaybackService _ttsPlaybackService = TtsPlaybackService();

  List<Correction> _sentences = [];
  int _index = 0;
  bool _isLoading = true;
  // Current voice phase shown by the shared indicator.
  VoicePhase _phase = VoicePhase.idle;
  // The transcript of the user's last read-along, shown next to the target.
  String? _userSaid;
  // Whether a TTS demo is playing or a recording is in flight — used to
  // disable buttons to prevent overlapping voice actions.
  bool _busy = false;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadSentences();
  }

  @override
  void dispose() {
    _recordingService.dispose();
    _ttsPlaybackService.dispose();
    super.dispose();
  }

  Future<void> _loadSentences() async {
    try {
      final repo = ref.read(chatRepoProvider);
      // Practice sentences = due corrections + favorites, de-duped by
      // corrected text. Favorites first so the user drills what they
      // explicitly want to master.
      final due = await repo.getDueCorrections(limit: 30);
      final fav = await repo.getFavoriteCorrections(limit: 30);
      final seen = <String>{};
      final list = <Correction>[];
      for (final c in [...fav, ...due]) {
        final key = c.corrected.trim().toLowerCase();
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        list.add(c);
      }
      if (mounted) {
        setState(() {
          _sentences = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Correction? get _current =>
      _sentences.isNotEmpty && _index < _sentences.length
          ? _sentences[_index]
          : null;

  void _setPhase(VoicePhase p) {
    if (!mounted) return;
    setState(() => _phase = p);
  }

  /// Step 1 — AI demo. Synthesize + play the target sentence via TTS.
  Future<void> _playDemo() async {
    if (_busy || _current == null) return;
    setState(() {
      _busy = true;
      _userSaid = null;
    });
    _setPhase(VoicePhase.speaking);
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();
      if (ttsProfile == null) {
        _snack(_l.t('guest.unavailable'));
        return;
      }
      final tts = TtsService(ttsProfile);
      await _ttsPlaybackService.playCached(
        _current!.corrected,
        () => tts.synthesize(_current!.corrected),
      );
    } catch (e) {
      _snack(_safeError(e));
    } finally {
      _setPhase(VoicePhase.idle);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Step 2 — user reads along. Record, then transcribe via STT, then show
  /// the comparison.
  Future<void> _readAlong() async {
    if (_busy || _current == null) return;
    setState(() {
      _busy = true;
      _userSaid = null;
    });
    _setPhase(VoicePhase.listening);
    try {
      await _recordingService.startRecording();
      // Hold the mic for a fixed 4s window so the user has a predictable
      // "now I speak" cadence without fumbling a stop button. The recording
      // service writes a WAV we then send to STT.
      await Future.delayed(const Duration(seconds: 4));
      _setPhase(VoicePhase.transcribing);
      final bytes = await _recordingService.stopRecording();
      if (bytes == null) {
        _snack(_l.t('health.mic_denied'));
        return;
      }
      final profileRepo = ref.read(profileRepoProvider);
      final sttProfile = await profileRepo.getActiveSttProfile();
      if (sttProfile == null) {
        _snack(_l.t('guest.unavailable'));
        return;
      }
      final stt = SttService(sttProfile);
      _setPhase(VoicePhase.thinking);
      final transcript = await stt.transcribe(bytes);
      if (mounted) setState(() => _userSaid = transcript.trim());
    } catch (e) {
      _snack(_safeError(e));
    } finally {
      _setPhase(VoicePhase.idle);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Say again" — clears the last transcript and re-arms the read step
  /// without advancing, so the user can drill the same sentence.
  void _sayAgain() {
    if (_busy) return;
    setState(() => _userSaid = null);
  }

  void _next() {
    if (_busy) return;
    if (_index < _sentences.length - 1) {
      setState(() {
        _index += 1;
        _userSaid = null;
      });
    } else {
      // Finished all sentences — go home.
      _snack(_l.t('practice.done'));
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isLight ? AppColors.lightGradientBg : AppColors.gradientBg,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sentences.isEmpty
                      ? _buildEmpty(context)
                      : _buildPractice(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.record_voice_over_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(_l.t('practice.empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(_l.t('nav.practice')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPractice(BuildContext context) {
    final c = _current!;
    return Column(
      children: [
        // Header with back button + title + progress.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/'),
                    tooltip: _l.t('common.back'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(_l.t('practice.title'),
                        style: Theme.of(context).textTheme.displayLarge),
                  ),
                  Text(
                    '${_index + 1}/${_sentences.length}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(_l.t('practice.intro'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      )),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Target sentence card.
                GlassCard(
                  glowColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_l.t('practice.target'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          )),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        c.corrected,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (c.original != c.corrected) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${_l.t('practice.you_said')} (原): ${c.original}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Unified voice status indicator (P0 #7).
                Center(
                  child: VoiceStatusIndicator(
                    phase: _phase,
                    expanded: true,
                    trailing: _userSaid,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Comparison block — only after the user has read along.
                if (_userSaid != null) _buildComparison(context, c.corrected),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        // Action bar — sticky at the bottom.
        _buildActionBar(context),
      ],
    );
  }

  Widget _buildComparison(BuildContext context, String target) {
    final match = _normalize(_userSaid!) == _normalize(target);
    final color = match ? AppColors.success : AppColors.warning;
    return GlassCard(
      glowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(match ? Icons.check_circle : Icons.info_outline,
                  color: color, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(_l.t('practice.compare'),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('${_l.t('practice.you_said')}:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(_userSaid!,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(_l.t('practice.target'),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(target, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _playDemo,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(_l.t('practice.demo')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _readAlong,
                  icon: const Icon(Icons.mic),
                  label: Text(_l.t('practice.read_along')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (_userSaid != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _sayAgain,
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text(_l.t('practice.try_again')),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _next,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_l.t('practice.next')),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _safeError(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }
}
