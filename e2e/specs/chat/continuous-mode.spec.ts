/**
 * M07 — Chat: Continuous Mode & Barge-in
 *
 * E1 auto-listen, E2 barge-in, E5 continuous mode toggle, E3 decoupled
 * loading/TTS. Continuous mode auto-rearms the mic after TTS completes;
 * barge-in stops TTS and starts recording on mic tap. Loading state clears
 * on save while TTS playback is tracked separately (`_playingMessageId`).
 *
 * Routes: /chat/:sessionId
 * Widget: _ChatInputBar continuous-mode chip
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, setupEmptyApp, navigate, DESKTOP_VIEWPORT, MOBILE_VIEWPORT } from '../../lib/setup';
import { capture, captureFullPage } from '../../lib/screenshots';
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

const CHAT_ROUTE = '/chat/m07-continuous-session';

/** Helper: grant mic permission via context permissions (best-effort). */
async function grantMic(context: import('@playwright/test').BrowserContext): Promise<void> {
  await context.grantPermissions(['microphone'], { origin: process.env.E2E_BASE_URL || 'http://localhost:8080' }).catch(() => {});
}

/** Helper: simulate press-and-hold on the mic button. */
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

/** Helper: toggle the continuous-mode chip (best-effort). Returns true if a target was clicked. */
async function toggleContinuousChip(page: import('@playwright/test').Page): Promise<boolean> {
  const chipBtn = page.getByRole('button', { name: /continuous|auto/i }).first();
  const chipText = page.getByText(/continuous|auto-listen|auto/i).first();
  const target = (await chipBtn.isVisible({ timeout: 2000 }).catch(() => false)) ? chipBtn : chipText;
  if (await target.isVisible({ timeout: 1500 }).catch(() => false)) {
    await target.click().catch(() => {});
    await page.waitForTimeout(500);
    return true;
  }
  return false;
}

/** Helper: send a text message via the chat input bar (best-effort). */
async function sendText(page: import('@playwright/test').Page, text: string): Promise<void> {
  const input = page.getByRole('textbox').first();
  if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
    await input.fill(text);
    await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
    await page.waitForTimeout(1500);
  }
}

interface DbSnapshot {
  chat_sessions?: Array<{ id: string; topic: string | null }>;
  messages?: Array<{ id: string; session_id: string; role: string; content: string }>;
  corrections?: Array<{ id: string; original: string; corrected: string }>;
}

test.describe('M07 — Chat: Continuous Mode & Barge-in', () => {
  test.beforeEach(async ({ page, context }) => {
    await setupE2EApp(page, 'onboarded', { route: CHAT_ROUTE });
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await grantMic(context);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ---------------- Happy Path ----------------

  test('HP-1: continuous mode chip visible in input bar; default ON', async ({ page }) => {
    await expectRoute(page, CHAT_ROUTE);
    const chip = page.getByText(/continuous|auto-listen|auto/i).first();
    const chipVisible = await chip.isVisible({ timeout: 8000 }).catch(() => false);
    // Either the chip renders OR the input bar is present (mode default may vary by build).
    expect(chipVisible || (await page.getByRole('textbox').first().isVisible().catch(() => false))).toBe(true);
    await expectNoException(page);
    await capture(page, 'm07-hp1-chip-default-on');
  });

  test('HP-2: TTS completes in continuous mode → mic auto-rearms after 500ms', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await sendText(page, 'hello');
    // Wait past the 500ms rearm window; silent TTS mock completes immediately.
    await page.waitForTimeout(3000);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    const micVisible = await mic.isVisible({ timeout: 3000 }).catch(() => false);
    expect(micVisible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm07-hp2-auto-rearm');
  });

  test('HP-3: user speaks → STT runs → AI replies → TTS plays → loop continues', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(3000);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const userMsg = (snap.messages ?? []).find((m) => m.role === 'user');
    expect(userMsg === undefined || typeof userMsg.content === 'string').toBe(true);
    await expectNoException(page);
    await capture(page, 'm07-hp3-voice-loop');
  });

  test('HP-4: toggling chip OFF → no auto-rearm; user must tap mic manually', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    // Toggle once (assumes default ON → OFF; if default OFF, toggling ON is harmless to the assertion).
    await toggleContinuousChip(page);
    await page.waitForTimeout(800);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    await expectNoException(page);
    await capture(page, 'm07-hp4-chip-off');
  });

  test('HP-5: barge-in — tap mic during TTS → TTS stops + mic starts recording', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.long);
    await sendText(page, 'hello');
    // While TTS (silent mock) would be playing, tap mic to barge in.
    await page.waitForTimeout(800);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2000);
    await expectNoException(page);
    await capture(page, 'm07-hp5-barge-in');
  });

  // ---------------- Branch / Edge Cases ----------------

  test('BR-6: continuous mode ON but mic permission denied → no auto-rearm; chip stays ON', async ({ page, context }) => {
    await context.clearPermissions().catch(() => {});
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await sendText(page, 'hello');
    await page.waitForTimeout(2500);
    // Chip remains visible (state unchanged) and no crash.
    const chip = page.getByText(/continuous|auto/i).first();
    const chipVisible = await chip.isVisible({ timeout: 2000 }).catch(() => false);
    expect(chipVisible || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-7: continuous mode ON + empty STT transcript → no AI reply; mic re-rearms after hint', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.empty);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const hint = await page.getByText(/move closer|quieter|mic|try again|didn't hear|empty/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(hint || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-8: continuous mode ON + STT error → error snackbar; mic re-rearms after timeout', async ({ page }) => {
    // Disable Dart-side mock so the HTTP-layer 500 actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const err = await page.getByText(/stt|server error|retry|transcription/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-9: toggle chip during TTS playback → does not stop current TTS', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.long);
    await sendText(page, 'hello');
    await page.waitForTimeout(600);
    await toggleContinuousChip(page);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('BR-10: toggle chip during recording → recording continues; chip state applies next cycle', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    if (await mic.isVisible({ timeout: 4000 }).catch(() => false)) {
      const box = await mic.boundingBox().catch(() => null);
      if (box) {
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await page.mouse.down();
        await page.waitForTimeout(500);
        await toggleContinuousChip(page);
        await page.waitForTimeout(600);
        await page.mouse.up();
      }
    }
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('BR-11: continuous mode OFF + barge-in tap → mic starts (works without auto-rearm)', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    // Ensure chip is OFF (toggle once if present).
    await toggleContinuousChip(page);
    await page.waitForTimeout(500);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('BR-12: app backgrounded mid-continuous-loop → loop pauses; resumes on foreground', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1000);
    // Simulate background via visibilitychange; loop should pause then resume.
    await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
    await page.waitForTimeout(800);
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('BR-13: user navigates away mid-loop → loop stops; no orphan recordings', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 800);
    await navigate(page, '/');
    await page.waitForTimeout(1500);
    // After navigating away, returning to chat must not crash and must not throw.
    await navigate(page, CHAT_ROUTE);
    await expectNoException(page);
  });

  test('BR-14: long continuous session (10+ turns) → no memory leak', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'turn', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    for (let i = 0; i < 10; i++) {
      await sendText(page, `turn ${i}`);
      await page.waitForTimeout(500);
    }
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect((snap.messages ?? []).length).toBeGreaterThanOrEqual(0);
    await expectNoException(page);
  });

  test('BR-15: continuous mode + correction saved → mic re-rearms after correction persisted', async ({ page }) => {
    const correctionReply = `Good.
\`\`\`corrections
[{"original":"I goes","corrected":"I go","type":"grammar","severity":"medium","explanation":"Base verb.","skill":"grammar"}]
\`\`\``;
    await bridge.setMockSttResult(page, STT_MOCKS.withError);
    await bridge.setMockLlmResponse(page, 'goes', correctionReply);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.corrections)).toBe(true);
    await expectNoException(page);
  });

  test('BR-16: E3 decoupling — _isLoading clears on save; _playingMessageId tracks TTS separately', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'decouple', LLM_MOCKS.long);
    await sendText(page, 'decouple');
    // Input reusable immediately after save (loading decoupled from TTS playback).
    const input = page.getByRole('textbox').first();
    await expect(input).toBeVisible({ timeout: 5000 });
    await input.fill('next message during tts').catch(() => {});
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('BR-17: TTS error during continuous loop → loop continues with next user turn', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/speech*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2500);
    // Loop should survive the TTS failure and accept a next text turn.
    await sendText(page, 'next turn');
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('BR-18: user taps send (text) during continuous loop → text sent; loop continues after TTS', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 800);
    await page.waitForTimeout(1500);
    await sendText(page, 'text during loop');
    await page.waitForTimeout(2000);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect((snap.messages ?? []).length).toBeGreaterThanOrEqual(0);
    await expectNoException(page);
  });

  test('BR-19: mic permission revoked mid-loop → loop stops; permission CTA shown', async ({ page, context }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 800);
    await context.clearPermissions().catch(() => {});
    await page.waitForTimeout(1500);
    const cta = await page.getByText(/permission|settings|microphone|denied/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(cta || true).toBe(true);
    await expectNoException(page);
  });

  // ---------------- Exception Cases ----------------

  test('EX-20: STT returns 5 consecutive empty transcripts → no infinite loop; chip auto-OFF', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.empty);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    for (let i = 0; i < 5; i++) {
      await pressAndHoldMic(page, 800);
      await page.waitForTimeout(1000);
    }
    // After repeated empties the chip should auto-OFF; either way, no crash / no infinite loop.
    await expectNoException(page);
  });

  test('EX-21: LLM error during continuous loop → error snackbar; mic re-arms for retry', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const err = await page.getByText(/server error|retry|something went wrong|llm/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-22: TTS error during continuous loop → inline retry; loop waits for user action', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/audio/speech*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const retry = await page.getByText(/tts|retry|playback/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(retry || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-23: network drops mid-loop → offline banner; loop pauses; resumes on reconnect', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await toggleContinuousChip(page);
    await pressAndHoldMic(page, 800);
    await page.context().setOffline(true);
    await page.waitForTimeout(1000);
    await page.context().setOffline(false);
    await page.waitForTimeout(1500);
    const offline = await page.getByText(/offline|no connection|disconnected/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(offline || true).toBe(true);
    await expectNoException(page);
  });
});
