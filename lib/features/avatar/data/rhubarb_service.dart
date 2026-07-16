/// Rhubarb Lip Sync service — public API for Phase 3 task 2.
///
/// Runs the rhubarb binary against TTS audio bytes (via a conditional-import
/// runner that's a no-op stub on Flutter Web), parses the JSON timeline,
/// and caches the result by audio-hash so repeated playback of the same TTS
/// bytes skips the analysis round-trip.
///
/// On Flutter Web (or any platform where the rhubarb binary is missing),
/// [isAvailable] returns false and [analyze] throws [RhubarbException] —
/// callers should catch this and fall back to the text-driven viseme
/// stepper in [VirtualCharacter.visemeForChar] (which is what the chat
/// screen already does today).
library;

import 'dart:typed_data';

import '../domain/viseme_timeline.dart';
import 'rhubarb_parser.dart' as parser;
import 'rhubarb_runner_stub.dart'
    if (dart.library.io) 'rhubarb_runner_io.dart' as runner;

/// Exception thrown by [RhubarbService] when analysis fails (binary missing,
/// non-zero exit, malformed JSON, …). Callers should catch this and fall
/// back to a [VisemeTimeline.silent] or the text-driven viseme stepper.
class RhubarbException implements Exception {
  final String message;
  RhubarbException(this.message);

  @override
  String toString() => 'RhubarbException: $message';
}

/// Rhubarb Lip Sync service — runs the CLI binary + caches results.
///
/// Instances are cheap — the timeline cache is static so a single cache is
/// shared across all [RhubarbService] instances within the isolate.
class RhubarbService {
  /// Optional override for the rhubarb binary path. When null, the runner
  /// looks up `rhubarb` on the system PATH.
  final String? binaryPath;

  /// Optional dialog file path passed to `--dialogFile`. Rhubarb supports a
  /// text transcript that improves recognition accuracy; usually null for
  /// TTS audio (the spoken text is known precisely via the LLM reply).
  final String? dialogFile;

  /// Lazily-constructed runner. Built once per service instance so the
  /// availability probe is memoised.
  runner.RhubarbRunner? _runner;

  RhubarbService({this.binaryPath, this.dialogFile});

  runner.RhubarbRunner get _impl => _runner ??= runner.RhubarbRunner();

  /// Static cache: audio hash → analysed timeline. Bounded to
  /// [_maxCacheEntries] so a long session doesn't grow unbounded.
  static final Map<String, VisemeTimeline> _cache = {};
  static const int _maxCacheEntries = 32;

  /// Whether the rhubarb binary is reachable on this platform. Cheap to
  /// call — the runner memoises internally so the probe runs only once even
  /// when [analyze] is called repeatedly.
  bool get isAvailable => _impl.available;

  /// Resolve the rhubarb binary path (used by [isAvailable]'s probe +
  /// exposed for tests). Returns null when not found.
  String? resolveBinary() => _impl.resolveBinary(binaryPath: binaryPath);

  /// Analyse [audioBytes] (WAV or any format rhubarb accepts) and return the
  /// resulting viseme timeline.
  ///
  /// Throws [RhubarbException] when:
  ///   - rhubarb is not available ([isAvailable] returns false)
  ///   - rhubarb exits non-zero (corrupt audio, OOM)
  ///   - the JSON output can't be parsed (unexpected schema)
  ///
  /// On success, the timeline is cached under [audioHash] (when provided) so
  /// repeated playback of the same TTS bytes skips the analysis round-trip.
  Future<VisemeTimeline> analyze(
    Uint8List audioBytes, {
    String? audioHash,
    String? formatExtension,
  }) async {
    if (audioHash != null) {
      final cached = _cache[audioHash];
      if (cached != null) return cached;
    }

    if (!isAvailable) {
      throw RhubarbException(
        'rhubarb binary not available on this platform',
      );
    }

    final result = await _impl.run(
      audioBytes: audioBytes,
      binaryPath: binaryPath,
      dialogFile: dialogFile,
      audioHash: audioHash,
      formatExtension: formatExtension ?? 'wav',
    );

    if (!result.isSuccess) {
      throw RhubarbException(result.error ?? 'unknown rhubarb failure');
    }

    final timeline = result.timeline!;
    if (audioHash != null) {
      _storeCache(audioHash, timeline);
    }
    return timeline;
  }

  /// Parse a previously-saved rhubarb JSON file into a [VisemeTimeline]
  /// without invoking the binary. Useful for tests + for replaying a cached
  /// analysis from disk. Re-exports [parser.parseRhubarbJson] under the
  /// service's namespace so callers only need one import line.
  static VisemeTimeline parseRhubarbJson(String json, {String? audioHash}) =>
      parser.parseRhubarbJson(json, audioHash: audioHash);

  static void _storeCache(String key, VisemeTimeline timeline) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = timeline;
  }

  /// Clear the in-memory timeline cache. Used by the settings "Clear Cache"
  /// action so the user can force a re-analysis after swapping the rhubarb
  /// binary.
  static void clearCache() => _cache.clear();
}
