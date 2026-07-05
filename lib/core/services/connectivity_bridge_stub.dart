import 'dart:async';

/// No-op stub used on non-web platforms. The web build swaps in
/// `connectivity_bridge_web.dart` via the conditional import in
/// `connectivity_check.dart`.
class ConnectivityBridge {
  static bool isOnline() => true;
  static Stream<bool> onOnlineStatusChange() {
    // Never emits on non-web — the controller just stays at the initial
    // value (online=true).
    return const Stream<bool>.empty();
  }
}
