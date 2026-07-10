import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' show platformViewRegistry;

import 'package:flutter/material.dart';

/// Web avatar host.
///
/// Renders the avatar inside an `<iframe>` whose `src` is the bundled
/// `assets/3d/avatar.html` (served same-origin by Flutter web, so the
/// three.js + Ready Player Me GLB pipeline runs in an isolated browsing
/// context). The iframe is registered as an [HtmlElementView] platform view
/// so it composes inside the Flutter widget tree. Dart drives the avatar by
/// `eval`-ing one-liners against the iframe's content window — the HTML
/// exposes a `window.speakflowAvatar` bridge (see avatar.html).
///
/// Same-origin assets mean `contentWindow` is reachable; if anything goes
/// cross-origin the call is swallowed and the caller's painter fallback
/// covers total load failure.
class AvatarHost {
  bool get isSupported => true;

  html.IFrameElement? _iframe;
  String? _viewType;
  bool _disposed = false;

  void init({String? avatarUrl, void Function()? onError}) {
    final base = 'assets/3d/avatar.html';
    final src = avatarUrl == null
        ? base
        : '$base?avatar=${Uri.encodeComponent(avatarUrl)}';
    // Per-instance viewType so multiple avatars don't share one iframe.
    final viewType = 'speakflow-avatar-${identityHashCode(this)}';
    _viewType = viewType;
    platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..allow = 'autoplay';
      _iframe = iframe;
      // iframe-level load failure (asset 404 etc.) → surface to Dart so the
      // caller can switch to the painter fallback. GLB-load failure is
      // detected via isReady() polling instead.
      iframe.onError.listen((_) => onError?.call());
      return iframe;
    });
  }

  void _eval(String expr) {
    if (_disposed) return;
    final cw = _iframe?.contentWindow;
    if (cw == null) return;
    try {
      // dart:js_util is no longer available in current Flutter web builds.
      // The iframe is same-origin, so its JS window can safely evaluate the
      // bridge call through the browser's native eval method.
      (cw as dynamic).eval(expr);
    } catch (_) {
      // Iframe not ready yet, or a rare cross-origin hiccup — ignore. The
      // next state change retries, and the painter fallback covers total
      // load failure.
    }
  }

  void setState(String stateName) => _eval(
    'window.speakflowAvatar&&window.speakflowAvatar.setState(${jsonEncode(stateName)})',
  );
  void setViseme(String visemeName) => _eval(
    'window.speakflowAvatar&&window.speakflowAvatar.setViseme(${jsonEncode(visemeName)})',
  );
  void setGesture(String gestureName) => _eval(
    'window.speakflowAvatar&&window.speakflowAvatar.setGesture(${jsonEncode(gestureName)})',
  );
  void setAudioLevel(double level) => _eval(
    'window.speakflowAvatar&&window.speakflowAvatar.setAudioLevel($level)',
  );

  Future<bool> isReady() async {
    if (_disposed) return false;
    final cw = _iframe?.contentWindow;
    if (cw == null) return false;
    try {
      final bridge = (cw as dynamic).speakflowAvatar;
      if (bridge == null) return false;
      final r = (bridge as dynamic).isReady();
      return r == true;
    } catch (_) {
      return false;
    }
  }

  Widget buildView(
    BuildContext context, {
    required double size,
    required bool showLabel,
    required String tutorName,
  }) {
    if (_viewType == null) return const SizedBox.shrink();
    return HtmlElementView(viewType: _viewType!);
  }

  void dispose() {
    _disposed = true;
    _iframe = null;
    // registerViewFactory is global and has no unregister API; the
    // per-instance viewType (identityHashCode) prevents collisions and the
    // entry is a no-op once the iframe is GC'd.
  }
}
