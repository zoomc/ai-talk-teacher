import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';
import 'package:speakflow/features/review/data/sm2_service.dart';

void main() {
  group('Sm2Service.scheduleReview', () {
    Correction baseCorrection({
      int reviewCount = 0,
      double ef = 2.5,
      int intervalDays = 0,
    }) {
      return Correction(
        original: 'I goes',
        corrected: 'I go',
        type: CorrectionType.grammar,
        reviewCount: reviewCount,
        easinessFactor: ef,
        intervalDays: intervalDays,
      );
    }

    test('quality 0 (blackout) resets review count and sets 1-day interval', () {
      final c = baseCorrection(reviewCount: 4, ef: 2.6, intervalDays: 15);
      final result = Sm2Service.scheduleReview(c, 0);
      expect(result.reviewCount, 0);
      expect(result.intervalDays, 1);
      expect(result.easinessFactor, lessThan(2.6));
      expect(result.easinessFactor, greaterThanOrEqualTo(1.3));
      expect(result.nextReviewAt, isNotNull);
    });

    test('quality 2 (fail) resets review count and sets 1-day interval', () {
      final c = baseCorrection(reviewCount: 3, ef: 2.5, intervalDays: 6);
      final result = Sm2Service.scheduleReview(c, 2);
      expect(result.reviewCount, 0);
      expect(result.intervalDays, 1);
      expect(result.nextReviewAt, isNotNull);
    });

    test('first successful review (quality 5) sets interval=1, count=1', () {
      final c = baseCorrection(reviewCount: 0, ef: 2.5);
      final result = Sm2Service.scheduleReview(c, 5);
      expect(result.reviewCount, 1);
      expect(result.intervalDays, 1);
      // EF should increase for perfect recall: 2.5 + 0.1 = 2.6
      expect(result.easinessFactor, closeTo(2.6, 0.001));
    });

    test('second successful review sets interval=6, count=2', () {
      final c = baseCorrection(reviewCount: 1, ef: 2.5, intervalDays: 1);
      final result = Sm2Service.scheduleReview(c, 4);
      expect(result.reviewCount, 2);
      expect(result.intervalDays, 6);
    });

    test('third+ successful review scales interval by EF', () {
      final c = baseCorrection(reviewCount: 2, ef: 2.5, intervalDays: 6);
      final result = Sm2Service.scheduleReview(c, 5);
      expect(result.reviewCount, 3);
      // interval = round(prevInterval * ef) = round(6 * 2.6) = 16
      expect(result.intervalDays, (6 * 2.6).round());
    });

    test('EF never drops below 1.3 even with repeated low quality', () {
      var c = baseCorrection(ef: 1.4);
      c = Sm2Service.scheduleReview(c, 0);
      c = Sm2Service.scheduleReview(c, 0);
      c = Sm2Service.scheduleReview(c, 0);
      expect(c.easinessFactor, greaterThanOrEqualTo(1.3));
    });

    test('perfect recall increases EF, poor recall decreases EF', () {
      final perfect = Sm2Service.scheduleReview(baseCorrection(ef: 2.5), 5);
      final poor = Sm2Service.scheduleReview(baseCorrection(ef: 2.5), 3);
      expect(perfect.easinessFactor, greaterThan(2.5));
      expect(poor.easinessFactor, lessThan(perfect.easinessFactor));
    });
  });

  group('Sm2Service.getMasteryLevel', () {
    Correction corr({int reviewCount = 0, double ef = 2.5}) {
      return Correction(
        original: 'x',
        corrected: 'y',
        type: CorrectionType.grammar,
        reviewCount: reviewCount,
        easinessFactor: ef,
      );
    }

    test('returns New for reviewCount 0', () {
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 0)), 'New');
    });

    test('returns Learning for reviewCount 1', () {
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 1)), 'Learning');
    });

    test('returns Struggling when EF < 2.0', () {
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 3, ef: 1.5)), 'Struggling');
    });

    test('returns Familiar for reviewCount 2-4 with healthy EF', () {
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 2, ef: 2.5)), 'Familiar');
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 4, ef: 2.5)), 'Familiar');
    });

    test('returns Mastered for reviewCount 5-7', () {
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 5, ef: 2.5)), 'Mastered');
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 7, ef: 2.5)), 'Mastered');
    });

    test('returns Expert for reviewCount >= 8', () {
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 8, ef: 2.5)), 'Expert');
      expect(Sm2Service.getMasteryLevel(corr(reviewCount: 20, ef: 2.5)), 'Expert');
    });
  });

  group('Sm2Service.getNextReviewText', () {
    test('returns Ready for review when nextReviewAt is null', () {
      final c = Correction(original: 'x', corrected: 'y', type: CorrectionType.grammar);
      expect(Sm2Service.getNextReviewText(c), 'Ready for review');
    });

    test('returns Ready for review when nextReviewAt is in the past', () {
      final c = Correction(
        original: 'x',
        corrected: 'y',
        type: CorrectionType.grammar,
        nextReviewAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(Sm2Service.getNextReviewText(c), 'Ready for review');
    });

    test('returns Tomorrow for nextReviewAt ~1 day away', () {
      final c = Correction(
        original: 'x',
        corrected: 'y',
        type: CorrectionType.grammar,
        nextReviewAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      );
      expect(Sm2Service.getNextReviewText(c), 'Tomorrow');
    });
  });
}
