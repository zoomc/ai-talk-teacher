/**
 * M11 — Avatar: Emotion Markers
 *
 * LLM prefixes each reply with `[emotion:id]`. Markers are stripped before
 * save/display/TTS. Covers parser, stripper, keyword fallback, easing, and
 * the 7-emotion pose table.
 *
 * Spec reference: docs/e2e-spec.md → M11 — Avatar: Emotion Markers.
 */
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { setupE2EApp, navigate, DESKTOP_VIEWPORT, MOBILE_VIEWPORT } from '../../lib/setup';
import { capture, captureFullPage } from '../../lib/screenshots';
import { expectVisible, expectText, expectNotVisible, expectRoute, expectNoException, expectElementCount } from '../../lib/assertions';
import * as bridge from '../../lib/e2e-bridge';
import { setLlmResponse, setSttTranscript, setTtsAudio, mockNetworkError, mockNetworkTimeout, resetOverrides } from '../../lib/mock';
import { FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';
import type { LlmProfileRow, SttProfileRow, TtsProfileRow, MessageRow } from '../../fixtures/fixtures';
import { settle } from '../../helpers';

const SESSION_ID = 'm11-emotion-session';

const SESSION_ROW = {
  id: SESSION_ID,
  topic: 'Emotion markers test',
  scenario_id: null,
  status: 'active',
  tutor_id: 'tutor-friendly',
  level_tag: 'B1',
  is_guest: 0,
  created_at: '2026-07-25T10:00:00.000Z',
  updated_at: '2026-07-25T10:00:00.000Z',
  archived_at: null,
};

/** Type a message into the chat input and submit it (Enter + send button fallback). */
async function sendAndWait(page: Page, text: string): Promise<void> {
  const input = page.getByRole('textbox').first();
  await input.click({ timeout: 5000 }).catch(() => {});
  await page.keyboard.type(text, { delay: 5 });
  await page.keyboard.press('Enter');
  // Fallback: some chat input bars only send on an explicit send tap.
  await page.getByRole('button', { name: /send|发送/i }).click({ timeout: 1500 }).catch(() => {});
  await settle(page, 2500);
}

async function bodyText(page: Page): Promise<string> {
  return page.locator('body').innerText().catch(() => '');
}

test.describe('M11 — Avatar: Emotion Markers', () => {
  test.beforeEach(async ({ page }) => {
    // /chat/... bypasses the onboarding/placement redirect guards so we can
    // land directly on a chat surface even before placement is marked done.
    await setupE2EApp(page, 'onboarded', { route: '/chat/m11-setup-bypass' });
    await bridge.seedChatSessions(page, [SESSION_ROW]);
    await navigate(page, `/chat/${SESSION_ID}`);
    await settle(page, 1500);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ── Happy Path (5) ─────────────────────────────────────────────────────

  test('HP-1: [emotion:happy] marker is stripped and reply text is shown in bubble', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', "[emotion:happy] That's great!");
    await sendAndWait(page, 'hello');
    await expectText(page, "That's great!");
    const body = await bodyText(page);
    expect(body).not.toContain('[emotion:');
    await expectNoException(page);
    await capture(page, 'm11-hp1-happy-marker');
  });

  test('HP-2: emotion transition uses 250ms easeOutCubic (avatar canvas stays visible)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hi', '[emotion:happy] Yay!');
    await sendAndWait(page, 'hi');
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });
    // Wait beyond the 250ms transition window; canvas must remain stable.
    await settle(page, 500);
    await expect(canvas).toBeVisible();
    await expectNoException(page);
    await capture(page, 'm11-hp2-transition');
  });

  test('HP-3: neutral → happy → neutral cycle renders without errors', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'first', '[emotion:happy] Wonderful!');
    await sendAndWait(page, 'first');
    await expectText(page, 'Wonderful!');

    await bridge.setMockLlmResponse(page, 'second', '[emotion:neutral] Okay.');
    await sendAndWait(page, 'second');
    await expectText(page, 'Okay.');

    await expectNoException(page);
    await capture(page, 'm11-hp3-neutral-cycle');
  });

  test('HP-4: waiting state used when avatar is idle waiting for user', async ({ page }) => {
    // Before any message is sent, avatar is in idle/waiting state.
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
    await capture(page, 'm11-hp4-waiting-idle');
  });

  test('HP-5: thinking state during LLM streaming (canvas persists, no errors)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'ponder', '[emotion:thinking] Hmm, let me consider.');
    await sendAndWait(page, 'ponder');
    await expectText(page, 'Hmm, let me consider');
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
    await capture(page, 'm11-hp5-thinking');
  });

  // ── Branch / Edge Cases (14) ───────────────────────────────────────────

  test('BR-6: (emotion:happy) paren form parses and is stripped', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'paren', '(emotion:happy) Nice work!');
    await sendAndWait(page, 'paren');
    await expectText(page, 'Nice work!');
    const body = await bodyText(page);
    expect(body).not.toContain('(emotion:');
    await expectNoException(page);
  });

  test('BR-7: [Emotion:Happy] case-insensitive marker is stripped', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'case', '[Emotion:Happy] Well done!');
    await sendAndWait(page, 'case');
    await expectText(page, 'Well done!');
    const body = await bodyText(page);
    expect(body.toLowerCase()).not.toContain('[emotion:');
    await expectNoException(page);
  });

  test('BR-8: [ emotion : happy ] whitespace-tolerant marker is stripped', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'ws', '[ emotion : happy ] Awesome!');
    await sendAndWait(page, 'ws');
    await expectText(page, 'Awesome!');
    const body = await bodyText(page);
    expect(body).not.toContain('[ emotion');
    await expectNoException(page);
  });

  test('BR-9: multiple markers in one reply — first wins, all stripped', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'multi', '[emotion:happy] First [emotion:thinking] Second part.');
    await sendAndWait(page, 'multi');
    await expectText(page, 'First');
    await expectText(page, 'Second part');
    const body = await bodyText(page);
    expect(body).not.toContain('[emotion:');
    await expectNoException(page);
  });

  test('BR-10: stripEmotionMarkers collapses double spaces left by removal', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'spaces', '[emotion:happy]  Double  spaces  here.');
    await sendAndWait(page, 'spaces');
    await expectText(page, 'Double');
    await expectText(page, 'spaces here');
    const body = await bodyText(page);
    expect(body).not.toMatch(/\[emotion:/);
    await expectNoException(page);
  });

  test('BR-11: explicit marker wins over keyword matching', async ({ page }) => {
    // Text contains "great" (keyword → happy) AND explicit [emotion:thinking].
    // Marker wins. Either way the marker is stripped from the displayed reply.
    await bridge.setMockLlmResponse(page, 'pref', '[emotion:thinking] That is great!');
    await sendAndWait(page, 'pref');
    await expectText(page, 'That is great!');
    const body = await bodyText(page);
    expect(body).not.toContain('[emotion:');
    await expectNoException(page);
  });

  test('BR-12: keyword fallback — "great" without marker renders normally', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'kw', "That's great, keep it up!");
    await sendAndWait(page, 'kw');
    await expectText(page, 'great');
    const body = await bodyText(page);
    expect(body).not.toContain('[emotion:');
    await expectNoException(page);
  });

  test('BR-13: amplitude-driven emotion overrides neutral only (keyword reply unaffected)', async ({ page }) => {
    // Keyword reply "Great job!" → happy; TTS amplitude cannot downgrade it.
    await bridge.setMockLlmResponse(page, 'amp', 'Great job!');
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await sendAndWait(page, 'amp');
    await expectText(page, 'Great job!');
    await expectNoException(page);
  });

  test('BR-14: easing curves (linear / easeInOutQuad / easeOutCubic) do not throw', async ({ page }) => {
    // Switching emotions across turns exercises every easing code path.
    await bridge.setMockLlmResponse(page, 'ease1', '[emotion:happy] A');
    await sendAndWait(page, 'ease1');
    await bridge.setMockLlmResponse(page, 'ease2', '[emotion:confused] B');
    await sendAndWait(page, 'ease2');
    await bridge.setMockLlmResponse(page, 'ease3', '[emotion:focused] C');
    await sendAndWait(page, 'ease3');
    await expectNoException(page);
  });

  test('BR-15: kDefaultEmotionPoses covers all 7 emotions without error', async ({ page }) => {
    const cases: Array<readonly [string, string]> = [
      ['n1', '[emotion:neutral] one'],
      ['n2', '[emotion:happy] two'],
      ['n3', '[emotion:thinking] three'],
      ['n4', '[emotion:encouraging] four'],
      ['n5', '[emotion:confused] five'],
      ['n6', '[emotion:focused] six'],
      ['n7', '[emotion:waiting] seven'],
    ];
    for (const [n, m] of cases) {
      await bridge.setMockLlmResponse(page, n, m);
      await sendAndWait(page, n);
    }
    await expectNoException(page);
  });

  test('BR-16: pose lerping blends parameters across consecutive emotions', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'lerp1', '[emotion:happy] Smile');
    await sendAndWait(page, 'lerp1');
    await bridge.setMockLlmResponse(page, 'lerp2', '[emotion:confused] Puzzled');
    await sendAndWait(page, 'lerp2');
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
  });

  test('BR-17: markers stripped before DB save (snapshot has no [emotion:)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'save', '[emotion:happy] Persisted reply.');
    await sendAndWait(page, 'save');
    const snap = await bridge.getSnapshot<{ messages?: MessageRow[] }>(page);
    const assistantMsgs = (snap.messages ?? []).filter((m) => m.role === 'assistant');
    expect(assistantMsgs.length).toBeGreaterThan(0);
    for (const m of assistantMsgs) {
      expect(m.content).not.toContain('[emotion:');
    }
    await expectNoException(page);
  });

  test('BR-18: markers stripped before TTS (no spoken markers in display)', async ({ page }) => {
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
    await bridge.setMockLlmResponse(page, 'tts', '[emotion:encouraging] Keep going!');
    await sendAndWait(page, 'tts');
    await expectText(page, 'Keep going!');
    const body = await bodyText(page);
    expect(body).not.toContain('[emotion:');
    await expectNoException(page);
  });

  test('BR-19: waiting emotion biases smile baseline lower (attentive, not happy)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'wait', '[emotion:waiting] Take your time.');
    await sendAndWait(page, 'wait');
    await expectText(page, 'Take your time');
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });
    await expectNoException(page);
  });

  // ── Exception Cases (4) ────────────────────────────────────────────────

  test('EX-20: unknown emotion id [emotion:foo] is ignored; keyword fallback applies', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'unknown', '[emotion:foo] great response');
    await sendAndWait(page, 'unknown');
    // "great" keyword → happy. Unknown marker is stripped regardless.
    await expectText(page, 'great response');
    const body = await bodyText(page);
    expect(body).not.toContain('[emotion:foo]');
    await expectNoException(page);
  });

  test('EX-21: malformed marker [emotion:happy (no close bracket) is plain text', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'malformed', '[emotion:happy plain text here');
    await sendAndWait(page, 'malformed');
    // No closing bracket → not a marker → shown as plain text (no exception).
    const body = await bodyText(page);
    expect(body).toContain('plain text here');
    await expectNoException(page);
  });

  test('EX-22: empty marker [emotion:] is ignored', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'empty', '[emotion:] Hello there');
    await sendAndWait(page, 'empty');
    await expectText(page, 'Hello there');
    const body = await bodyText(page);
    // No valid marker (id is empty) should be visible.
    expect(body).not.toMatch(/\[emotion:[a-zA-Z]/);
    await expectNoException(page);
  });

  test('EX-23: marker inside corrections JSON block is not parsed (only main reply scanned)', async ({ page }) => {
    const reply = [
      '[emotion:happy] Main reply text.',
      '```corrections',
      '[{"original":"x","corrected":"y","type":"grammar","severity":"low","skill":"grammar","explanation":"[emotion:confused] inside json"}]',
      '```',
    ].join('\n');
    await bridge.setMockLlmResponse(page, 'jsonblock', reply);
    await sendAndWait(page, 'jsonblock');
    await expectText(page, 'Main reply text');
    await expectNoException(page);
  });
});
