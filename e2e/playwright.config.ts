import { defineConfig, devices } from '@playwright/test';
import path from 'path';

const BASE_URL = process.env.E2E_BASE_URL || 'http://localhost:8080';

export default defineConfig({
  testDir: '.',
  testMatch: ['**/*.spec.ts'],
  timeout: 60000,
  expect: {
    timeout: 15000,
  },
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : 2,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report' }],
  ],
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 800 },
        launchOptions: {
          args: [
            '--force-renderer-accessibility',
            '--enable-accessibility-object-model',
            '--disable-blink-features=AutomationControlled',
          ],
        },
      },
    },
  ],

  webServer: {
    command: 'node start-server.mjs',
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 15000,
    cwd: path.resolve(__dirname),
  },
});
