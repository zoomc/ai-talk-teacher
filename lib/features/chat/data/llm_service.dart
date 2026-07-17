import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/util/openai_endpoint.dart';
import '../../profile/domain/profile_models.dart';
import '../domain/chat_models.dart';
import '../domain/session_summary.dart';
import 'llm_streaming.dart';

class LlmService {
  final LlmProfile profile;
  LlmService(this.profile);

  /// Send a chat message and get a response.
  Future<LlmResponse> sendMessage({
    required List<ChatMessage> history,
    required String systemPrompt,
    String? userMessage,
  }) async {
    final messages = _buildMessages(history, systemPrompt, userMessage);

    final response = await http
        .post(
          Uri.parse(openAiEndpoint(profile.baseUrl, 'chat/completions')),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${profile.apiKey}',
          },
          body: jsonEncode({
            'model': profile.model,
            'messages': messages,
            'temperature': 0.7,
            // 400 tokens aligns with the spine's "1–4 sentences per turn"
            // rule (≈80–120 tokens). The previous 1000 was 8–10x over budget
            // and encouraged rambling that violated the spine. 400 leaves
            // headroom for the corrections JSON block at the end.
            'max_tokens': 400,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw LlmException(
        'API error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    // Null-safe response parsing
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw LlmException('No response choices returned from API');
    }
    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String? ?? '';
    if (content.isEmpty) {
      throw LlmException('Empty response from API');
    }

    // Parse corrections from the response
    final corrections = extractCorrections(content);

    return LlmResponse(
      content: _cleanResponse(content),
      corrections: corrections,
      usage: data['usage'] != null
          ? LlmUsage(
              promptTokens: data['usage']['prompt_tokens'] ?? 0,
              completionTokens: data['usage']['completion_tokens'] ?? 0,
            )
          : null,
    );
  }

  /// P1 task 1 — Stream a chat completion via Server-Sent Events.
  ///
  /// Issues the same `chat/completions` POST as [sendMessage] but with
  /// `stream: true` and returns a typed [Stream<StreamChunk>] so the UI can
  /// render AI replies progressively (lower first-token latency). The
  /// trailing ```corrections``` JSON block, if any, is delivered on the
  /// closing chunk via [StreamChunk.correctionsJson] so the caller can
  /// persist corrections without re-parsing the full reply.
  ///
  /// On a non-2xx response the stream emits a single [LlmException] error
  /// and completes — matching the throw-semantics of [sendMessage] so the
  /// retry wrapper (task 3) treats both paths identically.
  Stream<StreamChunk> streamMessage({
    required List<ChatMessage> history,
    required String systemPrompt,
    String? userMessage,
  }) async* {
    final messages = _buildMessages(history, systemPrompt, userMessage);
    final request = http.Request(
      'POST',
      Uri.parse(openAiEndpoint(profile.baseUrl, 'chat/completions')),
    )
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${profile.apiKey}'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'model': profile.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 400,
        'stream': true,
        // Ask OpenAI-compatible providers to include the usage blob on the
        // terminating chunk. Providers that don't understand the field
        // ignore it; those that do let us surface token accounting for free.
        'stream_options': {'include_usage': true},
      });

    final http.Client client;
    final http.StreamedResponse response;
    try {
      client = http.Client();
      response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      // Network/timeout/lookup failure — surface as LlmException so the
      // retry wrapper (which inspects the error type) treats streaming and
      // non-streaming paths identically.
      throw LlmException('Stream request failed: $e');
    }

    if (response.statusCode != 200) {
      final body = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 5))
          .catchError((_) => '');
      client.close();
      throw LlmException(
        'API error: ${response.statusCode} - $body',
      );
    }

    try {
      yield* streamChatCompletion(response.stream);
    } finally {
      client.close();
    }
  }

  /// Build messages array for the API call.
  ///
  /// The system prompt is passed through UNCHANGED. The corrections-JSON
  /// output contract already lives inside the spine produced by
  /// [TutorPromptBuilder.build] — appending it again here (as the previous
  /// implementation did) duplicated ~180 tokens every turn and sometimes
  /// contradicted the spine. Passing the prompt through verbatim also keeps
  /// it byte-identical across turns, which lets providers with prefix prompt
  /// caching (e.g. DeepSeek) reuse the cached system segment.
  List<Map<String, String>> _buildMessages(
    List<ChatMessage> history,
    String systemPrompt,
    String? userMessage,
  ) {
    final messages = <Map<String, String>>[];

    // System prompt (correction instructions + JSON contract already inside).
    messages.add({'role': 'system', 'content': systemPrompt});

    // Chat history
    for (final msg in history) {
      messages.add({
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    // Current user message
    if (userMessage != null) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    return messages;
  }

  /// Extract corrections from the response.
  List<Correction> extractCorrections(String content) {
    final corrections = <Correction>[];

    // Find corrections JSON block
    final regex = RegExp(r'```corrections\s*\n([\s\S]*?)\n```');
    final match = regex.firstMatch(content);

    if (match != null) {
      try {
        final jsonStr = match.group(1)!;
        final List<dynamic> list = jsonDecode(jsonStr);

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            CorrectionType type;
            switch (item['type'] as String?) {
              case 'grammar':
                type = CorrectionType.grammar;
                break;
              case 'vocabulary':
                type = CorrectionType.vocabulary;
                break;
              case 'pronunciation':
                type = CorrectionType.pronunciation;
                break;
              case 'fluency':
                type = CorrectionType.fluency;
                break;
              default:
                type = CorrectionType.grammar;
            }

            // S5/S6 v7 — parse the skill tag. Trim + lower-case the
            // kebab-case form so the same mistake maps to the same skill
            // id across turns even when the LLM varies capitalisation.
            // Empty / whitespace-only strings become null so the mastery
            // roll-up doesn't create a "" skill bucket.
            final rawSkill = item['skill'] as String?;
            final skill = rawSkill == null
                ? null
                : (rawSkill.trim().isEmpty ? null : rawSkill.trim());

            corrections.add(
              Correction(
                original: item['original'] as String,
                corrected: item['corrected'] as String,
                type: type,
                explanation: item['explanation'] as String?,
                // Phase-1 P0 #4: the LLM assigns each error an importance
                // score (0-100). Clamp + default so a malformed value can't
                // corrupt the review ordering; missing falls back to 50.
                importance: _parseImportance(item['importance']),
                skill: skill,
              ),
            );
          }
        }
      } catch (e) {
        // Log parsing error - response still returned, just without corrections
        debugPrint('Warning: Failed to parse corrections block: $e');
      }
    }

    return corrections;
  }

  /// Remove the corrections block from the response.
  String _cleanResponse(String content) {
    final regex = RegExp(r'```corrections\s*\n[\s\S]*?\n```');
    return content.replaceAll(regex, '').trim();
  }

  /// Parse the LLM-emitted `importance` field into a clamped 0-100 int.
  ///
  /// Accepts int or num (e.g. `82` or `82.0`). Returns the model default
  /// (50) when missing or unparseable so review ordering stays sensible
  /// even when an older / non-compliant model omits the field.
  int _parseImportance(dynamic value) {
    if (value is int) {
      return value.clamp(0, 100);
    }
    if (value is num) {
      return value.toInt().clamp(0, 100);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed.clamp(0, 100);
    }
    return 50;
  }

  /// Phase-1 P0 #5 — generate a post-class summary for a finished session.
  ///
  /// Sends the conversation transcript + the corrections flagged during it
  /// to the LLM with a prompt that asks for a strict JSON shape (highlights,
  /// exactly three improvements, one next-sentence). The summary screen
  /// renders the result; on any parse / network failure we throw so the
  /// caller can show a retry affordance.
  Future<SessionSummary> generateSummary({
    required String sessionId,
    required List<ChatMessage> history,
    required List<Correction> corrections,
  }) async {
    final transcript = StringBuffer();
    for (final m in history) {
      transcript.writeln('${m.role.name}: ${m.content}');
    }
    final correctionList = corrections.isEmpty
        ? '(none flagged this session)'
        : corrections
            .map((c) => '- "${c.original}" → "${c.corrected}" (${c.type.name})')
            .join('\n');

    final systemPrompt = '''You are an English speaking coach. The student just 
finished a conversation. Produce a concise post-class summary as STRICT JSON with 
exactly these keys:
- "highlights": 1-2 short sentences on what the student did well.
- "improvements": an array of EXACTLY 3 concrete, prioritised improvement points 
(one short sentence each, most important first).
- "next_sentence": ONE ready-to-use English sentence the student can try in their 
next conversation, tailored to the weaknesses above.
Return ONLY the JSON object, no markdown fence, no commentary.''';

    final userPrompt =
        'Conversation transcript:\n$transcript\n\nCorrections flagged:\n$correctionList';

    final response = await http
        .post(
          Uri.parse(openAiEndpoint(profile.baseUrl, 'chat/completions')),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${profile.apiKey}',
          },
          body: jsonEncode({
            'model': profile.model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.5,
            // Summaries are short — keep the budget tight to stay fast + cheap.
            'max_tokens': 500,
            // Ask for JSON mode if the provider supports it; providers that
            // don't will ignore the field rather than error.
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw LlmException(
        'Summary API error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw LlmException('No response choices returned from summary API');
    }
    final content =
        (choices[0]['message'] as Map<String, dynamic>?)?['content'] as String? ??
            '';
    if (content.trim().isEmpty) {
      throw LlmException('Empty summary response');
    }

    return _parseSummary(content, sessionId);
  }

  /// Parse the LLM's summary JSON, tolerating an accidental ```json fence.
  SessionSummary _parseSummary(String raw, String sessionId) {
    String text = raw.trim();
    // Strip a markdown fence if the model added one despite being told not to.
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final improvements = <String>[];
    final list = decoded['improvements'];
    if (list is List) {
      for (final item in list) {
        if (item is String) improvements.add(item.trim());
      }
    }
    // Pad / trim to exactly 3 so the UI contract ("3 improvement points")
    // holds even when the model returns 2 or 4.
    while (improvements.length < 3) {
      improvements.add('');
    }
    if (improvements.length > 3) {
      improvements.removeRange(3, improvements.length);
    }

    return SessionSummary(
      sessionId: sessionId,
      highlights: (decoded['highlights'] as String?)?.trim() ?? '',
      improvements: improvements,
      nextSentence: (decoded['next_sentence'] as String?)?.trim() ?? '',
    );
  }

  /// Fetch available models from the server (OpenAI-compatible /v1/models).
  Future<List<String>> fetchModels() async {
    try {
      final response = await http
          .get(
            Uri.parse(openAiEndpoint(profile.baseUrl, 'models')),
            headers: {'Authorization': 'Bearer ${profile.apiKey}'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final models = <String>[];

      if (data['data'] is List) {
        for (final model in data['data']) {
          if (model is Map<String, dynamic> && model['id'] is String) {
            models.add(model['id'] as String);
          }
        }
      }

      return models;
    } catch (e) {
      return [];
    }
  }

  /// Test connectivity + credentials. Returns the model count on success,
  /// throws [LlmException] with a helpful message on failure.
  Future<int> testConnection() async {
    final response = await http
        .get(
          Uri.parse(openAiEndpoint(profile.baseUrl, 'models')),
          headers: {'Authorization': 'Bearer ${profile.apiKey}'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw LlmException(
        'Authentication failed (${response.statusCode}). '
        'Check your API key.',
      );
    }
    if (response.statusCode != 200) {
      throw LlmException(
        'Server returned ${response.statusCode}: '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
    }

    final data = jsonDecode(response.body);
    int count = 0;
    if (data['data'] is List) {
      count = (data['data'] as List).length;
    }
    return count;
  }
}

class LlmResponse {
  final String content;
  final List<Correction> corrections;
  final LlmUsage? usage;

  LlmResponse({required this.content, required this.corrections, this.usage});
}

class LlmUsage {
  final int promptTokens;
  final int completionTokens;

  LlmUsage({required this.promptTokens, required this.completionTokens});
}

class LlmException implements Exception {
  final String message;
  LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}
