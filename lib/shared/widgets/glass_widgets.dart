import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Glassmorphic container with frosted glass effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? glowColor;
  final double blurAmount;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.glowColor,
    this.blurAmount = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            if (glowColor != null)
              BoxShadow(
                color: glowColor!.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: -5,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
            child: Container(
              padding: padding ?? const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.glassBg : AppColors.lightGlassBg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isDark ? AppColors.glassBorder : AppColors.lightGlassBorder,
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glowing action button (e.g., record button)
class GlowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final bool isRecording;

  const GlowButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color = AppColors.accentSecondary,
    this.size = 64,
    this.isRecording = false,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withValues(alpha: 0.8),
                widget.color.withValues(alpha: 0.6),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _glowAnimation.value),
                blurRadius: widget.isRecording ? 30 : 20,
                spreadRadius: widget.isRecording ? 5 : 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.size),
              onTap: widget.onPressed,
              child: Icon(
                widget.icon,
                color: AppColors.textOnAccent,
                size: widget.size * 0.4,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Status pill showing AI state
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool isActive;

  const StatusPill({
    super.key,
    required this.text,
    this.color = AppColors.accentSecondary,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.3 : 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : color.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: TextStyle(
              color: isActive ? color : color.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading effect
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
