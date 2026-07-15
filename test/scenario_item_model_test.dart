import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';

void main() {
  group('ScenarioItem serialization', () {
    test('toMap and fromMap round-trip preserves fields', () {
      final original = ScenarioItem(
        id: 'item-id-123',
        scenarioId: 'scenario-1',
        expression: 'Could I get the bill, please?',
        translation: '我可以结账吗？',
        audioUrl: 'https://cdn.example.com/bill.mp3',
        practiceType: 'read',
        score: 80,
      );

      final map = original.toMap();
      final restored = ScenarioItem.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.scenarioId, original.scenarioId);
      expect(restored.expression, original.expression);
      expect(restored.translation, original.translation);
      expect(restored.audioUrl, original.audioUrl);
      expect(restored.practiceType, original.practiceType);
      expect(restored.score, original.score);
    });

    test('toMap includes all column keys', () {
      final item = ScenarioItem(
        id: 'item-id-456',
        scenarioId: 'scenario-1',
        expression: 'Hi',
        translation: '你好',
        audioUrl: 'https://cdn.example.com/hi.mp3',
        practiceType: 'respond',
        score: 42,
      );

      final map = item.toMap();

      expect(
        map.keys.toSet(),
        {
          'id',
          'scenario_id',
          'expression',
          'translation',
          'audio_url',
          'practice_type',
          'score',
        },
      );
    });

    test('defaults practiceType to repeat and score to 0', () {
      final item = ScenarioItem(
        id: 'item-id-789',
        scenarioId: 'scenario-1',
        expression: 'See you later',
        translation: '回见',
      );

      expect(item.practiceType, 'repeat');
      expect(item.score, 0);
    });

    test('fromMap tolerates missing optional columns', () {
      final map = {
        'id': 'legacy-id',
        'scenario_id': 'scenario-1',
        'expression': 'A cup of coffee',
      };

      final restored = ScenarioItem.fromMap(map);

      expect(restored.translation, '');
      expect(restored.practiceType, 'repeat');
      expect(restored.score, 0);
    });

    test('copyWith preserves id and scenarioId', () {
      final original = ScenarioItem(
        id: 'item-id-preserve',
        scenarioId: 'scenario-1',
        expression: 'Original expression',
        translation: 'Original translation',
        audioUrl: 'https://cdn.example.com/original.mp3',
        practiceType: 'listen',
        score: 10,
      );

      final copy = original.copyWith(expression: 'Updated expression');

      expect(copy.id, original.id);
      expect(copy.scenarioId, original.scenarioId);
      expect(copy.expression, 'Updated expression');
    });

    test('copyWith clearAudioUrl flag sets audioUrl to null', () {
      final original = ScenarioItem(
        id: 'item-id-clear',
        scenarioId: 'scenario-1',
        expression: 'Hello',
        translation: '你好',
        audioUrl: 'https://cdn.example.com/hello.mp3',
      );

      final cleared = original.copyWith(clearAudioUrl: true);
      expect(cleared.audioUrl, isNull);

      final kept = original.copyWith(expression: 'Hi');
      expect(kept.audioUrl, original.audioUrl);
    });
  });
}
