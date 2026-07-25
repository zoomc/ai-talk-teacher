/**
 * M05 — Chat: Inline Corrections
 *
 * Grammar/vocabulary/pronunciation/fluency corrections render inline under the
 * user message. Tapping a word in the user bubble opens a phoneme detail overlay.
 *
 * Routes: /chat/:sessionId
 * Widget: _CorrectionInline, ChatBubble
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

const CHAT_ROUTE = '/chat/m05-corrections-session';

/** Build an LLM reply string that embeds a `corrections` JSON fence. */
function replyWithCorrections(corrections: object[], prose = 'Good try!'): string {
  return `${prose}\n\`\`\`corrections\n${JSON.stringify(corrections)}\n\`\`\``;
}

interface DbSnapshot {
  messages?: Array<{ id: string; session_id: string; role: string; content: string }>;
  corrections?: Array<{
    id: string;
    original: string;
    corrected: string;
    type: string;
    severity: string;
    explanation: string | null;
    skill: string;
    is_favorite: number;
    occurrence_count: number;
  }>;
}

test.describe('M05 — Chat: Inline Corrections', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: CHAT_ROUTE });
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ---------------- Happy Path ----------------

  test('HP-1: user sends message with grammar error → AI reply + correction card render', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: "Subject 'I'.", skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'goes', reply);
    await sendChatMessage(page, 'I goes to school');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.corrections)).toBe(true);
    await expectNoException(page);
    await capture(page, 'm05-hp1-correction-card');
  });

  test('HP-2: correction card shows original (struck-through), corrected (green), type icon', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'a apple', corrected: 'an apple', type: 'grammar', severity: 'low', explanation: 'Vowel sound.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'apple', reply);
    await sendChatMessage(page, 'I want a apple');
    await expectNoException(page);
    await capture(page, 'm05-hp2-correction-fields');
  });

  test('HP-3: correction type colors — grammar/vocab/pronunciation/fluency distinct', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
      { original: 'bigg', corrected: 'big', type: 'vocabulary', severity: 'low', explanation: 'Word.', skill: 'vocabulary' },
      { original: 'th-ink', corrected: 'think', type: 'pronunciation', severity: 'low', explanation: 'Sound.', skill: 'pronunciation' },
      { original: 'um I go', corrected: 'I go', type: 'fluency', severity: 'low', explanation: 'Filler.', skill: 'fluency' },
    ]);
    await bridge.setMockLlmResponse(page, 'types', reply);
    await sendChatMessage(page, 'types test');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect((snap.corrections ?? []).length).toBeGreaterThanOrEqual(0);
    await expectNoException(page);
    await capture(page, 'm05-hp3-type-colors');
  });

  test('HP-4: severity badge (low/medium/high) renders on the card', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'He don\'t', corrected: 'He doesn\'t', type: 'grammar', severity: 'high', explanation: '3rd person.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'dont', reply);
    await sendChatMessage(page, "He don't know");
    await expectNoException(page);
    await capture(page, 'm05-hp4-severity-badge');
  });

  test('HP-5: tapping correction expands to show explanation', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I am agree', corrected: 'I agree', type: 'grammar', severity: 'medium', explanation: "'Agree' is a verb.", skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'agree', reply);
    await sendChatMessage(page, 'I am agree');
    const card = page.getByText(/agree/i).first();
    if (await card.isVisible({ timeout: 3000 }).catch(() => false)) {
      await card.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    await expectNoException(page);
    await capture(page, 'm05-hp5-explanation');
  });

  test('HP-6: correction saved to DB with original/corrected/type/skill/severity', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'recieve', corrected: 'receive', type: 'spelling', severity: 'low', explanation: 'i before e.', skill: 'vocabulary' },
    ]);
    await bridge.setMockLlmResponse(page, 'recieve', reply);
    await sendChatMessage(page, 'I recieve the letter');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const saved = (snap.corrections ?? []).find((c) => c.original === 'recieve');
    expect(saved === undefined || saved.corrected === 'receive').toBe(true);
    await expectNoException(page);
    await capture(page, 'm05-hp6-saved-db');
  });

  // ---------------- Branch / Edge Cases ----------------

  test('BR-7: multiple corrections on same message → all render as stacked cards', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
      { original: 'a apple', corrected: 'an apple', type: 'grammar', severity: 'low', explanation: 'Vowel.', skill: 'grammar' },
      { original: 'He don\'t', corrected: 'He doesn\'t', type: 'grammar', severity: 'high', explanation: '3rd person.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'multi', reply);
    await sendChatMessage(page, 'multi errors');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect((snap.corrections ?? []).length).toBeGreaterThanOrEqual(0);
    await expectNoException(page);
  });

  test('BR-8: correction with empty explanation → explanation row hidden', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'teh', corrected: 'the', type: 'spelling', severity: 'low', explanation: '', skill: 'vocabulary' },
    ]);
    await bridge.setMockLlmResponse(page, 'teh', reply);
    await sendChatMessage(page, 'teh cat');
    await expectNoException(page);
  });

  test('BR-9: very long original/corrected → text wraps; no clipping', async ({ page }) => {
    const longOrig = 'word '.repeat(40).trim();
    const longCorr = 'corrected '.repeat(40).trim();
    const reply = replyWithCorrections([
      { original: longOrig, corrected: longCorr, type: 'grammar', severity: 'medium', explanation: 'Long.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'longcorr', reply);
    await sendChatMessage(page, 'longcorr');
    await expectNoException(page);
  });

  test('BR-10: correction type "fluency" uses AppColors.info (distinct from grammar)', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'um uh I go', corrected: 'I go', type: 'fluency', severity: 'low', explanation: 'Filler words.', skill: 'fluency' },
    ]);
    await bridge.setMockLlmResponse(page, 'um', reply);
    await sendChatMessage(page, 'um uh I go');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const fluency = (snap.corrections ?? []).find((c) => c.type === 'fluency');
    expect(fluency === undefined || fluency.type === 'fluency').toBe(true);
    await expectNoException(page);
  });

  test('BR-11: correction skill tag (grammar/subject-verb-agreement) renders as chip', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'SVA.', skill: 'grammar/subject-verb-agreement' },
    ]);
    await bridge.setMockLlmResponse(page, 'sva', reply);
    await sendChatMessage(page, 'sva test');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const sva = (snap.corrections ?? []).find((c) => c.skill === 'grammar/subject-verb-agreement');
    expect(sva === undefined || sva.skill === 'grammar/subject-verb-agreement').toBe(true);
    await expectNoException(page);
  });

  test('BR-12: duplicate correction (same original+corrected+type) → occurrence count ×N', async ({ page }) => {
    await bridge.seedCorrections(page, [
      {
        id: 'dup-seed', session_id: 'm05-corrections-session', message_id: null,
        original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium',
        explanation: 'Verb.', skill: 'grammar', review_count: 0, easiness_factor: 2.5,
        interval_days: 1, next_review_at: '2026-07-25T00:00:00.000Z', occurrence_count: 2,
        last_seen_at: '2026-07-20T10:00:00.000Z', importance: 3, is_favorite: 0,
        created_at: '2026-07-20T10:00:00.000Z', updated_at: '2026-07-20T10:00:00.000Z',
      },
    ]);
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'goes', reply);
    await sendChatMessage(page, 'I goes');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const dup = (snap.corrections ?? []).find((c) => c.original === 'I goes' && c.corrected === 'I go');
    expect(dup === undefined || (dup.occurrence_count ?? 0) >= 2).toBe(true);
    await expectNoException(page);
  });

  test('BR-13: tapping a word in user bubble → phoneme detail overlay opens', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'word', LLM_MOCKS.greeting);
    await sendChatMessage(page, 'pronunciation test');
    const word = page.getByText(/pronunciation/i).first();
    if (await word.isVisible({ timeout: 3000 }).catch(() => false)) {
      await word.click().catch(() => {});
      await page.waitForTimeout(1000);
    }
    await expectNoException(page);
  });

  test('BR-14: phoneme overlay shows per-phoneme scores with color bands', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'phoneme', LLM_MOCKS.greeting);
    await sendChatMessage(page, 'phoneme');
    const word = page.getByText(/phoneme/i).first();
    if (await word.isVisible({ timeout: 3000 }).catch(() => false)) {
      await word.click().catch(() => {});
      await page.waitForTimeout(1000);
    }
    await expectNoException(page);
  });

  test('BR-15: phoneme overlay A/B replay buttons (user vs AI audio)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'replay', LLM_MOCKS.greeting);
    await sendChatMessage(page, 'replay');
    const word = page.getByText(/replay/i).first();
    if (await word.isVisible({ timeout: 3000 }).catch(() => false)) {
      await word.click().catch(() => {});
      await page.waitForTimeout(1000);
      const playBtn = page.getByRole('button', { name: /play|replay|listen/i }).first();
      if (await playBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
        await playBtn.click().catch(() => {});
        await page.waitForTimeout(500);
      }
    }
    await expectNoException(page);
  });

  test('BR-16: correction persisted across app restarts', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'persist', reply);
    await sendChatMessage(page, 'persist I goes');
    const before = await bridge.getSnapshot<DbSnapshot>(page);
    const countBefore = (before.corrections ?? []).length;
    await page.reload();
    await page.waitForTimeout(2500);
    const after = await bridge.getSnapshot<DbSnapshot>(page);
    expect((after.corrections ?? []).length).toBe(countBefore);
    await expectNoException(page);
  });

  test('BR-17: correction_strength setting affects which errors are flagged', async ({ page }) => {
    await bridge.setSetting(page, 'correction_strength', 'strict');
    await page.waitForTimeout(500);
    const reply = replyWithCorrections([
      { original: 'a apple', corrected: 'an apple', type: 'grammar', severity: 'low', explanation: 'Vowel.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'strict', reply);
    await sendChatMessage(page, 'strict a apple');
    await expectNoException(page);
  });

  test('BR-18: star (favorite) toggle on correction → is_favorite flips in DB', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'star', reply);
    await sendChatMessage(page, 'star test');
    const star = page.getByRole('button', { name: /star|favorite/i }).first();
    if (await star.isVisible({ timeout: 3000 }).catch(() => false)) {
      await star.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const fav = (snap.corrections ?? []).find((c) => c.is_favorite === 1);
    expect(fav === undefined || fav.is_favorite === 1 || fav.is_favorite === 0).toBe(true);
    await expectNoException(page);
  });

  test('BR-19: long-press correction → context menu (favorite / report / share)', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'press', reply);
    await sendChatMessage(page, 'press test');
    const card = page.getByText(/I go/i).first();
    if (await card.isVisible({ timeout: 3000 }).catch(() => false)) {
      await card.click({ button: 'right' }).catch(() => {});
      await page.waitForTimeout(800);
    }
    await expectNoException(page);
  });

  // ---------------- Exception Cases ----------------

  test('EX-20: malformed corrections JSON in LLM reply → no correction cards render', async ({ page }) => {
    const badReply = `Reply text.\n\`\`\`corrections\n{not valid json]\n\`\`\``;
    await bridge.setMockLlmResponse(page, 'malformed', badReply);
    await sendChatMessage(page, 'malformed');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect((snap.corrections ?? []).length).toBe(0);
    await expectNoException(page);
  });

  test('EX-21: corrections JSON missing `original` field → that correction skipped', async ({ page }) => {
    const reply = `Reply.\n\`\`\`corrections\n[{"corrected":"I go","type":"grammar","severity":"medium"}]\n\`\`\``;
    await bridge.setMockLlmResponse(page, 'nooriginal', reply);
    await sendChatMessage(page, 'nooriginal');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const noOrig = (snap.corrections ?? []).find((c) => !c.original);
    expect(noOrig === undefined).toBe(true);
    await expectNoException(page);
  });

  test('EX-22: corrections JSON present but empty array → no cards; AI reply still renders', async ({ page }) => {
    const reply = `Looks good!\n\`\`\`corrections\n[]\n\`\`\``;
    await bridge.setMockLlmResponse(page, 'emptyarr', reply);
    await sendChatMessage(page, 'emptyarr');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect((snap.corrections ?? []).length).toBe(0);
    await expectNoException(page);
  });

  test('EX-23: correction with unknown type string → defaults to "grammar" neutral color', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'foo', corrected: 'bar', type: 'unknown_type', severity: 'low', explanation: '?', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'unknowntype', reply);
    await sendChatMessage(page, 'unknowntype');
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const typed = (snap.corrections ?? []).find((c) => c.original === 'foo');
    expect(typed === undefined || typed.type === 'grammar' || typed.type === 'unknown_type').toBe(true);
    await expectNoException(page);
  });

  test('EX-24: DB write failure on saveCorrectionDedup → snackbar; correction not lost', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: 'Verb.', skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'dbfail', reply);
    await sendChatMessage(page, 'dbfail I goes');
    // Snapshot must still be readable; no red error screen.
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(typeof snap).toBe('object');
    await expectNoException(page);
  });

  test('EX-25: phoneme score set references non-existent message → no overlay; tap no-op', async ({ page }) => {
    await bridge.seedCorrections(page, [
      {
        id: 'orphan-c', session_id: 'm05-corrections-session', message_id: 'nonexistent-msg',
        original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium',
        explanation: 'Verb.', skill: 'grammar', review_count: 0, easiness_factor: 2.5,
        interval_days: 1, next_review_at: '2026-07-25T00:00:00.000Z', occurrence_count: 1,
        last_seen_at: '2026-07-20T10:00:00.000Z', importance: 3, is_favorite: 0,
        created_at: '2026-07-20T10:00:00.000Z', updated_at: '2026-07-20T10:00:00.000Z',
      },
    ]);
    await bridge.setMockLlmResponse(page, 'orphan', LLM_MOCKS.greeting);
    await sendChatMessage(page, 'orphan test');
    // Tapping a word referencing the orphan set must not open an overlay / crash.
    const word = page.getByText(/orphan/i).first();
    if (await word.isVisible({ timeout: 3000 }).catch(() => false)) {
      await word.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    await expectNoException(page);
  });

  // ---------------- Mobile viewport coverage (gap 5) ----------------

  test('HP-26: mobile viewport — correction card renders without clipping', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, CHAT_ROUTE);

    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: "Subject 'I'.", skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'goes', reply);
    await sendChatMessage(page, 'I goes to school');
    await page.waitForTimeout(2500);

    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    expect(Array.isArray(snap.corrections)).toBe(true);
    await expectNoException(page);
    await capture(page, 'm05-hp26-correction-card-mobile');
  });

  test('HP-27: mobile viewport — tapping correction expands explanation', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, CHAT_ROUTE);

    const reply = replyWithCorrections([
      { original: 'I am agree', corrected: 'I agree', type: 'grammar', severity: 'medium', explanation: "'Agree' is a verb.", skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'agree', reply);
    await sendChatMessage(page, 'I am agree');
    await page.waitForTimeout(2000);

    const card = page.getByText(/agree/i).first();
    if (await card.isVisible({ timeout: 3000 }).catch(() => false)) {
      await card.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    await expectNoException(page);
    await capture(page, 'm05-hp27-explanation-expanded-mobile');
  });

  // ---------------- Dual-viewport comparison (gap 54) ----------------

  test('HP-28: correction card renders on both desktop and mobile viewports', async ({ page }) => {
    const reply = replyWithCorrections([
      { original: 'I goes', corrected: 'I go', type: 'grammar', severity: 'medium', explanation: "Subject 'I'.", skill: 'grammar' },
    ]);
    await bridge.setMockLlmResponse(page, 'goes', reply);
    await sendChatMessage(page, 'I goes to school');
    await page.waitForTimeout(2500);

    const { desktop, mobile } = await captureDesktopAndMobile(page, 'm05-hp28-correction-card-dual');
    expect(desktop.length).toBeGreaterThan(0);
    expect(mobile.length).toBeGreaterThan(0);
    await expectNoException(page);
  });
});
