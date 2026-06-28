/// Utilities for working with OpenAI-compatible REST endpoints.
///
/// The provider catalog stores base URLs that already include the API version
/// path (e.g. `https://api.deepseek.com/v1`, `https://open.bigmodel.cn/api/paas/v4`).
/// Services append resource paths like `/chat/completions`, `/models`,
/// `/audio/transcriptions`, `/audio/speech`.
///
/// These helpers tolerate base URLs typed by users that may or may not include
/// a version segment, and ensure exactly one slash between the base and the
/// resource path.

/// Normalizes an OpenAI-compatible base URL.
///
/// - Strips trailing slashes.
/// - If the URL does not already end with a version segment (`/v\d+`, which also
///   covers vendor paths like `/api/paas/v4`), appends `/v1` as a best-effort
///   default so that `https://api.deepseek.com` works the same as
///   `https://api.deepseek.com/v1`.
String normalizeOpenAIBaseUrl(String baseUrl) {
  if (baseUrl.isEmpty) return baseUrl;
  var url = baseUrl.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.isEmpty) return url;
  // Already ends with a version segment (e.g. /v1, /v4) → leave alone.
  if (RegExp(r'/v\d+$').hasMatch(url)) return url;
  return '$url/v1';
}

/// Joins a base URL with a resource path, ensuring exactly one slash between them.
String joinEndpoint(String baseUrl, String path) {
  var base = baseUrl;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  var p = path;
  while (p.startsWith('/')) {
    p = p.substring(1);
  }
  return '$base/$p';
}

/// Returns the normalized full endpoint for an OpenAI-compatible resource.
///
/// Example: `openAiEndpoint('https://api.deepseek.com', 'chat/completions')`
/// → `https://api.deepseek.com/v1/chat/completions`.
String openAiEndpoint(String baseUrl, String resourcePath) {
  return joinEndpoint(normalizeOpenAIBaseUrl(baseUrl), resourcePath);
}
