import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Start recording audio
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw RecordingException('Microphone permission not granted');
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: 'audio_recording.wav',
    );

    _isRecording = true;
  }

  /// Stop recording and return audio data
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;

    if (path == null) return null;

    // Read the file as bytes
    // Note: In a real implementation, we'd read the file
    // For now, return empty bytes as placeholder
    return Uint8List(0);
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    await _recorder.stop();
    _isRecording = false;
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}

class RecordingException implements Exception {
  final String message;
  RecordingException(this.message);

  @override
  String toString() => 'RecordingException: $message';
}
