/// Chat input bar widget, extracted from chat_screen.dart as part of P1 task 2.
///
/// Contains the voice/text input toggle, record button, text field, send
/// button, continuous-mode toggle, and offline hint.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/connectivity_check.dart';
import '../../core/theme/app_colors.dart';

/// Input mode for [ChatInputBar]. Voice is the default.
enum InputMode { voice, text }

/// Chat input bar with voice (hold-to-talk) and text modes.
class ChatInputBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isRecording;
  final bool isLoading;
  final bool continuousMode;
  final VoidCallback onSend;
  final Future<void> Function() onRecordToggle;
  final ValueChanged<bool> onToggleContinuous;

  /// P1 task 3 — retry progress text to display inline ("重试中… 2/5").
  /// Null when no retry is in flight.
  final String? retryHint;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isRecording,
    required this.isLoading,
    required this.continuousMode,
    required this.onSend,
    required this.onRecordToggle,
    required this.onToggleContinuous,
    this.retryHint,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar>
    with SingleTickerProviderStateMixin {
  InputMode _inputMode = InputMode.voice;
  bool _voicePointerDown = false;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _startRecordingTimer();
    }
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
        _startRecordingTimer();
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
        _stopRecordingTimer();
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecordingTimer() {
    _recordingStartedAt = DateTime.now();
    _recordingSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _recordingStartedAt == null) return;
      setState(() {
        _recordingSeconds = DateTime.now()
            .difference(_recordingStartedAt!)
            .inSeconds;
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingStartedAt = null;
    if (mounted) setState(() => _recordingSeconds = 0);
  }

  String get _recordingDuration {
    final m = _recordingSeconds ~/ 60;
    final s = _recordingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = safeBottom + AppSpacing.md;
    final isOffline = ref.watch(isOfflineProvider);
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: bottomPad,
      ),
      decoration: BoxDecoration(
        color: isLight ? AppColors.lightBgSecondary : AppColors.bgSecondary,
        border: Border(
          top: BorderSide(
            color: isLight ? AppColors.lightGlassBorder : AppColors.glassBorder,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOffline) const _OfflineHint(),
          // P1 task 3 — retry progress indicator.
          if (widget.retryHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLight ? AppColors.lightWarning : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.retryHint!,
                    style: TextStyle(
                      color: isLight
                          ? AppColors.lightWarning
                          : AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (_inputMode == InputMode.voice)
                _ContinuousToggle(
                  enabled: widget.continuousMode,
                  onChanged: widget.onToggleContinuous,
                ),
              const Spacer(),
              Semantics(
                button: true,
                label: _inputMode == InputMode.voice
                    ? l.t('chat.switch_to_text')
                    : l.t('chat.switch_to_voice'),
                child: IconButton(
                  tooltip: _inputMode == InputMode.voice
                      ? l.t('chat.switch_to_text')
                      : l.t('chat.switch_to_voice'),
                  iconSize: 26,
                  icon: Icon(
                    _inputMode == InputMode.voice
                        ? Icons.keyboard_outlined
                        : Icons.mic_none,
                  ),
                  onPressed: () {
                    setState(() {
                      _inputMode = _inputMode == InputMode.voice
                          ? InputMode.text
                          : InputMode.voice;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_inputMode == InputMode.voice)
            _buildVoiceInput(l)
          else
            _buildTextInputRow(l),
        ],
      ),
    );
  }

  Widget _buildVoiceInput(AppLocalizations l) {
    final isRecording = widget.isRecording;
    final isLoading = widget.isLoading;
    // Keep the primary control available while the tutor is processing. A
    // user must be able to cancel a slow STT/LLM turn instead of waiting for
    // an opaque request to finish before they can speak again.
    final actionLabel = isLoading
        ? l.t('common.cancel')
        : (isRecording ? l.t('chat.stop_recording') : l.t('chat.start_voice'));
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = isRecording
        ? (isLight ? AppColors.lightError : AppColors.error)
        : (isLight
              ? AppColors.lightAccentSecondary
              : AppColors.accentSecondary);
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - AppSpacing.xl).clamp(224.0, 320.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: true,
            label: actionLabel,
            child: Tooltip(
              message: isLoading ? l.t('common.cancel') : actionLabel,
              child: Listener(
                onPointerDown: isRecording
                    ? null
                    : (_) async {
                        final wasLoading = widget.isLoading;
                        _voicePointerDown = true;
                        await widget.onRecordToggle();
                        // A pointer-up that happens while cancellation is in
                        // flight must not immediately start a new recording.
                        if (!wasLoading && !_voicePointerDown && mounted) {
                          await widget.onRecordToggle();
                        }
                      },
                onPointerUp: (_) async {
                  _voicePointerDown = false;
                  if (widget.isRecording) await widget.onRecordToggle();
                },
                onPointerCancel: (_) async {
                  _voicePointerDown = false;
                  if (widget.isRecording) await widget.onRecordToggle();
                },
                child: AnimatedBuilder(
                  animation: _pulseScale,
                  builder: (context, _) {
                    final scale = isRecording ? _pulseScale.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: buttonWidth,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          gradient: isRecording
                              ? LinearGradient(colors: [color, AppColors.error])
                              : AppColors.gradientPrimary,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: isRecording ? 24 : 12,
                              spreadRadius: isRecording ? 4 : 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isLoading
                                  ? Icons.cancel_outlined
                                  : (isRecording ? Icons.stop : Icons.mic),
                              color: Colors.white,
                              size: 26,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isLoading
                                      ? l.t('common.cancel')
                                      : (isRecording
                                            ? l.t('chat.stop_recording')
                                            : l.t('chat.hold_to_talk')),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black38,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRecording)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                isRecording
                    ? '${l.t('chat.recording')} $_recordingDuration'
                    : l.t('chat.release_to_send'),
                style: TextStyle(
                  color: isRecording
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputRow(AppLocalizations l) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isRecording = widget.isRecording;
    final isLoading = widget.isLoading;
    final controller = widget.controller;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: !isLoading,
          label: isRecording
              ? l.t('chat.stop_recording')
              : l.t('chat.start_voice'),
          hint: isRecording
              ? 'Double tap to stop and transcribe'
              : 'Double tap to record a voice message',
          child: Tooltip(
            message: isRecording
                ? l.t('chat.stop_recording')
                : l.t('chat.tap_to_record'),
            child: _RecordButton(
              isRecording: isRecording,
              onTap: isLoading ? null : () => widget.onRecordToggle(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, maxHeight: 160),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLight ? AppColors.lightBgTertiary : AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isRecording
                    ? AppColors.error.withValues(alpha: 0.6)
                    : (isLight
                          ? AppColors.lightGlassBorder
                          : AppColors.glassBorder),
                width: 1.2,
              ),
              boxShadow: isRecording
                  ? [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: -4,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: (isLight
                                ? AppColors.lightTextMuted
                                : AppColors.glassBorder)
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: -6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: TextField(
              controller: controller,
              focusNode: widget.focusNode,
              enabled: !isLoading,
              style: TextStyle(
                color: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
              ),
              textInputAction: TextInputAction.send,
              maxLines: null,
              minLines: 1,
              decoration: InputDecoration(
                hintText: l.t('chat.type_message'),
                hintStyle: TextStyle(
                  color: isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 4,
                ),
              ),
              onSubmitted: (_) {
                final canSubmit =
                    controller.text.trim().isNotEmpty && !isLoading;
                if (canSubmit) widget.onSend();
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSend = value.text.trim().isNotEmpty && !isLoading;
            return Semantics(
              button: true,
              enabled: canSend,
              label: l.t('chat.send'),
              hint: canSend
                  ? 'Double tap to send'
                  : 'Type a message first to send',
              child: MouseRegion(
                cursor: canSend
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.forbidden,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? null
                        : (isLight
                                  ? AppColors.lightDisabled
                                  : AppColors.disabled)
                              .withValues(alpha: 0.5),
                    gradient: canSend ? AppColors.gradientPrimary : null,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: canSend
                          ? Colors.white
                          : (isLight
                                ? AppColors.lightTextDisabled
                                : AppColors.textDisabled),
                      size: 24,
                    ),
                    onPressed: canSend ? widget.onSend : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Compact offline banner shown above the chat input when offline.
class _OfflineHint extends StatelessWidget {
  const _OfflineHint();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = isLight ? AppColors.lightWarning : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.t('chat.offline_hint'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Record (mic) button with a pulsing glow while recording.
class _RecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onTap;

  const _RecordButton({required this.isRecording, required this.onTap});

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = Tween<double>(
      begin: 0.25,
      end: 0.55,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isRecording) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording == oldWidget.isRecording) return;
    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = widget.isRecording
        ? (isLight ? AppColors.lightError : AppColors.error)
        : (isLight
              ? AppColors.lightAccentSecondary
              : AppColors.accentSecondary);
    final baseGlow = widget.isRecording ? 0.4 : 0.25;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glowAlpha = widget.isRecording ? _pulse.value : baseGlow;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isRecording)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RipplePainter(
                        progress: _controller.value,
                        color: color,
                      ),
                    ),
                  ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: glowAlpha),
                        blurRadius: widget.isRecording ? 24 : 12,
                        spreadRadius: widget.isRecording ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Draws one expanding ring (sonar pulse) for the recording state.
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final radius = maxRadius * (0.5 + progress * 0.9);
    final alpha = (1.0 - progress) * 0.5;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// E5: a compact "Continuous conversation" toggle chip.
class _ContinuousToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ContinuousToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      toggled: enabled,
      button: true,
      label: l.t('chat.continuous_mode'),
      hint: enabled
          ? 'Double tap to turn hands-free off'
          : 'Double tap to turn hands-free on',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () => onChanged(!enabled),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: enabled,
                onChanged: onChanged,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.accentPrimary;
                  }
                  return isLight
                      ? AppColors.lightTextMuted
                      : AppColors.textMuted;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.accentPrimary.withValues(alpha: 0.5);
                  }
                  return isLight
                      ? AppColors.lightBgTertiary
                      : AppColors.bgTertiary;
                }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                l.t('chat.continuous_mode'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: enabled
                      ? AppColors.accentPrimary
                      : (isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary),
                  fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.accentPrimary.withValues(alpha: 0.15)
                      : (isLight ? AppColors.lightDisabled : AppColors.disabled)
                            .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  enabled ? 'ON' : 'OFF',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: enabled
                        ? AppColors.accentPrimary
                        : (isLight
                              ? AppColors.lightTextMuted
                              : AppColors.textMuted),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
