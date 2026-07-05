import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/install_prompt_service.dart';
import '../../core/services/version_service.dart';
import '../../core/theme/app_colors.dart';

/// Routes where banners should never appear — these are first-run /
/// full-screen flows with no AppBar where an install/update banner
/// would block the primary CTA.
const _kHiddenRoutes = <String>{
  '/onboarding',
  '/placement',
};

/// Wraps the app so the [MaterialApp.router] is overlaid with two
/// non-blocking banners:
///   * [_UpdateBanner] — a new server version / SW update is available.
///   * [_InstallBanner] — PWA install prompt / iOS "Add to Home Screen".
///
/// Implementation: rather than painting on top of the AppBar (which
/// would block its taps), we measure the banners' height with a
/// post-frame callback and inject that height into the child's
/// `MediaQuery.padding.top`. The Scaffold inside the child then shifts
/// its AppBar down to clear the banner, so taps land on the AppBar
/// instead of the banner overlay.
///
/// Banners are also suppressed on first-run routes (onboarding,
/// placement) — see [_kHiddenRoutes].
class AppBanners extends ConsumerStatefulWidget {
  final Widget child;
  const AppBanners({super.key, required this.child});

  @override
  ConsumerState<AppBanners> createState() => _AppBannersState();
}

class _AppBannersState extends ConsumerState<AppBanners> {
  double _bannerHeight = 0;

  void _onBannerColumnSizeChanged(Size size) {
    final newHeight = size.height;
    if ((newHeight - _bannerHeight).abs() > 0.5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _bannerHeight = newHeight);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showUpdate = ref.watch(updateAvailableProvider);
    final showInstall = ref.watch(shouldShowInstallBannerProvider);

    // Route-aware suppression: hide banners entirely on first-run /
    // full-screen routes that have no AppBar. `GoRouterState.of` throws
    // when AppBanners is rendered outside the router subtree (e.g.
    // during very first frame before the router has attached), so we
    // guard with try/catch — on failure we treat the route as unknown
    // and don't suppress (the safe default — better to show a banner
    // than to crash).
    String route;
    try {
      route = GoRouterState.of(context).uri.path;
    } catch (_) {
      route = '';
    }
    final hiddenRoute = _kHiddenRoutes.any(route.startsWith);

    final showUpdateBanner = showUpdate && !hiddenRoute;
    final showInstallBanner = showInstall && !hiddenRoute;
    final showAny = showUpdateBanner || showInstallBanner;

    final mq = MediaQuery.of(context);
    // When banners are visible, push the Scaffold's top inset down by
    // the measured banner height so the AppBar isn't covered.
    final padded = showAny && _bannerHeight > 0
        ? mq.copyWith(
            padding: mq.padding.copyWith(
              top: mq.padding.top + _bannerHeight,
            ),
          )
        : mq;

    return Stack(
      children: [
        MediaQuery(
          data: padded,
          child: widget.child,
        ),
        if (showAny)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _MeasureSize(
                onSizeChanged: _onBannerColumnSizeChanged,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showUpdateBanner) const _UpdateBanner(),
                    if (showInstallBanner) const _InstallBanner(),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Measures the size of [child] via a custom RenderObject that reports
/// its size during layout (no post-frame callback, no rebuild churn).
/// Used by `AppBanners` to reserve space via MediaQuery padding.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSizeChanged;
  const _MeasureSize({
    required Widget child,
    required this.onSizeChanged,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeReporter(onSizeChanged: onSizeChanged);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderSizeReporter renderObject) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter({required this.onSizeChanged});
  ValueChanged<Size> onSizeChanged;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final size = this.size;
    if (_last != size) {
      _last = size;
      // Schedule a microtask so we don't mutate state during layout.
      scheduleMicrotask(() => onSizeChanged(size));
    }
  }
}

/// Banner shown when a new server version is detected OR the SW has a
/// waiting update. Tap "Update" to force a reload.
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(versionServiceProvider);
    final service = ref.read(versionServiceProvider.notifier);
    // Don't show the version arrow for SW-only updates (no server version).
    // `VersionService.checkNow` already normalizes empty → null, so the
    // isNotEmpty half would be redundant.
    final detail = state.serverVersion != null
        ? ' ${state.currentVersion} → ${state.serverVersion}'
        : '';
    final message = state.swUpdateWaiting
        ? 'A new version is ready to install.'
        : 'A new version of SpeakFlow is available.';
    return _BannerCard(
      icon: Icons.system_update_alt_rounded,
      iconColor: AppColors.accentSecondary,
      message: '$message$detail',
      actionLabel: 'Update',
      onAction: () => service.applyUpdate(),
      onDismiss: () => service.dismissUpdate(),
    );
  }
}

/// Banner shown when the app is openable as a PWA. Two variants:
///   * Native install prompt (Chrome/Edge/Android) — "Install" button
///     triggers `beforeinstallprompt`.
///   * iOS Safari — "Show steps" opens a bottom sheet with the actual
///     Share → Add to Home Screen walkthrough (no programmatic install
///     on iOS, so the banner must teach the user how to install).
class _InstallBanner extends ConsumerWidget {
  const _InstallBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(installPromptServiceProvider);
    final service = ref.read(installPromptServiceProvider.notifier);
    if (state.canPromptNative) {
      return _BannerCard(
        icon: Icons.add_to_home_screen_rounded,
        iconColor: AppColors.success,
        message: 'Install SpeakFlow for offline access.',
        actionLabel: 'Install',
        onAction: () async {
          final accepted = await service.promptInstall();
          if (!accepted) {
            // Treat dismiss as "don't nag me again" — same as the X.
            await service.dismiss();
          }
        },
        onDismiss: () => service.dismiss(),
      );
    }
    // iOS Safari variant — banner stays short; "Show steps" opens a
    // modal bottom sheet with the actual A2HS walkthrough.
    return _BannerCard(
      icon: Icons.ios_share_rounded,
      iconColor: AppColors.accentSecondary,
      message: 'Add SpeakFlow to Home Screen for offline use.',
      actionLabel: 'Show steps',
      onAction: () => _showIosA2HsSheet(context, onDismiss: service.dismiss),
      onDismiss: () => service.dismiss(),
    );
  }

  void _showIosA2HsSheet(BuildContext context, {required VoidCallback onDismiss}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.ios_share_rounded,
                        color: AppColors.accentSecondary, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Add to Home Screen',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _A2HsStep(
                  n: 1,
                  text: 'Tap the Share icon in Safari\'s toolbar.',
                ),
                _A2HsStep(
                  n: 2,
                  text: 'Scroll the share sheet and tap "Add to Home Screen".',
                ),
                _A2HsStep(
                  n: 3,
                  text: 'Tap "Add" — SpeakFlow will appear on your Home Screen '
                      'and work offline like a native app.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Not now'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onDismiss();
                        },
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _A2HsStep extends StatelessWidget {
  final int n;
  final String text;
  const _A2HsStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single banner card with icon, message, action button, and dismiss (X).
///
/// Layout is fixed at one row (message `maxLines: 1` with ellipsis) so
/// the banner height is predictable — important because the parent
/// `AppBanners` reserves that height via MediaQuery padding.
class _BannerCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _BannerCard({
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: iconColor.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  // 2 lines so the version detail "1.0.0+1 → 1.0.1+2"
                  // doesn't truncate on iPhone SE (320pt). The parent
                  // _MeasureSize already supports height changes via the
                  // RenderProxyBox reporter, so growing to 2 lines is
                  // safe and the MediaQuery padding injection below
                  // updates automatically.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ActionButton(
                label: actionLabel,
                color: iconColor,
                onTap: onAction,
              ),
              const SizedBox(width: AppSpacing.xs),
              _DismissButton(onTap: onDismiss),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms)
        .slideY(begin: -0.18, end: 0, duration: 220.ms);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          // 44pt min touch target per iOS HIG (was 32 — under spec).
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                // Pick a contrasting text color: white on dark accents
                // (purple/cyan/green all read well at this size).
                color: _isLight(color) ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.06,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Rough luminance check — if the accent color is bright (success
  /// green, cyan), use black text; otherwise (purple) use white.
  bool _isLight(Color c) {
    return c.computeLuminance() > 0.5;
  }
}

/// 44×44 dismiss (X) button. The visual icon is 16pt but the tap area
/// meets the iOS HIG minimum.
class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        onTap: onTap,
        child: const Center(
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
