/// Chat input bar widget, extracted from chat_screen.dart as part of P1 task 2.
///
/// Contains the voice/text input toggle, record button, text field, send
/// button, continuous-mode toggle, and offline hint.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/connectivity_check.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/responsive.dart';

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
    if (widget.isRecording) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.retryHint!,
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
    final color = isRecording ? AppColors.error : AppColors.accentSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: !isLoading,
            label: isRecording
                ? l.t('chat.stop_recording')
                : l.t('chat.start_voice'),
            child: Tooltip(
              message: isRecording
                  ? l.t('chat.stop_recording')
                  : l.t('chat.tap_to_record'),
              child: Listener(
                onPointerDown: isLoading || isRecording
                    ? null
                    : (_) async {
                        _voicePointerDown = true;
                        await widget.onRecordToggle();
                        if (!_voicePointerDown && mounted) {
                          await widget.onRecordToggle();
                        }
                      },
                onPointerUp: isLoading
                    ? null
                    : (_) async {
                        _voicePointerDown = false;
                        if (widget.isRecording) await widget.onRecordToggle();
                      },
                onPointerCancel: isLoading
                    ? null
                    : (_) async {
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
                        width: 224,
                        height: 62,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          gradient: isRecording
                              ? LinearGradient(colors: [color, AppColors.error])
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF11DDE1),
                                    Color(0xFF6CB9FF),
                                    Color(0xFFF038DA),
                                  ],
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: isRecording ? 24 : 12,
                              spreadRadius: isRecording ? 4 : 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isRecording ? Icons.stop : Icons.mic,
                              color: Colors.white,
                              size: 26,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              isRecording
                                  ? l.t('chat.stop_recording')
                                  : l.t('chat.hold_to_talk'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
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
          Text(
            isRecording
                ? l.t('chat.stop_recording')
                : l.t('chat.release_to_send'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
      crossAxisAlignment: CrossAxisAlignment.end,
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
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: isLight ? AppColors.lightBgSurface : AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isRecording
                    ? AppColors.error.withValues(alpha: 0.6)
                    : (isLight
                          ? AppColors.lightGlassBorder
                          : AppColors.glassBorder),
              ),
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
                      ? AppColors.lightTextMuted
                      : AppColors.textMuted,
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
              child: Opacity(
                opacity: canSend ? 1.0 : 0.4,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradientPrimary,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.t('chat.offline_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    height: 1.3,
                  ),
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
    _pulse = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
    final color =
        widget.isRecording ? AppColors.error : AppColors.accentSecondary;
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
    final active = enabled
        ? AppColors.accentPrimary
        : (isLight ? AppColors.lightTextMuted : AppColors.textMuted);
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
            Icon(
              enabled ? Icons.graphic_eq : Icons.record_voice_over_outlined,
              size: 16,
              color: active,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l.t('chat.continuous_mode'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: active,
                    fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
