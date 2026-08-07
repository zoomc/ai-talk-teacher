import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:webview_flutter/webview_flutter.dart';

/// Mobile/desktop avatar host backed by `webview_flutter`.
///
/// Loads the same bundled `assets/3d/avatar.html` that the web host uses,
/// so the three.js + self-hosted GLB pipeline is shared verbatim across
/// platforms. Dart drives the avatar through the same typed postMessage
/// protocol used by the web iframe.
///
/// `webview_flutter` supports Android, iOS and macOS — covering every
/// non-web target SpeakFlow ships to. The WebView does NOT need microphone
/// permission: TTS audio is played by `just_audio` on the Dart side and the
/// exact bytes are forwarded for local HeadAudio analysis; amplitude is only
/// a compatibility fallback, so no extra manifest/Info.plist entries are
/// required.
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

  void setState(String stateName) =>
      _post('avatar:setState', 'state', stateName);
  void setEmotion(String emotionName) =>
      _post('avatar:setEmotion', 'emotion', emotionName);
  void setViseme(String visemeName) =>
      _post('avatar:setViseme', 'viseme', visemeName);
  void setGesture(String gestureName) =>
      _post('avatar:gesture', 'gesture', gestureName);
  void setAudioLevel(double level) => _run(
    'window.postMessage({type:"avatar:setAudioLevel",level:$level},"*")',
  );

  void setSpeechAudio(Uint8List bytes, {DateTime? startedAt}) => _run(
    'window.postMessage({type:"avatar:speakAudio",audioBase64:${_js(base64Encode(bytes))},startedAtMs:${startedAt?.millisecondsSinceEpoch ?? 'null'}},"*")',
  );

  void clearSpeechAudio() =>
      _run('window.postMessage({type:"avatar:stopSpeechAudio"},"*")');

  void _post(String type, String key, String value) =>
      _run('window.postMessage({type:${_js(type)},$key:${_js(value)}},"*")');

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

  // JSON-encode a string arg so quotes/escapes are safe in the message.
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
    _run('window.postMessage({type:"avatar:dispose"},"*")');
    _disposed = true;
    _controller = null;
  }
}
