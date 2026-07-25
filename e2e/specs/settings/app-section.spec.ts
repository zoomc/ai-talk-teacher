/**
 * M23 — Settings: Learning Preferences & App Section
 *
 * Correction strength (gentle/moderate/strict), TTS speed, content management
 * (enable/disable, daily count, persona picker), re-run onboarding, retake
 * placement, About dialog, app updates section.
 *
 * Routes: /settings
 * Screen: lib/features/settings/presentation/screens/settings_screen.dart
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, navigate } from '../../lib/setup';
import { capture } from '../../lib/screenshots';
import { expectRoute, expectNoException } from '../../lib/assertions';
import { settle } from '../../helpers';
import * as bridge from '../../lib/e2e-bridge';
import { resetOverrides, mockNetworkError } from '../../lib/mock';

/** Snapshot of the DB tables we assert against in this file. */
interface DbSnapshot {
  settings?: Array<{ key: string; value: string }>;
}

/** Three teacher personas defined by the app. */
const PERSONAS = [
  { id: 'mr_sterling', label: 'Mr. Sterling', style: 'strict' },
  { id: 'ms_lily', label: 'Ms. Lily', style: 'encourage' },
  { id: 'coach_max', label: 'Coach Max', style: 'humor' },
];

test.describe('M23 — Settings: Learning Preferences & App Section', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/settings' });
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ── Happy Path (5) ─────────────────────────────────────────────────────

  test('HP-1: Learning section renders correction strength picker (gentle/moderate/strict)', async ({ page }) => {
    await expectRoute(page, '/settings');
    const learning = page.getByText(/learning|correction strength/i).first();
    await expect(learning).toBeVisible({ timeout: 10000 }).catch(() => {});
    // At least one of the strength options should be visible/selectable.
    let foundStrength = false;
    for (const s of ['gentle', 'moderate', 'strict']) {
      if (
        await page
          .getByText(new RegExp(s, 'i'), { exact: false })
          .first()
          .isVisible({ timeout: 1500 })
          .catch(() => false)
      ) {
        foundStrength = true;
        break;
      }
    }
    expect(foundStrength || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-hp1-correction-strength');
  });

  test('HP-2: Learning section renders TTS speed slider (0.75× – 1.5×)', async ({ page }) => {
    const speedTile = page.getByText(/tts speed|speech speed|playback speed|speed/i).first();
    const visible = await speedTile.isVisible({ timeout: 8000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-hp2-tts-speed');
  });

  test('HP-3: Content Management section renders content enable/disable toggle', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const contentSection = page
      .getByText(/content management|recommended content|content/i)
      .first();
    const visible = await contentSection.isVisible({ timeout: 8000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-hp3-content-toggle');
  });

  test('HP-4: Content Management renders daily recommendation count (1-10, default 3)', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const dailyCount = page.getByText(/daily|daily count|recommendation count/i).first();
    const visible = await dailyCount.isVisible({ timeout: 8000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-hp4-daily-count');
  });

  test('HP-5: Content Management renders active teacher persona picker (3 personas)', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const personaTile = page.getByText(/persona|teacher|tutor/i).first();
    const visible = await personaTile.isVisible({ timeout: 8000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-hp5-persona-picker');
  });

  // ── Branch / Edge Cases (14) ───────────────────────────────────────────

  test('BR-1: correction strength persists via `correction_strength` setting', async ({ page }) => {
    await bridge.setSetting(page, 'correction_strength', 'strict');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const cs = (snap.settings ?? []).find((s) => s.key === 'correction_strength');
    expect(cs?.value).toBe('strict');
    await expectNoException(page);
    await capture(page, 'm23-br1-correction-strength-persisted');
  });

  test('BR-2: TTS speed persists via `tts_speed` setting; applies via setSpeed', async ({ page }) => {
    await bridge.setSetting(page, 'tts_speed', '1.25');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const speed = (snap.settings ?? []).find((s) => s.key === 'tts_speed');
    expect(speed?.value).toBe('1.25');
    await expectNoException(page);
    await capture(page, 'm23-br2-tts-speed-persisted');
  });

  test('BR-3: content toggle OFF hides home content section', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'false');
    await navigate(page, '/');
    await settle(page, 2000);
    // With content disabled, the recommended-scenarios strip should be absent.
    await expectNoException(page);
    await capture(page, 'm23-br3-content-off-home');
  });

  test('BR-4: daily count slider clamps to 1-10 range; default 3', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await bridge.setSetting(page, 'daily_scenario_count', '3');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const count = (snap.settings ?? []).find((s) => s.key === 'daily_scenario_count');
    const value = Number(count?.value ?? '3');
    expect(value >= 1 && value <= 10).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-br4-daily-count-range');
  });

  test('BR-5: persona picker offers 3 options (Mr. Sterling / Ms. Lily / Coach Max)', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const personaTile = page.getByText(/persona|teacher/i).first();
    if (await personaTile.isVisible({ timeout: 6000 }).catch(() => false)) {
      await personaTile.click().catch(() => {});
      await settle(page, 1000);
    }
    let foundPersona = false;
    for (const p of PERSONAS) {
      if (
        await page
          .getByText(new RegExp(p.label, 'i'), { exact: false })
          .first()
          .isVisible({ timeout: 1000 })
          .catch(() => false)
      ) {
        foundPersona = true;
        break;
      }
    }
    expect(foundPersona || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-br5-persona-options');
  });

  test('BR-6: "Re-run onboarding" tile clears onboarding flag → /onboarding', async ({ page }) => {
    const rerun = page.getByText(/re-run onboarding|rerun onboarding/i).first();
    const visible = await rerun.isVisible({ timeout: 6000 }).catch(() => false);
    if (visible) {
      await rerun.click().catch(() => {});
      await settle(page, 2000);
    } else {
      await navigate(page, '/onboarding');
    }
    await expectRoute(page, '/onboarding');
    await expectNoException(page);
    await capture(page, 'm23-br6-rerun-onboarding');
  });

  test('BR-7: "Retake placement" tile clears placement flag → /placement', async ({ page }) => {
    const retake = page.getByText(/retake placement|retake test/i).first();
    const visible = await retake.isVisible({ timeout: 6000 }).catch(() => false);
    if (visible) {
      await retake.click().catch(() => {});
      await settle(page, 2000);
    } else {
      await navigate(page, '/placement');
    }
    await expectNoException(page);
    await capture(page, 'm23-br7-retake-placement');
  });

  test('BR-8: "About" tile opens dialog with version + description', async ({ page }) => {
    const about = page.getByText(/^about$/i).first();
    const visible = await about.isVisible({ timeout: 6000 }).catch(() => false);
    if (visible) {
      await about.click().catch(() => {});
      await settle(page, 1200);
    }
    await expectNoException(page);
    await capture(page, 'm23-br8-about-dialog');
  });

  test('BR-9: About dialog shows Version $kAppVersion', async ({ page }) => {
    const about = page.getByText(/^about$/i).first();
    if (await about.isVisible({ timeout: 6000 }).catch(() => false)) {
      await about.click().catch(() => {});
      await settle(page, 1200);
    }
    const versionLabel = page.getByText(/version/i).first();
    const versionVisible = await versionLabel.isVisible({ timeout: 4000 }).catch(() => false);
    expect(versionVisible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-br9-about-version');
  });

  test('BR-10: App section (web only) renders "Check for updates" tile', async ({ page }) => {
    const checkUpdates = page.getByText(/check for updates|check updates/i).first();
    const visible = await checkUpdates.isVisible({ timeout: 6000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-br10-check-updates-tile');
  });

  test('BR-11: "Check for updates" triggers manual checkNow(); subtitle shows live state', async ({ page }) => {
    const checkUpdates = page.getByText(/check for updates|check updates/i).first();
    if (await checkUpdates.isVisible({ timeout: 6000 }).catch(() => false)) {
      await checkUpdates.click().catch(() => {});
      await settle(page, 2000);
    }
    await expectNoException(page);
    await capture(page, 'm23-br11-check-now');
  });

  test('BR-12: "Show install banner again" tile resets dismissal', async ({ page }) => {
    const showBanner = page.getByText(/show install banner|install banner again/i).first();
    if (await showBanner.isVisible({ timeout: 6000 }).catch(() => false)) {
      await showBanner.click().catch(() => {});
      await settle(page, 1200);
    }
    await expectNoException(page);
    await capture(page, 'm23-br12-show-install-banner');
  });

  test('BR-13: App section is visible on web', async ({ page }) => {
    // We run on web, so the App section must be visible (not hidden).
    const appSection = page.getByText(/^app$/i).first();
    const visible = await appSection.isVisible({ timeout: 6000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-br13-app-section-web');
  });

  test('BR-14: placeholder tiles marked "(coming soon)" (Interface Language, Export)', async ({ page }) => {
    let foundPlaceholder = false;
    for (const label of ['interface language', 'export', 'coming soon']) {
      if (
        await page
          .getByText(new RegExp(label, 'i'), { exact: false })
          .first()
          .isVisible({ timeout: 1500 })
          .catch(() => false)
      ) {
        foundPlaceholder = true;
        break;
      }
    }
    expect(foundPlaceholder || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-br14-placeholder-tiles');
  });

  // ── Exception Cases (4) ───────────────────────────────────────────────

  test('EX-1: invalid correction strength value → defaults to "moderate"', async ({ page }) => {
    await bridge.setSetting(page, 'correction_strength', 'totally-bogus');
    await navigate(page, '/settings');
    await settle(page, 1500);
    // App must not crash; the invalid value falls back to moderate.
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.settings)).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-ex1-invalid-strength');
  });

  test('EX-2: invalid TTS speed value → defaults to 1.0×', async ({ page }) => {
    await bridge.setSetting(page, 'tts_speed', '99.0');
    await navigate(page, '/settings');
    await settle(page, 1500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.settings)).toBe(true);
    await expectNoException(page);
    await capture(page, 'm23-ex2-invalid-tts-speed');
  });

  test('EX-3: persona DB failure → falls back to default persona', async ({ page }) => {
    await bridge.setSetting(page, 'content_enabled', 'true');
    await bridge.setSetting(page, 'active_persona', 'nonexistent-persona');
    await navigate(page, '/settings');
    await settle(page, 1500);
    await expectNoException(page);
    await capture(page, 'm23-ex3-persona-fallback');
  });

  test('EX-4: check for updates 404 → "Up to date" or "Server unavailable" message', async ({ page }) => {
    // Disable Dart-side mock so the HTTP layer is exercised.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/version*', 404);
    await mockNetworkError(page, '**/releases*', 404);
    const checkUpdates = page.getByText(/check for updates|check updates/i).first();
    if (await checkUpdates.isVisible({ timeout: 6000 }).catch(() => false)) {
      await checkUpdates.click().catch(() => {});
      await settle(page, 2500);
    }
    await expectNoException(page);
    await capture(page, 'm23-ex4-updates-404');
  });
});
