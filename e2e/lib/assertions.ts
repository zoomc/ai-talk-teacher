/**
 * Assertion helpers for E2E tests.
 *
 * All helpers wrap Playwright's `expect` with project-specific defaults
 * (longer timeouts to accommodate Flutter web's slow first-frame render).
 */
import { Page, expect, Locator } from '@playwright/test';

/** Default assertion timeout for visible/attached checks. */
const VISIBLE_TIMEOUT = 15000;

/**
 * Assert an element matching `selector` is visible on the page.
 */
export async function expectVisible(
  page: Page,
  selector: string,
): Promise<Locator> {
  const loc = page.locator(selector).first();
  await expect(loc).toBeVisible({ timeout: VISIBLE_TIMEOUT });
  return loc;
}

/**
 * Assert an element matching `selector` is NOT visible (or not attached).
 */
export async function expectNotVisible(page: Page, selector: string): Promise<void> {
  const loc = page.locator(selector).first();
  await expect(loc).toBeHidden({ timeout: VISIBLE_TIMEOUT });
}

/**
 * Assert that `text` appears somewhere in the page body.
 * Uses `getByText` with `exact: false` so partial matches work.
 */
export async function expectText(
  page: Page,
  text: string,
  options: { exact?: boolean } = {},
): Promise<Locator> {
  const loc = page.getByText(text, { exact: options.exact ?? false }).first();
  await expect(loc).toBeVisible({ timeout: VISIBLE_TIMEOUT });
  return loc;
}

/**
 * Assert the current Flutter hash-route equals (or starts with) `route`.
 * Flutter web uses `#/path` format; we strip the leading `#`.
 */
export async function expectRoute(page: Page, route: string): Promise<void> {
  const url = page.url();
  const hash = new URL(url).hash.replace(/^#/, '') || '/';
  expect(hash === route || hash.startsWith(route + '/') || hash.startsWith(route + '?'),
    `expected route to be ${route}, got ${hash}`).toBeTruthy();
}

/**
 * Assert that no red error screen or raw exception text is visible.
 * Flutter renders unhandled errors as red screens with "Exception" or
 * "Error" headers in debug; in release they're suppressed but the body
 * text may still contain stacktrace fragments.
 */
export async function expectNoException(page: Page): Promise<void> {
  const bodyText = await page.locator('body').innerText().catch(() => '');
  for (const needle of ['Exception:', 'Error:', 'StackTrace', 'NoSuchMethodError', 'Null check operator']) {
    expect(bodyText, `body must not contain ${needle}`).not.toContain(needle);
  }
}

/**
 * Assert that exactly `n` elements match `selector`.
 */
export async function expectElementCount(
  page: Page,
  selector: string,
  n: number,
): Promise<void> {
  await expect(page.locator(selector)).toHaveCount(n, { timeout: VISIBLE_TIMEOUT });
}

/**
 * Assert that at least `n` elements match `selector`.
 */
export async function expectMinCount(
  page: Page,
  selector: string,
  n: number,
): Promise<void> {
  const count = await page.locator(selector).count();
  expect(count, `expected at least ${n} elements matching ${selector}, got ${count}`).toBeGreaterThanOrEqual(n);
}

/**
 * Assert the page has the SpeakFlow title (sanity check that the app loaded).
 */
export async function expectSpeakFlowTitle(page: Page): Promise<void> {
  await expect(page).toHaveTitle(/SpeakFlow/i, { timeout: VISIBLE_TIMEOUT });
}
