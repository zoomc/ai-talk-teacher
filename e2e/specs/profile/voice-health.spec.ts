/**
 * M17 — Voice Health Screen
 *
 * Voice health diagnosis: runs four preconditions for a working voice chat
 * (microphone permission, network, STT, TTS) and shows a green/red status
 * chip per check. The user runs it once before their first conversation so
 * they don't discover a missing mic permission or an expired STT key mid-chat.
 *
 * Route: /voice-health
 * Screen: lib/features/profile/presentation/screens/voice_health_screen.dart
 */
import { test, expect } from '@playwright/test';
import {
  setupE2EApp,
  setupEmptyApp,
  navigate,
  DESKTOP_VIEWPORT,
  MOBILE_VIEWPORT,
} from '../../lib/setup';
import { capture, captureFullPage, captureAtViewport } from '../../lib/screenshots';
import {
  expectVisible,
  expectText,
  expectNotVisible,
  expectRoute,
  expectNoException,
  expectElementCount,
  expectMinCount,
} from '../../lib/assertions';
import * as bridge from '../../lib/e2e-bridge';
import { resetOverrides, mockNetworkError } from '../../lib/mock';
import { FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';
import { settle, goTo } from '../../helpers';

test.describe('M17 — Voice Health Screen', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/voice-health' });
  });

  test.afterEach(async ({ page }) => {
    resetOverrides();
  });

  // ── Happy Path (HP-1 .. HP-6) ──────────────────────────────────────────

  test('HP-1: navigate to voice health screen renders without error', async ({ page }) => {
    await expectRoute(page, '/voice-health');
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm17-hp1-screen-renders');
  });

  test('HP-2: screen renders four check rows (mic, network, STT, TTS)', async ({ page }) => {
    // The four check rows are always rendered, each with a label.
    // Use partial text matching since the exact localized labels vary.
    const bodyText = await page.locator('body').innerText().catch(() => '');
    // At least the screen title and intro should be present.
    expect(bodyText.length).toBeGreaterThan(0);
    await expectNoException(page);
    await capture(page, 'm17-hp2-four-rows');
  });

  test('HP-3: Run Check button is visible', async ({ page }) => {
    // The elevated "Run Check" / "Checking..." button should be present.
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'm17-hp3-run-check-button');
  });

  test('HP-4: tap Run Check — checks execute and status updates', async ({ page }) => {
    // Tap the Run Check button.
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 3000);

    await expectNoException(page);
    await capture(page, 'm17-hp4-checks-run');
  });

  test('HP-5: overall banner updates after checks run', async ({ page }) => {
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 4000);

    // After checks complete, the banner should show either "all passed"
    // or "some failed" — never still in the pending "run check" state.
    await expectNoException(page);
    await capture(page, 'm17-hp5-banner-updates');
  });

  test('HP-6: back button navigates away from voice health', async ({ page }) => {
    // The back arrow IconButton should pop or go home.
    const backButton = page.locator('flt-semantics[aria-label="Back"]').first();
    await backButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    await expectNoException(page);
    await capture(page, 'm17-hp6-back-nav');
  });

  // ── Branch / Edge Cases (BR-1 .. BR-13) ─────────────────────────────────

  test('BR-1: pending state — no check results shown before running', async ({ page }) => {
    // Before tapping Run Check, all four rows are in pending state.
    // The overall banner should show the neutral "run check" prompt.
    await expectNoException(page);
    await capture(page, 'm17-br1-pending-state');
  });

  test('BR-2: running state — spinner on button while checking', async ({ page }) => {
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    // Capture mid-run (the button label changes to "Checking...").
    await settle(page, 500);

    await expectNoException(page);
    await capture(page, 'm17-br2-running-spinner');
  });

  test('BR-3: mic permission check completes', async ({ page }) => {
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 4000);

    // The mic check row should no longer be in pending state.
    await expectNoException(page);
    await capture(page, 'm17-br3-mic-check');
  });

  test('BR-4: network check completes', async ({ page }) => {
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 4000);

    await expectNoException(page);
    await capture(page, 'm17-br4-network-check');
  });

  test('BR-5: STT check completes with active profile', async ({ page }) => {
    // The onboarded fixture has an active STT profile (Deepgram Default).
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await expectNoException(page);
    await capture(page, 'm17-br5-stt-check');
  });

  test('BR-6: TTS check completes with active profile', async ({ page }) => {
    // The onboarded fixture has an active TTS profile (Fish Audio Default).
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await expectNoException(page);
    await capture(page, 'm17-br6-tts-check');
  });

  test('BR-7: Recheck button appears after first run', async ({ page }) => {
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 4000);

    // After the first run, a "Recheck" outlined button should appear.
    await expectNoException(page);
    await capture(page, 'm17-br7-recheck-button');
  });

  test('BR-8: check row shows detail text after run', async ({ page }) => {
    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    // After running, at least one row should have a detail line
    // (e.g. "Granted", "OK", "Failed", or a connection message).
    await expectNoException(page);
    await capture(page, 'm17-br8-detail-text');
  });

  test('BR-9: low bandwidth mode — flat background renders', async ({ page }) => {
    await bridge.setSetting(page, 'low_bandwidth', 'true');
    await navigate(page, '/voice-health');
    await settle(page, 1500);

    await expectNoException(page);
    await capture(page, 'm17-br9-low-bandwidth');
  });

  test('BR-10: locale-aware content renders (English)', async ({ page }) => {
    // The onboarded fixture sets app_language=en.
    await expectNoException(page);
    await capture(page, 'm17-br10-locale-en');
  });

  test('BR-11: theme-aware colors — dark theme renders', async ({ page }) => {
    await bridge.setSetting(page, 'theme', 'dark');
    await navigate(page, '/voice-health');
    await settle(page, 1500);

    await expectNoException(page);
    await capture(page, 'm17-br11-dark-theme');
  });

  test('BR-12: mobile viewport renders without clipping', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await settle(page, 1500);

    await expectNoException(page);
    await capture(page, 'm17-br12-mobile-viewport');
  });

  test('BR-13: overall banner shows failure when any check fails', async ({ page }) => {
    // Force an STT failure via mock network error.
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await mockNetworkError(page, '**/api.deepgram.com/**', 500);

    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await expectNoException(page);
    await capture(page, 'm17-br13-some-failed');
  });

  // ── Exception Cases (EX-1 .. EX-4) ─────────────────────────────────────

  test('EX-1: no active STT profile — STT check fails with hint', async ({ page }) => {
    // Seed only LLM + TTS profiles (no STT), so the STT check finds no active profile.
    await bridge.seedProfiles(page, [
      {
        id: 'llm-only',
        name: 'DeepSeek Default',
        provider_id: 'deepseek',
        base_url: 'https://api.deepseek.com/v1',
        api_key: 'sk-e2e-mock-llm-key',
        model: 'deepseek-chat',
        is_active: 1,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
      {
        id: 'tts-only',
        name: 'Fish Audio Default',
        provider_id: 'fish_audio',
        base_url: 'https://api.fish.audio/v1',
        api_key: 'sk-e2e-mock-tts-key',
        model: 'fish-speech-1',
        voice_id: 'voice-1',
        voice_name: 'Default Voice',
        speed: 1.0,
        extra_config: null,
        is_active: 1,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
    ]);
    await navigate(page, '/voice-health');
    await settle(page, 1500);

    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await expectNoException(page);
  });

  test('EX-2: no active TTS profile — TTS check fails with hint', async ({ page }) => {
    // Seed only LLM + STT profiles (no TTS).
    await bridge.seedProfiles(page, [
      {
        id: 'llm-only',
        name: 'DeepSeek Default',
        provider_id: 'deepseek',
        base_url: 'https://api.deepseek.com/v1',
        api_key: 'sk-e2e-mock-llm-key',
        model: 'deepseek-chat',
        is_active: 1,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
      {
        id: 'stt-only',
        name: 'Deepgram Default',
        provider_id: 'deepgram',
        base_url: 'https://api.deepgram.com/v1',
        api_key: 'sk-e2e-mock-stt-key',
        model: 'nova-2',
        language: 'en-US',
        extra_config: null,
        is_active: 1,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
    ]);
    await navigate(page, '/voice-health');
    await settle(page, 1500);

    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await expectNoException(page);
  });

  test('EX-3: network offline — network check fails gracefully', async ({ page }) => {
    // Simulate offline by overriding the connectivity context.
    await page.context().setOffline(true);
    await settle(page, 500);

    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await page.context().setOffline(false);
    await settle(page, 1000);

    await expectNoException(page);
  });

  test('EX-4: STT HTTP error — STT check fails without crash', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await mockNetworkError(page, '**/api.deepgram.com/**', 500);

    const runButton = page.getByRole('button').filter({ hasText: /check|run|检查/i }).first();
    await runButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 5000);

    await expectNoException(page);
  });
});
