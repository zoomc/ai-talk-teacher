// No-op stub for non-web platforms and as a fallback.
//
// On iOS/Android/macOS, E2E tests are not run via Playwright (they'd use
// Flutter's `integration_test` package). On web without `--dart-define=E2E=true`,
// `kE2E` is `false` and `maybeInit()` returns immediately, so the JS bridge
// is never exposed to the page.

/// Compile-time E2E flag. False unless `--dart-define=E2E=true` is passed.
const bool kE2E = bool.fromEnvironment('E2E', defaultValue: false);

/// No-op E2E bridge for non-web platforms.
///
/// All methods are stubs. On web, `e2e_bridge_web.dart` replaces this with
/// the real implementation that exposes JS hooks.
class E2eBridge {
  /// Called once from `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
  /// On non-web/non-E2E builds, returns immediately.
  static Future<void> maybeInit() async {
    // No-op on non-web platforms.
  }

  /// Called after `runApp()` to expose the `window.speakflowE2E` JS hooks.
  /// No-op on non-web/non-E2E builds.
  static void exposeHooks() {
    // No-op.
  }

  /// Whether the E2E bridge is active (web + E2E flag).
  static bool get isActive => false;
}
