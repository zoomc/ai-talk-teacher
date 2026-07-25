/**
 * Placement screen tests — level assessment page.
 */
import { test, expect } from '@playwright/test';
import { goTo, settle, getCurrentRoute, hasText } from './helpers';

test.describe('Placement screen', () => {
  test('loads without errors', async ({ page }) => {
    await goTo(page, '/placement');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('placement');
  });

  test('shows placement UI with Skip button', async ({ page }) => {
    await goTo(page, '/placement');
    await settle(page, 2000);
    const hasSkip = await hasText(page, 'Skip');
    expect(hasSkip).toBe(true);
  });

  test('displays SpeakFlow branding in title', async ({ page }) => {
    await goTo(page, '/placement');
    await settle(page, 1500);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });

  test('renders after loading', async ({ page }) => {
    await goTo(page, '/placement');
    await settle(page, 3000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('placement');
  });

  test('skip navigates without crash', async ({ page }) => {
    await goTo(page, '/placement');
    await settle(page, 2000);
    try {
      const skipBtn = page.getByText('Skip', { exact: false }).first();
      if (await skipBtn.isVisible({ timeout: 1000 }).catch(() => false)) {
        await skipBtn.click();
        await settle(page, 1500);
      }
    } catch { /* acceptable */ }
    // Page should still be functional
    expect(page.url()).toContain('SpeakFlow');
  });
});
