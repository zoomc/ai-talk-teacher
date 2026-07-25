/**
 * Screenshot capture helpers.
 *
 * Every happy-path test should call `capture(page, name)` at the end.
 * Screenshots are saved to `e2e/screenshots/<name>.png` (overwriting any
 * prior file with the same name — this is intentional, we want the latest
 * rendering to be reviewed).
 *
 * For future visual-regression work, `captureBaseline` writes to
 * `e2e/baselines/` and `compareWithBaseline` performs a pixel diff.
 * Both are stubs for now (per plan decision: no visual regression in v1).
 */
import { Page } from '@playwright/test';
import path from 'path';
import fs from 'fs';

const SHOT_DIR = path.resolve(__dirname, '..', 'screenshots');
const BASELINE_DIR = path.resolve(__dirname, '..', 'baselines');

function ensureDir(dir: string): void {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

/**
 * Capture a viewport screenshot (only what's visible in the browser window).
 * Use this for tests that verify a specific viewport's rendering.
 */
export async function capture(page: Page, name: string): Promise<string> {
  ensureDir(SHOT_DIR);
  const filePath = path.join(SHOT_DIR, `${name}.png`);
  await page.screenshot({
    path: filePath,
    fullPage: false,
    type: 'png',
  });
  return filePath;
}

/**
 * Capture a full-page screenshot (entire scrollable content).
 * Use this for tests on scrollable screens (chat history, projects list, etc.)
 * to verify that no content is clipped or overflowing.
 */
export async function captureFullPage(page: Page, name: string): Promise<string> {
  ensureDir(SHOT_DIR);
  const filePath = path.join(SHOT_DIR, `${name}-full.png`);
  await page.screenshot({
    path: filePath,
    fullPage: true,
    type: 'png',
  });
  return filePath;
}

/**
 * Capture a specific element's screenshot.
 * Useful for verifying a single widget's rendering in isolation.
 */
export async function captureElement(
  page: Page,
  selector: string,
  name: string,
): Promise<string> {
  ensureDir(SHOT_DIR);
  const filePath = path.join(SHOT_DIR, `${name}.png`);
  const loc = page.locator(selector).first();
  await loc.screenshot({ path: filePath, type: 'png' });
  return filePath;
}

/**
 * Capture a screenshot at a specific viewport size (for responsive testing).
 * Restores the original viewport afterwards.
 */
export async function captureAtViewport(
  page: Page,
  name: string,
  viewport: { width: number; height: number },
): Promise<string> {
  const original = page.viewportSize();
  await page.setViewportSize(viewport);
  try {
    await page.waitForTimeout(500); // allow re-layout
    return await capture(page, name);
  } finally {
    if (original) {
      await page.setViewportSize(original);
    }
  }
}

/**
 * Save a baseline screenshot for future visual regression.
 * Stub for v1 — just saves to baselines/ directory.
 */
export async function captureBaseline(page: Page, name: string): Promise<string> {
  ensureDir(BASELINE_DIR);
  const filePath = path.join(BASELINE_DIR, `${name}.png`);
  await page.screenshot({ path: filePath, fullPage: false, type: 'png' });
  return filePath;
}

/**
 * List all captured screenshots (used by the review step in Phase 5).
 */
export function listScreenshots(): string[] {
  if (!fs.existsSync(SHOT_DIR)) return [];
  return fs.readdirSync(SHOT_DIR)
    .filter((f) => f.endsWith('.png'))
    .sort();
}
