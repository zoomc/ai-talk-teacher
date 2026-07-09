import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Glassmorphic container with iOS 26 Liquid Glass effect: backdrop blur +
/// vertical tint gradient + specular rim + depth shadow + pressed/active
/// state + reduce-motion / reduce-transparency graceful degradation.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? glowColor;
  final double blurAmount;
  final VoidCallback? onTap;

  /// Force the "pressed/selected" visual (e.g. for a highlighted card).
  final bool isActive;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.glowColor,
    this.blurAmount = 20,
    this.onTap,
    this.isActive = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    // reduce-motion: skip the (expensive) backdrop blur; accessibleNavigation
    // is a reasonable proxy for "reduce transparency" — users tend to enable
    // both accessibility settings together.
    final reduceMotion = mq.disableAnimations;
    final reduceTransparency = mq.accessibleNavigation;

    final bgBase = isDark ? AppColors.glassBg : AppColors.lightGlassBg;
    final bgActive =
        isDark ? AppColors.glassBgActive : AppColors.lightGlassBgActive;
    final bg = widget.isActive || _pressed ? bgActive : bgBase;
    final border =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final shadow =
        isDark ? AppColors.glassShadow : AppColors.lightGlassShadow;
    final specular =
        isDark ? AppColors.glassSpecular : AppColors.lightGlassSpecular;
    final tint = isDark
        ? AppColors.glassTintGradient
        : AppColors.lightGlassTintGradient;
    final blur = reduceMotion ? 0.0 : widget.blurAmount;
    final radius = BorderRadius.circular(widget.borderRadius);

    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            },
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _pressed = false),
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            // Depth shadow — liquid glass sits above the canvas.
            BoxShadow(
              color: shadow,
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
            if (widget.glowColor != null)
              BoxShadow(
                color: widget.glowColor!.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: -5,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              // 1. Backdrop blur — skipped when reduce-transparency/motion
              //    is on; the more opaque fill below carries the surface.
              if (!reduceTransparency && blur > 0)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              // 2. Base fill + vertical brightness tint.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    gradient: tint,
                    borderRadius: radius,
                  ),
                ),
              ),
              // 3. Specular rim — top-left highlight + bottom-right dim,
              //    simulating the rounded glass edge catching light.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: border, width: 1),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        specular.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.transparent,
                        specular.withValues(alpha: 0.2),
                      ],
                      stops: const [0.0, 0.4, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // 4. Content.
              Padding(
                padding:
                    widget.padding ?? const EdgeInsets.all(AppSpacing.md),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final base = isLight ? AppColors.lightBgTertiary : AppColors.bgTertiary;
    final highlight =
        isLight ? AppColors.lightBgSecondary : AppColors.bgSecondary;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      );
  }
}

/// Glass surface colour for overlay menus/dropdowns (which can't host a
/// real BackdropFilter). Use as `color` on PopupMenuButton /
/// `dropdownColor` on DropdownButtonFormField for a consistent glassy
/// overlay.
Color glassOverlayColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? AppColors.glassBgHover : AppColors.lightGlassBg;
}

/// iOS 26 liquid-glass dialog. Use with showDialog:
///   showDialog(context: ctx, builder: (_) => GlassDialog(...))
class GlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry contentPadding;

  const GlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: GlassCard(
        borderRadius: AppRadius.xl,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleLarge ??
                      const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                  child: title!,
                ),
              ),
            if (content != null)
              Flexible(
                child: Padding(
                  padding: contentPadding,
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium ??
                        const TextStyle(fontSize: 15),
                    child: content!,
                  ),
                ),
              ),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// iOS 26 liquid-glass bottom sheet. Use with showModalBottomSheet:
///   showModalBottomSheet(
///     context: ctx,
///     backgroundColor: Colors.transparent,
///     builder: (_) => GlassBottomSheet(child: ...),
///   )
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: GlassCard(
        borderRadius: 0,
        margin: EdgeInsets.zero,
        padding: padding,
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }
}

/// Refractable aurora background — a soft multi-radial mesh gradient that
/// gives [GlassCard]'s backdrop blur something to refract. Place as the
/// bottom layer inside a Scaffold body (behind your content).
class GlassBackground extends StatelessWidget {
  final Widget? child;

  const GlassBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final a = isLight
        ? AppColors.lightAccentPrimary.withValues(alpha: 0.10)
        : AppColors.accentPrimary.withValues(alpha: 0.22);
    final b = isLight
        ? AppColors.lightAccentSecondary.withValues(alpha: 0.10)
        : AppColors.accentSecondary.withValues(alpha: 0.20);
    final c = isLight
        ? AppColors.lightSuccess.withValues(alpha: 0.08)
        : AppColors.success.withValues(alpha: 0.14);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient:
                  isLight ? AppColors.lightGradientBg : AppColors.gradientBg,
            ),
          ),
        ),
        // Aurora blobs — positioned to peek behind typical card areas so
        // the glass blur has colour to refract.
        Positioned(top: -80, left: -60, child: _blob(a, 260)),
        Positioned(top: 120, right: -80, child: _blob(b, 300)),
        Positioned(bottom: -100, left: 40, child: _blob(c, 280)),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
