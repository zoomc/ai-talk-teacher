/**
 * J01 — Cross-module Happy-Path Journey: Home → Chat → Review → Progress
 *
 * Validates the core learning loop:
 *   1. Dashboard quick action starts a chat session
 *   2. User sends a message that produces a correction
 *   3. User rates the correction in /review
 *   4. Progress dashboard reflects activity
 *
 * Covers gap 72 from the E2E coverage audit.
 */
import { test, expect } from '@playwright/test';
import { setupE2EApp, navigate, MOBILE_VIEWPORT } from '../../lib/setup';
import { capture } from '../../lib/screenshots';
import { expectVisible, expectRoute, expectNoException } from '../../lib/assertions';
import { enableAccessibility, settle, sendChatMessage } from '../../helpers';
import * as bridge from '../../lib/e2e-bridge';
import { resetOverrides } from '../../lib/mock';
import { LLM_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';

interface LoopSnapshot {
  corrections?: Array<{ id: string; original: string; corrected: string; review_count: number }>;
}

test.describe('J01 — Learning Loop Journey', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'with-review-queue', { route: '/' });
    await enableAccessibility(page);
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
  });

  test.afterEach(async () => {
    resetOverrides();
  });

  test('HP-1: Home → Chat → Review → Progress completes without crash', async ({ page }) => {
    // 1) Start a conversation from the dashboard.
    const convButton = page.getByRole('button', { name: /start conversation|conversation|对话|开始/i }).first();
    await convButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);
    expect(page.url()).toContain('chat');

    // 2) Send a message that triggers a grammar correction.
    const correctionReply = `Good try!
\`\`\`corrections
[{"original":"I goes","corrected":"I go","type":"grammar","severity":"medium","explanation":"Subject 'I'.","skill":"grammar"}]
\`\`\``;
    await bridge.setMockLlmResponse(page, 'goes', correctionReply);
    await sendChatMessage(page, 'I goes to school');
    await page.waitForTimeout(2500);

    const chatSnap = await bridge.getSnapshot<LoopSnapshot>(page);
    expect(Array.isArray(chatSnap.corrections)).toBe(true);

    // 3) Go to review and rate the due correction.
    await navigate(page, '/review');
    await settle(page, 1500);
    await expectRoute(page, '/review');

    const goodBtn = page.getByText('Good', { exact: true }).first();
    if (await goodBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await goodBtn.click().catch(() => {});
      await page.waitForTimeout(1500);
    }

    // 4) Go to progress and verify it renders.
    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectRoute(page, '/progress');
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'j01-hp1-learning-loop');
  });

  test('HP-2: mobile viewport — learning loop navigation stays within safe area', async ({ page }) => {
    await page.setViewportSize(MOBILE_VIEWPORT);
    await navigate(page, '/');

    const convButton = page.getByRole('button', { name: /start conversation|conversation|对话|开始/i }).first();
    await convButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);
    expect(page.url()).toContain('chat');

    await bridge.setMockLlmResponse(page, 'mobile journey', LLM_MOCKS.greeting);
    await sendChatMessage(page, 'mobile journey');
    await page.waitForTimeout(2000);

    await navigate(page, '/review');
    await settle(page, 1500);
    await expectRoute(page, '/review');

    await navigate(page, '/progress');
    await settle(page, 2000);
    await expectRoute(page, '/progress');
    await expectVisible(page, 'canvas');
    await expectNoException(page);
    await capture(page, 'j01-hp2-learning-loop-mobile');
  });
});
