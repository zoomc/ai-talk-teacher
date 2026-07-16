/// Stub `RhubarbRunner` — selected by the conditional import in
/// [rhubarb_service.dart] when `dart:io` is unavailable (Flutter Web).
///
/// Reports the runner as unavailable so [RhubarbService.analyze]
/// short-circuits with a [RhubarbException] and the caller falls back to
/// the text-driven viseme stepper. The class signature mirrors the
/// `dart:io` implementation (`rhubarb_runner_io.dart`) so the main
/// service can call either via the same `runner.RhubarbRunner` symbol.
library;

import 'dart:typed_data';

import '../domain/viseme_timeline.dart';

/// Result type returned by [RhubarbRunner.run]. Defined in BOTH the stub
/// and the IO runner so the conditional import resolves a single symbol
/// (`runner.RhubarbRunResult`) on every platform.
class RhubarbRunResult {
  final VisemeTimeline? timeline;
  final String? error;

  const RhubarbRunResult({this.timeline, this.error});

  bool get isSuccess => timeline != null;
}

/// Stub runner — every method returns "unavailable" so callers fall back
/// to the text-driven viseme stepper.
class RhubarbRunner {
  bool get available => false;

  String? resolveBinary({String? binaryPath}) => null;

  Future<RhubarbRunResult> run({
    required Uint8List audioBytes,
    String? binaryPath,
    String? dialogFile,
    String? audioHash,
    String formatExtension = 'wav',
  }) async {
    return const RhubarbRunResult(
      error: 'rhubarb binary unavailable on this platform (web)',
    );
  }
}
