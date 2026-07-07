/// No-op stub used on non-web platforms. The web build swaps in
/// `browser_language_bridge_web.dart` via the conditional import in
/// `app_localizations.dart` / `main.dart`.
///
/// Returns `null` so callers fall back to the platform dispatcher locale
/// (which on mobile/desktop is the OS language).
class BrowserLanguageBridge {
  /// The browser's preferred language tag (e.g. "zh-CN", "en-US"), or
  /// `null` when not running on the web.
  static String? get preferredLanguageTag => null;
}
