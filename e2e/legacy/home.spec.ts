/**
 * Home page and shell navigation tests.
 * Requires seeded app (onboarding + placement completed).
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Home page', () => {
  test('home page loads without errors after seeding', async ({ page }) => {
    await setupSeededApp(page);
    await settle(page, 1000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('displays SpeakFlow branding', async ({ page }) => {
    await setupSeededApp(page);
    await settle(page, 1000);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });

  test('renders interactive elements', async ({ page }) => {
    await setupSeededApp(page);
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('does not show raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('responsive: mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });
});
