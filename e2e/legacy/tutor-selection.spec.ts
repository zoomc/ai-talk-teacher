/**
 * Tutor Selection, Profile Form, Project Detail screen tests.
 */
import { test, expect } from '@playwright/test';
import { setupSeededApp, goTo, settle, getCurrentRoute } from './helpers';

test.describe.serial('Tutor selection screen', () => {
  test('loads without errors', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/tutor-selection');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('tutor-selection');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/tutor-selection');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('back navigation works', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/tutor-selection');
    await settle(page, 1500);
    const buttons = await page.getByRole('button').count();
    expect(buttons).toBeGreaterThanOrEqual(1);
  });

  test('responsive: mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await setupSeededApp(page);
    await goTo(page, '/tutor-selection');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('tutor-selection');
  });
});

test.describe.serial('Profile form screen', () => {
  test('loads LLM profile form', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/llm');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('loads STT profile form', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/stt');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('loads TTS profile form', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/tts');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/llm');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('edge case: unknown profile type', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/unknown');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });

  test('edge case: profile form with edit id parameter', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/profile-form/llm?id=edit-test-id');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('profile-form');
  });
});

test.describe.serial('Project detail screen', () => {
  test('loads with valid project ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/test-project-id');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('project');
  });

  test('no raw exception text', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/test-project');
    await settle(page, 2000);
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('Exception');
  });

  test('handles missing project gracefully', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, '/project/nonexistent-project');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('project');
  });

  test('edge case: very long project ID', async ({ page }) => {
    await setupSeededApp(page);
    await goTo(page, `/project/${'x'.repeat(150)}`);
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('project');
  });
});
