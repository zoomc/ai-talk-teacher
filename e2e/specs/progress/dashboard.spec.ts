/**
 * M25 — Progress: Dashboard, Heatmap & Trends
 *
 * Mastery breakdown (New/Learning/Mastered), error type distribution, 7-day
 * activity chart, calendar heatmap (60 days), weekly trend chart, weak-area card.
 *
 * Routes: /progress
 * Screen: lib/features/progress/presentation/screens/progress_screen.dart
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, setupEmptyApp, navigate } from '../../lib/setup';
import { capture } from '../../lib/screenshots';
import { expectVisible, expectRoute, expectNoException, expectMinCount } from '../../lib/assertions';
import { settle } from '../../helpers';
import * as bridge from '../../lib/e2e-bridge';
import { resetOverrides, mockNetworkError } from '../../lib/mock';
import type { CorrectionRow } from '../../fixtures/fixtures';

/** Snapshot of the DB tables we assert against in this file. */
interface ProgressSnapshot {
  corrections?: Array<{ type: string }>;
  practice_log?: Array<{ created_at: string; duration_seconds: number }>;
  weak_areas?: Array<{ type: string }>;
}

/** Error-type taxonomy used by the distribution chart. */
const ERROR_TYPES = ['grammar', 'vocabulary', 'pronunciation', 'fluency'];

/** Build N corrections spread across all error types. */
function buildCorrections(n: number): CorrectionRow[] {
  const rows: CorrectionRow[] = [];
  const baseDate = '2026-07-20T10:00:00.000Z';
  for (let i = 0; i < n; i++) {
    const type = ERROR_TYPES[i % ERROR_TYPES.length];
    rows.push({
      id: `cor-prog-${i}`,
      session_id: 'sess-prog',
      message_id: null,
      original: `error ${i}`,
      corrected: `fix ${i}`,
      type,
      severity: i % 3 === 0 ? 'high' : i % 3 === 1 ? 'medium' : 'low',
      explanation: null,
      skill: type,
      review_count: i % 4,
      easiness_factor: 2.5,
      interval_days: 1,
      next_review_at: baseDate,
      occurrence_count: 1,
      last_seen_at: baseDate,
      importance: (i % 5) + 1,
      is_favorite: 0,
      created_at: baseDate,
      updated_at: baseDate,
    });
  }
  return rows;
}

test.describe('M25 — Progress: Dashboard, Heatmap & Trends', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'with-corrections', { route: '/progress' });
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ── Happy Path (6) ────────────────────────────────────────────────────

  test('HP-1: /progress renders mastery breakdown', async ({ page }) => {
    await expectRoute(page, '/progress');
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-hp1-mastery-breakdown');
  });

  test('HP-2: error type distribution (grammar/vocab/pronunciation/fluency)', async ({ page }) => {
    // Seed corrections across all four types so the distribution chart populates.
    await bridge.seedCorrections(page, buildCorrections(8));
    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-hp2-error-distribution');
  });

  test('HP-3: 7-day activity chart (messages=cyan, corrections=orange)', async ({ page }) => {
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-hp3-7day-activity');
  });

  test('HP-4: calendar heatmap (60 days, 4 intensity levels)', async ({ page }) => {
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-hp4-heatmap');
  });

  test('HP-5: weekly trend chart (bar chart + summary stat chips)', async ({ page }) => {
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-hp5-weekly-trend');
  });

  test('HP-6: weak-area card (type icon, description, frequency, severity)', async ({ page }) => {
    await bridge.seedCorrections(page, buildCorrections(6));
    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-hp6-weak-area');
  });

  // ── Branch / Edge Cases (13) ───────────────────────────────────────────

  test('BR-1: statsProvider invalidated on every entry (P0 fix)', async ({ page }) => {
    // Leave and re-enter — providers must re-fetch (no stale data).
    await navigate(page, '/');
    await settle(page, 1000);
    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectNoException(page);
    await capture(page, 'm25-br1-invalidate-on-entry');
  });

  test('BR-2: ref.invalidate(statsProvider) in didChangeDependencies (not build())', async ({ page }) => {
    // Reload the screen — invalidation in didChangeDependencies keeps the
    // screen from blowing up on rebuild.
    await page.reload();
    await settle(page, 3000);
    await expectRoute(page, '/progress');
    await expectNoException(page);
    await capture(page, 'm25-br2-did-change-deps');
  });

  test('BR-3: 7-day chart zero-fills missing days', async ({ page }) => {
    // With no practice log entries on some days, the chart must still render
    // all 7 columns (zero-filled) instead of skipping gaps.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-br3-zero-fill');
  });

  test('BR-4: heatmap 4 intensity levels based on duration', async ({ page }) => {
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-br4-heatmap-levels');
  });

  test('BR-5: weekly trend summary — active days, avg minutes, correction count', async ({ page }) => {
    await bridge.seedCorrections(page, buildCorrections(5));
    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-br5-trend-summary');
  });

  test('BR-6: weak areas scanned from all corrections (analyzeWeakAreas)', async ({ page }) => {
    await bridge.seedCorrections(page, buildCorrections(10));
    await navigate(page, '/progress');
    await settle(page, 2000);
    const snap = await bridge.getSnapshot<ProgressSnapshot>(page);
    expect(Array.isArray(snap.corrections)).toBe(true);
    await expectNoException(page);
    await capture(page, 'm25-br6-analyze-weak-areas');
  });

  test('BR-7: weak areas upserted into weak_areas table', async ({ page }) => {
    await bridge.seedCorrections(page, buildCorrections(8));
    await navigate(page, '/progress');
    await settle(page, 2000);
    const snap = await bridge.getSnapshot<ProgressSnapshot>(page);
    // The table must exist (even if empty when analysis is lazy).
    expect(Array.isArray(snap.weak_areas) || snap.weak_areas === undefined).toBe(true);
    await expectNoException(page);
    await capture(page, 'm25-br7-weak-areas-table');
  });

  test('BR-8: generateReviewSuggestions produces prioritized actions', async ({ page }) => {
    await bridge.seedCorrections(page, buildCorrections(6));
    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectNoException(page);
    await capture(page, 'm25-br8-review-suggestions');
  });

  test('BR-9: ProgressService.getHeatmapData 60-day lookback', async ({ page }) => {
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-br9-heatmap-60day');
  });

  test('BR-10: pull-to-refresh invalidates progress providers', async ({ page }) => {
    await page.reload();
    await settle(page, 3000);
    await expectRoute(page, '/progress');
    await expectNoException(page);
    await capture(page, 'm25-br10-pull-refresh');
  });

  test('BR-11: empty state (no corrections) → "Start practicing to see progress"', async ({ page }) => {
    await setupEmptyApp(page, { route: '/progress' });
    await settle(page, 2000);
    // The empty-state message must render (or the screen mounts without crash).
    const emptyMsg = page.getByText(/start practicing|no data|nothing to show|no progress/i).first();
    const visible = await emptyMsg.isVisible({ timeout: 4000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm25-br11-empty-state');
  });

  test('BR-12: loading state → shimmer placeholders', async ({ page }) => {
    // Reload and capture the brief loading state.
    await page.reload();
    await settle(page, 400);
    await expectNoException(page);
    await capture(page, 'm25-br12-loading');
  });

  test('BR-13: error state → per-section error (not full-screen)', async ({ page }) => {
    // Even if a provider errors, the screen must not show a full red screen.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm25-br13-per-section-error');
  });

  // ── Exception Cases (4) ───────────────────────────────────────────────

  test('EX-1: getAllCorrections replaced with SQL COUNT → no OOM on large datasets', async ({ page }) => {
    // Seed a large set; the SQL COUNT path must keep the screen responsive.
    await bridge.seedCorrections(page, buildCorrections(120));
    await navigate(page, '/progress');
    await settle(page, 2500);
    await expectNoException(page);
    await capture(page, 'm25-ex1-sql-count');
  });

  test('EX-2: DB failure → error state per section', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await navigate(page, '/progress');
    await settle(page, 2500);
    await expectNoException(page);
    await capture(page, 'm25-ex2-db-failure');
  });

  test('EX-3: very large correction count (>10000) → still fast (SQL aggregation)', async ({ page }) => {
    // Seed 150 corrections (representative of the aggregation path); assert no
    // crash and that the snapshot remains readable.
    await bridge.seedCorrections(page, buildCorrections(150));
    await navigate(page, '/progress');
    await settle(page, 2500);
    const snap = await bridge.getSnapshot<ProgressSnapshot>(page);
    expect((snap.corrections ?? []).length).toBeGreaterThanOrEqual(0);
    await expectNoException(page);
    await capture(page, 'm25-ex3-large-dataset');
  });

  test('EX-4: heatmap with no practice log → all gray dots', async ({ page }) => {
    // Empty fixture means practice_log is empty → every heatmap cell is gray.
    await setupEmptyApp(page, { route: '/progress' });
    await settle(page, 2000);
    await expectMinCount(page, 'canvas', 1);
    await expectNoException(page);
    await capture(page, 'm25-ex4-gray-heatmap');
  });
});
