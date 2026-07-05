// Web-only implementation of the install prompt bridge. Talks to
// `web/install_prompt.js` via `dart:js_interop`.
//
// On non-web platforms this file is not compiled in — the conditional
// import in `install_prompt_service.dart` picks the stub instead.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('__speakflowInstall.canPromptNative')
external bool _canPromptNative();

@JS('__speakflowInstall.isIOSSafari')
external bool _isIOSSafari();

@JS('__speakflowInstall.isStandalone')
external bool _isStandalone();

@JS('__speakflowInstall.onAvailabilityChange')
external set _onAvailabilityChange(JSFunction cb);

@JS('__speakflowInstall.promptNative')
external JSPromise<JSString> _promptNative();

class InstallBridge {
  static bool canPromptNative() {
    try {
      return _canPromptNative();
    } catch (_) {
      return false;
    }
  }

  static bool isIOSSafari() {
    try {
      return _isIOSSafari();
    } catch (_) {
      return false;
    }
  }

  static bool isStandalone() {
    try {
      return _isStandalone();
    } catch (_) {
      return false;
    }
  }

  static void onAvailabilityChange(VoidCallback cb) {
    try {
      _onAvailabilityChange = cb.toJS;
    } catch (_) {
      // Bridge absent (e.g. test harness). Ignore.
    }
  }

  static Future<String> promptNative() async {
    try {
      final jsResult = await _promptNative().toDart;
      return jsResult.toDart;
    } catch (_) {
      return 'unavailable';
    }
  }
}
