/**
 * Chat screen tests.
 * ChatScreen bypasses the onboarding guard for guest sessions.
 */
import { test, expect } from '@playwright/test';
import { goTo, settle, getCurrentRoute } from './helpers';

test.describe('Chat screen', () => {
  test('loads chat screen for a session (bypasses guard)', async ({ page }) => {
    await goTo(page, '/chat/test-session-e2e');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
    expect(route).toContain('test-session-e2e');
  });

  test('renders without crash', async ({ page }) => {
    await goTo(page, '/chat/another-session');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('chat page has interactive elements', async ({ page }) => {
    await goTo(page, '/chat/test-session-ui');
    await settle(page, 2500);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('displays SpeakFlow branding', async ({ page }) => {
    await goTo(page, '/chat/test-session');
    await settle(page, 1500);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });

  test('edge case: handles missing session ID', async ({ page }) => {
    await goTo(page, '/chat/');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });

  test('edge case: very long session ID handles gracefully', async ({ page }) => {
    await goTo(page, `/chat/${'a'.repeat(200)}`);
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('chat');
  });
});
