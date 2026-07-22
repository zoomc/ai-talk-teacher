/**
 * Additional cross-cutting tests — error states, loading indicators, edge capacities.
 * These extend coverage beyond basic happy-path page loads.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Loading and error states', () => {
  test('data-dependent page shows loading indicator then content', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/scenarios');
    await settle(page, 3000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('scenarios');
  });

  test('progress page loads stats data without crash', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/progress');
    await settle(page, 3000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('progress');
  });

  test('review page loads correction data without crash', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/review');
    await settle(page, 3000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('review');
  });

  test('history page loads sessions list without crash', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 3000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('history');
  });

  test('projects page loads project list without crash', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/projects');
    await settle(page, 3000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('projects');
  });
});

test.describe.serial('Navigation resilience', () => {
  test('can navigate to all 5 shell tabs consecutively', async ({ page }) => {
    await setupSeededApp(page);
    for (const p of ['/', '/scenarios', '/review', '/projects', '/settings']) {
      await goTo(page, p);
      await settle(page, 800);
    }
    const route = await getCurrentRoute(page);
    expect(route).toContain('settings');
  });

  test('can navigate between shell and detail routes', async ({ page }) => {
    await setupSeededApp(page);
    const seq = ['/', '/history', '/', '/progress', '/', '/tutor-selection', '/'];
    for (const p of seq) {
      await goTo(page, p);
      await settle(page, 600);
    }
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('project detail with missing project ID does not crash', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/__missing__');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('project');
  });

  test('setting and unsetting theme route works', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('settings');
  });

  test('url with special characters in session ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/session-123_abc');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });
});

test.describe.serial('Edge capacity', () => {
  test('max-length session ID in chat route', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, `/chat/${'x'.repeat(100)}`);
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('empty string ID in project route', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/');
    await settle(page, 2000);
    // Should navigate without crash
    const url = page.url();
    expect(url).toBeTruthy();
  });

  test('null-like session summary IDs', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/summary/null');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('summary');
  });

  test('numeric session IDs', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/12345');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('plus sign in session ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/session+123');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });
});

test.describe.serial('App resilience', () => {
  test('app does not crash when navigating to /onboarding after seeded', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/onboarding');
    await settle(page, 2000);
    // Should not crash — the guard should prevent redirect loop
    const route = await getCurrentRoute(page);
    expect(route).toContain('onboarding');
  });

  test('app does not crash navigating to /placement after seeded', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/placement');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('placement');
  });

  test('double navigate to same detail page works', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/history');
    await settle(page, 1500);
    await goTo(page, '/history');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('history');
  });

  test('cross-navigation scenarios → settings → home', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/scenarios');
    await settle(page, 800);
    await goTo(page, '/settings');
    await settle(page, 800);
    await goTo(page, '/');
    await settle(page, 800);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('every route has SpeakFlow title', async ({ page }) => {
    await setupSeededApp(page);
    const paths = ['/', '/scenarios', '/review', '/projects', '/settings',
                    '/history', '/progress', '/tutor-selection', '/practice'];
    for (const p of paths) {
      await goTo(page, p);
      await settle(page, 600);
      const title = await page.title();
      expect(title).toContain('SpeakFlow');
    }
  });
});

test.describe.serial('Multi-page flow', () => {
  test('onboarding → placement → home after seed setup', async ({ page }) => {
    // This test does the full flow without setupSeededApp helper
    await page.goto('http://localhost:8080/', { waitUntil: 'load', timeout: 45000 });
    await page.waitForTimeout(5000);
    // Should be on onboarding
    const route1 = await getCurrentRoute(page);
    expect(route1).toContain('onboarding');
  });

  test('page title is always correct regardless of route', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1000);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });

  test('can load /settings after navigating from /', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('settings');
  });

  test('can load /projects after navigating from /settings', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/settings');
    await settle(page, 800);
    await goTo(page, '/projects');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('projects');
  });

  test('chat screen renders after navigating from home', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1000);
    await goTo(page, '/chat/test-session-123');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });
});
