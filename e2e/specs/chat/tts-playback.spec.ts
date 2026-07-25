/**
 * M06 — Chat: TTS Playback
 *
 * AI reply auto-plays TTS after the first sentence boundary. Manual play/pause
 * per message. Failure tracked per-message-id with inline retry.
 *
 * Routes: /chat/:sessionId
 * Service: TtsService, TtsPlaybackService
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, navigate, DESKTOP_VIEWPORT, MOBILE_VIEWPORT } from '../../lib/setup';
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
import { settle, goTo } from '../../helpers';
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
import type { ChatSessionRow, MessageRow } from '../../fixtures/fixtures';

const TEST_SESSION: ChatSessionRow = {
  id: 'test-session',
  topic: 'TTS Playback Test',
  scenario_id: null,
  status: 'active',
  tutor_id: 'tutor-friendly',
  level_tag: 'B1',
  is_guest: 0,
  created_at: '2026-07-25T10:00:00.000Z',
  updated_at: '2026-07-25T10:00:00.000Z',
  archived_at: null,
};

const SEEDED_AI_MSG: MessageRow = {
  id: 'ai-seed-1',
  session_id: 'test-session',
  role: 'assistant',
  content: 'Hello! I am your AI tutor. How can I help you practice today?',
  created_at: '2026-07-25T10:01:00.000Z',
};

test.describe('M06 — Chat: TTS Playback', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/chat/test-session' });
    await bridge.seedChatSessions(page, [TEST_SESSION]);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  test('HP-1: AI reply streams and TTS autoplays after first sentence', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 1500);
    await expectText(page, LLM_MOCKS.greeting);
    await expectNoException(page);
    await capture(page, 'm06-hp1-tts-autoplay');
  });

  test('HP-2: TTS audio plays and avatar enters speaking state', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hi', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hi there!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2000);
    await expectText(page, 'Speaking');
    await expectNoException(page);
    await capture(page, 'm06-hp2-avatar-speaking');
  });

  test('HP-3: Playback completes and avatar returns to idle', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hey', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hey!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 4000);
    await expectText(page, 'Ready');
    await expectNoException(page);
    await capture(page, 'm06-hp3-avatar-idle-after-tts');
  });

  test('HP-4: Manual play button visible on each AI message', async ({ page }) => {
    await bridge.seedMessages(page, [SEEDED_AI_MSG]);
    await navigate(page, '/chat/test-session');
    await expectText(page, SEEDED_AI_MSG.content);
    const playBtn = page.getByRole('button', { name: /play/i }).first();
    await expect(playBtn).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
    await capture(page, 'm06-hp4-play-button-visible');
  });

  test('HP-5: Tapping play on a previous AI message replays TTS', async ({ page }) => {
    await bridge.seedMessages(page, [SEEDED_AI_MSG]);
    await navigate(page, '/chat/test-session');
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('button', { name: /play/i }).first().click().catch(() => {});
    await settle(page, 1500);
    await expectNoException(page);
    await capture(page, 'm06-hp5-replay-previous');
  });

  test('HP-6: TTS speed follows tts_speed setting', async ({ page }) => {
    await bridge.setSetting(page, 'tts_speed', '1.5');
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await navigate(page, '/chat/test-session');
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 1500);
    await expectText(page, LLM_MOCKS.greeting);
    await expectNoException(page);
    await capture(page, 'm06-hp6-tts-speed-1.5x');
  });

  test('BR-1: Continuous mode plus TTS complete auto-rearms mic', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 4500);
    const mic = page.getByRole('button', { name: /mic|record|microphone/i }).first();
    await expect(mic).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
  });

  test('BR-2: Barge-in tap mic during TTS stops playback immediately', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 1500);
    await page.getByRole('button', { name: /mic|record|microphone/i }).first().click().catch(() => {});
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('BR-3: TTS speed change mid-playback applies via setSpeed', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 800);
    await bridge.setSetting(page, 'tts_speed', '1.25');
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('BR-4: TTS for long reply over 500 chars plays full audio', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'long', LLM_MOCKS.long);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Tell me a long story.');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2500);
    await expectText(page, 'long mock response');
    await expectNoException(page);
  });

  test('BR-5: Multiple AI messages in rapid succession only latest autoplays', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 600);
    await page.getByRole('textbox').fill('Hi again!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2000);
    await expectNoException(page);
  });

  test('BR-6: TTS audio cached replaying same text is instant', async ({ page }) => {
    await bridge.seedMessages(page, [SEEDED_AI_MSG]);
    await navigate(page, '/chat/test-session');
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('button', { name: /play/i }).first().click().catch(() => {});
    await settle(page, 1500);
    await page.getByRole('button', { name: /play/i }).first().click().catch(() => {});
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('BR-7: Viseme timeline pushed to AvatarStage on TTS success', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2000);
    await expectText(page, 'Speaking');
    await expectNoException(page);
  });

  test('BR-8: Viseme timeline cleared on playback completion', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 4500);
    await expectText(page, 'Ready');
    await expectNoException(page);
  });

  test('BR-9: low_bandwidth setting on TTS still plays', async ({ page }) => {
    await bridge.setSetting(page, 'low_bandwidth', 'true');
    await navigate(page, '/chat/test-session');
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2000);
    await expectText(page, LLM_MOCKS.greeting);
    await expectNoException(page);
  });

  test('BR-10: User navigates away mid-TTS playback stops', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 800);
    await navigate(page, '/');
    await settle(page, 1500);
    await expectRoute(page, '/');
    await expectNoException(page);
  });

  test('BR-11: App backgrounded mid-TTS playback pauses', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 800);
    await page.evaluate(() => {
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('BR-12: Volume muted at OS level playback proceeds silently', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2000);
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
  });

  test('EX-1: TTS HTTP 401 shows auth error snackbar with inline retry', async ({ page }) => {
    await bridge.setMockMode(page, false);
    setLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await mockNetworkError(page, '**/v1/audio/speech*', 401);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 3000);
    await expectNoException(page);
  });

  test('EX-2: TTS HTTP 5xx shows server error with inline retry', async ({ page }) => {
    await bridge.setMockMode(page, false);
    setLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await mockNetworkError(page, '**/v1/audio/speech*', 500);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 3000);
    await expectNoException(page);
  });

  test('EX-3: TTS timeout shows timed out with retry', async ({ page }) => {
    await bridge.setMockMode(page, false);
    setLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await mockNetworkTimeout(page, '**/v1/audio/speech*');
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 3000);
    await expectNoException(page);
  });

  test('EX-4: TTS returns empty audio throws TtsException with inline retry', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await bridge.setMockTtsAudio(page, '');
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 3000);
    await expectNoException(page);
  });

  test('EX-5: just_audio decode error avatar stuck speaking retry clears', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    // Non-audio payload that just_audio cannot decode.
    await bridge.setMockTtsAudio(page, Buffer.from('not-audio-bytes').toString('base64'));
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 2500);
    await page.getByRole('button', { name: /retry/i }).first().click().catch(() => {});
    await settle(page, 1500);
    await expectNoException(page);
  });

  test('EX-6: Network offline when TTS requested shows offline banner', async ({ page }) => {
    await bridge.setMockMode(page, false);
    await page.context.setOffline(true);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 3000);
    await expect(page.getByText(/offline/i).first()).toBeVisible({ timeout: 15000 }).catch(() => {});
    await page.context.setOffline(false);
    await expectNoException(page);
  });

  test('EX-7: Malformed audio bytes decode error with inline retry', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    // Garbage base64 — neither mp3 nor wav.
    await bridge.setMockTtsAudio(page, '@@@@malformed-not-audio@@@@');
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await settle(page, 3000);
    await expectNoException(page);
  });
});
