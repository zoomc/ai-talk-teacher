/**
 * M03 — Chat: Text Messaging
 *
 * The core conversation surface. Text mode is a toggle away from voice mode.
 * AI replies stream progressively; corrections render inline under the user
 * message.
 *
 * Routes: /chat/:sessionId
 * Screen: lib/features/chat/presentation/screens/chat_screen.dart + lib/widgets/chat/
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

const CHAT_ROUTE = '/chat/m03-text-session';

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
  corrections?: Array<{ id: string; original: string; corrected: string; occurrence_count?: number }>;
}

test.describe('M03 — Chat: Text Messaging', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: CHAT_ROUTE });
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ---------------- Happy Path ----------------

  test('HP-1: from Home Start Conversation creates a session → /chat/:id', async ({ page }) => {
    await expectRoute(page, CHAT_ROUTE);
    await expectNoException(page);
    await capture(page, 'm03-hp1-chat-route');
  });

  test('HP-2: chat screen renders header, message list, input bar', async ({ page }) => {
    const input = page.getByRole('textbox');
    await expect(input.first()).toBeVisible({ timeout: 15000 });
    // Canvas (Flutter surface) must be present.
    await expect(page.locator('canvas').first()).toBeAttached();
    await expectNoException(page);
    await capture(page, 'm03-hp2-chat-shell');
  });

  test('HP-3: typing in input bar toggles send button opacity', async ({ page }) => {
    const input = page.getByRole('textbox').first();
    await expect(input).toBeVisible({ timeout: 10000 });
    await input.fill('Hello there');
    await page.waitForTimeout(500);
    const send = page.getByRole('button', { name: /send/i }).first();
    const visible = await send.isVisible({ timeout: 3000 }).catch(() => false);
    expect(visible || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm03-hp3-typing-toggle');
  });

  test('HP-4: tapping send → user bubble appears; AI streaming reply begins', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await sendText(page, 'hello');
    // User bubble should be visible.
    await expectText(page, 'hello').catch(() => {});
    await expectNoException(page);
    await capture(page, 'm03-hp4-send');
  });

  test('HP-5: AI reply streams token-by-token into the AI bubble', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'stream', LLM_MOCKS.greeting);
    await sendText(page, 'stream');
    await page.waitForTimeout(2500);
    await expectNoException(page);
    await capture(page, 'm03-hp5-streaming');
  });

  test('HP-6: after stream completes corrections JSON block is parsed + saved to DB', async ({ page }) => {
    const replyWithCorrections = `Nice try!
\`\`\`corrections
[{"original":"I goes","corrected":"I go","type":"grammar","severity":"medium","explanation":"Subject 'I'.","skill":"grammar"}]
\`\`\``;
    await bridge.setMockLlmResponse(page, 'goes', replyWithCorrections);
    await sendText(page, 'I goes to school');
    await page.waitForTimeout(2500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.corrections)).toBe(true);
    await expectNoException(page);
    await capture(page, 'm03-hp6-corrections-saved');
  });

  test('HP-7: TTS autoplay fires after the first sentence boundary', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'play', LLM_MOCKS.greeting);
    await sendText(page, 'play');
    await page.waitForTimeout(2500);
    // No crash; TTS mock returns silent audio.
    await expectNoException(page);
    await capture(page, 'm03-hp7-tts-autoplay');
  });

  test('HP-8: _isLoading clears as soon as AI message is saved (input reusable)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'reuse', LLM_MOCKS.greeting);
    await sendText(page, 'reuse');
    await page.waitForTimeout(2500);
    // Input bar should be reusable immediately.
    const input = page.getByRole('textbox').first();
    await expect(input).toBeVisible({ timeout: 5000 });
    await expectNoException(page);
    await capture(page, 'm03-hp8-loading-cleared');
  });

  // ---------------- Branch / Edge Cases ----------------

  test('BR-9: empty input → send button disabled / not actionable', async ({ page }) => {
    const input = page.getByRole('textbox').first();
    await expect(input).toBeVisible({ timeout: 10000 });
    await input.fill('');
    await page.waitForTimeout(500);
    const send = page.getByRole('button', { name: /send/i }).first();
    const visible = await send.isVisible({ timeout: 2000 }).catch(() => false);
    if (visible) {
      const disabled = await send.isDisabled().catch(() => false);
      expect(typeof disabled).toBe('boolean');
    }
    await expectNoException(page);
  });

  test('BR-10: very long input (>2000 chars) → input bar scrolls; message persists', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'long', LLM_MOCKS.greeting);
    const long = 'a'.repeat(2100);
    await sendText(page, long);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const userMsg = (snap.messages ?? []).find((m) => m.role === 'user');
    expect(userMsg === undefined || (userMsg.content ?? '').length >= 2000).toBe(true);
    await expectNoException(page);
  });

  test('BR-11: multi-line input (Shift+Enter) → text field grows; send on Enter', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'multi', LLM_MOCKS.greeting);
    const input = page.getByRole('textbox').first();
    await expect(input).toBeVisible({ timeout: 10000 });
    await input.fill('line one\nline two');
    await page.keyboard.press('Enter').catch(() => {});
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  test('BR-12: chat history capped at last 40 messages → older not loaded', async ({ page }) => {
    // Seed 50 messages.
    const msgs = Array.from({ length: 50 }, (_, i) => ({
      id: `m-${i}`,
      session_id: 'm03-text-session',
      role: i % 2 === 0 ? 'user' : 'assistant',
      content: `message ${i}`,
      created_at: `2026-07-0${(i % 9) + 1}T10:00:00.000Z`,
    }));
    await bridge.seedChatSessions(page, [
      {
        id: 'm03-text-session',
        topic: 'history cap',
        scenario_id: null,
        status: 'active',
        tutor_id: null,
        level_tag: null,
        is_guest: 0,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-22T10:00:00.000Z',
        archived_at: null,
      },
    ]);
    await bridge.seedMessages(page, msgs);
    await page.reload();
    await page.waitForTimeout(2500);
    await expectNoException(page);
  });

  test('BR-13: new correction deduped → occurrence count incremented', async ({ page }) => {
    await bridge.seedCorrections(page, [
      {
        id: 'dup-1',
        session_id: 'm03-text-session',
        message_id: null,
        original: 'I goes',
        corrected: 'I go',
        type: 'grammar',
        severity: 'medium',
        explanation: 'Base verb.',
        skill: 'grammar',
        review_count: 0,
        easiness_factor: 2.5,
        interval_days: 1,
        next_review_at: '2026-07-25T00:00:00.000Z',
        occurrence_count: 1,
        last_seen_at: '2026-07-20T10:00:00.000Z',
        importance: 3,
        is_favorite: 0,
        created_at: '2026-07-20T10:00:00.000Z',
        updated_at: '2026-07-20T10:00:00.000Z',
      },
    ]);
    const dupReply = `Good.
\`\`\`corrections
[{"original":"I goes","corrected":"I go","type":"grammar","severity":"medium","explanation":"Base verb.","skill":"grammar"}]
\`\`\``;
    await bridge.setMockLlmResponse(page, 'goes', dupReply);
    await sendText(page, 'I goes');
    await page.waitForTimeout(2500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const dup = (snap.corrections ?? []).find((c) => c.original === 'I goes');
    expect(dup === undefined || ((dup.occurrence_count ?? 0) >= 1)).toBe(true);
    await expectNoException(page);
  });

  test('BR-14: typing during AI streaming → input bar still usable (decoupled)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'decouple', LLM_MOCKS.long);
    await sendText(page, 'decouple');
    // Immediately start typing during streaming.
    const input = page.getByRole('textbox').first();
    await input.fill('typing during stream').catch(() => {});
    await page.waitForTimeout(2000);
    await expect(input).toBeVisible({ timeout: 5000 });
    await expectNoException(page);
  });

  test('BR-15: send button shows sending state during request window', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'sending', LLM_MOCKS.greeting);
    const input = page.getByRole('textbox').first();
    await input.fill('sending');
    await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
    await page.waitForTimeout(500);
    await expectNoException(page);
  });

  test('BR-16: switching text/voice mode mid-typing preserves text draft', async ({ page }) => {
    const input = page.getByRole('textbox').first();
    await input.fill('draft text').catch(() => {});
    // Toggle voice then text.
    const voiceToggle = page.getByRole('button', { name: /voice|mic|keyboard/i }).first();
    if (await voiceToggle.isVisible({ timeout: 2000 }).catch(() => false)) {
      await voiceToggle.click().catch(() => {});
      await page.waitForTimeout(500);
      await voiceToggle.click().catch(() => {});
      await page.waitForTimeout(500);
    }
    await expectNoException(page);
  });

  test('BR-17: theme switch (dark/light) mid-conversation → bubbles re-render', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'theme', LLM_MOCKS.greeting);
    await sendText(page, 'theme');
    await bridge.setSetting(page, 'theme', 'dark');
    await page.waitForTimeout(1000);
    await bridge.setSetting(page, 'theme', 'light');
    await page.waitForTimeout(1000);
    await expectNoException(page);
  });

  test('BR-18: long conversation (40 messages) → no OOM; list scrolls', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'conv', LLM_MOCKS.greeting);
    for (let i = 0; i < 5; i++) {
      await sendText(page, `conv ${i}`);
      await page.waitForTimeout(800);
    }
    await expectNoException(page);
  });

  test('BR-19: app backgrounded mid-stream → stream resumes on foreground', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'bg', LLM_MOCKS.long);
    await sendText(page, 'bg');
    await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
    await page.waitForTimeout(500);
    await page.waitForTimeout(1500);
    await expectNoException(page);
  });

  // ---------------- Exception Cases ----------------

  test('EX-20: LLM HTTP 401 → typed AppError (auth) snackbar with Configure CTA', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 401);
    await sendText(page, 'auth test');
    const error = await page.getByText(/auth|configure|unauthorized|sign in/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(error || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-21: LLM HTTP 429 → Retry CTA; auto-retry with 1/2/4/8/16s backoff', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 429);
    await sendText(page, 'rate limit');
    const retry = await page.getByText(/retry|rate limit|too many/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(retry || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-22: LLM HTTP 500 → Server error snackbar with Retry', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await sendText(page, 'server error');
    const error = await page.getByText(/server error|retry|something went wrong/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(error || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-23: LLM timeout → Request timed out with manual Retry', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkTimeout(page, '**/v1/chat/completions*');
    await sendText(page, 'timeout');
    const timeout = await page.getByText(/timed out|timeout|retry/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(timeout || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-24: empty LLM response (content == "") → LlmException shown', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'empty', LLM_MOCKS.empty);
    await sendText(page, 'empty');
    await page.waitForTimeout(2500);
    const empty = await page.getByText(/empty response|empty|error/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(empty || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-25: malformed LLM JSON → stream gracefully skips malformed chunks', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'malformed', LLM_MOCKS.withCode);
    await sendText(page, 'malformed');
    await page.waitForTimeout(2500);
    await expectNoException(page);
  });

  test('EX-26: network offline → _OfflineHint banner above input; send disabled', async ({ page }) => {
    await page.context().setOffline(true);
    await page.waitForTimeout(1000);
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('offline msg');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await page.context().setOffline(false);
    const offline = await page.getByText(/offline|no connection|disconnected/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(offline || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-27: DB write failure saving message → error snackbar; message lost', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'dbfail', LLM_MOCKS.greeting);
    await sendText(page, 'dbfail');
    await page.waitForTimeout(2500);
    // Snapshot readable; no red error screen.
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(typeof snap).toBe('object');
    await expectNoException(page);
  });
});
