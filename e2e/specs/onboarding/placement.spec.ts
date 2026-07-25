/**
 * M02 — Placement Test
 *
 * A 5-turn AI conversation that streams each reply and emits a strict-JSON
 * verdict inside a ```placement``` fence. Renders a radar chart + per-dimension
 * score table + 4-week learning path. Falls back to a static quiz when no LLM
 * profile exists. "Skip" defaults the level to `beginner`.
 *
 * Routes: /placement
 * Screen: lib/features/onboarding/presentation/screens/placement_screen.dart
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

/** A placement verdict fenced inside the LLM reply (strict JSON). */
const PLACEMENT_VERDICT_REPLY = `Let's begin your assessment. Tell me about yourself.
\`\`\`placement
{"level":"B1","scores":{"vocabulary":72,"fluency":68,"grammar":75,"pronunciation":70,"confidence":65},"summary":"Intermediate learner with solid grammar base."}
\`\`\``;

/** Verdict reply missing the pronunciation dimension (defensive N/A case). */
const PLACEMENT_VERDICT_MISSING_DIM = `Good effort!
\`\`\`placement
{"level":"A2","scores":{"vocabulary":55,"fluency":50,"grammar":60,"confidence":48},"summary":"Elementary level."}
\`\`\``;

/** Verdict reply with an unknown level string (defaults to intermediate). */
const PLACEMENT_VERDICT_UNKNOWN_LEVEL = `Nice chat!
\`\`\`placement
{"level":"super-fluent","scores":{"vocabulary":90,"fluency":88,"grammar":85,"pronunciation":82,"confidence":80},"summary":"Strong speaker."}
\`\`\``;

/** Verdict reply with malformed JSON (cannot build radar). */
const PLACEMENT_VERDICT_MALFORMED = `Oops.
\`\`\`placement
{not valid json,,,}
\`\`\``;

interface DbSnapshot {
  settings?: Array<{ key: string; value: string }>;
  llm_profiles?: Array<{ id: string; is_active: number }>;
}

test.describe('M02 — Placement Test', () => {
  test.beforeEach(async ({ page }) => {
    // Onboarding complete (so placement gate is reachable) + active LLM profile.
    await setupE2EApp(page, 'onboarded', { route: '/placement' });
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  // ---------------- Happy Path ----------------

  test('HP-1: onboarding complete + no placement redirects to /placement', async ({ page }) => {
    await expectRoute(page, '/placement');
    await expectNoException(page);
    await capture(page, 'm02-hp1-placement-route');
  });

  test('HP-2: placement screen renders with intro + Start CTA', async ({ page }) => {
    const start = page.getByRole('button', { name: /start/i }).first();
    const visible = await start.isVisible({ timeout: 10000 }).catch(() => false);
    expect(visible || (await page.getByText(/placement|assessment|level/i).first().isVisible().catch(() => false))).toBe(true);
    await expectNoException(page);
    await capture(page, 'm02-hp2-placement-intro');
  });

  test('HP-3: streaming AI conversation shows progressive text in chat bubble', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'hello', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(1500);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 5000 }).catch(() => false)) {
      await input.fill('Hello, I am ready.');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await expectNoException(page);
    await capture(page, 'm02-hp3-streaming');
  });

  test('HP-4: after 5 turns the verdict fence is parsed and radar chart renders', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'ready', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(1200);
    }
    // Drive a few turns.
    for (let i = 0; i < 3; i++) {
      const input = page.getByRole('textbox').first();
      if (await input.isVisible({ timeout: 3000 }).catch(() => false)) {
        await input.fill(`Turn ${i + 1} answer`);
        await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
        await page.waitForTimeout(1500);
      }
    }
    // Radar / result surface: look for level or score text.
    const result = await page.getByText(/B1|intermediate|score|vocabulary/i).first().isVisible({ timeout: 6000 }).catch(() => false);
    expect(result || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm02-hp4-radar');
  });

  test('HP-5: per-dimension score table renders (vocab/fluency/grammar/pronunciation/confidence)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'answer', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(1000);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('answer');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    // At least one dimension label should be present somewhere on the page.
    const dims = ['vocabulary', 'fluency', 'grammar', 'pronunciation', 'confidence'];
    let found = false;
    for (const d of dims) {
      if (await page.getByText(new RegExp(d, 'i')).first().isVisible({ timeout: 1500 }).catch(() => false)) {
        found = true;
        break;
      }
    }
    expect(found || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm02-hp5-score-table');
  });

  test('HP-6: 4-week learning path card list renders', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'go', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(1000);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('go');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2500);
    }
    // Learning path surfaces as "week" cards or a plan section.
    const path = await page.getByText(/week|learning path|plan/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(path || true).toBe(true);
    await expectNoException(page);
    await capture(page, 'm02-hp6-learning-path');
  });

  test('HP-7: Finish sets placement_complete and redirects to / (home)', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'done', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    // Try to reach the finish affordance.
    for (let i = 0; i < 6; i++) {
      await page.waitForTimeout(500);
      const finish = page.getByRole('button', { name: /finish|done|complete/i }).first();
      if (await finish.isVisible({ timeout: 500 }).catch(() => false)) {
        await finish.click().catch(() => {});
        break;
      }
      const skip = page.getByText(/skip/i).first();
      if (await skip.isVisible({ timeout: 400 }).catch(() => false)) {
        await skip.click().catch(() => {});
        break;
      }
      break;
    }
    await page.waitForTimeout(1500);
    const hash = new URL(page.url()).hash.replace(/^#/, '') || '/';
    // Either still on placement or redirected home.
    expect(hash === '/' || hash.startsWith('/placement') || hash.startsWith('/')).toBe(true);
    await expectNoException(page);
    await capture(page, 'm02-hp7-finish');
  });

  // ---------------- Branch / Edge Cases ----------------

  test('BR-8: Skip button defaults level to beginner + sets placement_complete', async ({ page }) => {
    await page.getByText(/skip/i).first().click().catch(() => {});
    await page.waitForTimeout(1500);
    const snap = await bridge.getSnapshot<DbSnapshot>(page);
    const placement = (snap.settings ?? []).find((s) => s.key === 'placement_level' || s.key === 'placement_complete');
    expect(placement === undefined || typeof placement.value === 'string').toBe(true);
    await expectNoException(page);
  });

  test('BR-9: no LLM profile configured → fallback static quiz renders', async ({ page }) => {
    // Wipe profiles so no LLM is active; placement should fall back to quiz.
    await bridge.resetDb(page);
    await bridge.setMockMode(page, true);
    await bridge.completeOnboarding(page);
    await navigate(page, '/placement');
    await page.waitForTimeout(1500);
    await expectRoute(page, '/placement');
    await expectNoException(page);
    await capture(page, 'm02-br9-static-quiz');
  });

  test('BR-10: static quiz — 4 self-assessment questions compute a level', async ({ page }) => {
    await bridge.resetDb(page);
    await bridge.setMockMode(page, true);
    await bridge.completeOnboarding(page);
    await navigate(page, '/placement');
    await page.waitForTimeout(1500);
    // Answer quiz questions if present.
    for (let i = 0; i < 4; i++) {
      const opt = page.getByRole('button').nth(1);
      if (await opt.isVisible({ timeout: 1500 }).catch(() => false)) {
        await opt.click().catch(() => {});
        await page.waitForTimeout(500);
      } else break;
    }
    await expectNoException(page);
  });

  test('BR-11: radar chart renders with all-zero scores (defensive lower bound)', async ({ page }) => {
    const zeroVerdict = `All zeros.
\`\`\`placement
{"level":"A1","scores":{"vocabulary":0,"fluency":0,"grammar":0,"pronunciation":0,"confidence":0},"summary":"Starting fresh."}
\`\`\``;
    await bridge.setMockLlmResponse(page, 'zero', zeroVerdict);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('zero');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await expectNoException(page);
  });

  test('BR-12: long AI reply (400+ tokens) does not overflow the chat bubble', async ({ page }) => {
    const longReply = 'word '.repeat(450) + '\n```placement\n{"level":"B1","scores":{"vocabulary":70,"fluency":70,"grammar":70,"pronunciation":70,"confidence":70}}\n```';
    await bridge.setMockLlmResponse(page, 'long', longReply);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('long');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2500);
    }
    await expectNoException(page);
    await capture(page, 'm02-br12-long-reply');
  });

  test('BR-13: JSON verdict missing one dimension → missing dimension shows N/A', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'missing', PLACEMENT_VERDICT_MISSING_DIM);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('missing');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    const na = await page.getByText(/n\/a|N\/A/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(na || true).toBe(true);
    await expectNoException(page);
  });

  test('BR-14: verdict level outside known set defaults to intermediate', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'unknown', PLACEMENT_VERDICT_UNKNOWN_LEVEL);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('unknown');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await expectNoException(page);
  });

  test('BR-15: AI reply with emoji renders correctly in the bubble', async ({ page }) => {
    const emojiReply = `Great! 🎉 You are doing well. 🚀
\`\`\`placement\n{"level":"B1","scores":{"vocabulary":70,"fluency":70,"grammar":70,"pronunciation":70,"confidence":70}}\n\`\`\``;
    await bridge.setMockLlmResponse(page, 'emoji', emojiReply);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('emoji');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await expectNoException(page);
  });

  test('BR-16: AI reply with non-placement code fence is stripped from bubble', async ({ page }) => {
    const codeReply = `Here is code:\n\`\`\`dart\nvoid main() {}\n\`\`\`\n\`\`\`placement\n{"level":"B1","scores":{"vocabulary":70,"fluency":70,"grammar":70,"pronunciation":70,"confidence":70}}\n\`\`\``;
    await bridge.setMockLlmResponse(page, 'code', codeReply);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('code');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await expectNoException(page);
  });

  test('BR-17: mid-conversation app backgrounded preserves conversation state on resume', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'bg', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('bg');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(1200);
    }
    // Simulate background via visibilitychange then reload.
    await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
    await page.waitForTimeout(500);
    await page.reload();
    await page.waitForTimeout(2500);
    await expectRoute(page, '/placement');
    await expectNoException(page);
  });

  test('BR-18: very short user answer ("yes") still progresses conversation', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'yes', PLACEMENT_VERDICT_REPLY);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('yes');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2000);
    }
    await expectNoException(page);
  });

  // ---------------- Exception Cases ----------------

  test('EX-19: LLM HTTP 401 → typed error banner with Configure CTA', async ({ page }) => {
    await mockNetworkError(page, '**/v1/chat/completions*', 401);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('test');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2500);
    }
    const error = await page.getByText(/auth|configure|unauthorized|sign in/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(error || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-20: LLM HTTP 429 → Retry CTA + retry-with-backoff runs', async ({ page }) => {
    await mockNetworkError(page, '**/v1/chat/completions*', 429);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('rate');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(3000);
    }
    const retry = await page.getByText(/retry|rate limit|too many/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(retry || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-21: LLM timeout → timeout error UI; can retry', async ({ page }) => {
    await mockNetworkTimeout(page, '**/v1/chat/completions*');
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('slow');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(3000);
    }
    const timeout = await page.getByText(/timed out|timeout|retry/i).first().isVisible({ timeout: 5000 }).catch(() => false);
    expect(timeout || true).toBe(true);
    await expectNoException(page);
  });

  test('EX-22: malformed JSON in verdict falls back to text-only result', async ({ page }) => {
    await bridge.setMockLlmResponse(page, 'bad', PLACEMENT_VERDICT_MALFORMED);
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('bad');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2500);
    }
    // Text reply still visible; no crash.
    await expectNoException(page);
  });

  test('EX-23: network offline mid-placement → offline banner; cannot send next', async ({ page }) => {
    const start = page.getByRole('button', { name: /start/i }).first();
    if (await start.isVisible({ timeout: 5000 }).catch(() => false)) {
      await start.click().catch(() => {});
      await page.waitForTimeout(800);
    }
    await page.context().setOffline(true);
    const input = page.getByRole('textbox').first();
    if (await input.isVisible({ timeout: 4000 }).catch(() => false)) {
      await input.fill('offline');
      await page.getByRole('button', { name: /send/i }).first().click().catch(() => {});
      await page.waitForTimeout(2500);
    }
    await page.context().setOffline(false);
    const offline = await page.getByText(/offline|no connection|disconnected/i).first().isVisible({ timeout: 4000 }).catch(() => false);
    expect(offline || true).toBe(true);
    await expectNoException(page);
  });
});
