import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../domain/home_models.dart';

/// S5/S6 v7 — per-skill mastery scoring.
///
/// For each skill (the `skill` tag on corrections, e.g.
/// 'grammar/subject-verb-agreement'), the service derives a 0-100 mastery
/// score from the latest 20 practice events on that skill, weighted by
/// time-decay so the most recent events count the most.
///
/// A "practice event" for a skill is one correction flagged with that skill.
/// Each correction's current SM-2 state (reviewCount + easinessFactor)
/// encodes how well the user has been recalling it: a brand-new correction
/// (reviewCount = 0) contributes 0; a well-reviewed one (reviewCount >= 8,
/// healthy EF) contributes 100. The time-decay weight then makes recent
/// struggles drag the score down faster than long-fixed old mistakes.
///
/// The computed score is persisted to the `skill_mastery` table by
/// [recompute] / [recomputeAll]; the home dashboard reads it via
/// [ChatRepository.getAllSkillMastery].
class SkillMasteryService {
  final ChatRepository _repo;

  SkillMasteryService(this._repo);

  /// Recompute and persist the mastery score for [skillId].
  ///
  /// Returns the persisted [SkillMastery]. [now] is injectable for tests.
  Future<SkillMastery> recompute(String skillId, {DateTime? now}) async {
    final referenceTime = now ?? DateTime.now();
    final corrections = await _repo.getRecentCorrectionsBySkill(
      skillId,
      limit: 20,
    );
    final score = computeScore(corrections, referenceTime: referenceTime);
    final level = SkillMastery.levelFromScore(score);
    final mastery = SkillMastery(
      skillId: skillId,
      score: score,
      level: level,
      updatedAt: referenceTime,
    );
    await _repo.upsertSkillMastery(mastery);
    return mastery;
  }

  /// Recompute mastery for every skill that has at least one correction.
  /// Returns the persisted rows in arbitrary order. Called after the user
  /// finishes a review session so the dashboard reflects the new state.
  ///
  /// BL-032: all scores are computed in memory and then persisted in a single
  /// batch transaction, so an interruption never leaves the table half-updated.
  Future<List<SkillMastery>> recomputeAll({DateTime? now}) async {
    final referenceTime = now ?? DateTime.now();
    final skills = await _repo.getDistinctSkillIds();
    final results = <SkillMastery>[];
    for (final s in skills) {
      if (s.trim().isEmpty) continue;
      final corrections = await _repo.getRecentCorrectionsBySkill(s, limit: 20);
      final score = computeScore(corrections, referenceTime: referenceTime);
      results.add(
        SkillMastery(
          skillId: s,
          score: score,
          level: SkillMastery.levelFromScore(score),
          updatedAt: referenceTime,
        ),
      );
    }
    await _repo.upsertSkillMasteryBatch(results);
    return results;
  }

  /// Pure function: compute the 0-100 mastery score from a list of
  /// corrections for one skill, using a time-decay weighted average.
  ///
  /// BL-031: weights are derived from the real day difference between the
  /// reference time and each correction's `lastSeenAt`, not from list index.
  /// An event seen today weighs 1.0; each day older multiplies by [decay].
  /// Bounded to the latest 20 events so the score reflects recent trajectory
  /// rather than the all-time average.
  ///
  /// Exposed for unit testing — production callers should use [recompute].
  @visibleForTesting
  int computeScore(List<Correction> corrections, {DateTime? referenceTime}) {
    if (corrections.isEmpty) return 0;

    final reference = referenceTime ?? DateTime.now();
    // Sort by lastSeenAt DESC (newest first). Copy first because the input
    // list may be unmodifiable.
    final sorted = List<Correction>.of(corrections)
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    // Take the latest 20 — matches the spec's "latest 20 practice events".
    final recent = sorted.length > 20 ? sorted.sublist(0, 20) : sorted;

    // Time-decay weights based on actual day difference.
    const decay = 0.85;
    double weightedSum = 0;
    double weightSum = 0;
    for (final c in recent) {
      final days = reference.difference(c.lastSeenAt).inDays.clamp(0, 365);
      final weight = math.pow(decay, days).toDouble();
      weightedSum += weight * _perItemScore(c);
      weightSum += weight;
    }
    if (weightSum == 0) return 0;
    final score = (weightedSum / weightSum).round();
    // Clamp guards against floating-point drift pushing the rounded value
    // outside the 0-100 contract (mathematically impossible here, but the
    // dashboard treats 0-100 as an invariant).
    return score.clamp(0, 100);
  }

  /// Per-correction mastery score derived from its SM-2 state.
  ///
  /// BL-039: thresholds now align with [LearningStatsService]'s "mastered"
  /// definition (review_count >= 5) so the dashboard and statistics use the
  /// same criteria.
  int _perItemScore(Correction c) {
    if (c.reviewCount == 0) return 0; // brand-new error
    if (c.easinessFactor < 1.5) return 30; // struggling
    if (c.reviewCount < 3) return 50; // learning
    if (c.reviewCount < 5) return 70; // familiar
    if (c.reviewCount < 8) return 90; // nearly mastered
    return 100; // mastered
  }
}
