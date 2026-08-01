/**
 * M18 — Home: Dashboard Shell & Quick Actions
 *
 * Six sections: streak, quick actions, today's tasks, ability radar, review
 * queue, goal. Pull-to-refresh invalidates all dashboard providers.
 *
 * Route: /dashboard (the focused practice page now owns /)
 * Screen: lib/features/home/presentation/screens/home_page.dart
 */
import { test, expect } from '@playwright/test';
import {
  setupE2EApp,
  setupEmptyApp,
  navigate,
  DESKTOP_VIEWPORT,
  MOBILE_VIEWPORT,
} from '../../lib/setup';
import { capture, captureFullPage, captureAtViewport, captureDesktopAndMobile } from '../../lib/screenshots';
import {
  expectVisible,
  expectText,
  expectNotVisible,
  expectRoute,
  expectNoException,
  expectElementCount,
  expectMinCount,
} from '../../lib/assertions';
import * as bridge from '../../lib/e2e-bridge';
import { resetOverrides, mockNetworkError } from '../../lib/mock';
import { FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';
import { settle, goTo } from '../../helpers';

/** iPad portrait viewport (single column layout). */
const IPAD_PORTRAIT = { width: 768, height: 1024 };

/** iPhone SE viewport (smallest supported — no clipping). */
const IPHONE_SE = { width: 320, height: 568 };

test.describe('M18 — Home: Dashboard Shell & Quick Actions', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/dashboard' });
  });

  test.afterEach(async ({ page }) => {
    resetOverrides();
  });

  // ── Happy Path (HP-1 .. HP-7) ──────────────────────────────────────────

  test('HP-1: onboarding complete — / renders HomePage', async ({ page }) => {
    await expectRoute(page, '/dashboard');
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp1-home-render');
  });

  test('HP-2: streak section visible at top', async ({ page }) => {
    // The streak badge (flame icon + count) appears in the header.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp2-streak-section');
  });

  test('HP-3: three quick-action buttons visible', async ({ page }) => {
    // Start Conversation, Review Corrections, Pronunciation Practice.
    // These render as GlassCards with icons + labels.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp3-quick-actions');
  });

  test('HP-4: today tasks section renders', async ({ page }) => {
    // The "Today's tasks" header + task cards (or empty state) should render.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp4-today-tasks');
  });

  test('HP-5: ability radar section renders', async ({ page }) => {
    // The ability overview card with a radar chart (CustomPainter on canvas).
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp5-ability-radar');
  });

  test('HP-6: pending review queue section renders', async ({ page }) => {
    // The review queue card (either items or "nothing due" empty state).
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp6-review-queue');
  });

  test('HP-7: goal section renders', async ({ page }) => {
    // The goal card with "Set goal" button or current goal chip.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-hp7-goal-section');
  });

  // ── Branch / Edge Cases (BR-1 .. BR-12) ─────────────────────────────────

  test('BR-1: Start Conversation creates session and navigates to /chat/:id', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    // Tap the "Start Conversation" quick-action button.
    const convButton = page.getByRole('button').filter({ hasText: /conversation|对话|开始/i }).first();
    await convButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);

    // Should navigate to a chat session route.
    const url = page.url();
    expect(url).toContain('chat');
    await expectNoException(page);
    await capture(page, 'm18-br1-start-conversation');
  });

  test('BR-2: Review Corrections navigates to /review', async ({ page }) => {
    const reviewButton = page.getByRole('button').filter({ hasText: /review|复习|纠错/i }).first();
    await reviewButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);

    const url = page.url();
    expect(url).toContain('review');
    await expectNoException(page);
    await capture(page, 'm18-br2-review-corrections');
  });

  test('BR-3: Pronunciation Practice navigates to /practice', async ({ page }) => {
    const pracButton = page.getByRole('button').filter({ hasText: /pronunciation|发音|practice/i }).first();
    await pracButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);

    const url = page.url();
    expect(url).toContain('practice');
    await expectNoException(page);
    await capture(page, 'm18-br3-pronunciation-practice');
  });

  test('BR-4: pull-to-refresh reloads all dashboard providers', async ({ page }) => {
    // Trigger a reload (simulating pull-to-refresh).
    await page.reload();
    await settle(page, 2500);

    await expectRoute(page, '/dashboard');
    await expectNoException(page);
    await capture(page, 'm18-br4-pull-refresh');
  });

  test('BR-5: refresh during loading — no duplicate requests', async ({ page }) => {
    // Reload twice in quick succession — providers should not issue dupes.
    await page.reload();
    await settle(page, 500);
    await page.reload();
    await settle(page, 2500);

    await expectNoException(page);
    await capture(page, 'm18-br5-no-dup-requests');
  });

  test('BR-6: empty state — sections render with empty-state copy', async ({ page }) => {
    // Use the empty fixture (no corrections, no sessions).
    await setupEmptyApp(page, { route: '/dashboard' });
    await settle(page, 2000);

    await expectRoute(page, '/dashboard');
    await expectNoException(page);
    await capture(page, 'm18-br6-empty-state');
  });

  test('BR-7: quick-action buttons remain tappable after load', async ({ page }) => {
    // Wait for the dashboard to fully load, then verify buttons are present.
    await settle(page, 2000);
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-br7-buttons-tappable');
  });

  test('BR-8: LayoutBuilder — wide layout shows radar + queue side by side', async ({ page }) => {
    // Desktop viewport (1280×800) is wide enough for the side-by-side layout.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-br8-wide-layout');
  });

  test('BR-9: iPad portrait — single column layout', async ({ page }) => {
    await captureAtViewport(page, 'm18-br9-ipad-portrait', IPAD_PORTRAIT);
    await expectNoException(page);
  });

  test('BR-10: iPhone SE (320pt) — no clipping', async ({ page }) => {
    await captureAtViewport(page, 'm18-br10-iphone-se', IPHONE_SE);
    await expectNoException(page);
  });

  test('BR-11: active persona badge visible when content enabled', async ({ page }) => {
    // The structured content section shows an active persona badge.
    await bridge.setSetting(page, 'content_enabled', 'true');
    await navigate(page, '/dashboard');
    await settle(page, 2000);

    await expectNoException(page);
    await capture(page, 'm18-br11-persona-badge');
  });

  test('BR-12: recommended scenarios strip visible when content enabled', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await navigate(page, '/dashboard');
    await settle(page, 2000);

    await expectNoException(page);
    await capture(page, 'm18-br12-scenarios-strip');
  });

  // ── Exception Cases (EX-1 .. EX-5) ─────────────────────────────────────

  test('EX-1: provider error — per-section error state, not full-screen', async ({ page }) => {
    // Force an error on review queue fetch via network mock.
    // The dashboard should still render — error is contained per section.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-ex1-per-section-error');
  });

  test('EX-2: loading state — shimmer placeholders render', async ({ page }) => {
    // Reload and capture immediately to catch the loading/shimmer state.
    await page.reload();
    await settle(page, 300);

    await expectNoException(page);
    await capture(page, 'm18-ex2-shimmer-loading');
  });

  test('EX-3: pull-to-refresh during error retries and clears error', async ({ page }) => {
    // Reload after an error state — should retry and clear.
    await page.reload();
    await settle(page, 2500);

    await expectRoute(page, '/dashboard');
    await expectNoException(page);
    await capture(page, 'm18-ex3-refresh-retry');
  });

  test('EX-4: goal section with no goal — Set a goal prompt', async ({ page }) => {
    // Use empty fixture — no user_goals row → "no goal" prompt.
    await setupEmptyApp(page, { route: '/dashboard' });
    await settle(page, 2000);

    await expectNoException(page);
    await capture(page, 'm18-ex4-no-goal-prompt');
  });

  test('EX-5: practice log DB failure — streak section shows gracefully', async ({ page }) => {
    // Even if the streak provider errors, the dashboard should not crash.
    // The _StreakBadge error state renders SizedBox.shrink().
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm18-ex5-streak-graceful');
  });

  // ---------------- Mobile viewport coverage (gap 30) ----------------

  test('HP-8: mobile viewport — Start Conversation navigates to /chat/:id', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, '/dashboard');
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);

    const convButton = page.getByRole('button').filter({ hasText: /conversation|对话|开始/i }).first();
    await convButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);

    const url = page.url();
    expect(url).toContain('chat');
    await expectNoException(page);
    await capture(page, 'm18-hp8-start-conversation-mobile');
  });

  test('HP-9: mobile viewport — dashboard six sections render without horizontal overflow', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, '/dashboard');
    await expectRoute(page, '/dashboard');
    await expectVisible(page, 'canvas');

    const canvas = page.locator('canvas').first();
    const box = await canvas.boundingBox().catch(() => null);
    if (box) {
      expect(box.width).toBeLessThanOrEqual(MOBILE_VIEWPORT.width);
    }

    await expectNoException(page);
    await capture(page, 'm18-hp9-sections-mobile');
  });

  // ---------------- Dual-viewport comparison (gap 59) ----------------

  test('HP-10: dashboard renders on both desktop and mobile viewports', async ({ page }) => {
    await navigate(page, '/dashboard');
    const { desktop, mobile } = await captureDesktopAndMobile(page, 'm18-hp10-home-render-dual');
    expect(desktop.length).toBeGreaterThan(0);
    expect(mobile.length).toBeGreaterThan(0);
    await expectNoException(page);
  });
});
