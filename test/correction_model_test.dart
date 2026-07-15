import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';

void main() {
  group('Correction serialization', () {
    test('toMap and fromMap round-trip preserves fields', () {
      final original = Correction(
        id: 'test-id-123',
        original: 'I goes',
        corrected: 'I go',
        type: CorrectionType.grammar,
        explanation: 'Subject-verb agreement',
        messageId: 'msg-1',
        sessionId: 'sess-1',
        reviewCount: 3,
        easinessFactor: 2.4,
        intervalDays: 6,
        nextReviewAt: DateTime(2026, 7, 1, 10, 30),
        createdAt: DateTime(2026, 6, 28, 12, 0),
      );

      final map = original.toMap();
      final restored = Correction.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.original, original.original);
      expect(restored.corrected, original.corrected);
      expect(restored.type, original.type);
      expect(restored.explanation, original.explanation);
      expect(restored.messageId, original.messageId);
      expect(restored.sessionId, original.sessionId);
      expect(restored.reviewCount, original.reviewCount);
      expect(restored.easinessFactor, original.easinessFactor);
      expect(restored.intervalDays, original.intervalDays);
      expect(restored.nextReviewAt, original.nextReviewAt);
      expect(restored.createdAt, original.createdAt);
    });

    test('toMap encodes type as name string', () {
      for (final type in CorrectionType.values) {
        final c = Correction(
          original: 'x',
          corrected: 'y',
          type: type,
        );
        expect(c.toMap()['type'], type.name);
      }
    });

    test('fluency is a valid CorrectionType', () {
      expect(CorrectionType.values, contains(CorrectionType.fluency));
    });

    test('skill field round-trips through toMap/fromMap', () {
      final original = Correction(
        original: 'I goes',
        corrected: 'I go',
        type: CorrectionType.grammar,
        skill: 'grammar/subject-verb-agreement',
        createdAt: DateTime(2026, 6, 28, 12, 0),
      );
      final map = original.toMap();
      expect(map['skill'], 'grammar/subject-verb-agreement');
      final restored = Correction.fromMap(map);
      expect(restored.skill, 'grammar/subject-verb-agreement');
    });

    test('skill field defaults to null when not set', () {
      final c = Correction(
        original: 'x',
        corrected: 'y',
        type: CorrectionType.grammar,
      );
      expect(c.skill, isNull);
      expect(c.toMap()['skill'], isNull);
    });

    test('fromMap handles null skill field with default', () {
      final map = {
        'id': 'x',
        'original': 'a',
        'corrected': 'b',
        'type': 'grammar',
        'skill': null,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      };
      expect(Correction.fromMap(map).skill, isNull);
    });

    test('fromMap handles null optional fields with defaults', () {
      final map = {
        'id': 'x',
        'original': 'a',
        'corrected': 'b',
        'type': 'vocabulary',
        'explanation': null,
        'message_id': null,
        'session_id': null,
        'review_count': null,
        'easiness_factor': null,
        'interval_days': null,
        'next_review_at': null,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      };
      final c = Correction.fromMap(map);
      expect(c.reviewCount, 0);
      expect(c.easinessFactor, 2.5);
      expect(c.intervalDays, 0);
      expect(c.nextReviewAt, isNull);
      expect(c.explanation, isNull);
    });

    test('fromMap parses all CorrectionType values', () {
      for (final type in CorrectionType.values) {
        final map = {
          'id': 'x',
          'original': 'a',
          'corrected': 'b',
          'type': type.name,
          'explanation': null,
          'message_id': null,
          'session_id': null,
          'review_count': 0,
          'easiness_factor': 2.5,
          'interval_days': 0,
          'next_review_at': null,
          'created_at': DateTime(2026, 1, 1).toIso8601String(),
        };
        expect(Correction.fromMap(map).type, type);
      }
    });
  });

  group('Correction.copyWith', () {
    test('copies only specified fields, keeps others', () {
      final original = Correction(
        original: 'a',
        corrected: 'b',
        type: CorrectionType.grammar,
        reviewCount: 1,
        easinessFactor: 2.5,
        intervalDays: 1,
      );
      final copy = original.copyWith(reviewCount: 5);
      expect(copy.original, 'a');
      expect(copy.corrected, 'b');
      expect(copy.type, CorrectionType.grammar);
      expect(copy.reviewCount, 5);
      expect(copy.easinessFactor, 2.5);
      expect(copy.intervalDays, 1);
      expect(copy.id, original.id);
    });

    test('clearNextReviewAt sets nextReviewAt to null', () {
      final original = Correction(
        original: 'a',
        corrected: 'b',
        type: CorrectionType.grammar,
        nextReviewAt: DateTime(2026, 7, 1),
      );
      final copy = original.copyWith(clearNextReviewAt: true);
      expect(copy.nextReviewAt, isNull);
    });

    test('copyWith preserves nextReviewAt when not clearing', () {
      final dt = DateTime(2026, 7, 1);
      final original = Correction(
        original: 'a',
        corrected: 'b',
        type: CorrectionType.grammar,
        nextReviewAt: dt,
      );
      final copy = original.copyWith(reviewCount: 2);
      expect(copy.nextReviewAt, dt);
    });

    test('copyWith sets skill when provided', () {
      final original = Correction(
        original: 'a',
        corrected: 'b',
        type: CorrectionType.grammar,
      );
      final copy = original.copyWith(skill: 'grammar/articles');
      expect(copy.skill, 'grammar/articles');
    });

    test('copyWith preserves skill when not changing it', () {
      final original = Correction(
        original: 'a',
        corrected: 'b',
        type: CorrectionType.grammar,
        skill: 'grammar/tenses',
      );
      final copy = original.copyWith(reviewCount: 1);
      expect(copy.skill, 'grammar/tenses');
    });

    test('clearSkill sets skill to null', () {
      final original = Correction(
        original: 'a',
        corrected: 'b',
        type: CorrectionType.grammar,
        skill: 'grammar/tenses',
      );
      final copy = original.copyWith(clearSkill: true);
      expect(copy.skill, isNull);
    });
  });
}
