/**
 * Deep-link, query param, and routing edge case tests.
 * Expands coverage for router-level behavior beyond simple page loads.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Deep link navigation', () => {
  test('direct navigation to /summary/:id loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/summary/deep-link-test-1');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('summary');
  });

  test('direct navigation to /pronunciation/:id loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/pronunciation/deep-link-test-2');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('pronunciation');
  });

  test('direct navigation to /chat/:id loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/deep-link-test-3');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('direct navigation to /project/:id loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/deep-link-test-4');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('project');
  });

  test('direct navigation to /profile-form/llm loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/llm');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('direct navigation to /profile-form/stt loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/stt');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('direct navigation to /profile-form/tts loads correctly', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/tts');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });
});

test.describe.serial('Route parameter edge cases', () => {
  test('profile form with query parameter', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/llm?edit=true');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('session ID with underscores', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/session_with_underscores');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('session ID with hyphens', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/session-with-hyphens');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('session ID with mixed case', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/MixedCaseSessionId');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('session ID with dots', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/session.id.with.dots');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });
});

test.describe.serial('Viewport and rendering', () => {
  test('renders on very small viewport (320px)', async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 568 });
    await setupSeededApp(page);
    await settle(page, 1000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('renders on tablet portrait viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('renders on tablet landscape viewport', async ({ page }) => {
    await page.setViewportSize({ width: 1024, height: 768 });
    await setupSeededApp(page);
    await goTo(page, '/');
    await settle(page, 1500);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('renders at all shell breakpoints without crash', async ({ page }) => {
    const viewports = [{ w: 320, h: 568 }, { w: 375, h: 812 }, { w: 768, h: 1024 },
                        { w: 1024, h: 768 }, { w: 1280, h: 800 }, { w: 1440, h: 900 }];
    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.w, height: vp.h });
      await setupSeededApp(page);
      await goTo(page, '/');
      await settle(page, 1000);
      const route = await getCurrentRoute(page);
      expect(route).toBe('/');
    }
  });
});

test.describe.serial('Page state persistence', () => {
  test('can return to home after visiting multiple pages', async ({ page }) => {
    await setupSeededApp(page);
    const routes = ['/scenarios', '/review', '/projects', '/settings', '/history'];
    for (const r of routes) {
      await goTo(page, r);
      await settle(page, 500);
    }
    await goTo(page, '/');
    await settle(page, 1000);
    const route = await getCurrentRoute(page);
    expect(route).toBe('/');
  });

  test('can navigate to chat from seeding state', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/chat/nav-test-session');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('can navigate to all LLM/STT/TTS profile forms', async ({ page }) => {
    await setupSeededApp(page);
    const types = ['llm', 'stt', 'tts'];
    for (const t of types) {
      await goTo(page, `/profile-form/${t}`);
      await settle(page, 1000);
      const route = await getCurrentRoute(page);
      expect(route).toContain('profile-form');
    }
  });
});
