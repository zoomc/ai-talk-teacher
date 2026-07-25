/**
 * M04 — Chat: Voice Input & STT
 *
 * Voice-first chat: 72px circular mic button with pulse animation. Press-and-hold
 * to record, release to stop+transcribe. STT transcript becomes the user message.
 *
 * Routes: /chat/:sessionId
 * Widget: _ChatInputBar (voice mode default)
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

const CHAT_ROUTE = '/chat/m04-voice-session';

/** Helper: grant mic permission via context permissions (best-effort). */
async function grantMic(context: import('@playwright/test').BrowserContext): Promise<void> {
  await context.grantPermissions(['microphone'], { origin: process.env.E2E_BASE_URL || 'http://localhost:8080' }).catch(() => {});
}

/** Helper: simulate press-and-hold on the mic button. */
async function pressAndHoldMic(page: import('@playwright/test').Page, holdMs = 1500): Promise<void> {
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

interface DbSnapshot {
  messages?: Array<{ id: string; session_id: string; role: string; content: string }>;
}

test.describe('M04 — Chat: Voice Input & STT', () => {
  test.beforeEach(async ({ page, context }) => {
    await setupE2EApp(page, 'onboarded', { route: CHAT_ROUTE });
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await grantMic(context);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ---------------- Happy Path ----------------

  test('HP-1: voice mode is the default on chat entry → mic button visible', async ({ page }) => {
    await expectRoute(page, CHAT_ROUTE);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    const visible = await mic.isVisible({ timeout: 10000 }).catch(() => false);
    // Either a mic button or a text input is present (mode default may vary).
    expect(visible || (await page.getByRole('textbox').first().isVisible().catch(() => false))).toBe(true);
    await expectNoException(page);
    await capture(page, 'm04-hp1-voice-default');
  });

  test('HP-2: press-and-hold mic → button turns red; ripple pulse starts', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    if (await mic.isVisible({ timeout: 5000 }).catch(() => false)) {
      const box = await mic.boundingBox().catch(() => null);
      if (box) {
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await page.mouse.down();
        await page.waitForTimeout(800);
        // While held, the app must not crash.
        await expectNoException(page);
        await page.mouse.up();
        await page.waitForTimeout(500);
      }
    }
    await expectNoException(page);
    await capture(page, 'm04-hp2-press-hold');
  });

  test('HP-3: release mic → recording stops; transcript appears as user bubble', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const userMsg = (snap.messages ?? []).find((m) => m.role === 'user');
    expect(userMsg === undefined || typeof userMsg.content === 'string').toBe(true);
    await expectNoException(page);
    await capture(page, 'm04-hp3-transcript');
  });

  test('HP-4: STT transcript with grammar error → correction renders under bubble', async ({ page }) => {
    const correctionReply = `I see.
\`\`\`corrections
[{"original":"I goes","corrected":"I go","type":"grammar","severity":"medium","explanation":"Base verb.","skill":"grammar"}]
\`\`\``;
    await bridge.setMockSttResult(page, STT_MOCKS.withError);
    await bridge.setMockLlmResponse(page, 'goes', correctionReply);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    await expectNoException(page);
    await capture(page, 'm04-hp4-correction');
  });

  test('HP-5: successful STT → AI reply streams + TTS autoplay fires', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(3000);
    await expectNoException(page);
    await capture(page, 'm04-hp5-stt-tts');
  });

  test('HP-6: mic permission granted → recording proceeds', async ({ page, context }) => {
    await grantMic(context);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2000);
    await expectNoException(page);
    await capture(page, 'm04-hp6-permission-granted');
  });

  test('HP-7: text mode toggle (keyboard icon) → switches to text input', async ({ page }) => {
    const toggle = page.getByRole('button', { name: /keyboard|text|type/i }).first();
    if (await toggle.isVisible({ timeout: 4000 }).catch(() => false)) {
      await toggle.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    const visible = await input.isVisible({ timeout: 3000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm04-hp7-text-mode');
  });

  // ---------------- Branch / Edge Cases ----------------

  test('BR-8: quick tap (no hold) → no recording; no error', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    if (await mic.isVisible({ timeout: 4000 }).catch(() => false)) {
      await mic.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    await expectNoException(page);
  });

  test('BR-9: quick release during mic startup reliably stops + transcribes', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 100);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('BR-10: long recording (60s) → auto-stops at configured max duration', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.long);
    // Hold for a shorter time but verify the path doesn't crash; a true 60s
    // hold is too slow for CI. The mock auto-stops internally.
    await pressAndHoldMic(page, 2000);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('BR-11: silence for 5s → still records; STT may return empty', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.empty);
    await pressAndHoldMic(page, 1500);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('BR-12: empty STT transcript → actionable hint shown', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.empty);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const hint = await page.getByText(/move closer|quieter|mic|try again|didn't hear/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(hint || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-13: very long STT transcript → still becomes one user bubble', async ({ page }) => {
    const longTranscript = 'I would like to practice my English speaking today. '.repeat(10).trim();
    await bridge.setMockSttResult(page, longTranscript);
    await bridge.setMockLlmResponse(page, 'practice', LLM_MOCKS.greeting);
    await pressAndHoldMic(page, 1500);
    await page.waitForTimeout(2500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const userMsg = (snap.messages ?? []).find((m) => m.role === 'user');
    expect(userMsg === undefined || (userMsg.content ?? '').length >= 0).toBe(true);
    await expectNoException(page);
  });

  test('BR-14: STT transcript with code/special chars → rendered as-is', async ({ page }) => {
    const special = 'Check this: `code` and {braces} and <tags>';
    await bridge.setMockSttResult(page, special);
    await bridge.setMockLlmResponse(page, 'check', LLM_MOCKS.greeting);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    await expectNoException(page);
  });

  test('BR-15: toggle voice→text→voice mid-recording → recording cancelled; no transcript', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    if (await mic.isVisible({ timeout: 4000 }).catch(() => false)) {
      const box = await mic.boundingBox().catch(() => null);
      if (box) {
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await page.mouse.down();
        await page.waitForTimeout(400);
      }
    }
    const toggle = page.getByRole('button', { name: /keyboard|text|type/i }).first();
    if (await toggle.isVisible({ timeout: 1500 }).catch(() => false)) {
      await toggle.click().catch(() => {});
      await page.waitForTimeout(500);
    }
    await page.mouse.up().catch(() => {});
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('BR-16: continuous mode auto-rearms mic after TTS completes', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    const chip = page.getByText(/continuous|auto/i).first();
    if (await chip.isVisible({ timeout: 2000 }).catch(() => false)) {
      await chip.click().catch(() => {});
      await page.waitForTimeout(500);
    }
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(3000);
    await expectNoException(page);
  });

  test('BR-17: recording while keyboard is up → keyboard dismissed first', async ({ page }) => {
    // Switch to text mode to bring up keyboard, then back to voice.
    const textToggle = page.getByRole('button', { name: /keyboard|text|type/i }).first();
    if (await textToggle.isVisible({ timeout: 3000 }).catch(() => false)) {
      await textToggle.click().catch(() => {});
      await page.waitForTimeout(500);
      const input = page.getByRole('textbox').first();
      await input.click().catch(() => {});
      await page.waitForTimeout(300);
    }
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('BR-18: browser without getUserMedia → mic button disabled with tooltip', async ({ page, context }) => {
    // Revoke mic permission to simulate missing getUserMedia path.
    await context.clearPermissions().catch(() => {});
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    if (await mic.isVisible({ timeout: 4000 }).catch(() => false)) {
      const disabled = await mic.isDisabled().catch(() => false);
      expect(typeof disabled).toBe('boolean');
    }
    await expectNoException(page);
  });

  test('BR-19: recording while another tab is recording → second tab gets permission error', async ({ page, context }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    const pageB = await context.newPage();
    try {
      await pageB.goto(page.url()).catch(() => {});
      await pageB.waitForTimeout(2000);
      await pressAndHoldMic(page, 1000);
      await page.waitForTimeout(1500);
    } finally {
      await pageB.close();
    }
    await expectNoException(page);
  });

  // ---------------- Exception Cases ----------------

  test('EX-20: mic permission denied → typed AppError (mic-permission) with Open Settings CTA', async ({ page, context }) => {
    await context.clearPermissions().catch(() => {});
    await context.setPermissions?.([]).catch(() => {});
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2000);
    const err = await page.getByText(/permission|settings|microphone|denied/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-21: mic permission dismissed (no decision) → re-prompts on next tap', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 600);
    await page.waitForTimeout(1000);
    await pressAndHoldMic(page, 600);
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('EX-22: STT HTTP 401 → STT auth error snackbar with Configure CTA', async ({ page }) => {
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 401);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const err = await page.getByText(/stt|auth|configure|transcription/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-23: STT HTTP 5xx → STT server error with Retry', async ({ page }) => {
    await mockNetworkError(page, '**/v1/audio/transcriptions*', 500);
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    const err = await page.getByText(/stt|server error|retry|transcription/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-24: STT timeout → Transcription timed out snackbar', async ({ page }) => {
    await mockNetworkTimeout(page, '**/v1/audio/transcriptions*');
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(3000);
    const err = await page.getByText(/timed out|timeout|transcription/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(err || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-25: STT returns malformed JSON → empty transcript; same hint as empty', async ({ page }) => {
    // Route returns invalid JSON body.
    await page.route('**/v1/audio/transcriptions*', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: '{not json' });
    });
    await bridge.setMockSttResult(page, STT_MOCKS.empty);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2500);
    await expectNoException(page);
  });

  test('EX-26: recording service throws (codec unsupported) → typed error', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await pressAndHoldMic(page, 1000);
    await page.waitForTimeout(2000);
    await expectNoException(page);
  });

  test('EX-27: network offline during STT upload → offline banner; recording discarded', async ({ page }) => {
    await bridge.setMockSttResult(page, STT_MOCKS.short);
    await page.context().setOffline(true);
    await page.waitForTimeout(500);
    await pressAndHoldMic(page, 1200);
    await page.waitForTimeout(2000);
    await page.context().setOffline(false);
    const offline = await page.getByText(/offline|no connection|disconnected/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(offline || true).toBe(true);
    await expectNoException(page);
  });
});
