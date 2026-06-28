import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/data/llm_service.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';
import 'package:speakflow/features/profile/domain/profile_models.dart';

void main() {
  late LlmService service;
  setUp(() {
    service = LlmService(LlmProfile(
      name: 'test',
      baseUrl: 'https://example.com',
      apiKey: 'sk-test',
      model: 'test-model',
    ));
  });

  group('LlmService.extractCorrections', () {
    test('returns empty list when no corrections block present', () {
      final result = service.extractCorrections('Hello! How are you today?');
      expect(result, isEmpty);
    });

    test('parses a single grammar correction', () {
      const content = '''That's a great question!

```corrections
[
  {"original": "I goes", "corrected": "I go", "type": "grammar", "explanation": "Subject-verb agreement"}
]
```''';
      final result = service.extractCorrections(content);
      expect(result.length, 1);
      expect(result[0].original, 'I goes');
      expect(result[0].corrected, 'I go');
      expect(result[0].type, CorrectionType.grammar);
      expect(result[0].explanation, 'Subject-verb agreement');
    });

    test('parses multiple corrections of different types', () {
      const content = '''Nice work!

```corrections
[
  {"original": "he don't", "corrected": "he doesn't", "type": "grammar", "explanation": null},
  {"original": "bigly", "corrected": "a lot", "type": "vocabulary", "explanation": "informal word"},
  {"original": "colonel", "corrected": "kernel", "type": "pronunciation", "explanation": "silent l"}
]
```''';
      final result = service.extractCorrections(content);
      expect(result.length, 3);
      expect(result[0].type, CorrectionType.grammar);
      expect(result[0].explanation, isNull);
      expect(result[1].type, CorrectionType.vocabulary);
      expect(result[2].type, CorrectionType.pronunciation);
    });

    test('defaults unknown type to grammar', () {
      const content = '''```corrections
[
  {"original": "x", "corrected": "y", "type": "unknown_type", "explanation": null}
]
```''';
      final result = service.extractCorrections(content);
      expect(result.length, 1);
      expect(result[0].type, CorrectionType.grammar);
    });

    test('returns empty list on malformed JSON', () {
      const content = '''```corrections
[not valid json]
```''';
      final result = service.extractCorrections(content);
      expect(result, isEmpty);
    });

    test('skips non-map items in the list', () {
      const content = '''```corrections
[
  "not a map",
  {"original": "a", "corrected": "b", "type": "grammar", "explanation": null}
]
```''';
      final result = service.extractCorrections(content);
      expect(result.length, 1);
      expect(result[0].original, 'a');
    });
  });
}
