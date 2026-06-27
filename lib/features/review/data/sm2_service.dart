import '../../features/chat/domain/chat_models.dart';

/// SM-2 Spaced Repetition Algorithm
/// Based on the SuperMemo SM-2 algorithm
class Sm2Service {
  /// Calculate next review date based on SM-2 algorithm
  static Correction scheduleReview(Correction correction, int quality) {
    // quality: 0-5 (0=complete blackout, 5=perfect)
    assert(quality >= 0 && quality <= 5);

    final reviewCount = correction.reviewCount + 1;
    double easinessFactor = 2.5; // default EF
    int interval;

    if (reviewCount == 1) {
      interval = 1; // 1 day
    } else if (reviewCount == 2) {
      interval = 6; // 6 days
    } else {
      // Calculate interval based on previous interval and EF
      // For simplicity, we use a basic implementation
      interval = (6 * easinessFactor).round();
    }

    // Adjust easiness factor based on quality
    easinessFactor = easinessFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (easinessFactor < 1.3) easinessFactor = 1.3;

    // If quality < 3, reset the review count
    if (quality < 3) {
      return correction.copyWith(
        reviewCount: 0,
        nextReviewAt: DateTime.now().add(const Duration(days: 1)),
      );
    }

    return correction.copyWith(
      reviewCount: reviewCount,
      nextReviewAt: DateTime.now().add(Duration(days: interval)),
    );
  }

  /// Get quality rating from user response
  static int getQualityFromResponse(String response) {
    switch (response.toLowerCase()) {
      case 'perfect':
        return 5;
      case 'easy':
        return 4;
      case 'good':
        return 3;
      case 'hard':
        return 2;
      case 'fail':
        return 1;
      case 'blackout':
        return 0;
      default:
        return 3;
    }
  }

  /// Get human-readable next review time
  static String getNextReviewText(Correction correction) {
    if (correction.nextReviewAt == null) return 'Ready for review';

    final now = DateTime.now();
    final diff = correction.nextReviewAt!.difference(now);

    if (diff.isNegative) return 'Ready for review';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} minutes';
    if (diff.inHours < 24) return 'In ${diff.inHours} hours';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays} days';
  }

  /// Get mastery level based on review count
  static String getMasteryLevel(Correction correction) {
    if (correction.reviewCount == 0) return 'New';
    if (correction.reviewCount < 3) return 'Learning';
    if (correction.reviewCount < 6) return 'Familiar';
    if (correction.reviewCount < 10) return 'Mastered';
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
