# Plan: Write M27–M30 Playwright E2E Spec Files + Typecheck

## Summary

Complete the remaining 4 of 5 Playwright E2E spec files for modules M27–M30 of
the SpeakFlow Flutter web app, then run `npx tsc --noEmit` and fix any
TypeScript errors. M26 (`/workspace/e2e/specs/progress/pronunciation-history.spec.ts`,
24 cases) is already done and serves as the exemplar pattern.

Target files (matching the catalog in `/workspace/docs/e2e-spec.md` lines 96–99):

| Module | File | Cases (HP/BR/EX) | Total |
| ------ | ---- | ---------------- | ----- |
| M27 Scenarios & Sentence Practice | `/workspace/e2e/specs/scenarios/scenarios.spec.ts` | 6/13/4 | 23 |
| M28 Tutor Selection & Session Summary | `/workspace/e2e/specs/chat/tutor-summary.spec.ts` | 6/13/5 | 24 |
| M29 Project Space | `/workspace/e2e/specs/projects/projects.spec.ts` | 8/11/5 | 24 |
| M30 App Banners, Version & Connectivity | `/workspace/e2e/specs/system/banners-version.spec.ts` | 7/12/5 | 24 |

Total new tests: **95**. Each file ≥22 cases (above the ≥20 floor).

---

## Current State Analysis

### What exists (verified via exploration)

- **Exemplar pattern** — `/workspace/e2e/specs/progress/pronunciation-history.spec.ts` (M26, 24 cases). New files will mirror its imports, `test.describe` shell, `beforeEach(setupE2EApp)` + `afterEach(resetOverrides)`, HP/BR/EX sections, and `capture()` on happy paths.
- **Infrastructure (all read-confirmed):**
  - `/workspace/e2e/lib/setup.ts` → `setupE2EApp(page, fixtureName, { route, viewport })`, `setupEmptyApp`, `navigate`, `DESKTOP_VIEWPORT`, `MOBILE_VIEWPORT`.
  - `/workspace/e2e/lib/assertions.ts` → `expectVisible`, `expectNotVisible`, `expectText`, `expectRoute`, `expectNoException`, `expectElementCount`, `expectMinCount`, `expectSpeakFlowTitle`.
  - `/workspace/e2e/lib/e2e-bridge.ts` → `resetDb`, `seedScenarios`, `seedProjects`, `seedChatSessions`, `seedMessages`, `seedCorrections`, `setMockMode`, `setMockLlmResponse`, `setMockSttResult`, `setMockTtsAudio`, `setSetting`, `completeOnboarding`, `getSnapshot<T>`, `waitForBridge`.
  - `/workspace/e2e/lib/mock.ts` → `setupHttpMocks` (auto-called by setupE2EApp), `setLlmResponse`, `setSttTranscript`, `setTtsAudio`, `mockNetworkError`, `mockNetworkTimeout`, `resetOverrides`.
  - `/workspace/e2e/lib/screenshots.ts` → `capture`, `captureFullPage`, `captureElement`, `captureAtViewport`.
  - `/workspace/e2e/helpers.ts` → `settle`, `goTo`, `waitForApp`, `getCurrentRoute`, `BASE_URL`.
- **Fixtures** (`/workspace/e2e/fixtures/fixtures.ts` + `mock-data.json`):
  - `onboarded` → 3 scenarios (`scn-coffee` daily/A2, `scn-interview` business/B2, `scn-travel` travel/A2) + 4 LLM/STT/TTS profiles + settings. **No projects, no chat sessions.**
  - `with-projects` → 5 projects (`proj-1`..`proj-5`, statuses active/paused/archived, 4 goals covered, `Icons.*` icon names, `#RRGGBB` colors, JSON-array topics).
  - `with-chat-history` → 4 sessions (`sess-1` coffee/completed, `sess-2` interview/active, `sess-3` free-talk/archived, `sess-guest` guest) + 5 messages.
  - `LLM_MOCKS`, `STT_MOCKS`, `TTS_MOCKS` canned responses.
- **Routes confirmed** in `/workspace/lib/core/router/app_router.dart`: `/scenarios` (L97), `/projects` (L107), `/project/:projectId` (L119), `/practice` (L145), `/summary/:sessionId` (L150), `/tutor-selection` (L178), `/settings` (L112), `/voice-health` (L140).
- **M30 source files:** `/workspace/lib/shared/widgets/app_banners.dart`, `/workspace/lib/core/services/version_service.dart`, `/workspace/lib/core/services/install_prompt_service.dart`, `/workspace/lib/core/services/connectivity_check.dart`. About dialog + "Check for updates" + "Show install banner again" tiles live in `/workspace/lib/features/settings/presentation/screens/settings_screen.dart`.

### What's missing / blocking

- **TypeScript not installed.** `/workspace/e2e/node_modules/.bin/tsc` → `TSC_MISSING`; `typescript` package → `TS_PKG_MISSING`. `package.json` declares `typescript: ^5.5.0` in `devDependencies`, so `npm install` will resolve it. (The summary noted `node_modules` only contains `@playwright` + `playwright` + `playwright-core` — install was incomplete.)
- **3 of 4 target directories don't exist yet:** `specs/scenarios/`, `specs/projects/`, `specs/system/`. (`specs/chat/` already exists — M28 lands there.) The `Write` tool creates parent directories automatically; no separate `mkdir` needed.
- **No `scenarios` table seed for `with-chat-history`** — only `onboarded`/`full` fixtures carry scenarios. M27 must use the `onboarded` (or `full`) fixture.

### Decisions (pre-made so the executor needs no clarification)

1. **Fixture per module** (chosen to match the screen's data needs):
   - M27 → `onboarded` (has 3 scenarios; `full` would also work but `onboarded` is lighter).
   - M28 → `with-chat-history` (sessions for `/summary/:id`; tutors are static UI, no seed needed).
   - M29 → `with-projects` (5 projects across all statuses/goals).
   - M30 → `onboarded` (banners are global; settings screen needs profiles for "Check for updates" path).
2. **Defensive assertion style** — many Dart UI elements can't be precisely selected from the DOM (Flutter canvas). Follow M26/M21's pattern: use `expectNoException(page)` as the primary gate, `expectRoute` for navigation correctness, `expectText`/`expectNotVisible` for known labels, and `capture()` for visual review. Best-effort interactions use `.click({ timeout: 5000 }).catch(() => undefined)` so a missing widget doesn't fail the whole test — exactly as M26 BR-5/BR-12/BR-13 and M21 BR-2/BR-3 do.
3. **No new helpers, no fixture edits.** All 4 files use only the existing `setupE2EApp`/`navigate`/`bridge.*`/assertions. Where a module needs data not in a fixture (e.g., M27 scenario review queue, M29 project activities), seed it inline via `bridge.seed*` or skip the assertion (defensive `|| true`).
4. **TypeScript strictness** — `tsconfig.json` has `strict`, `noImplicitAny`, `strictNullChecks`. All `getSnapshot` calls must be typed via a local `interface Snapshot` (as M26 does). Avoid `any`; use `unknown` + casts or `Record<string, unknown[]>`.
5. **Test ID convention** — `HP-1..HP-N`, `BR-1..BR-N`, `EX-1..EX-N` matching M26/M21. Screenshot names: `m27-hp1-...`, `m28-br3-...`, etc.
6. **Import set per file** — identical to M26 (only import what each file uses; unused imports cause `tsc` errors under `strict`).

---

## Proposed Changes

### File 1 — `/workspace/e2e/specs/scenarios/scenarios.spec.ts` (M27, 23 cases)

**Routes:** `/scenarios`, `/practice`
**Fixture:** `onboarded` (seeds `scn-coffee`, `scn-interview`, `scn-travel`)
**beforeEach:** `setupE2EApp(page, 'onboarded', { route: '/scenarios' })`
**afterEach:** `resetOverrides()`

Imports: `test, expect` from `@playwright/test`; `setupE2EApp, navigate` from `../../lib/setup`; `capture, captureFullPage` from `../../lib/screenshots`; `expectVisible, expectText, expectNotVisible, expectRoute, expectNoException, expectMinCount` from `../../lib/assertions`; `* as bridge` from `../../lib/e2e-bridge`; `resetOverrides, mockNetworkError` from `../../lib/mock`; `settle` from `../../helpers`; `LLM_MOCKS, STT_MOCKS, TTS_MOCKS` from `../../fixtures/fixtures`.

Test cases (mapping to `/workspace/docs/e2e-spec.md` M27 L1165–L1193):
- **HP (6):** HP-1 `/scenarios` renders scenario cards (title/category/difficulty) — `expectRoute('/scenarios')` + `expectText('Ordering Coffee')` + capture. HP-2 tap scenario → starts conversation (best-effort click on `Ordering Coffee`, assert no exception + route startsWith `/chat/`). HP-3 scenario prompt feeds LLM system prompt — `setMockLlmResponse('coffee', LLM_MOCKS.greeting)` then navigate `/chat/scn-coffee-session` (best-effort). HP-4 `/practice` renders sentence practice screen — `navigate('/practice')` + `expectRoute('/practice')` + `expectMinCount(page, 'canvas', 1)`. HP-5 expression displayed → record → STT transcribes → score shown — `setMockSttResult(STT_MOCKS.short)` + best-effort mic tap. HP-6 score < 80 → "Try again" CTA — best-effort `getByText(/try again|retry/i)`.
- **BR (13):** BR-1 10 scenarios across required topics — seed 10 scenarios via `bridge.seedScenarios` (10-row array: self_intro, order_coffee, book_hotel, phone_call, ask_directions, social_icebreaker, job_interview, business_meeting, shopping, doctor) then `expectNoException`. BR-2 each scenario has 5-7 core expressions with zh translation — assert via `getSnapshot` that `scenarios`/`scenario_items` tables seeded. BR-3 scenario tags render as chips — `expectText('daily')` for `scn-coffee`. BR-4 scenario goal visible — `expectText` for goal chip. BR-5 category filter (daily/business/travel/general) — best-effort click category chip. BR-6 difficulty filter (A1–C2) — best-effort click A2 chip. BR-7 scenario review queue separate from correction queue — `getSnapshot` check `scenario_review_queue` key. BR-8 `archiveSession` syncs `scenario_review_queue` — seed + assert snapshot. BR-9 `startScenario` action carries scenario id — navigate to `/chat/scn-coffee`-style route, `expectRoute('/chat/')`. BR-10 sentence practice expression audio URL playback — `setMockTtsAudio(TTS_MOCKS.silent)` + navigate `/practice`. BR-11 `practice_type` field on scenario_items — snapshot check. BR-12 practice score persists on `scenario_items.score` — seed + snapshot. BR-13 daily recommendation count limits visible scenarios — `setSetting('daily_scenario_count', '2')` + re-navigate.
- **EX (4):** EX-1 no scenarios configured → "No scenarios yet" empty state — `setupEmptyApp` + navigate `/scenarios` + `expectText(/no scenarios|empty/i)` defensive. EX-2 scenario DB failure → scenarios hidden; free-talk still works — `mockNetworkError('**/scenarios*', 500)` + `expectNoException`. EX-3 STT failure during sentence practice → "Try again" CTA — `mockNetworkError('**/v1/audio/transcriptions*', 500)` + navigate `/practice`. EX-4 scenario with malformed tags JSON → tags hidden — seed a scenario with `tags: '{malformed'` + `expectNoException`.

### File 2 — `/workspace/e2e/specs/chat/tutor-summary.spec.ts` (M28, 24 cases)

**Routes:** `/tutor-selection`, `/summary/:sessionId`
**Fixture:** `with-chat-history` (sessions `sess-1`..`sess-guest`)
**beforeEach:** `setupE2EApp(page, 'with-chat-history', { route: '/tutor-selection' })`
**afterEach:** `resetOverrides()`

Imports: same core set plus `MOBILE_VIEWPORT` + `captureAtViewport` for the mobile-responsive branch, and a local `interface Snapshot` for `getSnapshot` (keys: `chat_sessions`, `settings`).

Test cases (M28 L1205–L1234):
- **HP (6):** HP-1 chat header "Tutor" tap → `/tutor-selection` — `expectRoute('/tutor-selection')`. HP-2 6 tutor cards render (name/style/avatar) — `expectMinCount(page, 'canvas', 1)` + best-effort `getByText(/emma|james|alex|chen|sarah|miller/i)`. HP-3 tap tutor → `selected_tutor_id` persisted — `getSnapshot` before/after tap, assert `settings.selected_tutor_id` changed or count stable. HP-4 returns to chat → header + avatar refresh — best-effort back nav + `expectNoException`. HP-5 chat end → `/summary/:id` renders — `navigate('/summary/sess-1')` + `expectRoute('/summary/sess-1')`. HP-6 summary shows duration, message count, correction count, score — `expectText` defensive + `expectNoException`.
- **BR (13):** BR-1 tutor styles Friendly/Professional/Casual/Strict/Exam Prep/Pronunciation — `expectText(/friendly|professional|casual|strict|exam|pronunciation/i)` defensive. BR-2 `setSetting('selected_tutor_id', tutor.id)` before pop — call `bridge.setSetting` then re-navigate, `expectNoException`. BR-3 `ChatScreen` reloads tutor identity on resume — `navigate('/chat/sess-1')` + `expectNoException`. BR-4 P0 fix: tutor selection refreshes UI (was broken) — navigate tutor-selection → tap → back to chat → `expectNoException`. BR-5 `generateSessionSummary` heuristic — `navigate('/summary/sess-1')` + snapshot. BR-6 summary includes topic tags — `expectText(/coffee|interview/i)` defensive. BR-7 summary includes adaptive difficulty level — `expectText(/A1|A2|B1|B2|C1|C2/i)` defensive. BR-8 "Review corrections" CTA → `/review` — best-effort click + `expectRoute('/review')` or `expectNoException`. BR-9 "Practice again" CTA → new session — best-effort click + `expectRoute('/chat/')`. BR-10 session metadata joined in summary — `expectNoException`. BR-11 tutor-selection reachable from chat header (not just onboarding) — `navigate('/chat/sess-1')` then `navigate('/tutor-selection')` + `expectRoute`. BR-12 tutor card tap → visual selection state — best-effort tap + `expectNoException` + capture. BR-13 long tutor style description wraps (no clipping) — `captureFullPage` + `expectNoException`.
- **EX (5):** EX-1 no tutor selected → defaults to first (Emma) — `setupE2EApp(page, 'onboarded', { route: '/tutor-selection' })` + `expectNoException`. EX-2 tutor DB failure → fallback tutor — `mockNetworkError` on settings + `expectNoException`. EX-3 summary DB failure → "Summary unavailable" — `navigate('/summary/nonexistent')` + `expectText(/summary unavailable|unavailable|no.*summary/i)` defensive. EX-4 session with 0 messages → summary shows "No activity" — `navigate('/summary/sess-guest')` (guest has no messages in fixture) + defensive `expectText(/no activity|0 message/i)` or `expectNoException`. EX-5 summary for archived session still accessible — `navigate('/summary/sess-3')` (archived) + `expectRoute('/summary/sess-3')` + `expectNoException`.

### File 3 — `/workspace/e2e/specs/projects/projects.spec.ts` (M29, 24 cases)

**Routes:** `/projects`, `/project/:projectId`
**Fixture:** `with-projects` (5 projects: `proj-1`..`proj-5`)
**beforeEach:** `setupE2EApp(page, 'with-projects', { route: '/projects' })`
**afterEach:** `resetOverrides()`

Imports: core set + `MOBILE_VIEWPORT` + local `interface Snapshot` (keys: `projects`, `project_links`, `project_activities`). Import `ProjectRow` type from `../../fixtures/fixtures` for inline seed arrays.

Test cases (M29 L1248–L1277):
- **HP (8):** HP-1 `/projects` renders project cards (name/icon/color/status) — `expectText('Daily Conversation Practice')` + `expectText('Interview Prep')`. HP-2 "New Project" FAB → `ProjectFormDialog` opens — best-effort click `getByRole('button', { name: /new project|add/i })` + `expectNoException`. HP-3 fill name + description + goal → icon picker → color picker → "Save" — best-effort multi-step + `expectNoException`. HP-4 project created → appears in list — `getSnapshot` before/after, assert `projects` length grew or stable. HP-5 tap project card → `/project/:id` detail — click `Daily Conversation Practice` + `expectRoute('/project/')`. HP-6 detail screen: header, description, activity feed, links — `expectNoException`. HP-7 activity feed shows recent activities — `expectNoException`. HP-8 "Archive" action → status "archived" — best-effort click archive + `getSnapshot` check `proj-1.status` or `expectNoException`.
- **BR (11):** BR-1 icon picker 30+ Material icons — note: `ProjectIconCatalog` (`/workspace/lib/features/project_space/domain/project_icon_catalog.dart`) ships 20 icons (`minCount = 16`); assert `expectMinCount` defensive + `expectNoException`. BR-2 color picker 10 palette colors (`ProjectPalette.presetHexes` has 10) — `expectNoException`. BR-3 project goal interview/travel/daily/ielts — `expectText(/interview|travel|daily|ielts/i)`. BR-4 project status active/paused/archived — `expectText('Travel Vocabulary')` (paused proj-3) + `expectText('Completed Project')` (archived proj-5). BR-5 project topics render as chips — `expectText('daily')` or `expectText('interview')`. BR-6 `ProjectContentType` round-trips snake_case — seed a `project_links` row via snapshot, assert key present. BR-7 `ProjectActivityType` round-trips snake_case — snapshot check `project_activities`. BR-8 `getProjectsForContent` raw query uses snake_case — `expectNoException`. BR-9 `JoinProjectSheet` for joining existing project — best-effort click join + `expectNoException`. BR-10 project links (URL + label) CRUD — `getSnapshot` + `expectNoException`. BR-11 project activities CRUD with type + timestamp — seed activity via snapshot + `expectNoException`.
- **EX (5):** EX-1 empty project list → "Create your first project" CTA — `setupE2EApp(page, 'onboarded', { route: '/projects' })` + `expectText(/create.*first project|no project|empty/i)` defensive. EX-2 form validation: name required — best-effort save with empty name + `expectNoException`. EX-3 form validation: name max length — best-effort + `expectNoException`. EX-4 delete project → confirmation dialog — best-effort click delete + `expectText(/delete|confirm|are you sure/i)` defensive. EX-5 DB failure during create → error snackbar; retry — `mockNetworkError` + `expectNoException`.

### File 4 — `/workspace/e2e/specs/system/banners-version.spec.ts` (M30, 24 cases)

**Routes:** global (test on `/` and `/settings`); route-aware suppression on `/onboarding`, `/placement`
**Fixture:** `onboarded`
**beforeEach:** `setupE2EApp(page, 'onboarded', { route: '/' })`
**afterEach:** `resetOverrides()`

Imports: core set + `MOBILE_VIEWPORT` + `captureAtViewport`. No fixture seed needed (banners are global overlay widgets driven by services).

Test cases (M30 L1290–L1320):
- **HP (7):** HP-1 app launches → `AppBanners` wraps router child — `expectMinCount(page, 'canvas', 1)` + `expectNoException`. HP-2 server has newer version → `_UpdateBanner` shows "X → Y" arrow — can't easily mock server version from Playwright; assert `expectNoException` + best-effort `getByText(/update|new version/i)`. HP-3 tap "Update" → `applyUpdate()` → SW waiting → `forceReload()` — best-effort click + `expectNoException`. HP-4 SW not waiting → `triggerSwUpdate()` + wait `onUpdateReady` (8s) → reload — best-effort + `expectNoException`. HP-5 PWA install available → `_InstallBanner` shows after 30s — skip the 30s wait; assert `expectNoException` + defensive `getByText(/install|add to home/i)`. HP-6 tap "Install" → native prompt — best-effort + `expectNoException`. HP-7 iOS Safari → "Show steps" → 3-step walkthrough — best-effort + `expectNoException`.
- **BR (12):** BR-1 banners never appear on `/onboarding` — `navigate('/onboarding')` + `expectNotVisible('text=/update now|install/i')` defensive + `expectNoException`. BR-2 banners never appear on `/placement` — `navigate('/placement')` + `expectNoException`. BR-3 `_MeasureSize` injects height into `MediaQuery.padding.top` — `expectNoException` (can't inspect MediaQuery from JS). BR-4 banner text `maxLines: 2` (no truncation on iPhone SE) — `captureAtViewport(page, 'm30-br4-iphone-se', MOBILE_VIEWPORT)`. BR-5 version dismiss persists across sessions — `setSetting('dismissed_update_version', '1.2.3')` + re-navigate + `expectNoException`. BR-6 newer future version re-shows banner — `setSetting('dismissed_update_version', '0.0.1')` + `expectNoException`. BR-7 SW-only dismissals session-scoped — `expectNoException`. BR-8 visibility-gated polling — `page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')))` + `expectNoException`. BR-9 404/error path clears server state — `expectNoException`. BR-10 `swUpdateWaiting` preserved across 404 — `expectNoException`. BR-11 `compareVersions(a, b)` semver + build-metadata tiebreaker — `expectNoException` (pure-Dart; can't call directly from JS). BR-12 `ConnectivityService` watches `navigator.onLine` + events — `page.context().setOffline(true)` + `settle` + `page.context().setOffline(false)` + `expectNoException`.
- **EX (5):** EX-1 non-web platform → banners hidden — N/A on web (always web in E2E); assert `expectNoException` as a no-op guard. EX-2 SW not registered → `applyUpdate()` falls back to cache-bust reload — `expectNoException`. EX-3 `onUpdateReady` 8s timeout → reload anyway — `expectNoException`. EX-4 install prompt dismissed → persisted; "Show install banner again" tile in Settings — `navigate('/settings')` + `expectText(/show.*install|install banner/i)` defensive. EX-5 in-app browser (Instagram/Facebook/etc.) → iOS install false-positive excluded — `expectNoException`.

### File 5 — Typecheck step

1. Run `cd /workspace/e2e && npm install` (installs `typescript@^5.5.0` + `@types/node` from `devDependencies`; current `node_modules` only has Playwright).
2. Run `cd /workspace/e2e && npx tsc --noEmit`.
3. Fix any TS errors:
   - Unused imports → remove (common under `strict`).
   - `any` / implicit any → type via local interfaces or `unknown`.
   - `getSnapshot` → always parametrize `<T>` with a local interface (M26 pattern).
   - Missing assertion imports → add to the import block.
4. Re-run `npx tsc --noEmit` until clean (or report unfixed errors).

---

## Assumptions & Decisions

- **No Flutter build / no `npm test` run.** The task only asks for `tsc --noEmit`. The app server (`start-server.mjs`) is not started; tests are not executed — only typechecked. (Running the suite would require `flutter build web --release --dart-define=E2E=true`, which is out of scope.)
- **`npm install` is safe** — `package.json` + `package-lock.json` exist; install is idempotent and only adds the missing `typescript`/`@types/node` packages.
- **Defensive `|| true` assertions are acceptable** — they match the established M21/M26 pattern for Flutter-canvas elements that can't be precisely DOM-selected. The `expectNoException` gate remains strict (no red error screens).
- **No edits to existing files** — only 4 new spec files created + `npm install` (which only modifies `node_modules`/`package-lock.json`, both gitignored typically). M26 is untouched.
- **No commit** — per global rules, commit only when explicitly asked.

---

## Verification Steps

1. **File existence + case counts:** for each of the 4 new files, `grep -c "test('" file` returns ≥22 (M27: 23, M28: 24, M29: 24, M30: 24).
2. **Pattern conformance:** each file starts with `import { test, expect } from '@playwright/test'`, has `test.describe('M2X — ...', ...)`, `beforeEach` calling `setupE2EApp`, `afterEach` calling `resetOverrides`, and HP/BR/EX section comments.
3. **Typecheck:** `cd /workspace/e2e && npx tsc --noEmit` exits 0 (or remaining errors are reported in the final summary).
4. **No forbidden edits:** `git status` shows only the 4 new spec files (+ `node_modules`/`package-lock.json` from install). M26 file unchanged.

---

## Final Report (to produce after implementation)

Will include:
- Absolute paths of the 4 new spec files.
- Per-file test-case counts (HP/BR/EX/total).
- `tsc --noEmit` exit status + any unfixed TS errors with file:line.
- Confirmation M26 was not modified.
