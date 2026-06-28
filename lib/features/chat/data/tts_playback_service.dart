import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TtsPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  int _fileCounter = 0;

  /// In-memory cache: text key -> audio bytes, to avoid re-writing files.
  static final Map<String, Uint8List> _memCache = {};

  String _keyOf(String text) {
    // Simple stable key: hex of the string hashCode + length, good enough for a
    // local non-cryptographic cache key.
    final h = text.hashCode.toUnsigned(32);
    return '${h.toRadixString(16)}_${text.length}';
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
  Future<void> playCached(String text, Future<Uint8List> Function() synthesize) async {
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

  /// Clean up cached audio files
  Future<void> clearCache() async {
    _memCache.clear();
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (final file in files) {
        if (file is File && (file.path.contains('tts_') || file.path.contains('tts_cache'))) {
          await file.delete();
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}

class TtsPlaybackException implements Exception {
  final String message;
  TtsPlaybackException(this.message);

  @override
  String toString() => 'TtsPlaybackException: $message';
}
