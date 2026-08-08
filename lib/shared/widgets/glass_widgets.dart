import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Glassmorphic container with premium Liquid Glass effect: backdrop blur +
/// vertical tint gradient + specular rim + depth shadow + pressed/active
/// state + reduce-motion / reduce-transparency graceful degradation.
///
/// Enhanced v2: richer glow, improved depth, smoother pressed transitions,
/// hover elevation for desktop.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? glowColor;
  final double blurAmount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Force the "pressed/selected" visual (e.g. for a highlighted card).
  final bool isActive;

  /// Show hover lift effect on desktop (subtle scale + glow boost).
  final bool enableHoverEffect;

  /// Outer glow intensity multiplier (1.0 = default).
  final double glowIntensity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.glowColor,
    this.blurAmount = 24,
    this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.enableHoverEffect = true,
    this.glowIntensity = 1.0,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _hovered = false;
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
      value: 0,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovered) {
    if (!widget.enableHoverEffect) return;
    setState(() => _hovered = hovered);
    if (hovered) {
      _pressController.forward();
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final reduceTransparency = MediaQuery.highContrastOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    final bgBase = isDark ? AppColors.glassBg : AppColors.lightGlassBg;
    final bgHover =
        isDark ? AppColors.glassBgHover : AppColors.lightGlassBgHover;
    final bgActive =
        isDark ? AppColors.glassBgActive : AppColors.lightGlassBgActive;
    final bg = widget.isActive || _pressed
        ? bgActive
        : (_hovered ? bgHover : bgBase);
    final border = isDark
        ? (_hovered ? AppColors.glassBorderHover : AppColors.glassBorder)
        : (_hovered
            ? AppColors.lightGlassBorderHover
            : AppColors.lightGlassBorder);
    final shadow =
        isDark ? AppColors.glassShadow : AppColors.lightGlassShadow;
    final tint = isDark
        ? AppColors.glassTintGradient
        : AppColors.lightGlassTintGradient;
    final blur = reduceMotion
        ? 0.0
        : widget.blurAmount * pixelRatio.clamp(1.0, 2.0);
    final radius = BorderRadius.circular(widget.borderRadius);
    final shadowBlur = (28 + (_hovered ? 8 : 0)) * pixelRatio.clamp(1.0, 2.0);
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    final card = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppDurations.fast,
      curve: AppDurations.curveDecelerate,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Depth shadow — liquid glass sits above the canvas.
          BoxShadow(
            color: shadow,
            blurRadius: shadowBlur,
            spreadRadius: _hovered ? -6 : -10,
            offset: Offset(0, _hovered ? 14 : 10),
          ),
          // Ambient glow — boosted on hover/active.
          if (widget.glowColor != null)
            BoxShadow(
              color: widget.glowColor!.withValues(
                alpha: (_pressed
                    ? 0.45
                    : _hovered
                        ? 0.35
                        : 0.2) * widget.glowIntensity,
              ),
              blurRadius: (_hovered ? 28 : 20) * pixelRatio.clamp(1.0, 1.5),
              spreadRadius: _hovered ? -3 : -6,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // 1. Backdrop blur.
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
            // 3. Specular rim.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: border,
                      width: _hovered ? 1.2 : 1,
                    ),
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
    );

    if (!isInteractive) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        onLongPress: widget.onLongPress,
        child: card,
      ),
    );
  }
}

/// Status pill showing AI state — premium v2 with glow dot + refined shape.
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
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isActive ? color : color.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.12 : 0.04),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.25 : 0.08),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ]
            : null,
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
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: textStyle,
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading effect — premium v2 with gradient shimmer + rounded shape.
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
      period: const Duration(milliseconds: 1500),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                  child: SingleChildScrollView(
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
      ),
    );
  }
}

/// iOS 26 liquid-glass bottom sheet. Use with showModalBottomSheet:
///   showModalBottomSheet(
///     context: ctx,
///     backgroundColor: Colors.transparent,
///     isScrollControlled: true,
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
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: padding.vertical / 2,
              bottom: MediaQuery.viewInsetsOf(context).bottom +
                  padding.vertical / 2,
              left: padding.horizontal / 2,
              right: padding.horizontal / 2,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Refractable aurora background — a soft multi-radial mesh gradient that
/// gives [GlassCard]'s backdrop blur something to refract. Place as the
/// bottom layer inside a Scaffold body (behind your content).
///
/// Enhanced v2: richer 4-blob aurora with pink accent, smoother gradients,
/// and depth-aware positioning.
class GlassBackground extends StatelessWidget {
  final Widget? child;

  const GlassBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final size = MediaQuery.sizeOf(context);
    final shortEdge = size.shortestSide;
    final a = isLight
        ? AppColors.lightAccentPrimary.withValues(alpha: 0.08)
        : AppColors.accentPrimary.withValues(alpha: 0.25);
    final b = isLight
        ? AppColors.lightAccentSecondary.withValues(alpha: 0.06)
        : AppColors.accentSecondary.withValues(alpha: 0.22);
    final c = isLight
        ? AppColors.lightAccentTertiary.withValues(alpha: 0.04)
        : AppColors.accentTertiary.withValues(alpha: 0.15);
    final d = isLight
        ? AppColors.lightSuccess.withValues(alpha: 0.04)
        : AppColors.success.withValues(alpha: 0.12);
    // Scale blobs with the screen short edge so they don't dwarf small
    // phones or look tiny on tablets.
    final s = shortEdge * 0.7;
    return Stack(
      children: [
        // Base gradient — deeper, richer dark.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient:
                  isLight ? AppColors.lightGradientBg : AppColors.gradientBg,
            ),
          ),
        ),
        // Aurora blobs — 4-point mesh for richer refraction.
        Positioned(top: -s * 0.35, left: -s * 0.2, child: _blob(a, s * 1.1)),
        Positioned(
          top: s * 0.3,
          right: -s * 0.35,
          child: _blob(b, s * 1.3),
        ),
        Positioned(
          bottom: -s * 0.3,
          left: s * 0.2,
          child: _blob(c, s * 1.0),
        ),
        Positioned(
          bottom: s * 0.1,
          right: s * 0.1,
          child: _blob(d, s * 0.8),
        ),
        // Subtle noise texture overlay for depth.
        if (!isLight)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.03),
              ),
            ),
          ),
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
            colors: [
              color,
              color.withValues(alpha: 0.4),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
