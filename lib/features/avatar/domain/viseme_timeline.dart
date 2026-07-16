/// Viseme timeline data model.
///
/// Represents the output of a single Rhubarb Lip Sync analysis run: a list
/// of `[time, viseme, time, viseme, …]` cues that describe which viseme is
/// active at every moment of the analysed audio. The player (see
/// [VisemeTimelinePlayer]) advances through the timeline in sync with
/// [just_audio] playback and emits the currently-active viseme + an
/// interpolation fraction toward the next one.
library;

import 'viseme_mapping.dart';

/// A single cue: at [start] the active viseme switches to [viseme]. The cue
/// is "held" until the next cue's start time. The end time is derived from
/// the next cue's start (or [VisemeTimeline.duration] for the final cue).
class VisemeCue {
  /// Cue start time in seconds, relative to the audio file's start.
  final double start;

  /// Rhubarb viseme active from this cue's start onward.
  final RhubarbViseme viseme;

  const VisemeCue({required this.start, required this.viseme});

  @override
  String toString() => 'VisemeCue(${start.toStringAsFixed(3)}s, $viseme)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisemeCue &&
          start == other.start &&
          viseme == other.viseme);

  @override
  int get hashCode => Object.hash(start, viseme);
}

/// A complete Rhubarb timeline + its metadata.
///
/// Equality is by reference content: two timelines with identical cues +
/// duration compare equal so tests can assert against a hand-built expected
/// timeline.
class VisemeTimeline {
  /// Time-ordered cue list. The first cue's start is always 0.
  final List<VisemeCue> cues;

  /// Total audio duration in seconds. The final cue is held from its start
  /// to [duration].
  final double duration;

  /// SHA-1 / content hash of the source audio file (Rhosharb emits
  /// `soundFile` + `metadata.soundFile`); used as a cache key by the rhubarb
  /// service so a re-analysis is skipped when the bytes haven't changed.
  final String? audioHash;

  const VisemeTimeline({
    required this.cues,
    required this.duration,
    this.audioHash,
  });

  /// Empty timeline — emits silence for the entire duration. Used as a
  /// fallback when rhubarb analysis fails or is unavailable, so the player
  /// never throws.
  factory VisemeTimeline.silent(double duration) => VisemeTimeline(
        cues: [
          VisemeCue(start: 0, viseme: RhubarbViseme.x),
        ],
        duration: duration,
      );

  /// Empty + zero-duration timeline. Returned by parsers when the input is
  /// malformed beyond recovery.
  static const VisemeTimeline empty = VisemeTimeline(
    cues: [VisemeCue(start: 0, viseme: RhubarbViseme.x)],
    duration: 0,
  );

  /// Whether the timeline carries any non-silence cues.
  bool get hasSpeech =>
      cues.any((c) => c.viseme != RhubarbViseme.x);

  /// Look up the active cue at [timeSeconds]. Returns the silence cue when
  /// [timeSeconds] is past the end (graceful fallback for audio that runs
  /// slightly longer than the rhubarb analysis).
  VisemeCue cueAt(double timeSeconds) {
    if (cues.isEmpty) {
      return const VisemeCue(start: 0, viseme: RhubarbViseme.x);
    }
    // Binary-search would be overkill for typical < 200 cue lists.
    for (var i = cues.length - 1; i >= 0; i--) {
      if (cues[i].start <= timeSeconds) return cues[i];
    }
    return cues.first;
  }

  /// Look up the *next* cue after [timeSeconds], or null when [timeSeconds]
  /// is in the final cue (no transition to interpolate toward).
  VisemeCue? nextCueAfter(double timeSeconds) {
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].start > timeSeconds) return cues[i];
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisemeTimeline &&
          duration == other.duration &&
          _listEq(cues, other.cues));

  static bool _listEq(List<VisemeCue> a, List<VisemeCue> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(duration, Object.hashAll(cues));
}
