import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  /// Start recording audio to a writable temp file.
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw RecordingException('Microphone permission not granted');
    }

    // Use a writable directory. The previous code used a relative path
    // ('audio_recording.wav') which fails on most platforms.
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/speakflow_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _currentPath = path;
    _isRecording = true;
  }

  /// Stop recording and return the captured audio bytes.
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;

    // Prefer the path returned by the recorder; fall back to the one we
    // captured at start (some platforms return null even on success).
    final actualPath = path ?? _currentPath;
    _currentPath = null;

    if (actualPath == null) return null;

    final file = File(actualPath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();

    // Clean up the temp file; the bytes are now in memory.
    try {
      await file.delete();
    } catch (_) {
      // Ignore cleanup errors — bytes are still returned to the caller.
    }

    return bytes.isEmpty ? null : bytes;
  }

  /// Cancel current recording and discard audio.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    await _recorder.stop();
    _isRecording = false;
    _currentPath = null;
  }

  /// Dispose resources.
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
