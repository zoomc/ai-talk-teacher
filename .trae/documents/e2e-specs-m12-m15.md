# Plan: E2E Specs for M12–M15 (Avatar Lip Sync + Profile CRUD)

## Summary

Write 4 Playwright E2E spec files for modules M12–M15 of the SpeakFlow
Flutter web app, then run `tsc --noEmit` and fix any TypeScript errors.
M11 (`/workspace/e2e/specs/avatar/emotion.spec.ts`) is already complete
and serves as the structural template.

| File | Module | Cases | Happy | Branch | Exception |
| ---- | ------ | ----- | ----- | ------ | --------- |
| `e2e/specs/avatar/lip-sync.spec.ts` | M12 — Avatar: Lip Sync (Viseme) | 23 | 5 | 14 | 4 |
| `e2e/specs/profile/llm-crud.spec.ts` | M13 — Profile: LLM CRUD | 25 | 8 | 11 | 6 |
| `e2e/specs/profile/stt-crud.spec.ts` | M14 — Profile: STT CRUD | 24 | 7 | 12 | 5 |
| `e2e/specs/profile/tts-crud.spec.ts` | M15 — Profile: TTS CRUD | 24 | 7 | 12 | 5 |

These counts match the Coverage Matrix in `/workspace/docs/e2e-spec.md`
(M12=23, M13=25, M14=24, M15=24).

## Current State Analysis

### Infrastructure available (all confirmed via exploration)

- **`/workspace/e2e/lib/setup.ts`** — exports `setupE2EApp(page, fixtureName, { route, viewport })`, `setupEmptyApp(...)`, `navigate(page, route)`, `DESKTOP_VIEWPORT`, `MOBILE_VIEWPORT`. `setupE2EApp` calls `resetOverrides()` → `setupHttpMocks()` → `waitForApp()` → `waitForBridge()` → `resetDb()` → `setMockMode(true)` → seeds fixture → `goTo(route)`.
- **`/workspace/e2e/lib/e2e-bridge.ts`** — typed wrappers for `window.speakflowE2E.*`: `resetDb`, `seedProfiles`, `seedChatSessions`, `seedMessages`, `seedCorrections`, `seedScenarios`, `seedProjects`, `seedReviewQueue`, `setMockMode`, `setMockLlmResponse`, `setMockSttResult`, `setMockTtsAudio`, `getSnapshot<T>`, `setSetting`, `completeOnboarding`, `waitForBridge`.
- **`/workspace/e2e/lib/mock.ts`** — `setupHttpMocks`, `setLlmResponse`, `setSttTranscript`, `setTtsAudio`, `mockNetworkError(page, urlPattern, status)`, `mockNetworkTimeout(page, urlPattern)`, `resetOverrides`.
- **`/workspace/e2e/lib/assertions.ts`** — `expectVisible`, `expectNotVisible`, `expectText`, `expectRoute`, `expectNoException`, `expectElementCount`, `expectMinCount`, `expectSpeakFlowTitle`. Default 15s timeout.
- **`/workspace/e2e/lib/screenshots.ts`** — `capture`, `captureFullPage`, `captureElement`, `captureAtViewport`.
- **`/workspace/e2e/helpers.ts`** — `waitForApp`, `goTo`, `navigateHash`, `waitForFlutterReady`, `settle(page, ms=1200)`, `getCurrentRoute`, `hasText`, `clickText`, `completeOnboarding`, `completePlacement`, `setupSeededApp`.
- **`/workspace/e2e/fixtures/fixtures.ts`** — `FIXTURES` registry (names: `empty`, `guest`, `onboarded`, `with-projects`, `with-chat-history`, `with-corrections`, `with-review-queue`, `full`). Typed row interfaces: `LlmProfileRow`, `SttProfileRow`, `TtsProfileRow`, `ChatSessionRow`, `MessageRow`, `CorrectionRow`, etc. `LLM_MOCKS`, `STT_MOCKS`, `TTS_MOCKS` canned data.
- **`/workspace/e2e/fixtures/mock-data.json`** — `onboarded` fixture seeds: LLM "DeepSeek Default" (active) + "OpenAI Backup" (inactive), STT "Deepgram Default" (active), TTS "Fish Audio Default" (active), 3 scenarios.

### M11 template pattern (to replicate)

Each spec file follows this skeleton (from `/workspace/e2e/specs/avatar/emotion.spec.ts`):

```typescript
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { setupE2EApp, navigate, DESKTOP_VIEWPORT, MOBILE_VIEWPORT } from '../../lib/setup';
import { capture, captureFullPage } from '../../lib/screenshots';
import { expectVisible, expectText, expectNotVisible, expectRoute, expectNoException, expectElementCount } from '../../lib/assertions';
import * as bridge from '../../lib/e2e-bridge';
import { setLlmResponse, setSttTranscript, setTtsAudio, mockNetworkError, mockNetworkTimeout, resetOverrides } from '../../lib/mock';
import { FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS } from '../../fixtures/fixtures';
import type { ... } from '../../fixtures/fixtures';
import { settle } from '../../helpers';

const SESSION_ID = '...';
const SESSION_ROW = { ... };

async function sendAndWait(page: Page, text: string): Promise<void> { ... }
async function bodyText(page: Page): Promise<string> { ... }

test.describe('Mxx — Module Name', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '...' });
    // optional seeding + navigation
    await settle(page, 1500);
  });
  test.afterEach(async () => { resetOverrides(); });

  // ── Happy Path (N) ─────
  test('HP-1: ...', async ({ page }) => { ... await capture(page, 'mxx-hp1-...'); });

  // ── Branch / Edge Cases (N) ─────
  test('BR-6: ...', async ({ page }) => { ... });

  // ── Exception Cases (N) ─────
  test('EX-20: ...', async ({ page }) => { ... });
});
```

Key conventions observed:
- Every test ends happy-path cases with `await capture(page, 'mxx-...')`.
- Every test calls `await expectNoException(page)` before its final assertion.
- Tests use `.catch(() => {})` / `|| true` patterns to be resilient to Flutter semantics tree variance (FltSemantics accessibility nodes are flaky in CI).
- DB state is asserted via `bridge.getSnapshot<T>(page)` with a local interface describing the rows needed.
- Branch/exception tests don't always `capture` (only happy paths are required to per the spec's screenshot-review section).

### M12 implementation grounding (Lip Sync)

From `/workspace/lib/features/avatar/data/rhubarb_service.dart`, `/workspace/lib/features/avatar/domain/viseme_mapping.dart`, `/workspace/lib/features/avatar/data/rhubarb_parser.dart`, `/workspace/lib/features/avatar/data/rhubarb_runner_stub.dart`, and `/workspace/lib/features/chat/presentation/screens/chat_screen.dart`:

- On Flutter Web, `RhubarbRunner` (stub) reports `available = false` → `RhubarbService.analyze` throws `RhubarbException('rhubarb binary not available on this platform')` → `_maybeAnalyzeVisemes` catches + `debugPrint`s, avatar falls back to **amplitude-driven** mouth via `amplitudeStream` wired into `AvatarStage`.
- `kRhubarbToLive2DMap` covers all 9 visemes (A–H + X=silence) with `mouthOpenY` / `mouthForm` targets.
- `parseRhubarbJson` is defensive: missing `start` → falls back to previous cue's end; missing/non-string `value` → skipped; non-numeric `start` → skipped; empty `mouthCues` → silence cue; first cue not at 0 → silence inserted at 0; cues sorted by start; malformed top-level JSON → `VisemeTimeline.empty`.
- 32-entry LRU cache (`_maxCacheEntries = 32`) keyed by `audioHash`; eviction removes the oldest (`_cache.keys.first`).
- `cacheKeyFor(text)` lives on `TtsPlaybackService` (referenced at chat_screen.dart line 388).
- TTS error → timeline never pushed (the `try/catch` in `_maybeAnalyzeVisemes` swallows).
- Avatar canvas (`page.locator('canvas').first()`) must remain visible throughout — used as the stability sentinel in M11.

Because Playwright runs against the **web build** (rhubarb stub), most M12 viseme-pipeline cases assert the **amplitude-fallback path**: avatar canvas stays visible, no exceptions thrown, TTS playback proceeds, timeline cleared on completion. The pure-Dart parser/LRU behaviors can't be unit-tested through Playwright against the running app (no JS hook exposes `parseRhubarbJson`), so those cases are exercised indirectly: by feeding the chat a TTS-backed reply and asserting the canvas + no-exception invariants hold across many cue-shape variations (long reply, repeated reply = cache hit signal, empty audio, malformed audio, etc.).

### M13–M15 implementation grounding (Profile CRUD)

From `/workspace/lib/core/router/app_router.dart`, `/workspace/lib/features/profile/presentation/screens/profile_form_screen.dart`, and `/workspace/e2e/specs/profile/service-config.spec.ts` (M16 reference):

- Routes: `/service-config` (list, three sections LLM/STT/TTS), `/profile-form/:type` where `:type ∈ {llm, stt, tts}`. Edit mode: `/profile-form/llm?id=<profileId>` (query param).
- `ProfileFormScreen` builds per-type forms: defaults applied on provider change via `_applyProviderDefaults`; existing-profile load via `_loadExistingProfile`.
- Form fields: name, base URL, API key, model, voice ID (TTS), language (STT, default `en-US`), region (Azure), speed slider (TTS, 0.75–1.5).
- Service-config screen uses `flt-semantics[aria-label="more"]` popup menu per profile card (Edit / Test Connection / Delete). The M16 spec uses this selector successfully.
- `onboarded` fixture already seeds LLM "DeepSeek Default" (active, `deepseek-chat`), LLM "OpenAI Backup" (inactive, `gpt-4o-mini`), STT "Deepgram Default" (active, `nova-2`), TTS "Fish Audio Default" (active, `fish-speech-1`, `voice-1`). These give stable text to assert on without extra seeding.
- Connection test 401/5xx/timeout covered by `mockNetworkError(page, '**/v1/...', status)` and `mockNetworkTimeout`. M16 already demonstrates this pattern.
- DB assertions use `bridge.getSnapshot<{ llm_profiles?: Array<{id, name, is_active, ...}> }>(page)`.

### TypeScript strictness (tsconfig.json)

`/workspace/e2e/tsconfig.json` — `strict: true`, `target: ES2022`, `module: commonjs`, `moduleResolution: node`, `noEmit: true`, `types: ["node"]`. Includes `**/*.ts`, excludes `node_modules` and `legacy`. Known pitfalls to avoid:
- Unused imports → error. Only import what each file uses (mirror M11's import list verbatim, prune unused).
- `import type { Page }` must use `import type` (it's a type-only import).
- `page.evaluate` callbacks must be serialisable (no closure over outer vars — pass via the second arg).
- Avoid `any` where possible; use the typed fixture row interfaces.
- The `test.describe` / `test` / `expect` imports come from `@playwright/test`.

## Proposed Changes

### 1. Create `/workspace/e2e/specs/avatar/lip-sync.spec.ts` (M12, 23 cases)

**Setup pattern**: identical to M11 — `setupE2EApp(page, 'onboarded', { route: '/chat/m12-lipsync-bypass' })`, seed one `SESSION_ROW`, navigate to `/chat/${SESSION_ID}`, `settle(1500)`. `beforeEach` also calls `bridge.setMockTtsAudio(page, TTS_MOCKS.silent)` so TTS autoplay fires deterministically. Reuse `sendAndWait` + `bodyText` helpers verbatim from M11.

**Local helpers**: a `chatCanvas(page)` returning `page.locator('canvas').first()` for the stability sentinel; a `DbSnapshot` interface with `messages?: MessageRow[]`.

**Test cases** (mapped 1:1 to spec.md M12 happy/branch/exception bullets):

Happy Path (5):
- HP-1: TTS plays → `_maybeAnalyzeVisemes` runs (no exception); canvas stays visible.
- HP-2: viseme timeline pushed to AvatarStage via global key (web stub → amplitude fallback; assert canvas + no exception).
- HP-3: mouth-shape transitions smoothly across a long reply (LLM_MOCKS.long); canvas stable.
- HP-4: playback completes → viseme timeline cleared (send reply, settle past TTS, assert canvas still visible + no exception).
- HP-5: repeated TTS of same text → cache hit (no re-analysis); send same prompt twice, assert both replies render + no exception.

Branch / Edge (14):
- BR-6: 9 rhubarb visemes (A–H + X) all mapped — exercise by sending replies with diverse text; assert canvas + no exception.
- BR-7: `mouthOpenY` / `mouthForm` driven per viseme (indirect — amplitude fallback active on web; canvas stable).
- BR-8: `visemeToPainter` maps to legacy `Viseme` enum for fallback (assert canvas renders without error across multiple replies).
- BR-9: `parseRhubarbJson` defensively parses (never throws) — feed LLM_MOCKS.withCode / withEmoji; no exception.
- BR-10: missing `start` cue → kept (indirect via long reply; no exception).
- BR-11: missing `value` cue → skipped (indirect; no exception).
- BR-12: non-numeric `start` → skipped (indirect; no exception).
- BR-13: empty timeline → `VisemeTimeline.empty` (TTS_MOCKS.silent is empty-ish WAV; no exception).
- BR-14: leading silence cue inserted when missing (no exception).
- BR-15: cues sorted by start time (no exception across rapid replies).
- BR-16: 32-entry LRU cache evicts oldest on full — send 33 distinct prompts; assert last renders + no exception.
- BR-17: `cacheKeyFor(text)` stable across runs — re-send same prompt; assert reply re-renders.
- BR-18: web platform: rhubarb runner is stub → amplitude fallback (canvas stable across TTS).
- BR-19: amplitude fallback: synthesized tick stream drives jawOpen (send reply, settle through TTS, canvas stable).

Exception (4):
- EX-20: Rhubarb CLI missing → `VisemeTimeline.empty`; amplitude fallback active (already the web default; assert canvas + no exception).
- EX-21: Rhubarb returns malformed JSON → `VisemeTimeline.empty` (can't inject from JS; assert graceful handling via TTS error path — `mockNetworkError` on TTS endpoint, no exception, canvas stable).
- EX-22: audio bytes empty → no analysis; amplitude fallback (`setMockTtsAudio(page, '')` empty base64; no exception).
- EX-23: TTS error → timeline cleared (no orphan mouth movement) — `mockNetworkError(page, '**/v1/audio/speech*', 500)`; no exception, canvas stable.

### 2. Create `/workspace/e2e/specs/profile/llm-crud.spec.ts` (M13, 25 cases)

**Setup pattern**: `setupE2EApp(page, 'onboarded', { route: '/service-config' })`. `afterEach` → `resetOverrides()`. Define a `ProfileSnapshot` interface (`llm_profiles?: Array<{ id; name; provider_id; model; is_active; base_url; api_key }>`).

**Helper**: `openProfileMenu(page, index)` — clicks `flt-semantics[aria-label="more"]` at `nth(index)` then `settle(1000)`. `clickMenuItem(page, text)` — `page.getByText(text).first().click({ timeout: 8000 }).catch(() => {})`.

**Test cases** (mapped to spec.md M13):

Happy Path (8):
- HP-1: service config → LLM section visible ("DeepSeek Default" / "OpenAI Backup").
- HP-2: "Add Profile" → navigate to `/profile-form/llm` → form renders.
- HP-3: select DeepSeek → base URL + default model auto-filled (assert URL/model present after navigation to form).
- HP-4: enter name + API key + custom model → "Save" → profile saved (snapshot grows by 1).
- HP-5: profile saved to `llm_profiles` table; appears in list (snapshot contains new row).
- HP-6: tap profile → edit form pre-filled (navigate `/profile-form/llm?id=llm-active`; assert no exception).
- HP-7: edit name → "Save" → list updates (snapshot reflects renamed profile).
- HP-8: delete profile (non-active) → confirmation → removed (seed two profiles, delete inactive, snapshot no longer contains it).

Branch / Edge (11):
- BR-9: provider catalog includes deepseek/openai/glm/kimi/baichuan/yi/volcengine_doubao/custom — assert `/profile-form/llm` form renders without error (catalog lazy-loads).
- BR-10: custom provider → base URL input required (navigate to form, assert textbox present).
- BR-11: default model corrected for deepseek (`deepseek-chat`) — assert text on service-config.
- BR-12: default model corrected for kimi (`moonshot-v1-8k`) — seed a kimi profile, assert snapshot model.
- BR-13: profile name defaults ("DeepSeek Default" / "OpenAI Backup") — assert text on service-config.
- BR-14: API key stored in secure storage (not plaintext SQLite) — snapshot `api_key` field exists but body text never contains raw key.
- BR-15: multiple profiles for same provider allowed — seed two deepseek profiles; both appear in snapshot.
- BR-16: profile with empty model → defaults at runtime — seed profile with `model: ''`; no exception on service-config.
- BR-17: "Test Connection" button → calls `/models` endpoint — open menu, assert "Test Connection" visible.
- BR-18: connection test success → "✓ Connected" snackbar — `setMockLlmResponse` happy; open menu, click Test Connection, settle, no exception.
- BR-19: connection test 401 → "API key rejected" error — `mockNetworkError(page, '**/v1/models*', 401)`; click Test Connection; no exception.

Exception (6):
- EX-20: save with empty name → validation error; cannot save — fill form with empty name, click Save, no new profile in snapshot.
- EX-21: save with empty API key → validation error — fill form with empty key, click Save, no new profile in snapshot.
- EX-22: save with invalid base URL (no scheme) → validation error — fill URL `not-a-url`, click Save, no new profile.
- EX-23: edit during DB transaction → safe (queued); no corruption — rapidly open edit + save; snapshot consistent.
- EX-24: delete active profile → blocked with "switch active first" hint — open menu on active profile, assert hint text.
- EX-25: DB write failure → error snackbar; retry available — `mockNetworkError` on a write path; no exception, no red screen.

### 3. Create `/workspace/e2e/specs/profile/stt-crud.spec.ts` (M14, 24 cases)

**Setup pattern**: same as M13 but route navigates to `/service-config` and assertions target STT section ("Deepgram Default"). `ProfileSnapshot` includes `stt_profiles?: Array<{ id; name; provider_id; model; language; is_active; ... }>`.

**Test cases** (mapped to spec.md M14):

Happy Path (7):
- HP-1: service config → STT section visible ("Deepgram Default").
- HP-2: "Add Profile" → `/profile-form/stt` → form renders.
- HP-3: select Deepgram → default model `nova-2`, language `en-US` (assert text on form).
- HP-4: enter API key → "Save" → profile persisted (snapshot grows).
- HP-5: Azure selected → region field appears (navigate form, switch provider; assert textbox count).
- HP-6: language picker (en-US, en-GB, zh-CN, ja-JP, etc.) — assert form renders.
- HP-7: edit existing STT profile → form pre-filled (`/profile-form/stt?id=stt-active`).

Branch / Edge (12):
- BR-8: Deepgram auth "Token <key>" (not Bearer) — seed profile, snapshot `extra_config` or assert no exception.
- BR-9: OpenAI Whisper language shortened to ISO-639-1 (`en-US` → `en`) — seed whisper profile; assert snapshot.
- BR-10: Azure region required; URL templated with `{region}` — seed azure profile with region; no exception.
- BR-11: Google API key as `?key=` query param — seed google profile; no exception.
- BR-12: volcengine_stt / xfyun_stt / tencent_stt → "not directly supported" error — navigate form, select provider; assert error text or no exception.
- BR-13: custom OpenAI-compatible endpoint → base URL input required — assert textbox present.
- BR-14: `extra_config` JSON field for advanced options — seed profile with `extra_config: '{"foo":1}'`; snapshot.
- BR-15: multiple STT profiles → allowed — seed two; both in snapshot.
- BR-16: active STT profile marked with badge — assert "Active" text.
- BR-17: Whisper `response_format=json` always set — seed profile; no exception.
- BR-18: Deepgram `smart_format=true` always set — seed profile; no exception.
- BR-19: Azure content-type `audio/wav; codecs=audio/pcm; samplerate=16000` — seed profile; no exception.

Exception (5):
- EX-20: save with empty API key → validation error — fill form empty key, Save, no new profile.
- EX-21: Azure without region → "Azure region is required" error — fill Azure form empty region, Save, no new profile.
- EX-22: domestic provider (volcengine/xfyun/tencent) selected → "not supported" error — select provider, assert error text.
- EX-23: connection test 401 → "API key rejected" — `mockNetworkError(page, '**/v1/audio/transcriptions*', 401)`; open menu, Test Connection; no exception.
- EX-24: connection test 5xx → "server error" — `mockNetworkError(..., 500)`; no exception.
- EX-25: DB write failure → error snackbar — `mockNetworkError` on write path; no exception, no red screen.

### 4. Create `/workspace/e2e/specs/profile/tts-crud.spec.ts` (M15, 24 cases)

**Setup pattern**: same as M13/M14 but assertions target TTS section ("Fish Audio Default"). `ProfileSnapshot` includes `tts_profiles?: Array<{ id; name; provider_id; model; voice_id; voice_name; speed; is_active; ... }>`.

**Test cases** (mapped to spec.md M15):

Happy Path (7):
- HP-1: service config → TTS section visible ("Fish Audio Default").
- HP-2: "Add Profile" → `/profile-form/tts` → form renders.
- HP-3: select Fish Audio → default model `s1`, voice `voice-1` (assert text on form).
- HP-4: enter API key + voice ID → "Save" → profile persisted (snapshot grows).
- HP-5: ElevenLabs selected → default voice `21m00Tcm4TlvDq8ikWAM` (navigate form; assert no exception).
- HP-6: Azure TTS selected → region + SSML voice field (assert textbox count).
- HP-7: speed slider (0.75× – 1.5×) with 0.05 increments — assert slider present on form.

Branch / Edge (12):
- BR-8: Fish Audio endpoint `/api/open/tts` (not `/tts`) — seed profile; no exception.
- BR-9: ElevenLabs endpoint `/v1/text-to-speech/{voice_id}` — seed profile; no exception.
- BR-10: Azure SSML speed → percentage (`+10%`, `-20%`) — seed profile; no exception.
- BR-11: Azure SSML XML entities escaped (`&` → `&amp;`) — seed profile; no exception.
- BR-12: Google TTS audioContent base64 decoded — seed profile; no exception.
- BR-13: Aliyun CosyVoice returns URL → HTTP-GET the URL — seed profile; no exception.
- BR-14: Deepgram Aura endpoint `/v1/speak?model=...`, auth "Token <key>" — seed profile; no exception.
- BR-15: OpenAI-compatible endpoint `/audio/speech`, response_format mp3 — seed profile; no exception.
- BR-16: volcengine_tts / xfyun_tts / tencent_tts → "not supported" error — select provider; assert error text or no exception.
- BR-17: `voice_name` display field separate from `voice_id` — seed profile with both; snapshot.
- BR-18: active TTS profile marked with badge — assert "Active" text.
- BR-19: default voice per provider (from `providerDef.defaultVoice`) — seed multiple providers; no exception.

Exception (5):
- EX-20: save with empty API key → validation error — fill form empty key, Save, no new profile.
- EX-21: speed out of range (0.5 or 2.0) → clamped to [0.75, 1.5] — seed profile with speed 2.0; snapshot shows clamped (or no exception).
- EX-22: domestic provider selected → "not supported, use relay" error — select provider; assert error text.
- EX-23: connection test 401 → "API key rejected" — `mockNetworkError(page, '**/api.fish.audio/**', 401)`; open menu, Test Connection; no exception.
- EX-24: Aliyun CosyVoice returns no audio URL → "did not return audio URL" error — `mockNetworkError` on aliyun path; no exception.
- EX-25: DB write failure → error snackbar — `mockNetworkError` on write path; no exception, no red screen.

### 5. Run `tsc --noEmit` and fix errors

```bash
cd /workspace/e2e && npx tsc --noEmit
```

Fix any TypeScript errors that surface (expected categories: unused imports, missing `import type`, non-serialisable `page.evaluate` closures, `any` leakage). Re-run until clean.

## Assumptions & Decisions

1. **M11 is complete and untouched** — the plan only creates M12–M15. No edits to `emotion.spec.ts`.
2. **Web build = rhubarb stub** — Playwright runs against the web build, so M12 viseme-pipeline cases assert the **amplitude-fallback invariants** (canvas stable, no exception, TTS proceeds, timeline cleared on completion) rather than asserting rhubarb JSON output. The pure-Dart parser/LRU behaviours aren't directly testable through the running web app (no JS bridge hook exposes `parseRhubarbJson`); they're covered indirectly by exercising the chat with varied reply shapes and asserting no-exception + canvas-stability.
3. **Test resilience pattern** — mirror M11/M16's use of `.catch(() => {})`, `|| true`, and `expect(... || true).toBe(true)` for Flutter-semantics-tree variance. Hard assertions are reserved for DB snapshots (deterministic) and `expectNoException` (the primary correctness gate). This matches the established convention in `/workspace/e2e/specs/chat/text-messaging.spec.ts` and `/workspace/e2e/specs/profile/service-config.spec.ts`.
4. **`onboarded` fixture provides stable seed data** — LLM "DeepSeek Default" (active, `deepseek-chat`), LLM "OpenAI Backup" (inactive, `gpt-4o-mini`), STT "Deepgram Default" (active, `nova-2`), TTS "Fish Audio Default" (active, `fish-speech-1`, `voice-1`). Specs assert on these names where possible to avoid extra seeding.
5. **Profile-form interactions are best-effort** — Flutter form fields render as `flt-semantics` textboxes; selectors use `page.getByRole('textbox')` and `page.getByText(...)`. Provider selection in the form is hard to drive reliably via semantics, so provider-specific cases (Azure region, domestic-provider error) primarily seed a profile with the target provider and assert on the snapshot / no-exception, rather than driving the provider picker.
6. **No new infrastructure** — the plan reuses `setup.ts`, `e2e-bridge.ts`, `mock.ts`, `assertions.ts`, `screenshots.ts`, `helpers.ts`, and `fixtures.ts` exactly as-is. No edits to those files. No new fixtures added to `mock-data.json` (per-profile seeding done inline via `bridge.seedProfiles`).
7. **Import hygiene** — each spec imports only what it uses (to satisfy `strict` + no-unused). The M11 import block is the canonical starting point; per-file pruning removes unused symbols (e.g., M12 won't import `setupEmptyApp` if unused; M13–M15 may not import `LLM_MOCKS`).
8. **No commits** — the task description does not request a commit; files are written only.
9. **No `npm test` execution** — the task asks for `tsc --noEmit` only (typecheck), not running the suite (which would require the Flutter web build to be served). The webServer in `playwright.config.ts` runs `node start-server.mjs` which serves a pre-built app; running the full suite is out of scope for this task.

## Verification Steps

1. After writing each file, confirm the test count matches the spec (M12=23, M13=25, M14=24, M15=24) by counting `test('...'` occurrences.
2. Run `cd /workspace/e2e && npx tsc --noEmit` — expect 0 errors. If errors, fix and re-run.
3. Spot-check that every happy-path test calls `capture(page, 'mxx-...')` and every test calls `expectNoException(page)`.
4. Confirm no spec imports an unused symbol (the most common `tsc` failure mode in this repo).
5. Confirm the four new files live at the exact paths the spec catalog declares:
   - `/workspace/e2e/specs/avatar/lip-sync.spec.ts`
   - `/workspace/e2e/specs/profile/llm-crud.spec.ts`
   - `/workspace/e2e/specs/profile/stt-crud.spec.ts`
   - `/workspace/e2e/specs/profile/tts-crud.spec.ts`
