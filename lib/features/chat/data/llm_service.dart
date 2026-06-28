import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/util/openai_endpoint.dart';
import '../../profile/domain/profile_models.dart';
import '../domain/chat_models.dart';

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

    final response = await http.post(
      Uri.parse(openAiEndpoint(profile.baseUrl, 'chat/completions')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${profile.apiKey}',
      },
      body: jsonEncode({
        'model': profile.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1000,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw LlmException('API error: ${response.statusCode} - ${response.body}');
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

  /// Build messages array for the API call.
  List<Map<String, String>> _buildMessages(
    List<ChatMessage> history,
    String systemPrompt,
    String? userMessage,
  ) {
    final messages = <Map<String, String>>[];

    // System prompt with correction instructions
    messages.add({
      'role': 'system',
      'content': '''$systemPrompt

IMPORTANT: When you notice grammar, vocabulary, or pronunciation errors in the student's message, naturally correct them in your response by restating the correct version. Do NOT interrupt the conversation flow.

At the end of your response, if there were any errors, add a JSON block like this:
```corrections
[
  {"original": "what student said", "corrected": "correct version", "type": "grammar|vocabulary|pronunciation", "explanation": "brief explanation"}
]
```

If there were no errors, do not include the corrections block.''',
    });

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
              default:
                type = CorrectionType.grammar;
            }

            corrections.add(Correction(
              original: item['original'] as String,
              corrected: item['corrected'] as String,
              type: type,
              explanation: item['explanation'] as String?,
            ));
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

  /// Fetch available models from the server (OpenAI-compatible /v1/models).
  Future<List<String>> fetchModels() async {
    try {
      final response = await http.get(
        Uri.parse(openAiEndpoint(profile.baseUrl, 'models')),
        headers: {
          'Authorization': 'Bearer ${profile.apiKey}',
        },
      ).timeout(const Duration(seconds: 15));

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
      throw LlmException('Authentication failed (${response.statusCode}). '
          'Check your API key.');
    }
    if (response.statusCode != 200) {
      throw LlmException('Server returned ${response.statusCode}: '
          '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
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

  LlmResponse({
    required this.content,
    required this.corrections,
    this.usage,
  });
}

class LlmUsage {
  final int promptTokens;
  final int completionTokens;

  LlmUsage({
    required this.promptTokens,
    required this.completionTokens,
  });
}

class LlmException implements Exception {
  final String message;
  LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}
