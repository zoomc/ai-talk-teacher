/**
 * Typed TypeScript wrapper around the Flutter-side E2E bridge exposed via
 * `window.speakflowE2E.*` when the app is built with `--dart-define=E2E=true`.
 *
 * If the bridge is NOT present (production build), all calls reject with a
 * helpful error. Tests that use this wrapper must run against the E2E build.
 */
import { Page } from '@playwright/test';

/** Shape of the JS bridge exposed by Flutter. */
interface SpeakflowE2E {
  resetDatabase(): Promise<void>;
  seedFixture(name: string, json: string): Promise<void>;
  seedProjects(json: string): Promise<void>;
  seedChatSessions(json: string): Promise<void>;
  seedMessages(json: string): Promise<void>;
  seedCorrections(json: string): Promise<void>;
  seedReviewQueue(json: string): Promise<void>;
  seedScenarios(json: string): Promise<void>;
  seedProfiles(json: string): Promise<void>;
  setMockMode(enabled: boolean): Promise<void>;
  setMockLlmResponse(promptSubstring: string, reply: string): Promise<void>;
  setMockSttResult(transcript: string): Promise<void>;
  setMockTtsAudio(base64Audio: string): Promise<void>;
  getDatabaseSnapshot(): Promise<string>;
  setSetting(key: string, value: string): Promise<void>;
  completeOnboarding(): Promise<void>;
}

declare global {
  interface Window {
    speakflowE2E?: SpeakflowE2E;
  }
}

/**
 * Assert the E2E bridge is present. Throws a clear error if the app
 * was built without `--dart-define=E2E=true`.
 */
async function assertBridge(page: Page): Promise<SpeakflowE2E> {
  const hasBridge = await page.evaluate(() => typeof window.speakflowE2E === 'object' && window.speakflowE2E !== null);
  if (!hasBridge) {
    throw new Error(
      'window.speakflowE2E is not present. The app was likely built without --dart-define=E2E=true. ' +
      'Rebuild with: flutter build web --release --dart-define=E2E=true'
    );
  }
  return page.evaluate(() => window.speakflowE2E!) as unknown as SpeakflowE2E;
}

/** Wipe all SQLite tables (profiles, sessions, messages, corrections, projects, etc.). */
export async function resetDb(page: Page): Promise<void> {
  await page.evaluate(() => window.speakflowE2E!.resetDatabase());
}

/** Seed a named fixture set (defined in `fixtures/fixtures.ts`). */
export async function seedFixture(page: Page, name: string, json: string): Promise<void> {
  await page.evaluate(
    ({ n, j }) => window.speakflowE2E!.seedFixture(n, j),
    { n: name, j: json },
  );
}

/** Seed the `projects` table from a JSON array of project rows. */
export async function seedProjects<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedProjects(j),
    JSON.stringify(rows),
  );
}

/** Seed the `chat_sessions` table. */
export async function seedChatSessions<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedChatSessions(j),
    JSON.stringify(rows),
  );
}

/** Seed the `messages` table. */
export async function seedMessages<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedMessages(j),
    JSON.stringify(rows),
  );
}

/** Seed the `corrections` table. */
export async function seedCorrections<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedCorrections(j),
    JSON.stringify(rows),
  );
}

/** Seed the `review_queue` table. */
export async function seedReviewQueue<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedReviewQueue(j),
    JSON.stringify(rows),
  );
}

/** Seed the `scenarios` and `scenario_items` tables. */
export async function seedScenarios<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedScenarios(j),
    JSON.stringify(rows),
  );
}

/** Seed the `llm_profiles`, `stt_profiles`, `tts_profiles` tables. */
export async function seedProfiles<T = unknown>(page: Page, rows: T[]): Promise<void> {
  await page.evaluate(
    (j) => window.speakflowE2E!.seedProfiles(j),
    JSON.stringify(rows),
  );
}

/** Enable/disable Dart-side mock mode (short-circuits LLM/STT/TTS services). */
export async function setMockMode(page: Page, enabled: boolean): Promise<void> {
  await page.evaluate(
    (e) => window.speakflowE2E!.setMockMode(e),
    enabled,
  );
}

/** Override the LLM mock response for any prompt containing `promptSubstring`. */
export async function setMockLlmResponse(page: Page, promptSubstring: string, reply: string): Promise<void> {
  await page.evaluate(
    ({ p, r }) => window.speakflowE2E!.setMockLlmResponse(p, r),
    { p: promptSubstring, r: reply },
  );
}

/** Override the STT mock transcript (returned by next recording). */
export async function setMockSttResult(page: Page, transcript: string): Promise<void> {
  await page.evaluate(
    (t) => window.speakflowE2E!.setMockSttResult(t),
    transcript,
  );
}

/** Override the TTS mock audio (base64-encoded WAV/MP3). */
export async function setMockTtsAudio(page: Page, base64Audio: string): Promise<void> {
  await page.evaluate(
    (a) => window.speakflowE2E!.setMockTtsAudio(a),
    base64Audio,
  );
}

/** Return a JSON snapshot of every SQLite table (for test assertions). */
export async function getSnapshot<T = Record<string, unknown[]>>(page: Page): Promise<T> {
  const json = await page.evaluate(() => window.speakflowE2E!.getDatabaseSnapshot());
  return JSON.parse(json) as T;
}

/** Set a key/value in the `settings` table (theme, locale, low_bandwidth, etc.). */
export async function setSetting(page: Page, key: string, value: string): Promise<void> {
  await page.evaluate(
    ({ k, v }) => window.speakflowE2E!.setSetting(k, v),
    { k: key, v: value },
  );
}

/** Programmatically mark onboarding complete (skip the wizard). */
export async function completeOnboarding(page: Page): Promise<void> {
  await page.evaluate(() => window.speakflowE2E!.completeOnboarding());
}

/**
 * Wait for the bridge to be ready. The bridge is exposed asynchronously
 * after Flutter's first frame; this polls until `window.speakflowE2E` exists.
 */
export async function waitForBridge(page: Page, timeoutMs = 30000): Promise<void> {
  await page.waitForFunction(
    () => typeof (window as any).speakflowE2E === 'object' && (window as any).speakflowE2E !== null,
    { timeout: timeoutMs },
  );
}

export { assertBridge };
