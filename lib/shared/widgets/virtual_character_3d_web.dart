import 'dart:html' as html;
import 'dart:ui_web' show platformViewRegistry;

import 'package:flutter/material.dart';

/// Web avatar host.
///
/// The iframe is an isolated WebGL runtime. Flutter sends only semantic
/// Avatar V2 messages through an origin-checked `postMessage` protocol; the
/// browser runtime owns the GLB, morph targets, animation blending and gaze.
class AvatarHost {
  bool get isSupported => true;

  html.IFrameElement? _iframe;
  String? _viewType;
  bool _disposed = false;
  bool _ready = false;
  final List<Map<String, Object?>> _pending = [];

  void init({String? avatarUrl, void Function()? onError}) {
    final base = 'assets/3d/avatar.html';
    final src = avatarUrl == null
        ? base
        : '$base?avatar=${Uri.encodeComponent(avatarUrl)}';
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
      iframe.onError.listen((_) => onError?.call());
      return iframe;
    });
    html.window.onMessage.listen((event) {
      if (_disposed || event.origin != html.window.location.origin) return;
      if (event.source != _iframe?.contentWindow) return;
      final data = event.data;
      if (data is! Map) return;
      if (data['type'] == 'avatar:ready') {
        _ready = true;
        final queued = List<Map<String, Object?>>.from(_pending);
        _pending.clear();
        for (final message in queued) _post(message);
      } else if (data['type'] == 'avatar:error') {
        onError?.call();
      }
    });
  }

  void _post(Map<String, Object?> message) {
    if (_disposed) return;
    final cw = _iframe?.contentWindow;
    if (cw == null) return;
    cw.postMessage(message, html.window.location.origin);
  }

  void _send(String type, [Map<String, Object?> payload = const {}]) {
    final message = <String, Object?>{'type': type, ...payload};
    if (!_ready) {
      _pending.add(message);
    } else {
      _post(message);
    }
  }

  void setState(String stateName) =>
      _send('avatar:setState', {'state': stateName});

  void setEmotion(String emotionName) =>
      _send('avatar:setEmotion', {'emotion': emotionName});

  void setViseme(String visemeName) =>
      _send('avatar:setViseme', {'viseme': visemeName});

  void setGesture(String gestureName) =>
      _send('avatar:gesture', {'gesture': gestureName});

  void setAudioLevel(double level) =>
      _send('avatar:setAudioLevel', {'level': level});

  Future<bool> isReady() async => !_disposed && _ready;

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
    _ready = false;
    _pending.clear();
    _iframe = null;
  }
}
