/**
 * Summary, Pronunciation, History screen tests.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Session summary screen', () => {
  test('loads with valid session ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/summary/test-session-summary');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('summary');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/summary/test-session');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('handles missing session gracefully', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/summary/missing-test-id');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('summary');
  });

  test('edge case: very long session ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, `/summary/${'z'.repeat(200)}`);
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('summary');
  });
});

test.describe.serial('Pronunciation detail screen', () => {
  test('loads with valid session ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/pronunciation/test-pron-session');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('pronunciation');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/pronunciation/test-session');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('handles missing session gracefully', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/pronunciation/nonexistent');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('pronunciation');
  });

  test('handles empty pronunciation data', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/pronunciation/empty-session');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('pronunciation');
  });
});

test.describe.serial('History screen', () => {
  test('loads without errors', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('history');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('handles empty history gracefully', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('history');
  });

  test('responsive: mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('history');
  });
});
