/**
 * Test setup orchestrator.
 *
 * `setupE2EApp(page, fixtureName)` is the standard entry point for every
 * E2E test. It:
 *   1. Navigates to the app root
 *   2. Waits for Flutter to boot and the E2E bridge to be exposed
 *   3. Resets the SQLite database
 *   4. Seeds the requested fixture set
 *   5. Enables Dart-side mock mode (short-circuits LLM/STT/TTS)
 *   6. Registers HTTP mocks (defense in depth)
 *   7. Returns a ready-to-use page
 *
 * Per-test overrides (e.g., custom LLM response) should be set AFTER this
 * call, in the test body.
 */
import { Page } from '@playwright/test';
import {
  waitForApp,
  goTo,
  settle,
} from '../helpers';
import * as bridge from './e2e-bridge';
import { setupHttpMocks, resetOverrides } from './mock';
import { FIXTURES, FixtureName } from '../fixtures/fixtures';

/** Default viewport for desktop tests. */
export const DESKTOP_VIEWPORT = { width: 1280, height: 800 };

/** Default viewport for mobile tests. */
export const MOBILE_VIEWPORT = { width: 375, height: 812 };

/**
 * Full E2E setup: reset DB, seed fixture, enable mocks, wait for app.
 *
 * @param page Playwright page
 * @param fixtureName One of the named fixtures in `fixtures/fixtures.ts`
 * @param options Optional overrides (e.g., viewport, route to land on after setup)
 */
export async function setupE2EApp(
  page: Page,
  fixtureName: FixtureName = 'onboarded',
  options: { viewport?: { width: number; height: number }; route?: string } = {},
): Promise<void> {
  // Reset per-test HTTP overrides (in case a prior test set them)
  resetOverrides();

  // Set viewport BEFORE navigating so the first render uses the right size
  await page.setViewportSize(options.viewport ?? DESKTOP_VIEWPORT);

  // Register HTTP mocks (before navigation so initial HTTP calls are intercepted)
  await setupHttpMocks(page);

  // Navigate to the app root and wait for Flutter + bridge
  await waitForApp(page);
  await bridge.waitForBridge(page);

  // Reset DB and seed the requested fixture
  await bridge.resetDb(page);
  await bridge.setMockMode(page, true);

  const fixture = FIXTURES[fixtureName];
  if (fixture.profiles) await bridge.seedProfiles(page, fixture.profiles);
  if (fixture.scenarios) await bridge.seedScenarios(page, fixture.scenarios);
  if (fixture.projects) await bridge.seedProjects(page, fixture.projects);
  if (fixture.chatSessions) await bridge.seedChatSessions(page, fixture.chatSessions);
  if (fixture.messages) await bridge.seedMessages(page, fixture.messages);
  if (fixture.corrections) await bridge.seedCorrections(page, fixture.corrections);
  if (fixture.reviewQueue) await bridge.seedReviewQueue(page, fixture.reviewQueue);
  if (fixture.settings) {
    for (const [key, value] of Object.entries(fixture.settings)) {
      await bridge.setSetting(page, key, value);
    }
  }
  if (fixture.completeOnboarding) {
    await bridge.completeOnboarding(page);
  }

  // Navigate to the requested route (default: home)
  await goTo(page, options.route ?? '/');
  await settle(page, 1500);
}

/**
 * Lightweight setup: just reset the DB and enable mock mode, no fixtures.
 * Use this for tests that need a truly empty state (e.g., empty-list tests).
 */
export async function setupEmptyApp(
  page: Page,
  options: { viewport?: { width: number; height: number }; route?: string } = {},
): Promise<void> {
  resetOverrides();
  await page.setViewportSize(options.viewport ?? DESKTOP_VIEWPORT);
  await setupHttpMocks(page);
  await waitForApp(page);
  await bridge.waitForBridge(page);
  await bridge.resetDb(page);
  await bridge.setMockMode(page, true);
  await bridge.completeOnboarding(page);
  await goTo(page, options.route ?? '/');
  await settle(page, 1500);
}

/**
 * Navigate to a route after setup. Use this in tests that need to
 * visit multiple screens.
 */
export async function navigate(page: Page, route: string): Promise<void> {
  await goTo(page, route);
  await settle(page, 1200);
}

/** Standard afterEach cleanup. */
export async function teardownE2E(_page: Page): Promise<void> {
  resetOverrides();
  // The browser context is torn down by Playwright automatically per test
  // when using `test()` with a fresh `page` fixture.
}
