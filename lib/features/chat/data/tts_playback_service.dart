import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TtsPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  int _fileCounter = 0;
  // Playback speed applied via just_audio's setSpeed. Defaults to 1.0.
  // Set from the global `tts_speed` user setting before each playback so the
  // user's speed preference (0.75 / 1.0 / 1.25 / 1.5) takes effect without
  // having to re-synthesize audio — the same cached bytes play faster.
  double _speed = 1.0;

  /// In-memory cache: text key -> audio bytes, to avoid re-writing files.
  static final Map<String, Uint8List> _memCache = {};

  String _keyOf(String text) {
    // Combine a 32-bit hashCode with the text length AND a short prefix of
    // the content itself. The prefix makes accidental collisions between
    // two different strings of the same length + hash effectively
    // impossible in practice (the two strings would have to share their
    // first 16 chars too). Stays filesystem-safe for the disk cache.
    final h = text.hashCode.toUnsigned(32);
    final prefix = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final prefixPart = prefix.length > 16 ? prefix.substring(0, 16) : prefix;
    return '${h.toRadixString(16)}_${text.length}_$prefixPart';
  }

  /// Set the playback speed for subsequent plays. Applied immediately to the
  /// player so the currently-playing track (if any) also adjusts.
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    try {
      await _player.setSpeed(speed);
    } catch (_) {
      // setSpeed can throw if no audio source is set yet — ignore, _speed is
      // applied on the next setFilePath via _applySpeed.
    }
  }

  /// Play TTS audio from bytes (uncached path — kept for compatibility).
  Future<void> playAudio(Uint8List audioBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      _fileCounter++;
      final file = File('${tempDir.path}/tts_$_fileCounter.mp3');

      await file.writeAsBytes(audioBytes);

      await player.setFilePath(file.path);
      await player.play();
    } catch (e) {
      throw TtsPlaybackException('Failed to play audio: $e');
    }
  }

  /// Play TTS audio for [text], caching by text hash so repeated playback of
  /// the same AI reply reuses the synthesized bytes/file. [synthesize] should
  /// produce fresh bytes on a cache miss.
  Future<void> playCached(
    String text,
    Future<Uint8List> Function() synthesize,
  ) async {
    try {
      final key = _keyOf(text);
      Uint8List bytes;
      File? file;

      // 1. Memory cache hit?
      if (_memCache.containsKey(key)) {
        bytes = _memCache[key]!;
      } else {
        // 2. Disk cache hit?
        final dir = await getTemporaryDirectory();
        final cacheDir = Directory('${dir.path}/tts_cache');
        if (!cacheDir.existsSync()) {
          cacheDir.createSync(recursive: true);
        }
        file = File('${cacheDir.path}/$key.mp3');
        if (file.existsSync()) {
          bytes = await file.readAsBytes();
        } else {
          // 3. Cache miss — synthesize and persist.
          bytes = await synthesize();
          await file.writeAsBytes(bytes);
        }
        _memCache[key] = bytes;
      }

      // Write bytes to a fresh playback file (just_audio needs a path).
      final tempDir = await getTemporaryDirectory();
      _fileCounter++;
      final playFile = File('${tempDir.path}/tts_play_$_fileCounter.mp3');
      await playFile.writeAsBytes(bytes);

      await player.setFilePath(playFile.path);
      // Apply the user's preferred speed after the source is set (setSpeed
      // before setFilePath is ignored by just_audio on some platforms).
      if (_speed != 1.0) {
        try {
          await player.setSpeed(_speed);
        } catch (_) {
          // Speed adjustment is best-effort — never block playback on it.
        }
      }
      await player.play();
    } catch (e) {
      throw TtsPlaybackException('Failed to play audio: $e');
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    await player.stop();
  }

  /// Pause current playback
  Future<void> pause() async {
    await player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await player.play();
  }

  /// Get the audio player for listening to state changes
  AudioPlayer get player => _player;

  /// Check if currently playing
  bool get isPlaying => player.playing;

  /// Dispose resources
  Future<void> dispose() async {
    await player.dispose();
  }

  /// Clean up cached audio files.
  ///
  /// Recursively deletes the `tts_cache/` directory (disk cache) and any
  /// stray `tts_*.mp3` / `tts_play_*.mp3` playback files in the temp root.
  /// The previous non-recursive `listSync()` left cached files inside
  /// `tts_cache/` on disk forever, defeating "Clear Cache".
  Future<void> clearCache() async {
    _memCache.clear();
    try {
      final tempDir = await getTemporaryDirectory();
      // 1. Wipe the disk cache directory wholesale.
      final cacheDir = Directory('${tempDir.path}/tts_cache');
      if (cacheDir.existsSync()) {
        await cacheDir.delete(recursive: true);
      }
      // 2. Sweep stray playback files in the temp root (tts_1.mp3 etc.).
      for (final entry in tempDir.listSync()) {
        if (entry is File) {
          final name = entry.uri.pathSegments.last;
          if (name.startsWith('tts_') && name.endsWith('.mp3')) {
            try {
              await entry.delete();
            } catch (_) {
              // Best-effort: a file in use can't be deleted, skip it.
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors — cache clearing must never crash the app.
    }
  }
}

class TtsPlaybackException implements Exception {
  final String message;
  TtsPlaybackException(this.message);

  @override
  String toString() => 'TtsPlaybackException: $message';
}
