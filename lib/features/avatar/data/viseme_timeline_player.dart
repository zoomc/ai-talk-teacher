/// Viseme timeline player.
///
/// Drives a [VisemeTimeline] in sync with a TTS audio playback clock. Emits
/// the currently-active viseme + an interpolation fraction (0..1) toward
/// the *next* viseme so consumers can render smooth transitions between
/// consecutive mouth shapes (no hard cuts).
///
/// The player is independent of the audio backend — the caller must invoke
/// [seek] with the current playback position (seconds) on every audio
/// clock tick (e.g. via `just_audio`'s `positionStream` at ~50 ms cadence).
/// This decoupling makes the player trivially unit-testable without a
/// real audio player.
library;

import 'dart:async';

import '../domain/viseme_mapping.dart';
import '../domain/viseme_timeline.dart';

/// Snapshot of the player state at a given playback position.
class VisemeFrame {
  /// Currently active viseme.
  final RhubarbViseme viseme;

  /// Next viseme (or equal to [viseme] when in the final cue).
  final RhubarbViseme nextViseme;

  /// Interpolation fraction from [viseme] toward [nextViseme] (0..1).
  /// 0 means "just entered [viseme]"; 1 means "about to switch to
  /// [nextViseme]". Use [Live2DMouthShape.lerp] to blend the two shapes.
  final double t;

  /// Whether playback has reached the end of the timeline.
  final bool ended;

  const VisemeFrame({
    required this.viseme,
    required this.nextViseme,
    required this.t,
    required this.ended,
  });

  /// Compute the interpolated Live2D mouth shape for this frame.
  /// Used by the avatar renderer when a Live2D model is loaded.
  Live2DMouthShape get mouthShape {
    final a = shapeForViseme(viseme);
    final b = shapeForViseme(nextViseme);
    return a.lerp(b, t);
  }

  /// Compute the painter-fallback [Viseme] for this frame. Used by the
  /// avatar renderer when no Live2D model is loaded. The painter doesn't
  /// support interpolation — it just picks [viseme] when t < 0.5, else
  /// [nextViseme].
  ///
  /// This is fine because the painter's per-frame mouth shapes are simple
  /// geometric forms that read fine without sub-frame interpolation. The
  /// smoothness comes from the 90ms viseme-stepper cadence already in
  /// place.
  ///
  /// NOTE: import via shared widget is intentionally lazy here so this
  /// data file doesn't pull in Flutter.
  String get painterVisemeName =>
      (t < 0.5 ? viseme : nextViseme).name;
}

/// Plays a [VisemeTimeline] in sync with an external audio clock.
///
/// Usage:
///   final player = VisemeTimelinePlayer(timeline);
///   player.start();
///   audioPlayer.positionStream.listen((pos) {
///     final frame = player.sampleAt(pos.inMilliseconds / 1000.0);
///     avatarRenderer.applyFrame(frame);
///   });
///   audioPlayer.playerStateStream.listen((s) {
///     if (s.processingState == ProcessingState.completed) player.stop();
///   });
class VisemeTimelinePlayer {
  VisemeTimeline timeline;

  VisemeTimelinePlayer(this.timeline);

  final StreamController<VisemeFrame> _frameController =
      StreamController<VisemeFrame>.broadcast();

  /// Broadcast stream of [VisemeFrame]s emitted as playback progresses.
  /// Callers should NOT drive this from a timer — they should call
  /// [sampleAt] on each audio position tick and let [sampleAt] push frames.
  Stream<VisemeFrame> get frames => _frameController.stream;

  /// Whether the player is currently active (between [start] and [stop]).
  bool get isActive => _frameController.hasListener && !_ended;

  bool _ended = false;

  /// Mark the player as started. Resets the ended flag.
  void start() {
    _ended = false;
  }

  /// Mark the player as stopped. Subsequent [sampleAt] calls return the
  /// final frame with [VisemeFrame.ended] = true.
  void stop() {
    _ended = true;
    if (!_frameController.isClosed) {
      _frameController.add(VisemeFrame(
        viseme: RhubarbViseme.x,
        nextViseme: RhubarbViseme.x,
        t: 0,
        ended: true,
      ));
    }
  }

  /// Sample the timeline at [timeSeconds]. Returns a [VisemeFrame] for the
  /// current position. When [timeSeconds] is past the timeline end, returns
  /// a silence frame with [VisemeFrame.ended] = true.
  ///
  /// The interpolation fraction `t` ramps linearly over the last 80 ms
  /// before the next cue's start — short enough to feel like a hard cut on
  /// short visemes (which is what real speech does), but smooth enough to
  /// avoid the "stutter" you'd see with a literal step function.
  VisemeFrame sampleAt(double timeSeconds) {
    if (_ended || timeSeconds >= timeline.duration) {
      final frame = VisemeFrame(
        viseme: RhubarbViseme.x,
        nextViseme: RhubarbViseme.x,
        t: 0,
        ended: true,
      );
      if (!_frameController.isClosed) _frameController.add(frame);
      _ended = true;
      return frame;
    }

    final current = timeline.cueAt(timeSeconds);
    final next = timeline.nextCueAfter(timeSeconds);

    final RhubarbViseme nextViseme;
    final double t;
    if (next == null) {
      nextViseme = current.viseme;
      t = 0;
    } else {
      nextViseme = next.viseme;
      final timeUntilNext = next.start - timeSeconds;
      // Ramp over the last 80ms before the next cue.
      const ramp = 0.080;
      t = (1.0 - (timeUntilNext / ramp)).clamp(0.0, 1.0);
    }

    final frame = VisemeFrame(
      viseme: current.viseme,
      nextViseme: nextViseme,
      t: t,
      ended: false,
    );
    if (!_frameController.isClosed) _frameController.add(frame);
    return frame;
  }

  /// Replace the current timeline with a new one. Used when the rhubarb
  /// service returns a fresh analysis for the next TTS audio chunk.
  void replaceTimeline(VisemeTimeline newTimeline) {
    timeline = newTimeline;
    _ended = false;
  }

  /// Dispose the broadcast stream controller. After dispose, [sampleAt]
  /// still works (returns frames) but no longer pushes them.
  void dispose() {
    _frameController.close();
  }
}
