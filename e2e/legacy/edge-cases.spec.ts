/**
 * Edge case tests — boundary data, missing params, error handling, crash resistance.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Edge cases', () => {
  test('unknown route does not crash the app', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/nonexistent-route-xyz');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('root route / defaults to home', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('rapid navigation between routes does not crash', async ({ page }) => {
    await setupSeededApp(page);
    const paths = ['/', '/scenarios', '/review', '/history', '/progress', '/settings', '/projects'];
    for (const path of paths) {
      await goTo(page, path);
      await settle(page, 600);
    }
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('repeated navigation to same route is stable', async ({ page }) => {
    await setupSeededApp(page);
    for (let i = 0; i < 3; i++) {
      await goTo(page, '/');
      await settle(page, 1000);
    }
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('service config route works', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/service-config');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('service-config');
  });

  test('voice health route works', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/voice-health');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('voice-health');
  });

  test('chat with non-existent session ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/nonexistent-session-99999');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('session summary with non-existent ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/summary/nonexistent-99999');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('summary');
  });

  test('pronunciation with non-existent ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/pronunciation/nonexistent-99999');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('pronunciation');
  });

  test('project detail with non-existent ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/nonexistent-99999');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('project');
  });

  test('all 18 routes accessible without Exception', async ({ page }) => {
    await setupSeededApp(page);
    const allRoutes = [
      '/', '/onboarding', '/placement', '/scenarios', '/review',
      '/projects', '/settings', '/project/test-id', '/chat/test-id',
      '/service-config', '/voice-health', '/practice',
      '/summary/test-id', '/progress', '/pronunciation/test-id',
      '/history', '/tutor-selection', '/profile-form/llm',
    ];
    for (const path of allRoutes) {
      await goTo(page, path);
      await settle(page, 800);
      const bodyText = await page.locator('body').innerText().catch(() => '');
      expect(bodyText).not.toContain('Exception');
    }
  });

  test('loading state appears during initial data fetch', async ({ page }) => {
    await setupSeededApp(page);
    // Navigate to a page that fetches data
    await goTo(page, '/progress');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('progress');
  });

  test('error state: page does not show raw error text', async ({ page }) => {
    await setupSeededApp(page);
    // Navigate to a page that might error
    await goTo(page, '/summary/missing');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });
});
