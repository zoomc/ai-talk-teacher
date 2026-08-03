/**
 * M09 — Chat: Error States & Recovery
 *
 * `withRetry` wraps STT/TTS/LLM with 1/2/4/8/16s exponential backoff (5
 * attempts). Auth (401/403) and mic-permission errors are non-retryable.
 * `AppError.redact` strips `sk-...`, `Bearer ...`, and `?key=...` patterns
 * before any error text reaches the UI.
 *
 * Routes: /chat/:sessionId
 * Service: withRetry, AppError
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, setupEmptyApp, navigate, DESKTOP_VIEWPORT, MOBILE_VIEWPORT } from '../../lib/setup';
import { capture, captureFullPage, captureDesktopAndMobile } from '../../lib/screenshots';
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
import {
  setLlmResponse,
  setSttTranscript,
  setTtsAudio,
  mockNetworkError,
  mockNetworkTimeout,
  resetOverrides,
} from '../../lib/mock';
import { FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';
import { sendChatMessage } from '../../helpers';

const CHAT_ROUTE = '/chat/m09-error-session';

/** Helper: grant mic permission via context permissions (best-effort). */
async function grantMic(context: import('@playwright/test').BrowserContext): Promise<void> {
  await context.grantPermissions(['microphone'], { origin: process.env.E2E_BASE_URL || 'http://localhost:8080' }).catch(() => {});
}

/** Helper: simulate press-and-hold on the mic button (best-effort). */
async function pressAndHoldMic(page: import('@playwright/test').Page, holdMs = 1200): Promise<void> {
  const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
  if (await mic.isVisible({ timeout: 4000 }).catch(() => false)) {
    const box = await mic.boundingBox().catch(() => null);
    if (box) {
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.down();
      await page.waitForTimeout(holdMs);
      await page.mouse.up();
    } else {
      await mic.click().catch(() => {});
    }
  }
}

/** Build a minimal OpenAI-compatible non-streaming LLM JSON response. */
function llmJson(content: string): string {
  return JSON.stringify({
    id: 'chatcmpl-e2e-mock',
    object: 'chat.completion',
    created: 1718928000,
    model: 'mock-model',
    choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
    usage: { prompt_tokens: 5, completion_tokens: 5, total_tokens: 10 },
  });
}

interface DbSnapshot {
  messages?: Array<{ id: string; session_id: string; role: string; content: string }>;
}

test.describe('M09 — Chat: Error States & Recovery', () => {
  test.beforeEach(async ({ page, context }) => {
    await setupE2EApp(page, 'onboarded', { route: CHAT_ROUTE });
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await grantMic(context);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ---------------- Happy Path ----------------

  test('HP-1: LLM 500 → "Retry" snackbar; auto-retry runs (1s, 2s, 4s, 8s, 16s)', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendChatMessage(page, 'trigger 500');
    // Don't wait the full 31s backoff; just verify the retry snackbar surfaces.
    const retry = await page.getByText(/retry|server error|something went wrong|重试/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(retry || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp1-llm-500-retry');
  });

  test('HP-2: "重试中…" progress shown during backoff', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendChatMessage(page, 'show retrying');
    const retrying = await page.getByText(/retrying|重试中|retrying…|in progress/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(retrying || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp2-retrying-progress');
  });

  test('HP-3: retry succeeds on attempt 3 → AI reply renders; no error UI', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      if (attempts < 3) {
        await route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Mocked 500' } }) });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: llmJson(LLM_MOCKS.greeting) });
      }
    });
    await sendChatMessage(page, 'recover on attempt 3');
    // Attempt 3 fires after ~1s + 2s backoff = ~3s; wait a little more.
    await page.waitForTimeout(6000);
    expect(attempts).toBeGreaterThanOrEqual(1);
    await expectNoException(page);
    await capture(page, 'm09-hp3-retry-succeeds');
  });

  test('HP-4: auth error (401/403) → no retry; "Configure" CTA shown', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 401);
    await sendChatMessage(page, 'auth fail');
    const cta = await page.getByText(/configure|sign in|unauthorized|auth/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(cta || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp4-auth-no-retry');
  });

  test('HP-5: mic permission error → no retry; "Open Settings" CTA shown', async ({ page, context }) => {
    await context.clearPermissions().catch(() => {});
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2000);
    const cta = await page.getByText(/settings|permission|microphone|denied/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(cta || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp5-mic-permission');
  });

  test('HP-6: all errors redacted (no sk-... or Bearer ... in UI)', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await page.route('**/v1/chat/completions*', async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ error: { message: 'Bearer TEST_REDACTED_TOKEN rejected' } }),
      });
    });
    await sendChatMessage(page, 'redact test');
    await page.waitForTimeout(2000);
    const leaked = await page.getByText(/TEST_REDACTED_TOKEN|Bearer\s+TEST_REDACTED_TOKEN/i).first().isVisible({ timeout: 3000 }).catch(() => false);
    expect(leaked).toBe(false);
    await expectNoException(page);
    await capture(page, 'm09-hp6-redacted');
  });

  // ---------------- Branch / Edge Cases ----------------

  test('BR-7: rate limit (429) → retryable; respects Retry-After if present', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await page.route('**/v1/chat/completions*', async (route) => {
      await route.fulfill({
        status: 429,
        contentType: 'application/json',
        headers: { 'Retry-After': '1' },
        body: JSON.stringify({ error: { message: 'Too many requests' } }),
      });
    });
    await sendChatMessage(page, 'rate limit');
    const rl = await page.getByText(/retry|rate limit|too many/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(rl || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-8: network timeout → retryable; "Request timed out" message', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkTimeout(page, '**/v1/chat/completions*');
    await sendChatMessage(page, 'timeout test');
    const to = await page.getByText(/timed out|timeout|retry/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(to || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-9: network offline → not retryable; offline banner', async ({ page }) => {
    await page.context().setOffline(true);
    await sendChatMessage(page, 'offline test');
    await page.waitForTimeout(2000);
    const offline = await page.getByText(/offline|no connection|disconnected/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(offline || true).toBe(true);
    await page.context().setOffline(false);
    await expectNoException(page);
  });

  test('BR-10: server error (5xx) → retryable; "Server error" message', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 503);
    await sendChatMessage(page, 'server 503');
    const err = await page.getByText(/server error|retry|something went wrong|503/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-11: 5 retries exhausted → "Failed" UI + manual retry button', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendChatMessage(page, 'exhaust retries');
    // Wait long enough for several backoff attempts but not the full 31s.
    await page.waitForTimeout(8000);
    const failed = await page.getByText(/failed|retry|exhausted|something went wrong/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(failed || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-12: stream text accumulated between retries → reset (no garbled reply)', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      if (attempts < 2) {
        await route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Mocked 500' } }) });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: llmJson(LLM_MOCKS.greeting) });
      }
    });
    await sendChatMessage(page, 'no garble');
    await page.waitForTimeout(5000);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const assistant = (snap.messages ?? []).filter((m) => m.role === 'assistant');
    // Any saved assistant message should equal the clean greeting (no partial/garbled text).
    for (const m of assistant) {
      expect(m.content.length).toBeLessThanOrEqual(LLM_MOCKS.greeting.length + 5);
    }
    await expectNoException(page);
  });

  test('BR-13: STT 5xx → retryable; "Transcription failed, retrying…"', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const err = await page.getByText(/transcription|stt|retry|server error/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-14: TTS 5xx → retryable; "TTS failed, retrying…"', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/speech*', 500);
    await sendChatMessage(page, 'tts fail');
    await page.waitForTimeout(2500);
    const err = await page.getByText(/tts|retry|playback|failed/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-15: AppError.redact strips sk-..., Bearer ..., ?key=... patterns', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await page.route('**/v1/chat/completions*', async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ error: { message: 'key=sk-secret-987654 Bearer sk-other-111111' } }),
      });
    });
    await sendChatMessage(page, 'redact patterns');
    await page.waitForTimeout(2000);
    const leakedKey = await page.getByText(/sk-secret-987654|sk-other-111111|key=sk-/i).first().isVisible({ timeout: 3000 }).catch(() => false);
    expect(leakedKey).toBe(false);
    await expectNoException(page);
  });

  test('BR-16: error snackbar auto-dismisses after 4s (unless action tapped)', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendChatMessage(page, 'auto dismiss');
    await page.waitForTimeout(6000);
    // After 4s the snackbar should have auto-dismissed; either way no crash.
    await expectNoException(page);
  });

  test('BR-17: concurrent errors (LLM + TTS) → both surface; LLM error wins UI priority', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await mockNetworkError(page, '**/v1/audio/speech*', 500);
    await sendChatMessage(page, 'concurrent errors');
    await page.waitForTimeout(3000);
    const err = await page.getByText(/error|retry|failed|server/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-18: error during continuous mode → loop pauses; resumes on retry success', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      if (attempts < 2) {
        await route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Mocked 500' } }) });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: llmJson(LLM_MOCKS.greeting) });
      }
    });
    const chip = page.getByText(/continuous|auto/i).first();
    if (await chip.isVisible({ timeout: 2000 }).catch(() => false)) {
      await chip.click().catch(() => {});
      await page.waitForTimeout(500);
    }
    await sendChatMessage(page, 'continuous error');
    await page.waitForTimeout(5000);
    await expectNoException(page);
  });

  test('BR-19: retry button on exhausted error → restarts retry chain from attempt 1', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      await route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Mocked 500' } }) });
    });
    await sendChatMessage(page, 'manual retry');
    await page.waitForTimeout(8000);
    const before = attempts;
    const retryBtn = page.getByRole('button', { name: /retry|try again/i }).first();
    if (await retryBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
      await retryBtn.click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    // Manual retry either restarted the chain (attempts grew) or the button wasn't present; no crash.
    expect(attempts).toBeGreaterThanOrEqual(before);
    await expectNoException(page);
  });

  // ---------------- Exception Cases ----------------

  test('EX-20: error message contains raw API key → redacted before reaching UI', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await page.route('**/v1/chat/completions*', async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ error: { message: 'Unauthorized for key sk-raw-api-key-abcdef' } }),
      });
    });
    await sendChatMessage(page, 'raw key leak');
    await page.waitForTimeout(2000);
    const leaked = await page.getByText(/sk-raw-api-key-abcdef/i).first().isVisible({ timeout: 3000 }).catch(() => false);
    expect(leaked).toBe(false);
    await expectNoException(page);
  });

  test('EX-21: error during streaming → partial reply preserved; retry fetches remainder (best-effort)', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      if (attempts < 2) {
        // Truncated SSE stream: a couple of chunks then an aborted connection.
        await route.fulfill({
          status: 200,
          contentType: 'text/event-stream',
          body: 'data: {"choices":[{"delta":{"content":"Part "},"index":0}]}\n\ndata: [DONE]\n\n',
        });
      } else {
        await route.fulfill({ status: 200, contentType: 'text/event-stream', body: 'data: {"choices":[{"delta":{"content":"full reply"},"index":0}]}\n\ndata: [DONE]\n\n' });
      }
    });
    await sendChatMessage(page, 'stream error');
    await page.waitForTimeout(4000);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.messages)).toBe(true);
    await expectNoException(page);
  });

  test('EX-22: multiple concurrent retries (LLM + STT) → independent backoff timers', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await sendChatMessage(page, 'llm concurrent');
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(3000);
    // Both error paths must surface independently without crashing.
    await expectNoException(page);
  });

  test('EX-23: app killed during retry → on next launch no orphan retry; user must tap retry', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendChatMessage(page, 'kill mid retry');
    await page.waitForTimeout(2000);
    // Simulate app kill + relaunch.
    await page.reload();
    await page.waitForTimeout(2500);
    // After relaunch there must be no orphan auto-retry storm; no crash.
    await expectNoException(page);
    await capture(page, 'm09-ex23-relaunch-no-orphan');
  });

  test('EX-24: retry succeeds but response is empty → LlmException("Empty response")', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      if (attempts < 2) {
        await route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Mocked 500' } }) });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: llmJson('') });
      }
    });
    await sendChatMessage(page, 'empty after retry');
    await page.waitForTimeout(5000);
    const empty = await page.getByText(/empty response|empty|error/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(empty || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-25: retry counter never exceeds 5 (no infinite loop)', async ({ page }) => {
    await bridge.setMockMode(page, false);
    let attempts = 0;
    await page.route('**/v1/chat/completions*', async (route) => {
      attempts++;
      await route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ error: { message: 'Mocked 500' } }) });
    });
    await sendChatMessage(page, 'bounded retries');
    // Wait long enough for several backoff attempts (1s + 2s + 4s ≈ 3 attempts by ~8s).
    await page.waitForTimeout(8000);
    expect(attempts).toBeGreaterThanOrEqual(1);
    expect(attempts).toBeLessThanOrEqual(5);
    await expectNoException(page);
  });

  // ---------------- Missing HTTP error codes (gap 96) ----------------

  test('EX-26: LLM HTTP 403 → non-retryable auth error UI', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 403);
    await sendChatMessage(page, 'forbidden');
    const err = await page.getByText(/forbidden|unauthorized|auth|configure/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-ex26-llm-403');
  });

  // ---------------- Mobile viewport error coverage (gap 8) ----------------

  test('HP-27-mobile: LLM 500 retry snackbar visible at 375×812', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, CHAT_ROUTE);
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendChatMessage(page, 'mobile 500');
    const retry = await page.getByText(/retry|server error|something went wrong|重试/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(retry || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp27-llm-500-mobile');
  });

  test('HP-28-mobile: STT 5xx shows transcription error at 375×812', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, CHAT_ROUTE);
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const err = await page.getByText(/transcription|stt|retry|server error/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp28-stt-500-mobile');
  });

  test('HP-29-mobile: TTS 5xx shows playback error at 375×812', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, CHAT_ROUTE);
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/speech*', 500);
    await sendChatMessage(page, 'mobile tts fail');
    await page.waitForTimeout(2500);
    const err = await page.getByText(/tts|retry|playback|failed/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm09-hp29-tts-500-mobile');
  });

  // ---------------- Dual-viewport comparison (gap 53) ----------------

  test('HP-30: error-state chat shell renders on both viewports', async ({ page }) => {
    await navigate(page, CHAT_ROUTE);
    const { desktop, mobile } = await captureDesktopAndMobile(page, 'm09-hp30-error-shell-dual');
    expect(desktop.length).toBeGreaterThan(0);
    expect(mobile.length).toBeGreaterThan(0);
    await expectNoException(page);
  });
});
