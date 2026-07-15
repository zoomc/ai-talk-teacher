import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/home/domain/home_models.dart';

void main() {
  group('GoalType', () {
    test('all contains the four supported goal types', () {
      expect(GoalType.all, hasLength(4));
      expect(GoalType.all, contains(GoalType.interview));
      expect(GoalType.all, contains(GoalType.travel));
      expect(GoalType.all, contains(GoalType.daily));
      expect(GoalType.all, contains(GoalType.ielts));
    });

    test('normalize returns known types unchanged', () {
      expect(GoalType.normalize('interview'), 'interview');
      expect(GoalType.normalize('travel'), 'travel');
      expect(GoalType.normalize('daily'), 'daily');
      expect(GoalType.normalize('ielts'), 'ielts');
    });

    test('normalize defaults to daily for unknown/null input', () {
      expect(GoalType.normalize(null), GoalType.daily);
      expect(GoalType.normalize('unknown'), GoalType.daily);
      expect(GoalType.normalize(''), GoalType.daily);
      expect(GoalType.normalize('INTERVIEW'), GoalType.daily);
    });

    test('labelKey returns correct i18n key for each type', () {
      expect(GoalType.labelKey(GoalType.interview), 'goal.type_interview');
      expect(GoalType.labelKey(GoalType.travel), 'goal.type_travel');
      expect(GoalType.labelKey(GoalType.daily), 'goal.type_daily');
      expect(GoalType.labelKey(GoalType.ielts), 'goal.type_ielts');
    });

    test('labelKey defaults to daily for unknown type', () {
      expect(GoalType.labelKey('unknown'), 'goal.type_daily');
    });

    test('preferredCategory maps goal types to scenario categories', () {
      expect(GoalType.preferredCategory(GoalType.interview), 'career');
      expect(GoalType.preferredCategory(GoalType.travel), 'travel');
      expect(GoalType.preferredCategory(GoalType.ielts), 'general');
      expect(GoalType.preferredCategory(GoalType.daily), 'daily');
    });

    test('preferredCategory defaults to daily for unknown type', () {
      expect(GoalType.preferredCategory('unknown'), 'daily');
    });
  });

  group('UserGoal model', () {
    test('toMap and fromMap round-trip preserves fields', () {
      final goal = UserGoal(
        id: 'goal-123',
        goalType: GoalType.interview,
        target: 'Software engineer interview',
        createdAt: DateTime(2026, 7, 15, 10, 0),
      );
      final map = goal.toMap();
      expect(map['id'], 'goal-123');
      expect(map['goal_type'], 'interview');
      expect(map['target'], 'Software engineer interview');
      expect(map['created_at'], DateTime(2026, 7, 15, 10, 0).toIso8601String());

      final restored = UserGoal.fromMap(map);
      expect(restored.id, goal.id);
      expect(restored.goalType, goal.goalType);
      expect(restored.target, goal.target);
      expect(restored.createdAt, goal.createdAt);
    });

    test('fromMap handles null target with empty default', () {
      final map = {
        'id': 'g1',
        'goal_type': 'daily',
        'target': null,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      };
      final goal = UserGoal.fromMap(map);
      expect(goal.target, '');
    });

    test('auto-generates id and createdAt when not provided', () {
      final goal = UserGoal(goalType: GoalType.travel, target: '');
      expect(goal.id, isNotEmpty);
      expect(goal.createdAt, isNotNull);
    });
  });

  group('SkillMastery model', () {
    test('toMap and fromMap round-trip preserves fields', () {
      final mastery = SkillMastery(
        id: 'm1',
        skillId: 'grammar/subject-verb-agreement',
        score: 72,
        level: 'mastered',
        updatedAt: DateTime(2026, 7, 15, 10, 0),
      );
      final map = mastery.toMap();
      expect(map['id'], 'm1');
      expect(map['skill_id'], 'grammar/subject-verb-agreement');
      expect(map['score'], 72);
      expect(map['level'], 'mastered');

      final restored = SkillMastery.fromMap(map);
      expect(restored.id, mastery.id);
      expect(restored.skillId, mastery.skillId);
      expect(restored.score, mastery.score);
      expect(restored.level, mastery.level);
      expect(restored.updatedAt, mastery.updatedAt);
    });

    test('levelFromScore returns correct level for score thresholds', () {
      expect(SkillMastery.levelFromScore(0), 'new');
      expect(SkillMastery.levelFromScore(19), 'new');
      expect(SkillMastery.levelFromScore(20), 'learning');
      expect(SkillMastery.levelFromScore(39), 'learning');
      expect(SkillMastery.levelFromScore(40), 'familiar');
      expect(SkillMastery.levelFromScore(69), 'familiar');
      expect(SkillMastery.levelFromScore(70), 'mastered');
      expect(SkillMastery.levelFromScore(89), 'mastered');
      expect(SkillMastery.levelFromScore(90), 'expert');
      expect(SkillMastery.levelFromScore(100), 'expert');
    });
  });
}
