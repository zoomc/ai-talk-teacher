import '../profile_models.dart';
import '../../../chat/data/llm_service.dart';
import '../../../chat/data/stt_service.dart';
import '../../../chat/data/tts_service.dart';

/// Result of a connection probe against a provider.
class ConnectionTestResult {
  final bool ok;
  final String message;
  final int? elapsedMs;
  const ConnectionTestResult({
    required this.ok,
    required this.message,
    this.elapsedMs,
  });
}

/// Shared connection-test helper used by both onboarding and settings
/// so the probe logic lives in one place.
class ConnectionTester {
  ConnectionTester._();

  static Future<ConnectionTestResult> testLlm(LlmProfile profile) async {
    final sw = Stopwatch()..start();
    try {
      final count = await LlmService(profile).testConnection();
      sw.stop();
      return ConnectionTestResult(
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        message:
            '✓ Connected (${sw.elapsedMilliseconds}ms${count > 0 ? ', $count models' : ''})',
      );
    } catch (e) {
      sw.stop();
      return ConnectionTestResult(
        ok: false,
        elapsedMs: sw.elapsedMilliseconds,
        message: _safeError(e),
      );
    }
  }

  static Future<ConnectionTestResult> testStt(SttProfile profile) async {
    final sw = Stopwatch()..start();
    try {
      await SttService(profile).testConnection();
      sw.stop();
      return ConnectionTestResult(
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        message: '✓ Connected (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      sw.stop();
      return ConnectionTestResult(
        ok: false,
        elapsedMs: sw.elapsedMilliseconds,
        message: _safeError(e),
      );
    }
  }

  static Future<ConnectionTestResult> testTts(TtsProfile profile) async {
    final sw = Stopwatch()..start();
    try {
      await TtsService(profile).testConnection();
      sw.stop();
      return ConnectionTestResult(
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        message: '✓ Connected (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      sw.stop();
      return ConnectionTestResult(
        ok: false,
        elapsedMs: sw.elapsedMilliseconds,
        message: _safeError(e),
      );
    }
  }

  static String _safeError(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }
}
