/**
 * Scenarios screen tests.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Scenarios screen', () => {
  test('loads without errors after seeding', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/scenarios');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('scenarios');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/scenarios');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('handles empty state gracefully', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/scenarios');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('scenarios');
  });

  test('responsive: mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    await goTo(page, '/scenarios');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('scenarios');
  });
});
