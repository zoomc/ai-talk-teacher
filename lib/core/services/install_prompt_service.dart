import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'install_bridge_stub.dart'
    if (dart.library.js_interop) 'install_bridge_web.dart' as bridge;

/// State exposed by [InstallPromptService].
class InstallPromptState {
  /// Native PWA install prompt is available (Chrome/Edge/Android).
  final bool canPromptNative;

  /// User is on iOS Safari — no programmatic prompt, show A2HS instructions.
  final bool isIOSSafari;

  /// App is already running in standalone (installed) mode — hide banner.
  final bool isStandalone;

  /// User dismissed the install banner before — don't show again (until a
  /// version bump resets the dismissal).
  final bool hasDismissed;

  /// Has the app been opened for at least 30s in this session — we wait
  /// before showing the banner so first-time visitors aren't ambushed.
  final bool hasDelayedEnough;

  /// The platform doesn't support install at all (mobile app, desktop).
  final bool platformUnsupported;

  const InstallPromptState({
    required this.canPromptNative,
    required this.isIOSSafari,
    required this.isStandalone,
    required this.hasDismissed,
    required this.hasDelayedEnough,
    this.platformUnsupported = false,
  });

  /// Should the install banner be shown?
  bool get shouldShowBanner {
    if (platformUnsupported) return false;
    if (isStandalone) return false;
    if (hasDismissed) return false;
    if (!hasDelayedEnough) return false;
    return canPromptNative || isIOSSafari;
  }

  InstallPromptState copyWith({
    bool? canPromptNative,
    bool? isIOSSafari,
    bool? isStandalone,
    bool? hasDismissed,
    bool? hasDelayedEnough,
    bool? platformUnsupported,
  }) {
    return InstallPromptState(
      canPromptNative: canPromptNative ?? this.canPromptNative,
      isIOSSafari: isIOSSafari ?? this.isIOSSafari,
      isStandalone: isStandalone ?? this.isStandalone,
      hasDismissed: hasDismissed ?? this.hasDismissed,
      hasDelayedEnough: hasDelayedEnough ?? this.hasDelayedEnough,
      platformUnsupported: platformUnsupported ?? this.platformUnsupported,
    );
  }
}

const _kPrefDismissedInstall = 'sf_install_banner_dismissed_v1';
const _kShowBannerAfter = Duration(seconds: 30);

/// Captures `beforeinstallprompt` (Chrome/Edge/Android) and detects iOS
/// Safari so the Dart side can show a branded "Install SpeakFlow" banner.
///
/// On non-web platforms the service reports `platformUnsupported=true`
/// and the banner is hidden — install only makes sense for the web build.
class InstallPromptService extends StateNotifier<InstallPromptState> {
  InstallPromptService() : super(const InstallPromptState(
          canPromptNative: false,
          isIOSSafari: false,
          isStandalone: false,
          hasDismissed: false,
          hasDelayedEnough: false,
        )) {
    _init();
  }

  Timer? _delayTimer;

  Future<void> _init() async {
    // Non-web: nothing to do. Mark unsupported so the banner is hidden.
    if (!kIsWeb) {
      state = state.copyWith(platformUnsupported: true);
      return;
    }

    // Persisted dismissal.
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_kPrefDismissedInstall) ?? false;

    final isStandalone = bridge.InstallBridge.isStandalone();
    final isIOSSafari = bridge.InstallBridge.isIOSSafari();
    final canPrompt = bridge.InstallBridge.canPromptNative();

    state = state.copyWith(
      canPromptNative: canPrompt,
      isIOSSafari: isIOSSafari,
      isStandalone: isStandalone,
      hasDismissed: dismissed,
    );

    // Listen for future availability changes (e.g. beforeinstallprompt
    // firing later in the session).
    bridge.InstallBridge.onAvailabilityChange(() {
      if (!mounted) return;
      state = state.copyWith(
          canPromptNative: bridge.InstallBridge.canPromptNative());
    });

    // 30s delay before showing — only matters for first-time visitors who
    // haven't engaged with the app yet.
    _delayTimer = Timer(_kShowBannerAfter, () {
      if (!mounted) return;
      state = state.copyWith(hasDelayedEnough: true);
    });

    // If the app is already installed, the user might still be in a
    // browser tab — but the install banner should never show once
    // standalone mode is detected.
    if (isStandalone) {
      _delayTimer?.cancel();
      state = state.copyWith(hasDelayedEnough: false);
    }
  }

  /// Trigger the native install prompt (Chrome/Edge/Android). Must be
  /// called from a user gesture. Returns true if the user accepted.
  Future<bool> promptInstall() async {
    if (!kIsWeb) return false;
    if (!state.canPromptNative) return false;
    final result = await bridge.InstallBridge.promptNative();
    return result == 'accepted';
  }

  /// User dismissed the banner — remember so we don't nag them again.
  Future<void> dismiss() async {
    state = state.copyWith(hasDismissed: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefDismissedInstall, true);
  }

  /// Reset the persisted dismissal so the install banner can show again.
  /// Wired up from the Settings screen ("Show install banner again") so
  /// users who dismissed by mistake have an undo path.
  Future<void> resetDismissal() async {
    state = state.copyWith(hasDismissed: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefDismissedInstall);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }
}

final installPromptServiceProvider =
    StateNotifierProvider<InstallPromptService, InstallPromptState>((ref) {
  return InstallPromptService();
});

/// Convenience: true when the install banner should be visible.
final shouldShowInstallBannerProvider = Provider<bool>((ref) {
  return ref.watch(installPromptServiceProvider).shouldShowBanner;
});
