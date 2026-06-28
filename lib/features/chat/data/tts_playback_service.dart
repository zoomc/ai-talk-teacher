import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TtsPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  int _fileCounter = 0;

  /// Play TTS audio from bytes
  Future<void> playAudio(Uint8List audioBytes) async {
    try {
      // Save audio to temp file
      final tempDir = await getTemporaryDirectory();
      _fileCounter++;
      final file = File('${tempDir.path}/tts_$_fileCounter.mp3');

      await file.writeAsBytes(audioBytes);

      // Play the audio
      await player.setFilePath(file.path);
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
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('tts_')) {
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
