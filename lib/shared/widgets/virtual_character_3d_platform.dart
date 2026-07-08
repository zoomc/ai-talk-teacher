import 'package:flutter/material.dart';

/// Default (stub) avatar host.
///
/// This file is the fallback target of the conditional import in
/// [VirtualCharacter3D] and is only selected when *neither*
/// `dart:js_interop` (web) nor `dart:io` (mobile/desktop) is available —
/// which does not happen on any supported Flutter target. It exists so the
/// analyzer resolves the `platform.AvatarHost` symbol on every configuration.
///
/// Every method reports the host as unsupported so the caller falls back to
/// the [VirtualCharacter] painter.
class AvatarHost {
  bool get isSupported => false;

  void init({String? avatarUrl, void Function()? onError}) {}

  void setState(String stateName) {}

  void setViseme(String visemeName) {}

  void setGesture(String gestureName) {}

  void setAudioLevel(double level) {}

  Future<bool> isReady() async => false;

  Widget buildView(
    BuildContext context, {
    required double size,
    required bool showLabel,
    required String tutorName,
  }) =>
      const SizedBox.shrink();

  void dispose() {}
}
