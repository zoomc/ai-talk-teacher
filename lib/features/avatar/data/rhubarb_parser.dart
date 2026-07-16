/// Pure-Dart Rhubarb JSON parser.
///
/// Extracted into its own file so both [RhubarbService] (pure Dart, no
/// platform-specific imports) and the dart:io runner
/// (`rhubarb_runner_io.dart`) can call it without a circular dependency.
///
/// Rhubarb's `--machineReadable` JSON shape:
///
/// ```json
/// {
///   "metadata": { "soundFile": "tts.wav", "duration": 4.32 },
///   "mouthCues": [
///     { "start": 0.00, "end": 0.18, "value": "X" },
///     { "start": 0.18, "end": 0.30, "value": "G" }
///   ]
/// }
/// ```
library;

import 'dart:convert';

import '../domain/viseme_mapping.dart';
import '../domain/viseme_timeline.dart';

/// Parse rhubarb's `--machineReadable` JSON output into a [VisemeTimeline].
///
/// Defensive: returns [VisemeTimeline.empty] when the input doesn't match
/// the expected schema. Never throws — the rhubarb runner already wraps the
/// call in try/catch, but exposing a never-throwing parser means callers
/// can use it directly in tests / from cached files without worrying
/// about partial / corrupt data.
VisemeTimeline parseRhubarbJson(String json, {String? audioHash}) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      return VisemeTimeline.empty;
    }

    // Duration: prefer metadata.duration (rhubarb >= 1.10), else fall back
    // to the last mouthCue end, else 0.
    double duration = 0;
    final metadata = decoded['metadata'];
    if (metadata is Map<String, dynamic>) {
      final d = metadata['duration'];
      if (d is num) duration = d.toDouble();
    }

    final cuesRaw = decoded['mouthCues'];
    if (cuesRaw is! List) {
      // No mouthCues → either malformed input or a fully-silent audio.
      // Emit a single silence cue spanning the metadata duration so the
      // player can still drive a "closed" mouth.
      return VisemeTimeline(
        cues: [VisemeCue(start: 0, viseme: RhubarbViseme.x)],
        duration: duration,
        audioHash: audioHash,
      );
    }

    final cues = <VisemeCue>[];
    double lastEnd = 0;
    for (final entry in cuesRaw) {
      if (entry is! Map<String, dynamic>) continue;
      final startRaw = entry['start'];
      final endRaw = entry['end'];
      final valueRaw = entry['value'];
      if (startRaw is! num) continue;
      if (valueRaw is! String) continue;
      cues.add(VisemeCue(
        start: startRaw.toDouble(),
        viseme: RhubarbViseme.fromCode(valueRaw),
      ));
      if (endRaw is num) {
        final e = endRaw.toDouble();
        if (e > lastEnd) lastEnd = e;
      }
    }

    if (cues.isEmpty) {
      return VisemeTimeline(
        cues: [VisemeCue(start: 0, viseme: RhubarbViseme.x)],
        duration: duration > 0 ? duration : lastEnd,
        audioHash: audioHash,
      );
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    // Ensure the first cue starts at 0 (rhubarb always does; defensive).
    if (cues.first.start > 0) {
      cues.insert(0, VisemeCue(start: 0, viseme: RhubarbViseme.x));
    }
    final finalDuration = duration > 0 ? duration : lastEnd;
    return VisemeTimeline(
      cues: cues,
      duration: finalDuration,
      audioHash: audioHash,
    );
  } catch (_) {
    return VisemeTimeline.empty;
  }
}
