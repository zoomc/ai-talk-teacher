/// Exponential-backoff retry helper shared by STT / TTS / LLM calls.
///
/// P1 reliability pass: every network call retries with a 1 / 2 / 4 / 8 / 16s
/// backoff schedule (5 attempts total). The caller decides what counts as
/// "retryable" via [shouldRetry]; non-retryable failures (auth, mic
/// permission) bubble out immediately so the user isn't kept waiting on a
/// doomed request.
///
/// The UI surface ([RetryProgress]) is exposed so the chat screen can render
/// "重试中… (attempt 2/5)" while a request is being retried, and a final
/// [RetryExhausted] exception carries the last error so the screen can show
/// the real failure reason alongside a manual "Retry" affordance.
library;

import 'dart:async';

/// Schedule of wait durations between retry attempts.
///
/// Per spec: 1 / 2 / 4 / 8 / 16 seconds, for up to 5 attempts. The first
/// attempt is immediate (no leading wait), so [delays] covers the gaps
/// *between* attempts — meaning 5 attempts total produce 4 waits.
const List<Duration> kRetryBackoffDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
];

/// Default maximum number of attempts (1 initial + 4 retries = 5).
const int kRetryMaxAttempts = 5;

/// Thrown when every retry attempt has failed. Carries the last underlying
/// error so the UI can show the real reason rather than a generic "failed".
class RetryExhausted implements Exception {
  final Object lastError;
  final int attempts;
  RetryExhausted(this.lastError, this.attempts);

  @override
  String toString() => 'RetryExhausted after $attempts attempts: $lastError';
}

/// Live progress reported after each failed attempt so the UI can render
/// "重试中… (attempt 2/5)" and the next wait duration.
class RetryProgress {
  /// 1-based index of the attempt that just failed.
  final int failedAttempt;

  /// Total attempts that will be made before giving up.
  final int maxAttempts;

  /// How long the runner will wait before the next attempt. Null when this
  /// is the final failure (no next attempt).
  final Duration? nextWait;

  const RetryProgress({
    required this.failedAttempt,
    required this.maxAttempts,
    this.nextWait,
  });

  /// 1-based index of the upcoming attempt (e.g. "attempt 2/5").
  int get nextAttempt => failedAttempt + 1;

  bool get isFinal => nextWait == null;
}

/// Run [action] with exponential backoff.
///
/// [shouldRetry] inspects the thrown error and decides whether it's
/// retryable. Auth / permission errors typically return false so the user
/// isn't made to wait through 5 doomed attempts. Defaults to "retry
/// everything" when omitted — callers should pass a targeted predicate.
///
/// [onProgress] is invoked after each failed attempt (before the wait) so
/// the UI can update its "retrying…" indicator. It is *not* invoked on the
/// final failure; the caller learns about that via the thrown
/// [RetryExhausted].
///
/// [maxAttempts] caps the total attempts. The default aligns with the spec
/// (5 = 1 initial + 4 retries) and pulls waits from [kRetryBackoffDelays].
/// If a caller passes a larger [maxAttempts], waits beyond the table
/// default to the last entry (16s) so the schedule stays monotonic.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  bool Function(Object error)? shouldRetry,
  void Function(RetryProgress progress)? onProgress,
  int maxAttempts = kRetryMaxAttempts,
  List<Duration> delays = kRetryBackoffDelays,
}) async {
  assert(maxAttempts >= 1);
  final retryPredicate = shouldRetry ?? (_) => true;
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      lastError = e;
      if (!retryPredicate(e) || attempt == maxAttempts) {
        // Non-retryable error OR we just exhausted the last attempt.
        if (attempt == maxAttempts && retryPredicate(e)) {
          throw RetryExhausted(e, attempt);
        }
        rethrow;
      }
      // Schedule the next attempt.
      final delayIndex = attempt - 1;
      final wait = delayIndex < delays.length
          ? delays[delayIndex]
          : delays.last;
      onProgress?.call(RetryProgress(
        failedAttempt: attempt,
        maxAttempts: maxAttempts,
        nextWait: wait,
      ));
      await Future<void>.delayed(wait);
    }
  }
  // Unreachable — the loop either returns or throws. Defensive fallback.
  throw RetryExhausted(lastError ?? StateError('retry loop exited'), maxAttempts);
}

/// Convenience predicate: retry on transient errors, give up immediately on
/// auth / mic-permission failures. Mirrors the [AppError] classification but
/// lives here so service layers don't need to import the UI error mapper.
bool isTransientRetryable(Object error) {
  final raw = error.toString().toLowerCase();
  // Auth — never retry, the key won't fix itself.
  if (raw.contains('401') ||
      raw.contains('403') ||
      raw.contains('unauthorized') ||
      raw.contains('invalid api key')) {
    return false;
  }
  // Mic permission — never retry, needs the user to grant it.
  if (raw.contains('permission') &&
      (raw.contains('microphone') ||
          raw.contains('mic') ||
          raw.contains('record'))) {
    return false;
  }
  // Empty transcript is a soft signal, not a transient failure.
  if (raw.contains('empty') && raw.contains('transcript')) return false;
  return true;
}
