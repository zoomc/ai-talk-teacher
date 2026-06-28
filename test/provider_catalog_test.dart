import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/profile/domain/provider_catalog.dart';

void main() {
  group('LlmProviderCatalog', () {
    test('exposes a custom entry as the fallback id', () {
      expect(LlmProviderCatalog.customId, 'custom');
      final custom = LlmProviderCatalog.byId(LlmProviderCatalog.customId);
      expect(custom.id, 'custom');
    });

    test('byId returns the matching provider for known ids', () {
      final deepseek = LlmProviderCatalog.byId('deepseek');
      expect(deepseek.id, 'deepseek');
      expect(deepseek.defaultBaseUrl, 'https://api.deepseek.com/v1');
      expect(deepseek.region, ProviderRegion.cn);
      expect(deepseek.kind, ProviderKind.openaiCompatible);
    });

    test('byId falls back to custom for unknown ids', () {
      final unknown = LlmProviderCatalog.byId('does_not_exist');
      expect(unknown.id, 'custom');
    });

    test('all entries have a non-empty id and display name', () {
      for (final p in LlmProviderCatalog.all) {
        expect(p.id, isNotEmpty);
        expect(p.displayName, isNotEmpty);
        expect(p.defaultBaseUrl, isNotEmpty);
      }
    });

    test('all entries are OpenAI-compatible (LLM catalog constraint)', () {
      for (final p in LlmProviderCatalog.all) {
        expect(p.kind, ProviderKind.openaiCompatible,
            reason: '${p.id} should be openaiCompatible');
      }
    });

    test('every catalog id is unique', () {
      final ids = LlmProviderCatalog.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('SttProviderCatalog', () {
    test('byId returns matching STT provider', () {
      final deepgram = SttProviderCatalog.byId('deepgram');
      expect(deepgram.id, 'deepgram');
      expect(deepgram.kind, ProviderKind.vendor);
    });

    test('openai_whisper is OpenAI-compatible', () {
      final whisper = SttProviderCatalog.byId('openai_whisper');
      expect(whisper.kind, ProviderKind.openaiCompatible);
      expect(whisper.defaultModel, 'whisper-1');
    });

    test('falls back to custom for unknown id', () {
      expect(SttProviderCatalog.byId('zzz').id, 'custom');
    });

    test('every catalog id is unique', () {
      final ids = SttProviderCatalog.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('TtsProviderCatalog', () {
    test('byId returns matching TTS provider', () {
      final fish = TtsProviderCatalog.byId('fish_audio');
      expect(fish.id, 'fish_audio');
    });

    test('openai_tts has a built-in voice list', () {
      final openai = TtsProviderCatalog.byId('openai_tts');
      expect(openai.voices, isNotEmpty);
      expect(openai.voices, contains('alloy'));
      expect(openai.voices, contains('shimmer'));
    });

    test('falls back to custom for unknown id', () {
      expect(TtsProviderCatalog.byId('zzz').id, 'custom');
    });

    test('every catalog id is unique', () {
      final ids = TtsProviderCatalog.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every CN-region provider has a non-empty docs url', () {
      for (final p in TtsProviderCatalog.all) {
        if (p.region == ProviderRegion.cn) {
          expect(p.docsUrl, isNotEmpty, reason: '${p.id} missing docs URL');
        }
      }
    });
  });

  group('ProviderDef defaults', () {
    test('apiKeyRequired defaults to true', () {
      const def = ProviderDef(
        id: 'x',
        displayName: 'X',
        defaultBaseUrl: 'https://x',
        docsUrl: 'https://x',
      );
      expect(def.apiKeyRequired, isTrue);
    });

    test('kind defaults to openaiCompatible', () {
      const def = ProviderDef(
        id: 'x',
        displayName: 'X',
        defaultBaseUrl: 'https://x',
        docsUrl: 'https://x',
      );
      expect(def.kind, ProviderKind.openaiCompatible);
    });

    test('region defaults to global', () {
      const def = ProviderDef(
        id: 'x',
        displayName: 'X',
        defaultBaseUrl: 'https://x',
        docsUrl: 'https://x',
      );
      expect(def.region, ProviderRegion.global);
    });
  });
}
