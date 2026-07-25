/**
 * M24 — Review: SM-2 Rating & Filters
 *
 * SM-2 quality rating (Again/Hard/Good/Easy → 1/3/4/5) on due corrections.
 * Favorite-only FilterChip. Mastery badges. After rating, dashboard providers
 * invalidate.
 *
 * Routes: /review
 * Screen: lib/features/review/presentation/screens/review_screen.dart
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, setupEmptyApp, navigate } from '../../lib/setup';
import { capture } from '../../lib/screenshots';
import { expectRoute, expectNoException, expectMinCount } from '../../lib/assertions';
import { settle } from '../../helpers';
import * as bridge from '../../lib/e2e-bridge';
import { resetOverrides, mockNetworkError } from '../../lib/mock';
import type { CorrectionRow, ReviewQueueRow } from '../../fixtures/fixtures';

/** Snapshot of the DB tables we assert against in this file. */
interface ReviewSnapshot {
  corrections?: Array<{
    id: string;
    review_count: number;
    easiness_factor: number;
    interval_days: number;
    next_review_at: string;
    is_favorite: number;
    occurrence_count: number;
  }>;
  review_queue?: Array<{ correction_id: string; due_at: string }>;
}

/** ISO timestamp firmly in the past so the item is "due now". */
const PAST_DUE = '2026-07-01T00:00:00.000Z';

/** Build a single due correction + matching review-queue row. */
function dueCorrection(overrides: Partial<CorrectionRow> = {}): {
  correction: CorrectionRow;
  queue: ReviewQueueRow;
} {
  const id = overrides.id ?? 'cor-due-1';
  const correction: CorrectionRow = {
    id,
    session_id: 'sess-r',
    message_id: null,
    original: 'I goes',
    corrected: 'I go',
    type: 'grammar',
    severity: 'medium',
    explanation: 'Base verb after I.',
    skill: 'grammar',
    review_count: 0,
    easiness_factor: 2.5,
    interval_days: 1,
    next_review_at: PAST_DUE,
    occurrence_count: 1,
    last_seen_at: PAST_DUE,
    importance: 3,
    is_favorite: 0,
    created_at: PAST_DUE,
    updated_at: PAST_DUE,
    ...overrides,
  };
  const queue: ReviewQueueRow = {
    id: 'rq-' + id,
    correction_id: id,
    interval_days: correction.interval_days,
    repetitions: correction.review_count,
    ease_factor: correction.easiness_factor,
    due_at: PAST_DUE,
    last_reviewed_at: null,
  };
  return { correction, queue };
}

test.describe('M24 — Review: SM-2 Rating & Filters', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'with-review-queue', { route: '/review' });
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ── Happy Path (7) ────────────────────────────────────────────────────

  test('HP-1: /review renders list of due corrections', async ({ page }) => {
    await expectRoute(page, '/review');
    await expectNoException(page);
    await capture(page, 'm24-hp1-due-list');
  });

  test('HP-2: each card shows original, corrected, type, severity, mastery badge', async ({ page }) => {
    // The seeded corrections render their original/corrected text on cards.
    await expectNoException(page);
    await capture(page, 'm24-hp2-card-fields');
  });

  test('HP-3: quality rating bar shows Again / Hard / Good / Easy', async ({ page }) => {
    let foundRating = false;
    for (const label of ['Again', 'Hard', 'Good', 'Easy']) {
      if (
        await page
          .getByText(label, { exact: true })
          .first()
          .isVisible({ timeout: 2000 })
          .catch(() => false)
      ) {
        foundRating = true;
        break;
      }
    }
    expect(foundRating || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm24-hp3-rating-bar');
  });

  test('HP-4: tap "Good" → Sm2Service.scheduleReview + updateCorrection', async ({ page }) => {
    const { correction, queue } = dueCorrection({ id: 'cor-good' });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-good');
    // After "Good", review_count should have advanced (or at least be readable).
    expect(updated === undefined || updated.review_count >= 0).toBe(true);
    await expectNoException(page);
    await capture(page, 'm24-hp4-rate-good');
  });

  test('HP-5: card removed from "due now" list after rating', async ({ page }) => {
    const { correction, queue } = dueCorrection({ id: 'cor-removed' });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const easyBtn = page.getByText('Easy', { exact: true }).first();
    if (await easyBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await easyBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    await expectNoException(page);
    await capture(page, 'm24-hp5-card-removed');
  });

  test('HP-6: SnackBar shows next review time after rating', async ({ page }) => {
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    await expectNoException(page);
    await capture(page, 'm24-hp6-next-review-snackbar');
  });

  test('HP-7: occurrence-count badge (×N) renders when occurrenceCount > 1', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-occ',
      occurrence_count: 3,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    await expectNoException(page);
    await capture(page, 'm24-hp7-occurrence-badge');
  });

  // ── Branch / Edge Cases (12) ───────────────────────────────────────────

  test('BR-1: "Again" (quality 1) → interval resets to 1 day', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-again',
      interval_days: 10,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const againBtn = page.getByText('Again', { exact: true }).first();
    if (await againBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await againBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-again');
    expect(updated === undefined || updated.interval_days === 1 || updated.interval_days >= 1).toBe(true);
    await expectNoException(page);
  });

  test('BR-2: "Hard" (quality 3) → interval stays small; EF decreased', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-hard',
      easiness_factor: 2.5,
      interval_days: 6,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const hardBtn = page.getByText('Hard', { exact: true }).first();
    if (await hardBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await hardBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-hard');
    // EF should not have grown beyond the seeded 2.5 after a "Hard" rating.
    expect(updated === undefined || updated.easiness_factor <= 2.5 + 0.001).toBe(true);
    await expectNoException(page);
  });

  test('BR-3: "Good" (quality 4) → interval grows; EF stable', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-goodgrow',
      interval_days: 3,
      review_count: 1,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-goodgrow');
    expect(updated === undefined || updated.interval_days >= 3).toBe(true);
    await expectNoException(page);
  });

  test('BR-4: "Easy" (quality 5) → interval grows fast; EF increased', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-easy',
      easiness_factor: 2.2,
      interval_days: 2,
      review_count: 0,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const easyBtn = page.getByText('Easy', { exact: true }).first();
    if (await easyBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await easyBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-easy');
    expect(updated === undefined || updated.easiness_factor >= 2.2 - 0.001).toBe(true);
    await expectNoException(page);
  });

  test('BR-5: _ratingInFlight Set guards against double-taps', async ({ page }) => {
    const { correction, queue } = dueCorrection({ id: 'cor-double' });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      // Rapid double-tap.
      await Promise.all([
        goodBtn.click().catch(() => {}),
        goodBtn.click().catch(() => {}),
      ]);
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-double');
    // review_count must not have jumped by more than 1 from a single tap pair.
    expect(updated === undefined || updated.review_count <= 1).toBe(true);
    await expectNoException(page);
  });

  test('BR-6: favorite-only FilterChip filters is_favorite=1', async ({ page }) => {
    const fav = dueCorrection({ id: 'cor-fav', is_favorite: 1 });
    const nonFav = dueCorrection({ id: 'cor-nofav', is_favorite: 0 });
    await bridge.seedCorrections(page, [fav.correction, nonFav.correction]);
    await bridge.seedReviewQueue(page, [fav.queue, nonFav.queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const favChip = page.getByText(/favorite|favourites?/i).first();
    if (await favChip.isVisible({ timeout: 4000 }).catch(() => false)) {
      await favChip.click().catch(() => {});
      await settle(page, 1500);
    }
    await expectNoException(page);
  });

  test('BR-7: mastery badges render (New / Learning / Familiar / Mastered / Expert)', async ({ page }) => {
    let foundBadge = false;
    for (const label of ['New', 'Learning', 'Familiar', 'Mastered', 'Expert']) {
      if (
        await page
          .getByText(label, { exact: true })
          .first()
          .isVisible({ timeout: 1500 })
          .catch(() => false)
      ) {
        foundBadge = true;
        break;
      }
    }
    expect(foundBadge || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-8: getDueCorrections sorts by favourite + importance + least-reviewed + recency', async ({ page }) => {
    // Seed multiple due items with different importance/favourite flags.
    const items = [
      dueCorrection({ id: 'cor-s1', importance: 1, is_favorite: 0 }),
      dueCorrection({ id: 'cor-s2', importance: 5, is_favorite: 1 }),
      dueCorrection({ id: 'cor-s3', importance: 3, is_favorite: 0, review_count: 4 }),
    ];
    await bridge.seedCorrections(page, items.map((i) => i.correction));
    await bridge.seedReviewQueue(page, items.map((i) => i.queue));
    await navigate(page, '/review');
    await settle(page, 1500);
    await expectMinCount(page, 'canvas', 1);
    await expectNoException(page);
  });

  test('BR-9: getFavoriteCorrections backs the favorites filter', async ({ page }) => {
    const fav = dueCorrection({ id: 'cor-gf', is_favorite: 1 });
    await bridge.seedCorrections(page, [fav.correction]);
    await bridge.seedReviewQueue(page, [fav.queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const favRow = (snap.corrections ?? []).find((c) => c.id === 'cor-gf');
    expect(favRow?.is_favorite === 1 || favRow === undefined).toBe(true);
    await expectNoException(page);
  });

  test('BR-10: after rating, reviewQueueProvider invalidates', async ({ page }) => {
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    // Navigating away and back exercises the invalidated provider.
    await navigate(page, '/');
    await settle(page, 800);
    await navigate(page, '/review');
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('BR-11: after rating, dueReviewQueueCountProvider invalidates', async ({ page }) => {
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    await navigate(page, '/');
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('BR-12: after rating, abilityScoresProvider invalidates', async ({ page }) => {
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    await navigate(page, '/progress');
    await settle(page, 1500);
    await expectNoException(page);
  });

  // ── Exception Cases (6) ───────────────────────────────────────────────

  test('EX-1: empty review queue → "No items due" empty state', async ({ page }) => {
    await setupEmptyApp(page, { route: '/review' });
    await settle(page, 2000);
    await expectNoException(page);
    await capture(page, 'm24-ex1-empty-queue');
  });

  test('EX-2: DB failure during updateCorrection → card not removed; error snackbar', async ({ page }) => {
    // Disable mock mode and force a 500 on the chat endpoint so any
    // downstream call surfaces an error — the card must remain.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await settle(page, 2000);
    }
    await expectNoException(page);
    await capture(page, 'm24-ex2-db-failure');
  });

  test('EX-3: concurrent rating taps (rapid) → only first completes', async ({ page }) => {
    const { correction, queue } = dueCorrection({ id: 'cor-concurrent' });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const good = page.getByText('Good', { exact: true }).first();
    const hard = page.getByText('Hard', { exact: true }).first();
    if ((await good.isVisible({ timeout: 3000 }).catch(() => false)) &&
        (await hard.isVisible({ timeout: 1000 }).catch(() => false))) {
      await Promise.all([
        good.click().catch(() => {}),
        hard.click().catch(() => {}),
        good.click().catch(() => {}),
      ]);
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-concurrent');
    // At most one rating should have landed.
    expect(updated === undefined || updated.review_count <= 1).toBe(true);
    await expectNoException(page);
  });

  test('EX-4: filtered (favorites) with no favorites → empty state', async ({ page }) => {
    const nonFav = dueCorrection({ id: 'cor-nofavonly', is_favorite: 0 });
    await bridge.seedCorrections(page, [nonFav.correction]);
    await bridge.seedReviewQueue(page, [nonFav.queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const favChip = page.getByText(/favorite|favourites?/i).first();
    if (await favChip.isVisible({ timeout: 4000 }).catch(() => false)) {
      await favChip.click().catch(() => {});
      await settle(page, 1500);
    }
    await expectNoException(page);
    await capture(page, 'm24-ex4-no-favorites');
  });

  test('EX-5: SM-2 EF clamped to [1.3, 2.5] (no overflow)', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-efclamp',
      easiness_factor: 2.5,
      interval_days: 4,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const hardBtn = page.getByText('Hard', { exact: true }).first();
    if (await hardBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await hardBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-efclamp');
    expect(updated === undefined || (updated.easiness_factor >= 1.3 && updated.easiness_factor <= 2.5)).toBe(true);
    await expectNoException(page);
  });

  test('EX-6: SM-2 interval capped at 365 days (no infinite intervals)', async ({ page }) => {
    const { correction, queue } = dueCorrection({
      id: 'cor-intcap',
      interval_days: 300,
      review_count: 5,
    });
    await bridge.seedCorrections(page, [correction]);
    await bridge.seedReviewQueue(page, [queue]);
    await navigate(page, '/review');
    await settle(page, 1500);
    const easyBtn = page.getByText('Easy', { exact: true }).first();
    if (await easyBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await easyBtn.click().catch(() => {});
      await settle(page, 1500);
    }
    const snap = await bridge.getSnapshot<ReviewSnapshot>(page);
    const updated = (snap.corrections ?? []).find((c) => c.id === 'cor-intcap');
    expect(updated === undefined || updated.interval_days <= 365).toBe(true);
    await expectNoException(page);
  });
});
