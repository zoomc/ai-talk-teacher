import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Mobile/desktop avatar host backed by `webview_flutter`.
///
/// Loads the same bundled `assets/3d/avatar.html` that the web host uses,
/// so the three.js + Ready Player Me GLB pipeline is shared verbatim across
/// platforms. Dart drives the avatar through `runJavaScript` one-liners
/// against the `window.speakflowAvatar` bridge defined in avatar.html.
///
/// `webview_flutter` supports Android, iOS and macOS — covering every
/// non-web target SpeakFlow ships to. The WebView does NOT need microphone
/// permission: TTS audio is played by `just_audio` on the Dart side and the
/// amplitude stream is forwarded here to drive lip-sync, so no extra
/// manifest/Info.plist entries are required.
class AvatarHost {
  bool get isSupported => true;

  WebViewController? _controller;
  bool _disposed = false;
  bool _pageLoaded = false;

  void init({String? avatarUrl, void Function()? onError}) {
    final base = 'assets/3d/avatar.html';
    final src = avatarUrl == null
        ? base
        : '$base?avatar=${Uri.encodeComponent(avatarUrl)}';
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _pageLoaded = true,
          onWebResourceError: (_) => onError?.call(),
        ),
      )
      ..loadFlutterAsset(src);
    _controller = controller;
  }

  Future<void> _run(String expr) async {
    if (_disposed) return;
    final c = _controller;
    if (c == null) return;
    try {
      await c.runJavaScript(expr);
    } catch (_) {
      // Page not ready or JS threw — ignore; the painter fallback covers
      // total load failure (onError), and the next state change retries.
    }
  }

  void setState(String stateName) => _run(
    'window.speakflowAvatar&&window.speakflowAvatar.setState(${_js(stateName)})',
  );
  void setViseme(String visemeName) => _run(
    'window.speakflowAvatar&&window.speakflowAvatar.setViseme(${_js(visemeName)})',
  );
  void setGesture(String gestureName) => _run(
    'window.speakflowAvatar&&window.speakflowAvatar.setGesture(${_js(gestureName)})',
  );
  void setAudioLevel(double level) => _run(
    'window.speakflowAvatar&&window.speakflowAvatar.setAudioLevel($level)',
  );

  Future<bool> isReady() async {
    if (_disposed || !_pageLoaded) return false;
    final c = _controller;
    if (c == null) return false;
    try {
      final r = await c.runJavaScriptReturningResult(
        '!!(window.speakflowAvatar&&window.speakflowAvatar.isReady())',
      );
      // webview_flutter may return a bool, a num (0/1) or a String — normalise.
      if (r is bool) return r;
      if (r is num) return r != 0;
      return r.toString().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  // JSON-encode a string arg so quotes/escapes are safe inside the eval.
  String _js(String s) {
    return '"${s.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n').replaceAll('\r', r'\r')}"';
  }

  Widget buildView(
    BuildContext context, {
    required double size,
    required bool showLabel,
    required String tutorName,
  }) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return WebViewWidget(controller: c);
  }

  void dispose() {
    _disposed = true;
    _controller = null;
  }
}
