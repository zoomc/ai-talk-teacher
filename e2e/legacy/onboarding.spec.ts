/**
 * Onboarding screen tests — first-time user flow.
 */
import { test, expect } from '@playwright/test';
import { goTo, settle, getCurrentRoute, hasText, clickText } from './helpers';

test.describe('Onboarding screen', () => {
  test('loads without errors', async ({ page }) => {
    await goTo(page, '/onboarding');
    await settle(page, 2000);
    const route = await getCurrentRoute(page);
    expect(route).toContain('onboarding');
  });

  test('shows Skip for now affordance', async ({ page }) => {
    await goTo(page, '/onboarding');
    await settle(page, 2000);
    const hasSkip = await hasText(page, 'Skip');
    expect(hasSkip).toBe(true);
  });

  test('displays SpeakFlow branding', async ({ page }) => {
    await goTo(page, '/onboarding');
    await settle(page, 1500);
    const title = await page.title();
    expect(title).toContain('SpeakFlow');
  });

  test('input fields are present for provider configuration', async ({ page }) => {
    await goTo(page, '/onboarding');
    await settle(page, 2000);
    const inputs = await page.getByRole('textbox').count();
    expect(inputs).toBeGreaterThanOrEqual(1);
  });

  test('multi-page flow can navigate through pages via skip', async ({ page }) => {
    await goTo(page, '/onboarding');
    await settle(page, 2000);
    let navigatedPages = 0;
    for (let i = 0; i < 5; i++) {
      await settle(page, 500);
      const skipLabels = ['Skip', 'Skip for now', '跳过', '跳过此步'];
      let found = false;
      for (const label of skipLabels) {
        try {
          const btn = page.getByText(label, { exact: false }).first();
          if (await btn.isVisible({ timeout: 300 }).catch(() => false)) {
            await btn.click();
            await settle(page, 500);
            navigatedPages++;
            found = true;
            break;
          }
        } catch { /* continue */ }
      }
      if (!found) break;
    }
    expect(navigatedPages).toBeGreaterThanOrEqual(1);
  });
});
