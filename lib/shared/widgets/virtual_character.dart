import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// AI Virtual Character Widget
/// Displays the AI tutor with animations and state indicators.
///
/// Pass [size] (the diameter of the circular avatar) to scale the widget
/// for the current breakpoint — see [Responsive.characterSize].
class VirtualCharacter extends StatefulWidget {
  final String tutorName;
  final String tutorAvatar;
  final CharacterState state;
  final Color accentColor;

  /// Diameter of the character circle in pixels. Defaults to 120 (legacy
  /// size) so existing callers keep working without changes.
  final double size;

  /// Whether to render the name + state pill below the avatar.
  /// On compact layouts with a tight stack height this can be hidden
  /// (the AppBar already identifies the tutor).
  final bool showLabel;

  const VirtualCharacter({
    super.key,
    required this.tutorName,
    required this.tutorAvatar,
    this.state = CharacterState.idle,
    this.accentColor = AppColors.accentPrimary,
    this.size = 120,
    this.showLabel = true,
  });

  @override
  State<VirtualCharacter> createState() => _VirtualCharacterState();
}

class _VirtualCharacterState extends State<VirtualCharacter>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _glowController;
  late AnimationController _mouthController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _mouthAnimation;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _breathingAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    _breathingController.repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    // Mouth / speaking animation — simulates lip movement while speaking.
    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _mouthAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _mouthController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant VirtualCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == CharacterState.speaking &&
        oldWidget.state != CharacterState.speaking) {
      _mouthController.repeat(reverse: true);
    } else if (widget.state != CharacterState.speaking &&
        oldWidget.state == CharacterState.speaking) {
      _mouthController.stop();
      _mouthController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _glowController.dispose();
    _mouthController.dispose();
    super.dispose();
  }

  Color get _stateColor {
    switch (widget.state) {
      case CharacterState.idle:
        return AppColors.accentPrimary;
      case CharacterState.listening:
        return AppColors.accentSecondary;
      case CharacterState.thinking:
        return AppColors.accentPrimary;
      case CharacterState.speaking:
        return AppColors.success;
    }
  }

  String get _stateText {
    switch (widget.state) {
      case CharacterState.idle:
        return 'Ready';
      case CharacterState.listening:
        return 'Listening...';
      case CharacterState.thinking:
        return 'Thinking...';
      case CharacterState.speaking:
        return 'Speaking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarFontSize = widget.size * 0.42;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathingController,
        _glowController,
        _mouthController,
      ]),
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Character with glow effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stateColor.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: _stateColor.withValues(
                        alpha: _glowAnimation.value,
                      ),
                      blurRadius: 30,
                      spreadRadius: widget.state == CharacterState.listening
                          ? 10
                          : 0,
                    ),
                  ],
                ),
                child: Transform.scale(
                  scale: _breathingAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accentColor.withValues(alpha: 0.8),
                          widget.accentColor.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: widget.state == CharacterState.speaking
                            ? _mouthAnimation.value
                            : 1.0,
                        child: Text(
                          widget.tutorAvatar,
                          style: TextStyle(fontSize: avatarFontSize),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: AppSpacing.md),

                // Tutor name
                Text(
                  widget.tutorName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // State indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: _stateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: _stateColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _stateColor,
                          boxShadow: widget.state != CharacterState.idle
                              ? [
                                  BoxShadow(
                                    color: _stateColor.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _stateText,
                        style: TextStyle(
                          color: _stateColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum CharacterState { idle, listening, thinking, speaking }
