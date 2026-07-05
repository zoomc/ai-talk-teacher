import 'package:flutter/foundation.dart';

/// No-op stub used on non-web platforms. The web build swaps in
/// `install_bridge_web.dart` via the conditional import in
/// `install_prompt_service.dart`.
class InstallBridge {
  static bool canPromptNative() => false;
  static bool isIOSSafari() => false;
  static bool isStandalone() => false;
  static void onAvailabilityChange(VoidCallback cb) {}
  static Future<String> promptNative() async => 'unavailable';
}
