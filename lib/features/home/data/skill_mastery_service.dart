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
    final corrections =
        await _repo.getRecentCorrectionsBySkill(skillId, limit: 20);
    final score = computeScore(corrections);
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
  Future<List<SkillMastery>> recomputeAll({DateTime? now}) async {
    final skills = await _repo.getDistinctSkillIds();
    final results = <SkillMastery>[];
    for (final s in skills) {
      // Skip empty skill tags defensively — the repository already filters
      // them, but a stray '' here would create a bogus mastery row.
      if (s.trim().isEmpty) continue;
      results.add(await recompute(s, now: now));
    }
    return results;
  }

  /// Pure function: compute the 0-100 mastery score from a list of
  /// corrections for one skill, using a time-decay weighted average.
  ///
  /// Newest correction (highest `lastSeenAt`) gets the highest weight; the
  /// decay factor (0.85) means an event 5 positions back counts ~44% as
  /// much as the most recent one. Bounded to the latest 20 events so the
  /// score reflects recent trajectory rather than the all-time average.
  ///
  /// Exposed for unit testing — production callers should use [recompute].
  @visibleForTesting
  int computeScore(List<Correction> corrections) {
    if (corrections.isEmpty) return 0;

    // Sort by lastSeenAt DESC (newest first). Copy first because the input
    // list may be unmodifiable.
    final sorted = List<Correction>.of(corrections)
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    // Take the latest 20 — matches the spec's "latest 20 practice events".
    final recent = sorted.length > 20 ? sorted.sublist(0, 20) : sorted;

    // Time-decay weights: w_i = decay ^ i, i = 0 (newest) ... n-1 (oldest).
    // decay < 1 → newest has the highest weight. 0.85 is the standard
    // SuperMemo-style decay: events 5 positions back weigh ~44% as much.
    const decay = 0.85;
    double weightedSum = 0;
    double weightSum = 0;
    for (int i = 0; i < recent.length; i++) {
      final weight = math.pow(decay, i).toDouble();
      weightedSum += weight * _perItemScore(recent[i]);
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
  /// Thresholds mirror [Sm2Service.getMasteryLevel] but return a numeric
  /// 0-100 contribution so the weighted average produces a continuous
  /// score. A correction that has never been reviewed (reviewCount = 0)
  /// contributes 0 — it's an open mistake pulling the skill down. A
  /// well-reviewed one (reviewCount >= 8) contributes 100.
  int _perItemScore(Correction c) {
    if (c.reviewCount == 0) return 0; // brand-new error
    if (c.easinessFactor < 1.5) return 30; // struggling
    if (c.reviewCount < 3) return 50; // learning
    if (c.reviewCount < 5) return 70; // familiar
    if (c.reviewCount < 8) return 90; // mastered
    return 100; // expert
  }
}
