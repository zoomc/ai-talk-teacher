import { expect, test } from '@playwright/test';
import {
  enableAccessibility,
  getCurrentRoute,
  goTo,
  sendChatMessage,
} from '../../helpers';
import { expectText } from '../../lib/assertions';
import { getSnapshot } from '../../lib/e2e-bridge';

test.describe('compile-time E2E simulation runtime', () => {
  test('runs the happy path through UI, gateways, persistence, and summary', async ({
    page,
  }) => {
    const externalRequests = new Set<string>();
    page.on('request', (request) => {
      const url = request.url();
      if (!/^https?:/i.test(url)) return;
      const host = new URL(url).hostname;
      // Flutter CanvasKit and bundled font fallback may load from Google's
      // static CDN; the simulation contract is specifically that no provider
      // or application API endpoint is contacted.
      const staticFlutterHosts = new Set(['www.gstatic.com', 'fonts.gstatic.com']);
      if (
        host !== 'localhost' &&
        host !== '127.0.0.1' &&
        !staticFlutterHosts.has(host)
      ) {
        externalRequests.add(url);
      }
    });

    await goTo(page, '/');
    await enableAccessibility(page);
    await expectText(page, 'E2E Simulation');
    await expectText(page, 'No real AI requests');

    await page
      .getByRole('button', { name: /start conversation|开始对话/i })
      .first()
      .click();
    await expect
      .poll(() => getCurrentRoute(page), { timeout: 15000 })
      .toMatch(/^\/chat\//);
    const chatRoute = await getCurrentRoute(page);
    const sessionId = chatRoute.split('/').pop()!;

    await sendChatMessage(page, 'I went to a cafe yesterday.');
    await expectText(page, 'That sounds lovely!');
    await expectText(page, 'What did you order at the cafe?');

    const snapshot = await getSnapshot<{
      chat_messages?: Array<{
        session_id?: string;
        role?: string;
        content?: string;
      }>;
    }>(page);
    const sessionMessages = (snapshot.chat_messages ?? []).filter(
      (message) => message.session_id === sessionId,
    );
    expect(sessionMessages.map((message) => message.role)).toEqual(
      expect.arrayContaining(['user', 'assistant']),
    );
    expect(
      sessionMessages.some(
        (message) =>
          message.role === 'assistant' &&
          (message.content?.trim().length ?? 0) > 0,
      ),
    ).toBe(true);

    // A reload must restore the persisted conversation rather than relying on
    // in-memory widget state.
    await goTo(page, chatRoute);
    await expectText(page, 'What did you order at the cafe?');

    await goTo(page, `/summary/${sessionId}`);
    await expectText(
      page,
      'You kept the conversation moving and expressed your ideas clearly.',
    );
    await expectText(
      page,
      'Next time, I would like to explain my idea in more detail.',
    );
    expect([...externalRequests]).toEqual([]);
  });

  test('shows isolated simulation state and exposes Avatar Lab only here', async ({
    page,
  }, testInfo) => {
    await goTo(page, '/');
    await enableAccessibility(page);
    await expectText(page, 'E2E Simulation');
    await expectText(page, 'No real AI requests');

    await goTo(page, '/lab/avatar');
    await expectText(page, 'Avatar Lab');
    await expectText(page, 'Experimental 3D');
    await page.screenshot({
      path: testInfo.outputPath('avatar-lab.png'),
      fullPage: true,
    });
  });
});
