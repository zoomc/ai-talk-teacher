/**
 * Redirect guard tests — verify onboarding/placement redirect logic.
 */
import { test, expect } from '@playwright/test';
import { goTo, settle, getCurrentRoute, waitForApp } from './helpers';

test.describe('Redirect guards', () => {
  test('un-onboarded user redirects from / to /onboarding', async ({ page }) => {
    await waitForApp(page);
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('onboarding');
  });

  test('/onboarding loads directly without redirect', async ({ page }) => {
    await goTo(page, '/onboarding');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('onboarding');
  });

  test('/placement loads directly (accessible without onboarding)', async ({ page }) => {
    await goTo(page, '/placement');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('placement');
  });

  test('deep link /chat/:sessionId bypasses onboarding guard', async ({ page }) => {
    await goTo(page, '/chat/test-session-bypass');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('page renders SpeakFlow title', async ({ page }) => {
    await waitForApp(page);
    await settle(page, 1500);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });
});
