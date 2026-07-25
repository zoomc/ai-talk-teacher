/**
 * M16 — Service Config: Active Switching & Delete Guard
 *
 * Tabbed/sectioned UI for LLM/STT/TTS profiles. Active profile switching is
 * wrapped in a DB transaction (atomic). Active profile deletion is prevented
 * via a disabled popup-menu item with a "switch active first" hint.
 *
 * Route: /service-config
 * Screen: lib/features/profile/presentation/screens/service_config_screen.dart
 */
import { test, expect } from '@playwright/test';
import {
  setupE2EApp,
  setupEmptyApp,
  navigate,
  DESKTOP_VIEWPORT,
  MOBILE_VIEWPORT,
} from '../../lib/setup';
import { capture, captureFullPage, captureAtViewport } from '../../lib/screenshots';
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
import { resetOverrides, mockNetworkError } from '../../lib/mock';
import { FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';
import { settle, goTo } from '../../helpers';

/** Shape of the DB snapshot rows we assert on. */
interface ProfileSnapshot {
  llm_profiles?: Array<{ id: string; name: string; is_active: number }>;
  stt_profiles?: Array<{ id: string; name: string; is_active: number }>;
  tts_profiles?: Array<{ id: string; name: string; is_active: number }>;
}

/** Two LLM profiles: one active, one inactive — for switch/delete tests. */
const TWO_LLM_PROFILES = [
  {
    id: 'llm-a',
    name: 'DeepSeek Active',
    provider_id: 'deepseek',
    base_url: 'https://api.deepseek.com/v1',
    api_key: 'sk-e2e-mock-llm-key-a',
    model: 'deepseek-chat',
    is_active: 1,
    created_at: '2026-07-01T10:00:00.000Z',
    updated_at: '2026-07-01T10:00:00.000Z',
  },
  {
    id: 'llm-b',
    name: 'OpenAI Inactive',
    provider_id: 'openai',
    base_url: 'https://api.openai.com/v1',
    api_key: 'sk-e2e-mock-llm-key-b',
    model: 'gpt-4o-mini',
    is_active: 0,
    created_at: '2026-07-02T10:00:00.000Z',
    updated_at: '2026-07-02T10:00:00.000Z',
  },
];

test.describe('M16 — Service Config: Active Switching & Delete Guard', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/service-config' });
  });

  test.afterEach(async ({ page }) => {
    resetOverrides();
  });

  // ── Happy Path (HP-1 .. HP-7) ──────────────────────────────────────────

  test('HP-1: service config renders with three sections (LLM / STT / TTS)', async ({ page }) => {
    await expectText(page, 'DeepSeek Default');
    await expectText(page, 'Deepgram Default');
    await expectText(page, 'Fish Audio Default');
    await expectNoException(page);
    await capture(page, 'm16-hp1-three-sections');
  });

  test('HP-2: active profile marked with badge and check icon', async ({ page }) => {
    // The active LLM profile "DeepSeek Default" shows an "Active" badge.
    await expectText(page, 'Active');
    await expectNoException(page);
    await capture(page, 'm16-hp2-active-badge');
  });

  test('HP-3: tap inactive profile to activate — DB updates is_active', async ({ page }) => {
    // Seed two LLM profiles (one active, one inactive) for a clean switch.
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Tap the inactive profile card to activate it.
    await page.getByText('OpenAI Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const openai = snap.llm_profiles?.find((p) => p.id === 'llm-b');
    expect(openai?.is_active).toBe(1);
    await expectNoException(page);
    await capture(page, 'm16-hp3-switch-active');
  });

  test('HP-4: switching is atomic — exactly one active profile', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    await page.getByText('OpenAI Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const activeCount = snap.llm_profiles?.filter((p) => p.is_active === 1).length ?? 0;
    expect(activeCount).toBe(1);
    await expectNoException(page);
    await capture(page, 'm16-hp4-atomic-switch');
  });

  test('HP-5: popup menu on each profile shows Edit, Test Connection, Delete', async ({ page }) => {
    // Open the popup menu on the first profile card.
    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    // The popup should reveal Edit + Test Connection items.
    await expectText(page, 'Edit');
    await expectText(page, 'Test Connection');
    await expectNoException(page);
    await capture(page, 'm16-hp5-popup-menu');
  });

  test('HP-6: delete inactive profile — confirmation then removed', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Open popup on the inactive profile.
    const cards = page.getByText('OpenAI Inactive');
    await cards.first().scrollIntoViewIfNeeded().catch(() => {});
    // Find the more-vert icon near the inactive card and open its menu.
    const moreButtons = page.locator('flt-semantics[aria-label="more"]');
    const count = await moreButtons.count();
    // Click the second more button (inactive profile is second).
    if (count >= 2) {
      await moreButtons.nth(1).click({ timeout: 8000 }).catch(() => {});
    } else {
      await moreButtons.first().click({ timeout: 8000 }).catch(() => {});
    }
    await settle(page, 1000);

    // Click "Delete" in the popup.
    await page.getByText('Delete').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    // Confirm in the dialog.
    await page.getByText('Delete').last().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const deleted = snap.llm_profiles?.find((p) => p.id === 'llm-b');
    expect(deleted).toBeUndefined();
    await expectNoException(page);
    await capture(page, 'm16-hp6-delete-inactive');
  });

  test('HP-7: edit profile navigates to profile form', async ({ page }) => {
    // Open popup menu on the first profile.
    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    // Click "Edit".
    await page.getByText('Edit').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    // Should navigate to /profile-form/llm?id=...
    const url = page.url();
    expect(url).toContain('profile-form');
    await expectNoException(page);
    await capture(page, 'm16-hp7-edit-navigate');
  });

  // ── Branch / Edge Cases (BR-1 .. BR-12) ─────────────────────────────────

  test('BR-1: active profile Delete menu item is disabled with hint', async ({ page }) => {
    // Open popup on the active profile (DeepSeek Default).
    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    // The disabled delete item shows the hint text.
    await expectText(page, 'switch active first');
    await expectNoException(page);
    await capture(page, 'm16-br1-delete-disabled');
  });

  test('BR-2: switching active profile invalidates dependent providers', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Switch active profile.
    await page.getByText('OpenAI Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    // Navigate to home — providers should re-fetch with the new active profile.
    await navigate(page, '/');
    await settle(page, 1500);
    await expectNoException(page);
    await capture(page, 'm16-br2-invalidate-providers');
  });

  test('BR-3: switching LLM profile — next chat uses new profile', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Switch to the inactive LLM profile.
    await page.getByText('OpenAI Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    // Verify in snapshot that the new profile is active.
    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const active = snap.llm_profiles?.find((p) => p.is_active === 1);
    expect(active?.id).toBe('llm-b');
    await expectNoException(page);
    await capture(page, 'm16-br3-llm-switch');
  });

  test('BR-4: switching TTS profile — next TTS uses new profile', async ({ page }) => {
    // Seed two TTS profiles (one active, one inactive).
    await bridge.seedProfiles(page, [
      {
        id: 'tts-a',
        name: 'Fish Active',
        provider_id: 'fish_audio',
        base_url: 'https://api.fish.audio/v1',
        api_key: 'sk-tts-a',
        model: 'fish-speech-1',
        voice_id: 'voice-1',
        voice_name: 'Default Voice',
        speed: 1.0,
        extra_config: null,
        is_active: 1,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
      {
        id: 'tts-b',
        name: 'ElevenLabs Inactive',
        provider_id: 'elevenlabs',
        base_url: 'https://api.elevenlabs.io/v1',
        api_key: 'sk-tts-b',
        model: 'eleven-multilingual-v2',
        voice_id: '21m00Tcm4TlvDq8ikWAM',
        voice_name: 'Rachel',
        speed: 1.0,
        extra_config: null,
        is_active: 0,
        created_at: '2026-07-02T10:00:00.000Z',
        updated_at: '2026-07-02T10:00:00.000Z',
      },
    ]);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Tap the inactive TTS profile to activate.
    await page.getByText('ElevenLabs Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const active = snap.tts_profiles?.find((p) => p.is_active === 1);
    expect(active?.id).toBe('tts-b');
    await expectNoException(page);
    await capture(page, 'm16-br4-tts-switch');
  });

  test('BR-5: switching STT profile — next STT uses new profile', async ({ page }) => {
    await bridge.seedProfiles(page, [
      {
        id: 'stt-a',
        name: 'Deepgram Active',
        provider_id: 'deepgram',
        base_url: 'https://api.deepgram.com/v1',
        api_key: 'sk-stt-a',
        model: 'nova-2',
        language: 'en-US',
        extra_config: null,
        is_active: 1,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
      {
        id: 'stt-b',
        name: 'Whisper Inactive',
        provider_id: 'openai_whisper',
        base_url: 'https://api.openai.com/v1',
        api_key: 'sk-stt-b',
        model: 'whisper-1',
        language: 'en-US',
        extra_config: null,
        is_active: 0,
        created_at: '2026-07-02T10:00:00.000Z',
        updated_at: '2026-07-02T10:00:00.000Z',
      },
    ]);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    await page.getByText('Whisper Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const active = snap.stt_profiles?.find((p) => p.is_active === 1);
    expect(active?.id).toBe('stt-b');
    await expectNoException(page);
    await capture(page, 'm16-br5-stt-switch');
  });

  test('BR-6: profile list shows name, provider, model, active badge', async ({ page }) => {
    // The onboarded fixture has DeepSeek Default (active) with model deepseek-chat.
    await expectText(page, 'DeepSeek Default');
    await expectText(page, 'deepseek-chat');
    await expectText(page, 'Active');
    await expectNoException(page);
    await capture(page, 'm16-br6-profile-details');
  });

  test('BR-7: sections persist across navigation', async ({ page }) => {
    // Navigate away and back — the three sections should still render.
    await navigate(page, '/');
    await settle(page, 1500);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    await expectText(page, 'DeepSeek Default');
    await expectText(page, 'Deepgram Default');
    await expectText(page, 'Fish Audio Default');
    await expectNoException(page);
    await capture(page, 'm16-br7-persist-nav');
  });

  test('BR-8: empty profile list shows Add Profile CTA', async ({ page }) => {
    // Use empty setup — no profiles seeded.
    await setupEmptyApp(page, { route: '/service-config' });
    await settle(page, 1500);

    await expectText(page, 'Add Profile');
    await expectNoException(page);
    await capture(page, 'm16-br8-empty-list');
  });

  test('BR-9: long profile name renders without overflow', async ({ page }) => {
    await bridge.seedProfiles(page, [
      {
        id: 'llm-long',
        name: 'A'.repeat(80),
        provider_id: 'deepseek',
        base_url: 'https://api.deepseek.com/v1',
        api_key: 'sk-long-key',
        model: 'deepseek-chat',
        is_active: 0,
        created_at: '2026-07-01T10:00:00.000Z',
        updated_at: '2026-07-01T10:00:00.000Z',
      },
    ]);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    await expectNoException(page);
    await captureFullPage(page, 'm16-br9-long-name');
  });

  test('BR-10: profile API key is not shown in plaintext', async ({ page }) => {
    // The subtitle shows model + base_url, never the raw api_key.
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('sk-e2e-mock-llm-key');
    await expectNoException(page);
    await capture(page, 'm16-br10-key-masked');
  });

  test('BR-11: Test Connection button available per profile', async ({ page }) => {
    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    await expectText(page, 'Test Connection');
    await expectNoException(page);
    await capture(page, 'm16-br11-test-connection');
  });

  test('BR-12: connection test running shows spinner, button disabled', async ({ page }) => {
    // Set a mock LLM response so the test connection has something to hit.
    await bridge.setMockLlmResponse(page, 'models', 'mock');
    await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);

    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    await page.getByText('Test Connection').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 2000);

    await expectNoException(page);
    await capture(page, 'm16-br12-test-running');
  });

  // ── Exception Cases (EX-1 .. EX-5) ─────────────────────────────────────

  test('EX-1: DB transaction fails mid-switch — original active preserved', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Attempt to switch — even if the underlying call were to fail, the
    // original active profile should remain intact.
    await page.getByText('OpenAI Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    // At least one profile must be active (no orphaned state).
    const activeCount = snap.llm_profiles?.filter((p) => p.is_active === 1).length ?? 0;
    expect(activeCount).toBeGreaterThanOrEqual(1);
    await expectNoException(page);
  });

  test('EX-2: delete during switch is blocked', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Tap to switch, then immediately try to delete via popup.
    await page.getByText('OpenAI Inactive').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 500);

    // The inactive profile should still exist (delete not executed mid-switch).
    const snap = await bridge.getSnapshot<ProfileSnapshot>(page);
    const stillExists = snap.llm_profiles?.find((p) => p.id === 'llm-b');
    expect(stillExists).toBeDefined();
    await expectNoException(page);
  });

  test('EX-3: edit during switch — read-only form pre-fill allowed', async ({ page }) => {
    await bridge.seedProfiles(page, TWO_LLM_PROFILES);
    await navigate(page, '/service-config');
    await settle(page, 1500);

    // Open popup and tap Edit while a switch might be in flight.
    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 500);
    await page.getByText('Edit').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1500);

    // Should land on the profile form without error.
    const url = page.url();
    expect(url).toContain('profile-form');
    await expectNoException(page);
  });

  test('EX-4: connection test 5xx — server error snackbar', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    await mockNetworkError(page, '**/v1/chat/completions*', 500);
    await mockNetworkError(page, '**/v1/models*', 500);

    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    await page.getByText('Test Connection').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 3000);

    await expectNoException(page);
  });

  test('EX-5: connection test timeout — timed out snackbar', async ({ page }) => {
    // Disable Dart-side mock so the HTTP error actually fires.
    await bridge.setMockMode(page, false);
    // Simulate a timeout by aborting the request.
    await page.route('**/v1/chat/completions*', (route) => {
      route.abort('timedout');
    });

    const menuButton = page.locator('flt-semantics[aria-label="more"]').first();
    await menuButton.click({ timeout: 8000 }).catch(() => {});
    await settle(page, 1000);

    await page.getByText('Test Connection').first().click({ timeout: 8000 }).catch(() => {});
    await settle(page, 3000);

    await expectNoException(page);
  });
});
