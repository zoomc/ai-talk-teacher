import '../../chat/domain/chat_models.dart';

/// SM-2 Spaced Repetition Algorithm
/// Based on the SuperMemo SM-2 algorithm
class Sm2Service {
  /// Calculate next review date based on SM-2 algorithm
  static Correction scheduleReview(Correction correction, int quality) {
    // quality: 0-5 (0=complete blackout, 5=perfect)
    assert(quality >= 0 && quality <= 5);

    // Get current values
    double ef = correction.easinessFactor;
    final reviewCount = correction.reviewCount + 1;
    int prevInterval = correction.intervalDays;
    int newInterval;

    // Adjust easiness factor based on quality (SM-2 formula)
    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (ef < 1.3) ef = 1.3;

    // Calculate interval
    if (quality < 3) {
      // Failed: reset to 1 day, keep EF reduction
      newInterval = 1;
      return correction.copyWith(
        reviewCount: 0, // reset review count on failure
        easinessFactor: ef,
        intervalDays: newInterval,
        nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
        clearNextReviewAt: false,
      );
    }

    // Passed: calculate next interval
    if (reviewCount == 1) {
      newInterval = 1;
    } else if (reviewCount == 2) {
      newInterval = 6;
    } else {
      newInterval = (prevInterval * ef).round();
    }

    return correction.copyWith(
      reviewCount: reviewCount,
      easinessFactor: ef,
      intervalDays: newInterval,
      nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
      clearNextReviewAt: false,
    );
  }

  /// Get human-readable next review time
  static String getNextReviewText(Correction correction) {
    if (correction.nextReviewAt == null) return 'Ready for review';

    final now = DateTime.now();
    final diff = correction.nextReviewAt!.difference(now);

    if (diff.isNegative) return 'Ready for review';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays}d';
  }

  /// Get mastery level based on review count and EF
  static String getMasteryLevel(Correction correction) {
    if (correction.reviewCount == 0) return 'New';
    if (correction.reviewCount < 2) return 'Learning';
    if (correction.easinessFactor < 2.0) return 'Struggling';
    if (correction.reviewCount < 5) return 'Familiar';
    if (correction.reviewCount < 8) return 'Mastered';
    return 'Expert';
  }

  /// Get mastery color based on level
  static int getMasteryColor(Correction correction) {
    final level = getMasteryLevel(correction);
    switch (level) {
      case 'New':
        return 0xFFFF5252; // error
      case 'Learning':
        return 0xFFFFB74D; // warning
      case 'Struggling':
        return 0xFFFF9800; // orange
      case 'Familiar':
        return 0xFF42A5F5; // info
      case 'Mastered':
        return 0xFF00E676; // success
      case 'Expert':
        return 0xFF6C5CE7; // accent
      default:
        return 0xFF8892A4; // secondary
    }
  }
}
