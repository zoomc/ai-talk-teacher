/**
 * E2E test helpers for SpeakFlow Flutter web app.
 * Flutter uses hash-based routing (#/route), so all URL parsing
 * must extract the hash fragment.
 */

import { Page } from '@playwright/test';

/** Base URL for the app under test */
export const BASE_URL = process.env.E2E_BASE_URL || 'http://localhost:8080';

/** Max time to wait for Flutter app to boot */
const APP_LOAD_MS = 45000;

/**
 * Wait for the Flutter app to finish loading.
 */
export async function waitForApp(page: Page) {
  await page.goto(BASE_URL, { waitUntil: 'load', timeout: APP_LOAD_MS });
  await waitForFlutterReady(page);
}

/**
 * Navigate to a route within the Flutter app using hash routing.
 */
export async function goTo(page: Page, path: string) {
  // Flutter web uses hash routing, navigate via hash
  await page.goto(`${BASE_URL}/#${path}`, { waitUntil: 'load', timeout: 30000 });
  await waitForFlutterReady(page);
}

/**
 * Navigate to a route using hash change (faster, no full reload).
 */
export async function navigateHash(page: Page, path: string) {
  await page.evaluate((p) => { window.location.hash = p; }, path);
  // Wait a bit for Flutter's GoRouter to process the hash change
  await page.waitForTimeout(2000);
}

/**
 * Wait for Flutter to be ready: splash removed + canvas present.
 */
async function waitForFlutterReady(page: Page) {
  try {
    await page.waitForFunction(
      () => !document.querySelector('#splash') ||
             document.querySelector('#splash')?.classList.contains('gone'),
      { timeout: 25000 }
    );
  } catch {
    // Splash might already be gone
  }

  // Wait for the Flutter canvas
  try {
    await page.waitForSelector('canvas', { state: 'attached', timeout: 15000 });
  } catch {
    // Canvas may not be present yet
  }

  // Essential settle time for Flutter initial render + async init
  await page.waitForTimeout(3000);
}

/**
 * Wait briefly for Flutter frame render after interactions.
 */
export async function settle(page: Page, ms = 1200) {
  await page.waitForTimeout(ms);
}

/**
 * Get the current Flutter route from the URL hash.
 */
export async function getCurrentRoute(page: Page): Promise<string> {
  const url = page.url();
  try {
    const u = new URL(url);
    // Flutter hash: #/route or #/route/param
    const hash = u.hash || '';
    // Remove leading '#', return the path
    return hash.replace(/^#/, '') || '/';
  } catch {
    return url;
  }
}

/**
 * Check if text is visible anywhere in the page body.
 */
export async function hasText(page: Page, text: string): Promise<boolean> {
  try {
    const bodyText = await page.locator('body').innerText().catch(() => '');
    if (bodyText.includes(text)) return true;
  } catch {
    // fall through
  }
  return false;
}

/**
 * Click a button or element by its text.
 */
export async function clickText(page: Page, text: string) {
  await page.getByText(text, { exact: false }).first().click({ timeout: 5000 }).catch(() => {});
  await settle(page);
}

/**
 * Try to skip the current onboarding/placement page.
 */
async function trySkipPage(page: Page): Promise<boolean> {
  const skipVariants = ['Skip', 'Skip for now', '跳过', '跳过此步'];
  for (const label of skipVariants) {
    try {
      const btn = page.getByText(label, { exact: false }).first();
      if (await btn.isVisible({ timeout: 300 }).catch(() => false)) {
        await btn.click();
        await settle(page, 600);
        return true;
      }
    } catch {
      // try next variant
    }
  }
  return false;
}

/**
 * Complete the onboarding flow by skipping through all pages.
 */
export async function completeOnboarding(page: Page) {
  await goTo(page, '/onboarding');
  await settle(page, 2000);

  for (let i = 0; i < 6; i++) {
    await settle(page, 400);
    const skipped = await trySkipPage(page);
    if (!skipped) break;
  }
}

/**
 * Complete the placement flow by skipping.
 */
export async function completePlacement(page: Page) {
  await goTo(page, '/placement');
  await settle(page, 2000);
  await trySkipPage(page);
  await settle(page, 1000);
}

/**
 * Full setup: onboard + place so all pages become accessible.
 */
export async function setupSeededApp(page: Page) {
  await waitForApp(page);
  await settle(page, 1000);

  await completeOnboarding(page);
  await settle(page, 1000);
  await completePlacement(page);
  await settle(page, 1500);

  await goTo(page, '/');
  await settle(page, 3000);
}
