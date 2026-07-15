import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/teacher_persona.dart';

void main() {
  group('TeacherPersona serialization', () {
    test('toMap and fromMap round-trip preserves fields', () {
      final original = TeacherPersona(
        id: 'persona-id-123',
        name: 'Mr. Sterling',
        style: 'strict',
        temp: 0.4,
        promptTemplate: 'You are {scenario_prompt}',
      );

      final map = original.toMap();
      final restored = TeacherPersona.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.style, original.style);
      expect(restored.temp, original.temp);
      expect(restored.promptTemplate, original.promptTemplate);
    });

    test('toMap column keys', () {
      final persona = TeacherPersona(
        id: 'persona-id-456',
        name: 'Coach',
        style: 'encourage',
        temp: 0.7,
        promptTemplate: 'Be warm: {scenario_prompt}',
      );

      final map = persona.toMap();

      expect(
        map.keys.toSet(),
        {'id', 'name', 'style', 'temp', 'prompt_template'},
      );
    });

    test('fromMap defaults temp to 0.7 when missing', () {
      final map = {
        'id': 'persona-id-789',
        'name': 'Joker',
        'style': 'humor',
        'prompt_template': 'Laugh: {scenario_prompt}',
      };

      final restored = TeacherPersona.fromMap(map);

      expect(restored.temp, 0.7);
    });

    test('copyWith updates only specified fields', () {
      final original = TeacherPersona(
        id: 'persona-id-copy',
        name: 'Mr. Sterling',
        style: 'strict',
        temp: 0.4,
        promptTemplate: 'You are {scenario_prompt}',
      );

      final copy = original.copyWith(style: 'humor', temp: 0.9);

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.style, 'humor');
      expect(copy.temp, 0.9);
      expect(copy.promptTemplate, original.promptTemplate);
    });
  });

  group('renderSystemPrompt', () {
    test('replaces scenario_prompt placeholder with the scenario prompt', () {
      final persona = TeacherPersona(
        id: 'persona-render-1',
        name: 'Mr. Sterling',
        style: 'strict',
        temp: 0.4,
        promptTemplate: 'Persona\n\n{scenario_prompt}\n\nRules',
      );

      final result = persona.renderSystemPrompt('Be a waiter');

      expect(result.contains('Be a waiter'), isTrue);
      expect(result.contains('{scenario_prompt}'), isFalse);
    });

    test('empty or null scenario prompt leaves no placeholder', () {
      final persona = TeacherPersona(
        id: 'persona-render-2',
        name: 'Mr. Sterling',
        style: 'strict',
        temp: 0.4,
        promptTemplate: 'Persona\n\n{scenario_prompt}\n\nRules',
      );

      final nullResult = persona.renderSystemPrompt(null);
      final emptyResult = persona.renderSystemPrompt('');

      expect(nullResult.contains('{scenario_prompt}'), isFalse);
      expect(emptyResult.contains('{scenario_prompt}'), isFalse);
    });
  });

  group('TeacherPersonaStyle', () {
    test('normalize returns known styles unchanged', () {
      for (final style in TeacherPersonaStyle.all) {
        expect(TeacherPersonaStyle.normalize(style), style);
      }
    });

    test('normalize falls back to encourage for unknown/null', () {
      expect(TeacherPersonaStyle.normalize('unknown'),
          TeacherPersonaStyle.encourage);
      expect(TeacherPersonaStyle.normalize(null),
          TeacherPersonaStyle.encourage);
    });

    test('labelKey and descKey cover all canonical styles', () {
      for (final style in TeacherPersonaStyle.all) {
        expect(
          TeacherPersonaStyle.labelKey(style).startsWith('persona.style_'),
          isTrue,
        );
        expect(
          TeacherPersonaStyle.descKey(style).endsWith('_desc'),
          isTrue,
        );
      }
    });

    test('all contains exactly strict encourage humor', () {
      expect(TeacherPersonaStyle.all.length, 3);
      expect(TeacherPersonaStyle.all, contains(TeacherPersonaStyle.strict));
      expect(TeacherPersonaStyle.all, contains(TeacherPersonaStyle.encourage));
      expect(TeacherPersonaStyle.all, contains(TeacherPersonaStyle.humor));
    });
  });
}
