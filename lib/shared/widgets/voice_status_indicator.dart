import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../voice_phase.dart';
import 'glass_widgets.dart';

/// Phase-1 P0 #7 — the single shared voice-state indicator.
///
/// Renders one consistent visual per [VoicePhase] (icon + pulsing dot +
/// label + a thin progress bar across the turn) so a voice turn looks
/// identical on the chat screen, the sentence-practice screen, the guest
/// trial, etc. Replaces the per-screen ad-hoc status rows that previously
/// drifted apart in copy, colour, and animation.
///
/// The widget is intentionally compact (a single GlassCard row) so it drops
/// into a chat input bar, a practice header, or a modal footer unchanged.
/// Callers drive it by setting [phase]; the widget owns its own animation
/// controller so callers don't have to thread one through.
class VoiceStatusIndicator extends StatefulWidget {
  /// Current voice phase. The widget animates a transition when this changes.
  final VoicePhase phase;

  /// Optional override shown to the right of the status label — e.g. the
  /// live transcription text during [VoicePhase.transcribing], or the guest
  /// trial countdown. Omit for the default compact look.
  final String? trailing;

  /// When true, the widget renders at a larger size suitable for a hero
  /// position (e.g. the sentence-practice header). Defaults to compact.
  final bool expanded;

  const VoiceStatusIndicator({
    super.key,
    required this.phase,
    this.trailing,
    this.expanded = false,
  });

  @override
  State<VoiceStatusIndicator> createState() => _VoiceStatusIndicatorState();
}

class _VoiceStatusIndicatorState extends State<VoiceStatusIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseScale = Tween<double>(begin: 0.7, end: 1.6).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant VoiceStatusIndicator old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _syncAnimation();
  }

  /// Pulse only during active phases; stop the controller at idle so the
  /// dot is a calm solid circle and we're not burning frames.
  void _syncAnimation() {
    if (widget.phase.isActive) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  (IconData, Color) _phaseVisual(VoicePhase phase) {
    return switch (phase) {
      VoicePhase.listening => (Icons.hearing_rounded, AppColors.accentSecondary),
      VoicePhase.transcribing => (
        Icons.graphic_eq_rounded,
        AppColors.accentSecondaryLight,
      ),
      VoicePhase.thinking => (Icons.auto_awesome_rounded, AppColors.accentPrimary),
      VoicePhase.speaking => (Icons.volume_up_rounded, AppColors.success),
      VoicePhase.idle => (Icons.record_voice_over_rounded, AppColors.accentPrimary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, color) = _phaseVisual(widget.phase);
    final label = l.t(widget.phase.labelKey);
    final dotSize = widget.expanded ? 16.0 : 11.0;
    final iconSize = widget.expanded ? 26.0 : 20.0;

    return GlassCard(
      borderRadius: AppRadius.lg,
      blurAmount: widget.expanded ? 28 : 20,
      glowColor: color,
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? AppSpacing.lg : AppSpacing.md,
        vertical: widget.expanded ? AppSpacing.md : AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing status dot — the heart of the "consistent animation"
          // requirement. Scale pulses only on active phases.
          SizedBox(
            width: dotSize + 4,
            height: dotSize + 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.phase.isActive)
                  AnimatedBuilder(
                    animation: _pulseScale,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseScale.value,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, color: color, size: iconSize),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: widget.expanded ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.expanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: widget.phase.progress,
                        minHeight: 3,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.trailing != null && widget.trailing!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 2,
              child: Text(
                widget.trailing!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
