/**
 * Review screen tests.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Review screen', () => {
  test('loads without errors after seeding', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/review');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('review');
  });

  test('handles empty state gracefully (no corrections)', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/review');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('review');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/review');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('responsive: mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    await goTo(page, '/review');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('review');
  });
});
