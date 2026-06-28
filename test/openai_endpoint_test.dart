import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/core/util/openai_endpoint.dart';

void main() {
  group('normalizeOpenAIBaseUrl', () {
    test('returns empty string unchanged', () {
      expect(normalizeOpenAIBaseUrl(''), '');
    });

    test('appends /v1 when no version segment present', () {
      expect(
        normalizeOpenAIBaseUrl('https://api.deepseek.com'),
        'https://api.deepseek.com/v1',
      );
    });

    test('does not append /v1 when /v1 already present', () {
      expect(
        normalizeOpenAIBaseUrl('https://api.openai.com/v1'),
        'https://api.openai.com/v1',
      );
    });

    test('does not append /v1 when /v4 (vendor path) present', () {
      expect(
        normalizeOpenAIBaseUrl('https://open.bigmodel.cn/api/paas/v4'),
        'https://open.bigmodel.cn/api/paas/v4',
      );
    });

    test('strips trailing slashes before deciding', () {
      expect(
        normalizeOpenAIBaseUrl('https://api.deepseek.com/'),
        'https://api.deepseek.com/v1',
      );
      expect(
        normalizeOpenAIBaseUrl('https://api.openai.com/v1///'),
        'https://api.openai.com/v1',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        normalizeOpenAIBaseUrl('  https://api.deepseek.com  '),
        'https://api.deepseek.com/v1',
      );
    });

    test('handles pure-whitespace input', () {
      expect(normalizeOpenAIBaseUrl('   '), '');
    });
  });

  group('joinEndpoint', () {
    test('joins base and path with a single slash', () {
      expect(
        joinEndpoint('https://api.openai.com/v1', 'chat/completions'),
        'https://api.openai.com/v1/chat/completions',
      );
    });

    test('collapses duplicate slashes at the boundary', () {
      expect(
        joinEndpoint('https://api.openai.com/v1/', '/chat/completions'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        joinEndpoint('https://api.openai.com/v1///', '///chat/completions'),
        'https://api.openai.com/v1/chat/completions',
      );
    });
  });

  group('openAiEndpoint', () {
    test('normalizes base then joins resource path', () {
      expect(
        openAiEndpoint('https://api.deepseek.com', 'chat/completions'),
        'https://api.deepseek.com/v1/chat/completions',
      );
      expect(
        openAiEndpoint('https://api.openai.com/v1', 'models'),
        'https://api.openai.com/v1/models',
      );
    });

    test('tolerates user-typed URL with extra trailing slashes', () {
      expect(
        openAiEndpoint('https://api.deepseek.com/v1/', 'audio/speech'),
        'https://api.deepseek.com/v1/audio/speech',
      );
    });

    test('works with vendor-style version paths', () {
      expect(
        openAiEndpoint('https://open.bigmodel.cn/api/paas/v4', 'chat/completions'),
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
    });
  });
}
