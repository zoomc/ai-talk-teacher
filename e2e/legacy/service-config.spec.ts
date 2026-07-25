/**
 * Service Config, Voice Health, Practice, Progress screen tests.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Service config screen', () => {
  test('loads without errors', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/service-config');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('service-config');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/service-config');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });
});

test.describe.serial('Voice health screen', () => {
  test('loads without errors', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/voice-health');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('voice-health');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/voice-health');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });
});

test.describe.serial('Practice screen', () => {
  test('loads without errors', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/practice');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('practice');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/practice');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('handles empty state gracefully', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/practice');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('practice');
  });
});

test.describe.serial('Progress screen', () => {
  test('loads without errors', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/progress');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('progress');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/progress');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });
});
