// Web-only implementation of the browser language bridge. Reads
// `navigator.language` (the user's preferred language tag, e.g.
// "zh-CN", "en-US", "ja-JP").
//
// On non-web platforms this file is not compiled in — the conditional
// import picks the stub instead.

import 'dart:js_interop';

@JS('navigator.language')
external String get _navigatorLanguage;

@JS('navigator.languages')
external JSArray<JSString> get _navigatorLanguages;

class BrowserLanguageBridge {
  /// The browser's preferred language tag, or `null` on any error.
  static String? get preferredLanguageTag {
    try {
      final lang = _navigatorLanguage;
      if (lang.isEmpty) {
        // Some embedded webviews return an empty string — try the
        // `languages` array as a backup.
        final arr = _navigatorLanguages.toDart;
        if (arr.isNotEmpty) return arr.first.toDart;
        return null;
      }
      return lang;
    } catch (_) {
      return null;
    }
  }
}
