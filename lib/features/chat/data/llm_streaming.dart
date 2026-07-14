/// LLM Server-Sent-Events streaming support.
///
/// P1 task 1 — LLM Provider 接口支持 SSE 流式返回，逐字展示 AI 回复降低首字
/// 延迟。 This module provides:
///
/// * [StreamChunk] — a typed chunk emitted by the streamer (delta text,
///   final corrections JSON, or completion signal).
/// * [streamChatCompletion] — parses an OpenAI-compatible SSE byte stream
///   (`text/event-stream`) into a Dart [Stream<StreamChunk>]. The HTTP
///   request itself is issued by the caller (the [LlmService]) so this
///   module stays free of profile/auth concerns and is unit-testable.
///
/// The same parser is reused by the placement AI evaluation flow (task 6),
/// which needs streaming so the radar-chart result feels responsive rather
/// than blocking for ~10s on a non-streaming completion.
library;

import 'dart:async';
import 'dart:convert';

/// A single chunk emitted by the LLM streamer.
class StreamChunk {
  /// Incremental text delta from the model. Empty for non-text events
  /// (e.g. the final corrections JSON or the done signal).
  final String delta;

  /// True once the stream has finished. After this the stream completes;
  /// no further chunks are emitted.
  final bool done;

  /// The raw `corrections` JSON string extracted from the accumulated
  /// content, if present. Emitted on the closing chunk so the caller can
  /// persist corrections without re-parsing the whole reply. Null when the
  /// model didn't emit a corrections block.
  final String? correctionsJson;

  /// Token-usage blob from the final SSE event (when the provider sends
  /// `usage` in the terminating chunk — DeepSeek does, OpenAI does when
  /// `stream_options.include_usage` is set). Null when not provided.
  final Map<String, dynamic>? usage;

  const StreamChunk({
    this.delta = '',
    this.done = false,
    this.correctionsJson,
    this.usage,
  });

  bool get isDelta => delta.isNotEmpty;
}

/// Parse a raw SSE byte stream into typed [StreamChunk]s.
///
/// The [byteStream] is the body of the HTTP response — typically obtained
/// via `request.send()` and `response.stream`. Each `data:` line is decoded
/// as JSON; we extract `choices[0].delta.content` for text deltas and watch
/// for the terminal `[DONE]` sentinel. The accumulated text is scanned for
/// a trailing ```corrections``` JSON block on completion so the caller can
/// persist corrections without a second pass over the full text.
Stream<StreamChunk> streamChatCompletion(Stream<List<int>> byteStream) async* {
  final buffer = StringBuffer();
  // Raw SSE lines can span multiple `List<int>` chunks; we line-buffer them.
  final lineBuffer = StringBuffer();
  String? pendingDataLine;
  await for (final chunk in byteStream) {
    lineBuffer.write(utf8.decode(chunk, allowMalformed: true));
    final text = lineBuffer.toString();
    final lastNewline = text.lastIndexOf('\n');
    if (lastNewline < 0) continue;
    final complete = text.substring(0, lastNewline + 1);
    lineBuffer.clear();
    lineBuffer.write(text.substring(lastNewline + 1));
    for (final rawLine in complete.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        // Blank line marks the end of an SSE event. If we have a pending
        // data line, dispatch it now.
        if (pendingDataLine != null) {
          final chunk = _parseDataLine(pendingDataLine, buffer);
          if (chunk != null) yield chunk;
          pendingDataLine = null;
        }
        continue;
      }
      if (line.startsWith(':')) continue; // SSE comment / heartbeat
      if (line.startsWith('data:')) {
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') {
          yield _finalChunk(buffer);
          return;
        }
        // Multiple `data:` lines in one event are concatenated per spec.
        pendingDataLine = pendingDataLine == null
            ? payload
            : '$pendingDataLine\n$payload';
      }
      // `event:` / `id:` / `retry:` lines are ignored — we only consume
      // `data:` payloads, which is what OpenAI-compatible servers use.
    }
  }
  // Flush any trailing pending event after the stream closes.
  if (pendingDataLine != null) {
    final chunk = _parseDataLine(pendingDataLine, buffer);
    if (chunk != null) yield chunk;
  }
  yield _finalChunk(buffer);
}

StreamChunk? _parseDataLine(String payload, StringBuffer buffer) {
  if (payload.isEmpty) return null;
  dynamic decoded;
  try {
    decoded = jsonDecode(payload);
  } catch (_) {
    return null; // Malformed JSON — skip; the stream is lossy by design.
  }
  if (decoded is! Map<String, dynamic>) return null;
  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty) {
    final choice = choices[0];
    if (choice is Map<String, dynamic>) {
      final delta = choice['delta'];
      if (delta is Map<String, dynamic>) {
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          buffer.write(content);
          return StreamChunk(delta: content);
        }
      }
    }
  }
  // Some providers emit a final chunk with `usage` but no delta.
  final usage = decoded['usage'];
  if (usage is Map<String, dynamic>) {
    return StreamChunk(usage: usage);
  }
  return null;
}

StreamChunk _finalChunk(StringBuffer buffer) {
  final full = buffer.toString();
  final correctionsJson = _extractCorrectionsJson(full);
  return StreamChunk(
    done: true,
    correctionsJson: correctionsJson,
  );
}

/// Pull the trailing ```corrections\n...\n``` block out of the accumulated
/// reply so the caller can persist corrections without re-scanning the text.
String? _extractCorrectionsJson(String content) {
  final regex = RegExp(r'```corrections\s*\n([\s\S]*?)\n```');
  final match = regex.firstMatch(content);
  return match?.group(1);
}

/// Strip fenced JSON blocks from a streamed reply so the UI shows only the
/// natural-language portion. Removes both the ```corrections``` block (emitted
/// by the chat tutor) and the ```placement``` block (emitted by the placement
/// tutor on its final turn). Mirrors [LlmService._cleanResponse] but is
/// exposed for the streaming path which doesn't go through that private
/// method.
String cleanStreamedReply(String content) {
  var cleaned = content;
  cleaned = cleaned.replaceAll(
    RegExp(r'```corrections\s*\n[\s\S]*?\n```'),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'```placement\s*\n[\s\S]*?\n```'),
    '',
  );
  return cleaned.trim();
}
