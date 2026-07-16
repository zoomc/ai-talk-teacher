/// `dart:io` implementation of [RhubarbRunner] — selected by the
/// conditional import in [rhubarb_service.dart] on every Flutter target
/// that has `dart:io` (mobile / desktop). Not compiled on Flutter Web.
///
/// Locates the rhubarb binary via [binaryPath] (override) or the system
/// PATH (`which rhubarb` on POSIX, `where rhubarb.exe` on Windows), runs
/// it against a temp file containing the TTS audio bytes, and parses the
/// JSON stdout into a [VisemeTimeline] via [parseRhubarbJson].
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../domain/viseme_timeline.dart';
import 'rhubarb_parser.dart';

/// Mirrors the stub `RhubarbRunResult` exactly (same symbol name + field
/// names) so the main service's conditional import resolves on every
/// platform.
class RhubarbRunResult {
  final VisemeTimeline? timeline;
  final String? error;

  const RhubarbRunResult({this.timeline, this.error});

  bool get isSuccess => timeline != null;
}

/// Real `dart:io` rhubarb runner. Mirrors [RhubarbRunner] in the stub so
/// the conditional-import namespace `runner.RhubarbRunner` resolves on both
/// web and IO targets.
class RhubarbRunner {
  /// Memoised availability probe so the per-isolate cost is one PATH lookup.
  bool? _availableCached;
  String? _binaryCached;

  bool get available {
    if (_availableCached != null) return _availableCached!;
    final bin = resolveBinary();
    if (bin == null) {
      _availableCached = false;
      return false;
    }
    try {
      final result = Process.runSync(bin, ['--version']);
      _availableCached = result.exitCode == 0;
      _binaryCached = bin;
    } catch (_) {
      _availableCached = false;
    }
    return _availableCached!;
  }

  /// Look up the rhubarb binary path: explicit [binaryPath] first, else
  /// `which rhubarb` (POSIX) or `where rhubarb.exe` (Windows). Returns null
  /// when no candidate is found.
  String? resolveBinary({String? binaryPath}) {
    if (binaryPath != null && binaryPath.isNotEmpty) return binaryPath;
    if (_binaryCached != null) return _binaryCached;
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = Process.runSync(
        cmd,
        [Platform.isWindows ? 'rhubarb.exe' : 'rhubarb'],
      );
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return null;
      return out.split(Platform.isWindows ? '\r\n' : '\n').first.trim();
    } catch (_) {
      return null;
    }
  }

  Future<RhubarbRunResult> run({
    required Uint8List audioBytes,
    String? binaryPath,
    String? dialogFile,
    String? audioHash,
    String formatExtension = 'wav',
  }) async {
    final bin = resolveBinary(binaryPath: binaryPath);
    if (bin == null) {
      return const RhubarbRunResult(
        error: 'rhubarb binary not found on PATH',
      );
    }

    final ext = formatExtension.toLowerCase();
    final tempFile = File(
      '${Directory.systemTemp.path}/rhubarb_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );

    try {
      await tempFile.writeAsBytes(audioBytes, flush: true);
      final args = <String>[
        '--machineReadable',
        '--quiet',
        if (dialogFile != null) ...['--dialogFile', dialogFile],
        tempFile.path,
      ];
      final result = await Process.run(bin, args);
      if (result.exitCode != 0) {
        return RhubarbRunResult(
          error: 'rhubarb exited ${result.exitCode}: ${result.stderr}',
        );
      }
      final stdout = result.stdout;
      if (stdout is! String) {
        return RhubarbRunResult(
          error: 'rhubarb produced non-string output: ${stdout.runtimeType}',
        );
      }
      final timeline = parseRhubarbJson(stdout, audioHash: audioHash);
      return RhubarbRunResult(timeline: timeline);
    } catch (e) {
      return RhubarbRunResult(error: 'rhubarb run failed: $e');
    } finally {
      try {
        if (tempFile.existsSync()) await tempFile.delete();
      } catch (_) {
        // best-effort cleanup
      }
    }
  }
}
