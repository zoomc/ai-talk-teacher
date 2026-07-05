import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Conditional import: web gets the real JS bridge, other platforms get
// a stub. The chosen file exports the same `_VersionBridge` class.
import 'version_bridge_stub.dart'
    if (dart.library.js_interop) 'version_bridge_web.dart' as bridge;

/// Bundled app version (from pubspec.yaml `version: 1.0.0+1`).
///
/// We expose it here as a constant rather than pulling in
/// `package_info_plus` to keep the dependency surface small. The
/// `--dart-define=APP_VERSION=...` flag can override it at build time
/// (the build script writes the same value into `web/version.json` so
/// the client + server always agree).
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);

/// State exposed by [VersionService].
class VersionState {
  final String currentVersion;
  final String? serverVersion;
  final DateTime? serverBuildTime;
  final String? serverCommit;
  final bool newVersionAvailable;
  final bool swUpdateWaiting;
  final bool isChecking;

  const VersionState({
    required this.currentVersion,
    this.serverVersion,
    this.serverBuildTime,
    this.serverCommit,
    this.newVersionAvailable = false,
    this.swUpdateWaiting = false,
    this.isChecking = false,
  });

  VersionState copyWith({
    String? serverVersion,
    DateTime? serverBuildTime,
    String? serverCommit,
    bool? newVersionAvailable,
    bool? swUpdateWaiting,
    bool? isChecking,
  }) {
    return VersionState(
      currentVersion: currentVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      serverBuildTime: serverBuildTime ?? this.serverBuildTime,
      serverCommit: serverCommit ?? this.serverCommit,
      newVersionAvailable: newVersionAvailable ?? this.newVersionAvailable,
      swUpdateWaiting: swUpdateWaiting ?? this.swUpdateWaiting,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

/// Compares two semver-style strings of the form `MAJOR.MINOR.PATCH(+BUILD)`.
///
/// Returns a negative number if `a < b`, zero if equal, positive if `a > b`.
/// Build metadata (`+N`) is compared numerically as a tiebreaker — useful
/// for hot-fix pushes that keep the same semver but bump the build.
int compareVersions(String a, String b) {
  final pa = a.split('+');
  final pb = b.split('+');
  final va = pa[0].split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final vb = pb[0].split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final ai = i < va.length ? va[i] : 0;
    final bi = i < vb.length ? vb[i] : 0;
    if (ai != bi) return ai - bi;
  }
  // Tiebreak on build number.
  final ba = pa.length > 1 ? (int.tryParse(pa[1]) ?? 0) : 0;
  final bb = pb.length > 1 ? (int.tryParse(pb[1]) ?? 0) : 0;
  return ba - bb;
}

/// Polls `/version.json` on the server and listens to the SW update bridge
/// exposed by `web/version_check.js`.
///
/// Two complementary signals trigger the "new version" banner:
///   1. Server-side: the version string in `/version.json` is greater than
///      the bundled [kAppVersion] — i.e. a new build was deployed.
///   2. SW-side: the service worker has a new app-shell waiting to
///      activate (`__speakflowUpdate.hasWaitingSW()`).
///
/// On the user's "Update now" tap, [applyUpdate] calls
/// `__speakflowUpdate.forceReload()` which posts `SKIP_WAITING` to the
/// waiting SW and hard-reloads the page.
class VersionService extends StateNotifier<VersionState> {
  VersionService() : super(VersionState(currentVersion: kAppVersion)) {
    _init();
  }

  Timer? _pollTimer;
  bool _disposed = false;

  static const _pollInterval = Duration(minutes: 5);
  // Note: this key stores the *version-update* dismissal (the server-side
  // version string the user chose to dismiss). It's separate from
  // `sf_install_banner_dismissed_v1` in install_prompt_service.dart,
  // which stores the *install-prompt* dismissal. The `sf_version_`
  // prefix makes the ownership unambiguous.
  static const _prefLastDismissed = 'sf_version_last_dismissed';

  Future<void> _init() async {
    // Hook the SW update bridge first so we catch any waiting SW from the
    // very first frame.
    bridge.VersionBridge.onUpdateReady(() {
      if (_disposed) return;
      if (!state.swUpdateWaiting) {
        state = state.copyWith(swUpdateWaiting: true);
      }
    });
    // Then do one immediate version check, followed by periodic polling.
    await checkNow();
    _pollTimer = Timer.periodic(_pollInterval, (_) => checkNow());
    // Pause polling when the tab is hidden and resume on visibility —
    // avoids wasting battery / bandwidth in backgrounded tabs.
    bridge.VersionBridge.onVisibilityChange((visible) {
      if (_disposed) return;
      if (visible) {
        _pollTimer ??= Timer.periodic(_pollInterval, (_) => checkNow());
        // Also fire an immediate check on resume so a deploy that
        // happened while backgrounded surfaces quickly.
        checkNow();
      } else {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }

  /// Fetch `/version.json?ts=<cache-buster>` and compare with bundled version.
  Future<void> checkNow() async {
    if (_disposed) return;
    state = state.copyWith(isChecking: true);
    try {
      final baseUrl = _baseUrl();
      if (baseUrl.isEmpty) {
        // Non-web (mobile/desktop): no server to poll. Skip silently.
        state = state.copyWith(isChecking: false);
        return;
      }
      final uri = Uri.parse(
        '$baseUrl/version.json?ts=${DateTime.now().millisecondsSinceEpoch}',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        // 404 / 5xx — clear server-side state so we don't keep showing a
        // banner for a phantom version from a previous successful poll.
        // Preserve `swUpdateWaiting` (the SW signal is independent of the
        // server's version.json).
        state = state.copyWith(
          serverVersion: null,
          serverBuildTime: null,
          serverCommit: null,
          newVersionAvailable: false,
          isChecking: false,
        );
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final serverVersion = data['version'] as String? ?? '';
      final buildTimeStr = data['buildTime'] as String?;
      final commit = data['commit'] as String?;
      final buildTime =
          buildTimeStr != null ? DateTime.tryParse(buildTimeStr) : null;

      // Don't re-show the banner for a version the user already dismissed.
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_prefLastDismissed);
      final isNew = serverVersion.isNotEmpty &&
          compareVersions(serverVersion, kAppVersion) > 0 &&
          dismissed != serverVersion;

      state = state.copyWith(
        serverVersion: serverVersion.isEmpty ? null : serverVersion,
        serverBuildTime: buildTime,
        serverCommit: commit,
        newVersionAvailable: isNew,
        isChecking: false,
      );
    } catch (_) {
      // Network error / parse error — clear server-side state for the
      // same reason as the 404 path (avoid phantom banners). The next
      // poll will re-populate if the server comes back.
      state = state.copyWith(
        serverVersion: null,
        serverBuildTime: null,
        serverCommit: null,
        newVersionAvailable: false,
        isChecking: false,
      );
    }
  }

  /// The user tapped "Update now". Two cases:
  ///   * Waiting SW already exists → call `forceReload()` which posts
  ///     `SKIP_WAITING` and reloads.
  ///   * No waiting SW yet (server-version bump only) → trigger an
  ///     SW update check, wait (up to 8s) for `onUpdateReady` to fire,
  ///     then reload. Falls through to a reload even if the SW never
  ///     reports back, so the user always gets feedback.
  ///
  /// On non-web platforms this is a no-op (there's no SW to talk to).
  Future<void> applyUpdate() async {
    if (state.swUpdateWaiting) {
      bridge.VersionBridge.forceReload();
      return;
    }
    // No waiting SW yet — kick the SW so it checks for an update, and
    // wait for the bridge to fire `onUpdateReady` (or 8s, whichever
    // comes first) before reloading. This avoids the race where we'd
    // reload before the SW has had time to download the new shell.
    final completer = Completer<void>();
    bridge.VersionBridge.onUpdateReady(() {
      if (!completer.isCompleted) completer.complete();
    });
    bridge.VersionBridge.triggerSwUpdate();
    await completer.future.timeout(const Duration(seconds: 8),
        onTimeout: () {});
    if (_disposed) return;
    bridge.VersionBridge.forceReload();
  }

  /// The user dismissed the banner. For server-version dismissals we
  /// persist the dismissal keyed by the server version string (so a
  /// *newer* future version will re-show the banner). For SW-only
  /// updates there's nothing to persist — the SW is still waiting, but
  /// we suppress the banner for the rest of this session via the
  /// `_swDismissedThisSession` flag (the next page load will re-evaluate
  /// because `hookSW` re-fires `onUpdateReady` on `reg.waiting`).
  bool _swDismissedThisSession = false;

  Future<void> dismissUpdate() async {
    _swDismissedThisSession = true;
    final v = state.serverVersion;
    if (v != null && v.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastDismissed, v);
    }
    state = state.copyWith(
      newVersionAvailable: false,
      // Keep swUpdateWaiting as-is — the SW is still waiting. We
      // suppress the banner via _swDismissedThisSession in the
      // updateAvailableProvider below.
    );
  }

  String _baseUrl() {
    if (!kIsWeb) return '';
    // Use the same origin/path as the document so this works with any
    // `--base-href`. Uri.base on web returns the document URL.
    final base = Uri.base;
    final path = base.path.endsWith('/')
        ? base.path
        : base.path.substring(0, base.path.lastIndexOf('/') + 1);
    final portPart = (base.port != 80 && base.port != 443 && base.port != 0)
        ? ':${base.port}'
        : '';
    return '${base.scheme}://${base.host}$portPart$path';
  }

  /// Whether the user has dismissed the SW-update signal this session.
  /// Read by [updateAvailableProvider] to suppress re-showing the banner.
  bool get isSwDismissedThisSession => _swDismissedThisSession;

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// Riverpod provider. Keep alive so the polling timer survives hot-reload
/// and screen pushes/pops.
final versionServiceProvider =
    StateNotifierProvider<VersionService, VersionState>((ref) {
  return VersionService();
});

/// Convenience: true when *any* update signal is firing (server-version OR
/// waiting SW) AND the user hasn't dismissed the SW signal this session.
/// Used by the `_UpdateBanner` widget.
final updateAvailableProvider = Provider<bool>((ref) {
  final s = ref.watch(versionServiceProvider);
  if (s.newVersionAvailable) return true;
  // SW signal is suppressed if the user dismissed it this session.
  final svc = ref.read(versionServiceProvider.notifier);
  if (s.swUpdateWaiting && !svc.isSwDismissedThisSession) return true;
  return false;
});
