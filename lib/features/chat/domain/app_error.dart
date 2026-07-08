/// Maps low-level exceptions thrown by LLM/STT/TTS services into
/// user-facing error descriptions with a suggested action.
///
/// Design goals (workflow E11–E17):
/// - Replace generic `_safeError(e)` SnackBars with a typed [AppError] that
///   carries a localized message key + an action (retry / configure).
/// - Redact API keys from any raw error text before it reaches the UI.
/// - Cover the common failure modes: auth, rate limit, server, timeout,
///   offline, mic permission, empty transcript.
library;

/// What the user can do about the error. Drives the SnackBar action label
/// (or lack thereof).
enum AppErrorAction {
  /// "Open Settings" — for mic permission denied.
  openSettings,
  /// "Configure" — for missing/invalid API config. Routes to /service-config.
  configure,
  /// "Retry" — for transient failures (server, rate limit, timeout, offline).
  retry,
  /// No action — purely informational (e.g. empty transcript).
  none,
}

class AppError {
  /// i18n key under the `error.*` namespace (e.g. 'error.auth').
  final String messageKey;

  /// Optional i18n key for an action button label (e.g. 'error.open_settings').
  final String? actionLabelKey;

  /// What kind of action the UI should offer.
  final AppErrorAction action;

  /// Whether the raw exception text should be appended to the message. True
  /// for server/unknown errors where the detail genuinely helps debugging;
  /// false for auth/rate-limit where the raw text often leaks keys.
  final bool appendDetail;

  const AppError({
    required this.messageKey,
    this.actionLabelKey,
    this.action = AppErrorAction.none,
    this.appendDetail = false,
  });

  /// Map an arbitrary exception to an [AppError]. Inspects the message for
  /// HTTP status codes and common socket/timeout signals so it works across
  /// all three service layers without them needing a shared exception type.
  factory AppError.from(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();

    // Microphone permission — usually surfaced as a platform exception with
    // "permission" in the message.
    if (lower.contains('permission') &&
        (lower.contains('microphone') || lower.contains('mic') || lower.contains('record'))) {
      return const AppError(
        messageKey: 'error.mic_permission',
        actionLabelKey: 'error.open_settings',
        action: AppErrorAction.openSettings,
      );
    }

    // Auth — 401/403 or "invalid api key".
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid api key') ||
        lower.contains('api key')) {
      return const AppError(
        messageKey: 'error.auth',
        actionLabelKey: 'common.configure',
        action: AppErrorAction.configure,
      );
    }

    // Rate limited — 429.
    if (lower.contains('429') || lower.contains('rate limit')) {
      return const AppError(
        messageKey: 'error.rate_limited',
        actionLabelKey: 'common.retry',
        action: AppErrorAction.retry,
      );
    }

    // Timeout.
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        e is StateError && lower.contains('timeout')) {
      return const AppError(
        messageKey: 'error.timeout',
        actionLabelKey: 'common.retry',
        action: AppErrorAction.retry,
      );
    }

    // Offline / socket.
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network') ||
        lower.contains('handshake')) {
      return const AppError(
        messageKey: 'error.offline',
        actionLabelKey: 'common.retry',
        action: AppErrorAction.retry,
      );
    }

    // Server — 5xx.
    if (RegExp(r'5\d\d').hasMatch(lower) ||
        lower.contains('internal server') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      return const AppError(
        messageKey: 'error.server',
        actionLabelKey: 'common.retry',
        action: AppErrorAction.retry,
        appendDetail: true,
      );
    }

    // Fallback — unknown error, surface the detail so the user can report it.
    return AppError(
      messageKey: 'error.server',
      actionLabelKey: 'common.retry',
      action: AppErrorAction.retry,
      appendDetail: true,
    );
  }

  /// Strip anything that looks like an API key from [text] so it never
  /// appears in a SnackBar or log. Matches common sk-/Bearer patterns.
  static String redact(String text) {
    // sk- followed by 10+ word chars.
    var out = text.replaceAll(RegExp(r'sk-[A-Za-z0-9-_]{10,}'), 'sk-****');
    // Bearer <token>
    out = out.replaceAll(RegExp(r'(?i)bearer\s+[A-Za-z0-9-_]{10,}'), 'Bearer ****');
    // dg- / generic 32+ hex keys
    out = out.replaceAll(RegExp(r'[A-Za-z]+-[A-Za-z0-9]{28,}'), '****');
    return out;
  }
}
