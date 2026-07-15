import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/data/chat_repository.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';
import 'package:speakflow/features/home/data/skill_mastery_service.dart';

void main() {
  group('SkillMasteryService.computeScore', () {
    final now = DateTime(2026, 7, 15, 10, 0);

    /// Helper: build a correction with a given SM-2 state and [lastSeenAt].
    Correction corr({
      int reviewCount = 0,
      double ef = 2.5,
      DateTime? lastSeenAt,
    }) {
      return Correction(
        original: 'x',
        corrected: 'y',
        type: CorrectionType.grammar,
        skill: 'grammar/test',
        reviewCount: reviewCount,
        easinessFactor: ef,
        lastSeenAt: lastSeenAt ?? now,
        createdAt: lastSeenAt ?? now,
      );
    }

    test('empty list returns 0', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([]), 0);
    });

    test('single brand-new correction (reviewCount=0) returns 0', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([corr(reviewCount: 0)]), 0);
    });

    test('single expert correction returns 100', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([corr(reviewCount: 8, ef: 2.5)]), 100);
    });

    test('single mastered correction (reviewCount 5-7) returns 90', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([corr(reviewCount: 6, ef: 2.5)]), 90);
    });

    test('single familiar correction (reviewCount 3-4) returns 70', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([corr(reviewCount: 4, ef: 2.5)]), 70);
    });

    test('single learning correction (reviewCount 1-2) returns 50', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([corr(reviewCount: 2, ef: 2.5)]), 50);
    });

    test('struggling correction (ef < 1.5) returns 30', () {
      final svc = SkillMasteryService(_DummyRepo());
      expect(svc.computeScore([corr(reviewCount: 5, ef: 1.4)]), 30);
    });

    test('newest correction weighs more than oldest (time decay)', () {
      final svc = SkillMasteryService(_DummyRepo());
      // Oldest = expert (100), Newest = brand-new (0).
      // The newest (0) should drag the score below 50 because it has the
      // highest weight.
      final corrections = [
        corr(reviewCount: 8, ef: 2.5, lastSeenAt: now.subtract(const Duration(days: 10))),
        corr(reviewCount: 0, ef: 2.5, lastSeenAt: now),
      ];
      final score = svc.computeScore(corrections);
      // Weighted: w0=1.0 (newest, score=0), w1=0.85 (oldest, score=100)
      // avg = (1*0 + 0.85*100) / (1 + 0.85) = 85/1.85 ≈ 45.9 → 46
      expect(score, lessThan(50));
      expect(score, greaterThan(40));
    });

    test('only the latest 20 corrections are considered', () {
      final svc = SkillMasteryService(_DummyRepo());
      // 21 corrections: indices 0..20.
      // The newest (index 20) is brand-new (score 0).
      // The other 20 are all expert (score 100).
      // computeScore takes the latest 20 → indices 1..20.
      // Since index 20 (newest, score 0) has the highest weight,
      // the result should be < 100.
      final corrections = List.generate(21, (i) {
        final isLast = i == 20;
        return corr(
          reviewCount: isLast ? 0 : 8,
          ef: 2.5,
          lastSeenAt: now.subtract(Duration(days: 20 - i)),
        );
      });
      final score = svc.computeScore(corrections);
      expect(score, lessThan(100));
      // The newest (score 0) has weight 1.0; the other 19 (score 100) have
      // decaying weights. The result should still be high since 19 out of 20
      // are experts, but strictly < 100.
      expect(score, greaterThan(80));
    });

    test('score is always in 0-100 range', () {
      final svc = SkillMasteryService(_DummyRepo());
      // Mix of corrections with varying states.
      final corrections = [
        corr(reviewCount: 0, ef: 2.5, lastSeenAt: now),
        corr(reviewCount: 10, ef: 2.8, lastSeenAt: now.subtract(const Duration(days: 1))),
        corr(reviewCount: 3, ef: 1.4, lastSeenAt: now.subtract(const Duration(days: 5))),
      ];
      final score = svc.computeScore(corrections);
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(100));
    });
  });
}

/// Minimal stub — never called in these tests because [computeScore] is a
/// pure function that doesn't touch the repository. Required only because
/// the constructor demands a [ChatRepository].
class _DummyRepo extends ChatRepository {}
