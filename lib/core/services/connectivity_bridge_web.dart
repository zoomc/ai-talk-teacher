// Web-only implementation of the connectivity bridge. Uses
// `window.navigator.onLine` + the `online`/`offline` window events.
//
// On non-web platforms this file is not compiled in — the conditional
// import in `connectivity_check.dart` picks the stub instead.

import 'dart:async';
import 'dart:js_interop';

@JS('navigator.onLine')
external bool get _navigatorOnLine;

@JS('addEventListener')
external void _addEventListener(String type, JSFunction cb);

class ConnectivityBridge {
  static bool isOnline() {
    try {
      return _navigatorOnLine;
    } catch (_) {
      return true;
    }
  }

  static Stream<bool> onOnlineStatusChange() {
    final controller = StreamController<bool>.broadcast();
    void handler(JSAny _) {
      controller.add(isOnline());
    }
    final jsHandler = handler.toJS;
    try {
      _addEventListener('online', jsHandler);
      _addEventListener('offline', jsHandler);
    } catch (_) {
      // If we can't bind events, the stream just won't update — initial
      // value is still correct.
    }
    return controller.stream;
  }
}
