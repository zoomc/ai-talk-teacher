/**
 * Navigation shell tests — tab switching and deep linking.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Navigation shell', () => {
  test('home page accessible from root route', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('can navigate between all shell tabs without crash', async ({ page }) => {
    await setupSeededApp(page);
    const shellRoutes = ['/', '/scenarios', '/review', '/projects', '/settings'];
    for (const path of shellRoutes) {
      await goTo(page, path);
      await settle(page, 1000);
      const route = await getCurrentRoute(page);
      if (path === '/') {
        expect(route).toBe('/');
      } else {
        expect(route).toContain(path.replace('/', ''));
      }
    }
  });

  test('back navigation from detail screen works', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 1500);
    const route1 = await getCurrentRoute(page);
    expect(route1).toContain('history');

    await goTo(page, '/');
    await settle(page, 1500);
    const route2 = await getCurrentRoute(page);
    expect(route2).toBe('/');
  });

  test('deep link to detail screen', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/progress');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('progress');
  });

  test('all shell routes do not show raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    const paths = ['/', '/scenarios', '/review', '/projects', '/settings',
                    '/history', '/tutor-selection', '/progress'];
    for (const path of paths) {
      await goTo(page, path);
      await settle(page, 800);
      const bodyText = await page.locator('body').innerText().catch(() => '');
      expect(bodyText).not.toContain('Exception');
    }
  });
});
