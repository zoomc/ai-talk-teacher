import 'package:flutter/foundation.dart';

/// No-op stub used on non-web platforms. The web build swaps in
/// `version_bridge_web.dart` via the conditional import in
/// `version_service.dart`.
class VersionBridge {
  static void onUpdateReady(VoidCallback cb) {}
  static void forceReload() {}
  static void onVisibilityChange(void Function(bool visible) cb) {}
  static void triggerSwUpdate() {}
}
