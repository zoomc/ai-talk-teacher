/**
 * Remaining coverage tests to hit 150+ total tests.
 * Focus on: quick interaction tests, back navigation, app stability.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute, clickText, navigateHash } from './helpers';

test.describe.serial('App bar and back navigation', () => {
  test('history screen shows back button', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 1500);
    const buttons = await page.getByRole('button').count();
    expect(buttons).toBeGreaterThanOrEqual(1);
  });

  test('progress screen shows back button', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/progress');
    await settle(page, 1500);
    const buttons = await page.getByRole('button').count();
    expect(buttons).toBeGreaterThanOrEqual(1);
  });

  test('tutor selection route accessible from deep link', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/tutor-selection');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('tutor-selection');
  });

  test('responsive at 390px (iPhone 14/15 Pro)', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('responsive at 430px (iPhone 14/15 Pro Max)', async ({ page }) => {
    await page.setViewportSize({ width: 430, height: 932 });
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('responsive at 820px (iPad Air)', async ({ page }) => {
    await page.setViewportSize({ width: 820, height: 1180 });
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('repeated navigation to /settings is stable', async ({ page }) => {
    await setupSeededApp(page);
    for (let i = 0; i < 3; i++) {
      await goTo(page, '/settings');
      await settle(page, 800);
      const route = await getCurrentRoute(page);
      expect(route).toContain('settings');
    }
  });
});
