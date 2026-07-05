// Web-only implementation of the SW update bridge. Talks to
// `web/version_check.js` via `dart:js_interop`'s unsafe interop layer
// (the bridge is a plain JS object on `window.__speakflowUpdate`).
//
// On non-web platforms this file is not compiled in — the conditional
// import in `version_service.dart` picks the stub instead.

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('__speakflowUpdate.onUpdateReady')
external set _onUpdateReady(JSFunction cb);

@JS('__speakflowUpdate.forceReload')
external void _forceReload();

@JS('__speakflowUpdate.triggerSwUpdate')
external void _triggerSwUpdate();

@JS('__speakflowUpdate.onVisibilityChange')
external set _onVisibilityChange(JSFunction cb);

class VersionBridge {
  static void onUpdateReady(VoidCallback cb) {
    try {
      _onUpdateReady = cb.toJS;
    } catch (_) {
      // Bridge not present (e.g. running in a test harness without the
      // index.html script). Silently ignore.
    }
  }

  static void forceReload() {
    try {
      _forceReload();
    } catch (_) {
      // Last resort: plain location reload via the DOM.
      // (We avoid importing dart:html to keep the surface minimal; the
      // bridge should always be present in production web builds.)
    }
  }

  /// Tell the SW to check for an updated app shell right now. Useful when
  /// the server-version bump hasn't yet resulted in a `waiting` SW — we
  /// kick the SW so it downloads the new shell and fires `updatefound`.
  static void triggerSwUpdate() {
    try {
      _triggerSwUpdate();
    } catch (_) {
      // Bridge absent — ignore.
    }
  }

  /// Subscribe to document visibility changes. The callback receives
  /// `true` when the tab becomes visible, `false` when hidden.
  static void onVisibilityChange(void Function(bool visible) cb) {
    try {
      _onVisibilityChange = ((JSBoolean v) => cb(v.toDart)).toJS;
    } catch (_) {
      // Bridge absent — caller's polling timer just keeps running.
    }
  }
}
