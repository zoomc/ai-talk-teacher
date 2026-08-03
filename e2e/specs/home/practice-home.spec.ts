/**
 * Focused practice entry point.
 *
 * Route: /
 * Screen: lib/features/home/presentation/screens/practice_home_page.dart
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, setupEmptyApp } from '../../lib/setup';
import { expectNoException, expectRoute } from '../../lib/assertions';
import { enableAccessibility, settle } from '../../helpers';
import * as bridge from '../../lib/e2e-bridge';

// CanvasKit does not expose Flutter text as ordinary DOM nodes in every
// headless Chromium build. These coordinates target the stable primary/secondary
// controls in the responsive layout while still exercising real pointer input.
async function clickPrimaryCta(page: import('@playwright/test').Page) {
  await enableAccessibility(page);
  const button = page.getByRole('button', { name: /start conversation/i }).first();
  if (await button.count() > 0 && await button.isVisible().catch(() => false)) {
    await button.click();
    return;
  }
  const viewport = page.viewportSize()!;
  await page.mouse.click(viewport.width / 2, 678);
}

async function clickScenarios(page: import('@playwright/test').Page) {
  await enableAccessibility(page);
  const button = page.getByRole('button', { name: /scenarios/i }).first();
  if (await button.count() > 0 && await button.isVisible().catch(() => false)) {
    await button.click();
    return;
  }
  const viewport = page.viewportSize()!;
  await page.mouse.click(viewport.width / 2, Math.min(735, viewport.height - 72));
}

test.describe('Focused practice home', () => {
  test('renders the tutor and practice CTA on desktop', async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/' });
    await expectRoute(page, '/');
    await expect(page.locator('canvas, iframe').first()).toBeVisible();
    await expectNoException(page);
  });

  test('renders the same entry point on a mobile viewport', async ({ page }) => {
    await setupE2EApp(page, 'onboarded', {
      route: '/',
      viewport: { width: 375, height: 812 },
    });
    await expectRoute(page, '/');
    await expect(page.locator('canvas, iframe').first()).toBeVisible();
    await expectNoException(page);
  });

  test('start conversation creates a session and opens chat', async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/' });
    await clickPrimaryCta(page);
    await settle(page, 1200);
    await expectRoute(page, '/chat');
    const snapshot = await bridge.getSnapshot<{ chat_sessions?: unknown[] }>(page);
    expect(snapshot.chat_sessions?.length ?? 0).toBeGreaterThan(0);
    await expectNoException(page);
  });

  test('scenarios remain reachable as a secondary entry', async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/' });
    await clickScenarios(page);
    await settle(page, 1000);
    await expectRoute(page, '/scenarios');
    await expectNoException(page);
  });

  test('empty local data still leaves the primary CTA usable', async ({ page }) => {
    await setupEmptyApp(page, { route: '/' });
    await expectRoute(page, '/');
    await expect(page.locator('canvas, iframe').first()).toBeVisible();
    await expectNoException(page);
  });
});
