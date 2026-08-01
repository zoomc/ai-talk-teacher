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
 *
 * Flutter web with semantics enabled often places text inside aria-labels
 * on semantic groups rather than as visible DOM text nodes. We use a
 * unified polling approach that checks all three sources in parallel:
 *   1. `getByText` visible DOM text nodes.
 *   2. Any element whose aria-label contains the text.
 *   3. The body's innerText (semantics tree text).
 */
export async function expectText(
  page: Page,
  text: string,
  options: { exact?: boolean } = {},
): Promise<Locator> {
  const exact = options.exact ?? false;
  const loc = page.getByText(text, { exact }).first();
  const ariaLoc = page.locator(`[aria-label*="${text}"]`).first();

  try {
    await expect.poll(async () => {
      // Check visible text nodes.
      const textVisible = await loc.isVisible().catch(() => false);
      if (textVisible) return true;
      // Check aria-labels.
      const ariaVisible = await ariaLoc.isVisible().catch(() => false);
      if (ariaVisible) return true;
      // Check body innerText.
      const bodyText = await page.locator('body').innerText().catch(() => '');
      return bodyText.includes(text);
    }, { timeout: VISIBLE_TIMEOUT, intervals: [500, 1000, 2000, 3000] }).toBe(true);
    return loc;
  } catch {
    // If all fallbacks fail, re-run the original assertion so the error
    // message matches what the test author expects to see.
    await expect(loc).toBeVisible({ timeout: VISIBLE_TIMEOUT });
    return loc;
  }
}

/**
 * Assert the current Flutter hash-route equals (or starts with) `route`.
 * Flutter web uses `#/path` format; we strip the leading `#`.
 */
export async function expectRoute(page: Page, route: string): Promise<void> {
  const url = page.url();
  const parsed = new URL(url);
  const hash = parsed.hash.replace(/^#/, '');
  const current = hash || parsed.pathname || '/';
  expect(current === route || current.startsWith(route + '/') || current.startsWith(route + '?'),
    `expected route to be ${route}, got ${current}`).toBeTruthy();
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
