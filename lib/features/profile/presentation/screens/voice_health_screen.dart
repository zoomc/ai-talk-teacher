import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/services/connectivity_check.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/services/connection_tester.dart';

/// Phase-1 P0 #2 — voice health diagnosis.
///
/// A single page that runs the four preconditions for a working voice chat
/// (microphone permission, network, STT, TTS) and shows a green/red status
/// chip per check. The user runs it once before their first conversation so
/// they don't discover a missing mic permission or an expired STT key mid-
/// chat. Reuses [ConnectionTester] for the STT/TTS probes so the logic stays
/// in one place.
class VoiceHealthScreen extends ConsumerStatefulWidget {
  const VoiceHealthScreen({super.key});

  @override
  ConsumerState<VoiceHealthScreen> createState() => _VoiceHealthScreenState();
}

/// Status of a single health check.
enum _CheckStatus { pending, running, pass, fail }

/// A tagged status so the row can render a custom label (e.g. the mic
/// permission result shows "Granted" / "Denied" rather than ok/fail).
class _CheckResult {
  final _CheckStatus status;
  final String detail;
  const _CheckResult(this.status, this.detail);
  const _CheckResult.pending()
      : status = _CheckStatus.pending,
        detail = '';
}

class _VoiceHealthScreenState extends ConsumerState<VoiceHealthScreen> {
  _CheckResult _mic = const _CheckResult.pending();
  _CheckResult _network = const _CheckResult.pending();
  _CheckResult _stt = const _CheckResult.pending();
  _CheckResult _tts = const _CheckResult.pending();
  bool _isRunning = false;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isLight
              ? AppColors.lightGradientBg
              : AppColors.gradientBg,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
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
                              Flexible(
                                child: Text(
                                  _l.t('health.title'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _l.t('health.intro'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _CheckRow(
                          icon: Icons.mic,
                          label: _l.t('health.mic_permission'),
                          result: _mic,
                        ),
                        _CheckRow(
                          icon: Icons.wifi,
                          label: _l.t('health.network'),
                          result: _network,
                        ),
                        _CheckRow(
                          icon: Icons.graphic_eq,
                          label: _l.t('health.stt'),
                          result: _stt,
                        ),
                        _CheckRow(
                          icon: Icons.volume_up,
                          label: _l.t('health.tts'),
                          result: _tts,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _overallBanner(),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isRunning ? null : _runAllChecks,
                              icon: _isRunning
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                _isRunning
                                    ? _l.t('health.checking')
                                    : _l.t('health.run_check'),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (_hasAnyResult)
                            OutlinedButton(
                              onPressed: _isRunning ? null : _runAllChecks,
                              child: Text(_l.t('health.recheck')),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasAnyResult =>
      _mic.status != _CheckStatus.pending ||
      _network.status != _CheckStatus.pending ||
      _stt.status != _CheckStatus.pending ||
      _tts.status != _CheckStatus.pending;

  /// Overall summary banner — green when everything passes, red when any
  /// check failed, neutral until the user runs the checks.
  Widget _overallBanner() {
    final all = [_mic, _network, _stt, _tts];
    final anyPending =
        all.any((r) => r.status == _CheckStatus.pending);
    final anyFail = all.any((r) => r.status == _CheckStatus.fail);
    final allPass =
        !anyPending && !anyFail && all.every((r) => r.status == _CheckStatus.pass);
    final Color color;
    final String label;
    final IconData icon;
    if (anyPending) {
      color = AppColors.textMuted;
      label = _l.t('health.run_check');
      icon = Icons.health_and_safety_outlined;
    } else if (allPass) {
      color = AppColors.success;
      label = _l.t('health.all_passed');
      icon = Icons.check_circle;
    } else {
      color = AppColors.error;
      label = _l.t('health.some_failed');
      icon = Icons.error_outline;
    }
    return GlassCard(
      glowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Run all four checks in order. Each check updates its row live so the
  /// user sees progress. Mic + network are local; STT/TTS hit the active
  /// profile's endpoint via [ConnectionTester].
  Future<void> _runAllChecks() async {
    setState(() => _isRunning = true);
    try {
      // 1. Microphone permission.
      setState(() => _mic = const _CheckResult(_CheckStatus.running, ''));
      try {
        final recorder = AudioRecorder();
        final granted = await recorder.hasPermission();
        await recorder.dispose();
        setState(() => _mic = _CheckResult(
          granted ? _CheckStatus.pass : _CheckStatus.fail,
          granted ? _l.t('health.mic_granted') : _l.t('health.mic_denied'),
        ));
      } catch (e) {
        setState(() => _mic =
            _CheckResult(_CheckStatus.fail, _safeError(e)));
      }

      // 2. Network.
      setState(() => _network = const _CheckResult(_CheckStatus.running, ''));
      try {
        // Reuse the connectivity provider for the live online state, but
        // also do a lightweight reachability probe so a captive portal
        // (online but no internet) shows red.
        final online = ref.read(connectivityServiceProvider);
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _network = _CheckResult(
          online ? _CheckStatus.pass : _CheckStatus.fail,
          online ? _l.t('health.ok') : _l.t('health.fail'),
        ));
      } catch (e) {
        setState(() => _network =
            _CheckResult(_CheckStatus.fail, _safeError(e)));
      }

      // 3. STT.
      setState(() => _stt = const _CheckResult(_CheckStatus.running, ''));
      try {
        final repo = ref.read(profileRepoProvider);
        final stt = await repo.getActiveSttProfile();
        if (stt == null) {
          setState(() => _stt = _CheckResult(
            _CheckStatus.fail,
            _l.tArg('health.no_active_profile',
                {'service': _l.t('health.stt')}),
          ));
        } else {
          final result = await ConnectionTester.testStt(stt);
          setState(() => _stt = _CheckResult(
            result.ok ? _CheckStatus.pass : _CheckStatus.fail,
            result.message,
          ));
        }
      } catch (e) {
        setState(() => _stt =
            _CheckResult(_CheckStatus.fail, _safeError(e)));
      }

      // 4. TTS.
      setState(() => _tts = const _CheckResult(_CheckStatus.running, ''));
      try {
        final repo = ref.read(profileRepoProvider);
        final tts = await repo.getActiveTtsProfile();
        if (tts == null) {
          setState(() => _tts = _CheckResult(
            _CheckStatus.fail,
            _l.tArg('health.no_active_profile',
                {'service': _l.t('health.tts')}),
          ));
        } else {
          final result = await ConnectionTester.testTts(tts);
          setState(() => _tts = _CheckResult(
            result.ok ? _CheckStatus.pass : _CheckStatus.fail,
            result.message,
          ));
        }
      } catch (e) {
        setState(() => _tts =
            _CheckResult(_CheckStatus.fail, _safeError(e)));
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  String _safeError(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }
}

/// A single health-check row: icon + label on the left, status chip on the
/// right. The chip is green/red/grey depending on [_CheckResult.status].
class _CheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final _CheckResult result;

  const _CheckRow({
    required this.icon,
    required this.label,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, String chip, Widget? trailing) = switch (result.status) {
      _CheckStatus.pending => (
        AppColors.textMuted,
        '',
        null,
      ),
      _CheckStatus.running => (
        AppColors.accentPrimary,
        AppLocalizations.of(context).t('health.checking'),
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      _CheckStatus.pass => (
        AppColors.success,
        AppLocalizations.of(context).t('health.ok'),
        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
      ),
      _CheckStatus.fail => (
        AppColors.error,
        AppLocalizations.of(context).t('health.fail'),
        const Icon(Icons.cancel, color: AppColors.error, size: 20),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: GlassCard(
        glowColor: color,
        isActive: result.status == _CheckStatus.pass,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (result.detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing,
            ] else if (chip.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
