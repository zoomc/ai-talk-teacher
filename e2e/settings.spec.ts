/**
 * Settings screen tests.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Settings screen', () => {
  test('loads without errors after seeding', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('settings');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('displays SpeakFlow branding', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 1500);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });

  test('responsive: mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('settings');
  });
});
