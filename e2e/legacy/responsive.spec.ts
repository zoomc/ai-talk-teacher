/**
 * Responsive layout tests — verify pages render on mobile and desktop viewports.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Responsive layouts', () => {
  const SHELL_PAGES = [
    { path: '/', name: 'Home' },
    { path: '/scenarios', name: 'Scenarios' },
    { path: '/review', name: 'Review' },
    { path: '/projects', name: 'Projects' },
    { path: '/settings', name: 'Settings' },
  ];

  for (const { path, name } of SHELL_PAGES) {
    test(`${name}: mobile 375px viewport renders without crash`, async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 812 });
      await setupSeededApp(page);
      await goTo(page, path);
      await settle(page, 1500);
      const route = await getCurrentRoute(page);
      if (path === '/') expect(route).toBe('/');
      else expect(route).toContain(path.replace('/', ''));
    });

    test(`${name}: desktop 1280px viewport renders without crash`, async ({ page }) => {
      await page.setViewportSize({ width: 1280, height: 800 });
      await setupSeededApp(page);
      await goTo(page, path);
      await settle(page, 1500);
      const route = await getCurrentRoute(page);
      if (path === '/') expect(route).toBe('/');
      else expect(route).toContain(path.replace('/', ''));
    });
  }

  test('detail screens render at mobile width without crash', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    const paths = ['/history', '/progress', '/tutor-selection', '/practice'];
    for (const path of paths) {
      await goTo(page, path);
      await settle(page, 1000);
      const bodyText = await page.locator('body').innerText().catch(() => '');
      expect(bodyText).not.toContain('Exception');
    }
  });

  test('detail screens render at desktop width without crash', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await setupSeededApp(page);
    const paths = ['/history', '/progress', '/tutor-selection', '/practice'];
    for (const path of paths) {
      await goTo(page, path);
      await settle(page, 1000);
      const bodyText = await page.locator('body').innerText().catch(() => '');
      expect(bodyText).not.toContain('Exception');
    }
  });

  test('tablet viewport (768px) renders shell pages without crash', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await setupSeededApp(page);
    const paths = ['/', '/scenarios', '/review', '/projects', '/settings'];
    for (const path of paths) {
      await goTo(page, path);
      await settle(page, 1000);
      const route = await getCurrentRoute(page);
      if (path === '/') expect(route).toBe('/');
      else expect(route).toContain(path.replace('/', ''));
    }
  });
});
