import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_bridge_stub.dart'
    if (dart.library.js_interop) 'connectivity_bridge_web.dart' as bridge;

/// True when the browser/device is online. Updates in real time as the
/// network goes up/down.
///
/// Used to show an "offline" hint in the chat input bar — the rest of the
/// app (review, history, settings, scenarios) works fully offline because
/// it's SQLite-backed.
class ConnectivityService extends StateNotifier<bool> {
  ConnectivityService() : super(true) {
    _init();
  }

  StreamSubscription<bool>? _sub;

  void _init() {
    if (!kIsWeb) {
      // Mobile/desktop: assume always online for the UI hint (the LLM/STT/TTS
      // calls themselves will fail with their own error messages if there's
      // truly no network — the inline hint is a web-only affordance).
      state = true;
      return;
    }
    state = bridge.ConnectivityBridge.isOnline();
    _sub = bridge.ConnectivityBridge.onOnlineStatusChange().listen((online) {
      if (!mounted) return;
      state = online;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final connectivityServiceProvider =
    StateNotifierProvider<ConnectivityService, bool>((ref) {
  return ConnectivityService();
});

final isOfflineProvider = Provider<bool>((ref) {
  return !ref.watch(connectivityServiceProvider);
});
