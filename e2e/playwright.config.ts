import { defineConfig, devices } from '@playwright/test';
import path from 'path';

const BASE_URL = process.env.E2E_BASE_URL || 'http://localhost:8080';

export default defineConfig({
  testDir: '.',
  testMatch: ['specs/**/*.spec.ts'],
  // Legacy specs are in `legacy/` and excluded by the testMatch above.
  // To run them, override testMatch: `npx playwright test --grep @legacy`.
  timeout: 90000, // Flutter web boot + first-frame is slow; 90s per test
  expect: {
    timeout: 20000, // 20s for assertions (Flutter can be sluggish)
  },
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  // Single-worker in CI for deterministic ordering; 2 locally for speed.
  workers: process.env.CI ? 1 : 2,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
  ],
  outputDir: 'test-results',
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // Give the Flutter app extra time to settle on first navigation.
    actionTimeout: 20000,
    navigationTimeout: 45000,
  },

  projects: [
    // Primary project: desktop Chromium at 1280×800 (matches old config).
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
            '--no-sandbox',
            '--disable-dev-shm-usage',
          ],
        },
      },
    },

    // Cross-browser smoke: Firefox at the same viewport.
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        viewport: { width: 1280, height: 800 },
      },
    },

    // Cross-browser smoke: WebKit at the same viewport.
    {
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 1280, height: 800 },
      },
    },

    // Mobile viewport: 375×812 (iPhone X-class) Chromium with touch.
    {
      name: 'mobile-chrome',
      use: {
        ...devices['Pixel 5'],
        viewport: { width: 375, height: 812 },
        isMobile: true,
        hasTouch: true,
      },
    },
  ],

  webServer: {
    command: 'node start-server.mjs',
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    // Flutter web build can take a moment to serve; bumped from 15s to 60s.
    timeout: 60000,
    cwd: path.resolve(__dirname),
  },
});
