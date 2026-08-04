import { test } from '@playwright/test';
import { enableAccessibility, goTo } from '../../helpers';
import { expectText } from '../../lib/assertions';

test.describe('compile-time E2E simulation runtime', () => {
  test('shows isolated simulation state and exposes Avatar Lab only here', async ({
    page,
  }) => {
    await goTo(page, '/');
    await enableAccessibility(page);
    await expectText(page, 'E2E Simulation');
    await expectText(page, 'No real AI requests');

    await goTo(page, '/lab/avatar');
    await expectText(page, 'Avatar Lab');
    await expectText(page, 'Experimental 3D');
  });
});
