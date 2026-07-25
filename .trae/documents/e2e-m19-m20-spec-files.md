# Plan: E2E Spec Files for M19 and M20 + Typecheck

## Summary

Finish the in-progress task of writing 5 Playwright E2E spec files (M16–M20) for the SpeakFlow Flutter web app. M16 (`profile/service-config.spec.ts`), M17 (`profile/voice-health.spec.ts`), and M18 (`home/dashboard.spec.ts`) are already created and follow a stable pattern. This plan covers the **2 remaining spec files** (M19 and M20), then runs `tsc --noEmit` and reports any unfixable TypeScript errors.

## Current State Analysis

### Already done (confirmed via Read)
- `/workspace/e2e/specs/profile/service-config.spec.ts` — M16, 24 cases (HP×7, BR×12, EX×5)
- `/workspace/e2e/specs/profile/voice-health.spec.ts` — M17, 23 cases (HP×6, BR×13, EX×4)
- `/workspace/e2e/specs/home/dashboard.spec.ts` — M18, 24 cases (HP×7, BR×12, EX×5)
- `/workspace/e2e/tsconfig.json` exists with `strict: true`, `noEmit: true`, `target: ES2022`, `module: commonjs`, `moduleResolution: node`, `types: ["node"]`, `include: ["**/*.ts"]`, `exclude: ["node_modules", "legacy"]`. Note: `noUnusedLocals` / `noUnusedParameters` are NOT enabled — unused imports are allowed.
- Helper libs confirmed exporting all symbols used by M16/M17/M18:
  - `e2e/lib/setup.ts`: `setupE2EApp`, `setupEmptyApp`, `navigate`, `DESKTOP_VIEWPORT`, `MOBILE_VIEWPORT`
  - `e2e/lib/assertions.ts`: `expectVisible`, `expectText`, `expectNotVisible`, `expectRoute`, `expectNoException`, `expectElementCount`, `expectMinCount`, `expectSpeakFlowTitle`
  - `e2e/lib/e2e-bridge.ts`: `resetDb`, `seedProfiles`, `seedChatSessions`, `seedMessages`, `seedCorrections`, `seedReviewQueue`, `seedScenarios`, `setMockMode`, `setMockLlmResponse`, `setMockSttResult`, `setMockTtsAudio`, `getSnapshot`, `setSetting`, `completeOnboarding`, `waitForBridge`
  - `e2e/lib/mock.ts`: `setupHttpMocks` (internal), `resetOverrides`, `mockNetworkError`, `mockNetworkTimeout`, `setLlmResponse`, `setSttTranscript`, `setTtsAudio`
  - `e2e/lib/screenshots.ts`: `capture`, `captureFullPage`, `captureElement`, `captureAtViewport`, `captureBaseline`, `listScreenshots`
  - `e2e/helpers.ts`: `waitForApp`, `goTo`, `navigateHash`, `settle`, `getCurrentRoute`, `hasText`, `clickText`, `completeOnboarding`, `completePlacement`, `setupSeededApp`, `BASE_URL`
  - `e2e/fixtures/fixtures.ts`: `FIXTURES`, `FixtureName`, `getFixture`, `ALL_FIXTURE_NAMES`, `LLM_MOCKS`, `STT_MOCKS`, `TTS_MOCKS` + row-type interfaces (`LlmProfileRow`, `SttProfileRow`, `TtsProfileRow`, `ChatSessionRow`, `MessageRow`, `CorrectionRow`, `ReviewQueueRow`, `ScenarioRow`, `ProjectRow`, `FixtureBundle`)

### Not yet created (confirmed via Glob — only `ability-goals.spec.ts` and `dashboard.spec.ts` exist under `specs/home/`)
- `/workspace/e2e/specs/home/streak.spec.ts` (M19)
- `/workspace/e2e/specs/home/daily-plan.spec.ts` (M20)

### Established pattern (from M16/M17/M18) — every new file MUST follow it
- Imports: `@playwright/test`; `setupE2EApp, setupEmptyApp, navigate, DESKTOP_VIEWPORT, MOBILE_VIEWPORT` from `../../lib/setup`; `capture, captureFullPage, captureAtViewport` from `../../lib/screenshots`; assertion helpers from `../../lib/assertions`; `settle` from `../../helpers`; `* as bridge` from `../../lib/e2e-bridge`; `resetOverrides, mockNetworkError` from `../../lib/mock`; `FIXTURES, LLM_MOCKS, STT_MOCKS, TTS_MOCKS` from `../../fixtures/fixtures`.
- Only import what each file actually uses — `noUnusedLocals` is NOT enabled so unused imports won't fail the build, but mirror M17/M18 and keep imports lean.
- `test.describe('Mxx — Module Name', () => { beforeEach(setupE2EApp), afterEach(resetOverrides), tests })`.
- `beforeEach` uses `setupE2EApp(page, 'onboarded', { route: '/' })`.
- Test IDs: `HP-1..HP-n`, `BR-1..BR-n`, `EX-1..EX-n` with descriptive titles.
- Defensive interaction: Flutter web is flaky in headless mode, so button clicks use `.click({ timeout: 8000 }).catch(() => {})` guards. Every test ends with `await expectNoException(page)` and happy-path tests end with `await capture(page, 'mxx-<id>-<slug>')`.
- TS-correctness: prefer reading snapshot via `await bridge.getSnapshot<Record<string, unknown[]>>(page)` when asserting on DB state. Profile-seed rows can use the typed interfaces from `fixtures.ts` but raw object literals also type-check because the bridge helpers are generic `<T = unknown>`.
- Route verification: `await expectRoute(page, '/')` and `expect(url).toContain('chat')` for post-navigation checks (M18 BR-1..BR-3 style).

### M19 spec source (from `/workspace/docs/e2e-spec.md` §M19 — 23 cases)
- Route: `/` (home)
- Service: `StreakService`, `practice_log` table
- 30-day dot grid + 7/14/21/28 milestone badges. Practice recorded on chat start, pronunciation practice open, correction rating.
- HP (5): 1) 30-day dot grid renders; 2) today's dot filled if practice today; 3) 7/14/21/28 milestone badges; 4) streak count visible; 5) practice recorded when starting a conversation.
- BR (14): 6) practice recorded when opening pronunciation practice; 7) practice recorded when rating a correction; 8) streak DB error swallowed; 9) streak denormalized on each `practice_log` row; 10) missed day resets streak; 11) two practices same day = one increment; 12) 30-day rolling window; 13) milestone badge color distinct; 14) streak service best-effort; 15) `duration_seconds` recorded; 16) `completed` flag on practice log; 17) streak updates immediately after practice; 18) locale-aware day labels; 19) theme-aware colors.
- EX (4): 20) practice log DB failure → streak not updated, no error; 21) streak overflow capped at 999; 22) midnight date boundary attributes to new day; 23) multiple practices across midnight counted in respective days.

### M20 spec source (from `/workspace/docs/e2e-spec.md` §M20 — 22 cases)
- Route: `/` (home)
- Service: `DailyPlanService` (`/workspace/lib/features/chat/data/daily_plan_service.dart`)
- 1–5 prioritized tasks: P1 SRS reviews, P2 recent-mistake drill, P3 voice-health pre-flight, P4 sentence practice, P5 free-talk/scenario.
- HP (5): 1) section renders 1–5 prioritized cards; 2) each card shows title + duration estimate + P1–P5 priority pill; 3) P1 surfaces when reviews due; 4) P2 surfaces when recent errors exist; 5) P3 surfaces conditionally.
- BR (13): 6) P4 always available; 7) P5 default when no higher-priority items; 8) `recentErrorCount` counts corrections seen in last 3 days; 9) content enabled → P5 uses `startScenario`; 10) content disabled → P5 uses `startConversation`; 11) tap P1 → `/review`; 12) tap P5 → creates session + `/chat/:id`; 13) tap P4 → `/practice`; 14) tap P3 → `/voice-health`; 15) `buildFromRepository` pulls content settings + recommended scenario; 16) daily scenario count (1–10, default 3) affects P5; 17) active teacher persona affects wording; 18) tasks re-prioritize on refresh; 19) empty state "All caught up!".
- EX (4): 20) recent errors DB failure → P2 skipped; 21) SRS queue DB failure → P1 skipped; 22) content settings DB failure → defaults applied (enabled, count 3); 23) scenario DB failure → P5 falls back to free-talk.

## Proposed Changes

### File 1: `/workspace/e2e/specs/home/streak.spec.ts` (M19 — 23 cases)

- Header doc-comment naming module + route + service (`StreakService`, `practice_log`).
- Imports (mirroring M17/M18): `test, expect` from `@playwright/test`; setup, screenshots, assertions, helpers, bridge, mock, fixtures.
- `test.describe('M19 — Home: Streak & Practice Log', () => { ... })`.
- `beforeEach`: `await setupE2EApp(page, 'onboarded', { route: '/' });`
- `afterEach`: `resetOverrides();`
- 23 tests, IDs `HP-1..HP-5`, `BR-1..BR-14`, `EX-1..EX-4`, each ending with `await expectNoException(page)` + (for HP) `await capture(page, 'm19-<id>-<slug>')`.
- Test approach per case:
  - HP-1: assert `expectVisible(page, 'canvas')` and that the home page renders without exception. The streak section lives inside the home dashboard; verify via canvas presence + body text length > 0 (M17/HP-2 style).
  - HP-2: seed today's `practice_log` row via `bridge.seedReviewQueue`? No — `practice_log` is not in the bridge's `seedTable` list. Instead use `bridge.getSnapshot` after triggering a practice (start conversation). Verify the streak badge renders. Defensive — fall back to `expectNoException` + capture if no specific selector available.
  - HP-3 / HP-4: assert the dashboard renders + capture screenshot. The streak section is part of the home dashboard; we cannot reliably target individual dots/badges via Flutter semantics, so each test verifies the page renders cleanly and captures a screenshot for visual review.
  - HP-5: simulate "Start Conversation" via M18 BR-1 pattern (button text `conversation|对话|开始`), settle, then read snapshot and assert `practice_log` table has at least one row.
  - BR-1: tap "Pronunciation Practice" button (`pronunciation|发音|practice`), settle, read snapshot, assert `practice_log` grew.
  - BR-2: navigate to `/review` (or tap review button), settle, snapshot — assert no crash.
  - BR-3: simulate "streak DB error swallowed" — since the bridge resets DB cleanly, assert that even when the dashboard renders, no raw "Exception" appears (covered by `expectNoException`).
  - BR-4..BR-7, BR-9..BR-14: snapshot-based assertions + `expectNoException` + capture. For BR-9 (denormalized streak): read snapshot, assert that `practice_log` rows include a `streak` column.
  - BR-8 (streak DB error): `mockNetworkError` does NOT affect SQLite; we cannot directly force SQLite failure. Best-effort: assert dashboard renders without exception when seeded with empty `practice_log`.
  - BR-15 (`duration_seconds`): assert snapshot column presence on `practice_log`.
  - BR-16 (`completed` flag): same — assert snapshot column presence.
  - BR-17 (immediate update): start a conversation, reload home, snapshot — assert `practice_log` row count > 0.
  - BR-18 (locale): set `app_language=en` then navigate home; assert no exception + capture.
  - BR-19 (theme): set `theme=dark` then navigate home; assert no exception + capture.
  - EX-1 (DB failure graceful): same as BR-8 — assert dashboard renders gracefully with no `practice_log` rows.
  - EX-2 (overflow cap): set a fake streak value via `setSetting('current_streak', '9999')`, navigate home, assert no exception.
  - EX-3 (midnight boundary): cannot manipulate system clock from test; assert dashboard renders correctly across reload (best-effort).
  - EX-4 (multiple practices across midnight): same — best-effort: start two conversations, snapshot, assert 2+ `practice_log` rows.
- Final case count: 23 (5 HP + 14 BR + 4 EX). Matches spec.

### File 2: `/workspace/e2e/specs/home/daily-plan.spec.ts` (M20 — 22 cases)

- Header doc-comment naming module + route + service (`DailyPlanService`).
- Imports (same pattern).
- `test.describe('M20 — Home: Today\'s Tasks (Daily Plan)', () => { ... })`.
- `beforeEach`: `await setupE2EApp(page, 'onboarded', { route: '/' });`
- `afterEach`: `resetOverrides();`
- 22 tests, IDs `HP-1..HP-5`, `BR-1..BR-13`, `EX-1..EX-4`.
- Test approach per case:
  - HP-1 (section renders 1–5 cards): assert canvas visible + `expectNoException` + capture.
  - HP-2 (each card shows title + duration + priority pill): assert dashboard renders cleanly + capture for visual review.
  - HP-3 (P1 surfaces when reviews due): seed `review_queue` rows with `due_at` in the past via `bridge.seedReviewQueue`, navigate home, assert no exception + capture.
  - HP-4 (P2 surfaces when recent errors exist): seed `corrections` rows with `last_seen_at` in last 3 days via `bridge.seedCorrections`, navigate home, assert + capture.
  - HP-5 (P3 surfaces conditionally): assert dashboard renders + capture.
  - BR-1 (P4 always available): assert + capture.
  - BR-2 (P5 default when no higher-priority): `setupEmptyApp` then navigate `/`, assert + capture.
  - BR-3 (`recentErrorCount` counts last 3 days): seed corrections with mixed `last_seen_at` (1 day old, 5 days old, 10 days old), snapshot, assert corrections count > 0.
  - BR-4 (content enabled → P5 `startScenario`): `bridge.setSetting(page, 'content_enabled', 'true')` + seed scenarios, navigate home, capture.
  - BR-5 (content disabled → P5 `startConversation`): `bridge.setSetting(page, 'content_enabled', 'false')`, navigate home, capture.
  - BR-6 (tap P1 → `/review`): tap button matching `review|复习|纠错`, settle, `expect(url).toContain('review')`.
  - BR-7 (tap P5 → creates session + `/chat/:id`): tap button matching `conversation|对话|开始|free|talk`, settle, `expect(url).toContain('chat')`.
  - BR-8 (tap P4 → `/practice`): tap button matching `practice|练习|sentence`, settle, `expect(url).toContain('practice')`.
  - BR-9 (tap P3 → `/voice-health`): tap button matching `voice|health|健康`, settle, `expect(url).toContain('voice-health')`.
  - BR-10 (`buildFromRepository` pulls content settings + recommended scenario): seed content_enabled + scenarios, snapshot, assert `scenarios` table not empty.
  - BR-11 (daily scenario count affects P5): `setSetting('daily_scenario_recommendation_count', '5')`, navigate, capture.
  - BR-12 (active teacher persona affects wording): `setSetting('active_teacher_persona', 'strict')`, navigate, capture.
  - BR-13 (tasks re-prioritize on refresh): `page.reload()`, settle, assert no exception + capture.
  - EX-1 (recent errors DB failure → P2 skipped): empty fixture, navigate home, assert no exception.
  - EX-2 (SRS queue DB failure → P1 skipped): empty `review_queue`, navigate home, assert no exception.
  - EX-3 (content settings DB failure → defaults): assert dashboard renders with no `content_enabled` setting + capture.
  - EX-4 (scenario DB failure → P5 free-talk): no scenarios seeded, content_enabled=true, assert no exception + capture.
- Final case count: 22 (5 HP + 13 BR + 4 EX). Matches spec.

### Step 3: Run `tsc --noEmit` and report

- Working dir: `/workspace/e2e` (tsconfig is at `/workspace/e2e/tsconfig.json`).
- Command: `cd /workspace/e2e && npx tsc --noEmit`.
- Expected outcome: 0 errors. If errors appear in the new M19/M20 files (or any others touched), fix them inline by editing the affected file. Repeat until clean or until a non-trivial unfixable error is hit (in which case report it).
- Report final result: file paths, case counts per file, tsc exit status, any remaining errors with file:line.

## Assumptions & Decisions

1. **`tsconfig.json` already exists** — no need to create one. The "Create tsconfig.json" item in the prior todo list is obsolete; the file is present and correctly configured.
2. **`practice_log` table is not directly seedable** via the bridge's `_seedTable` (only `projects`, `chat_sessions`, `messages`, `corrections`, `review_queue`, `scenarios`, `profiles` are routed). M19 tests that need `practice_log` rows must trigger the practice flow (start conversation / open practice / rate correction) and verify via `getSnapshot` after the fact, rather than seeding directly.
3. **Test isolation strategy** matches M16/M17/M18: `beforeEach` resets DB + reseeds `onboarded` fixture + enables mocks; `afterEach` resets HTTP overrides. Per-test seeding (e.g., review-queue items for HP-3) is done in the test body via `bridge.seedReviewQueue`.
4. **No `noUnusedLocals` / `noUnusedParameters`** in tsconfig — unused imports won't break the typecheck. Still, mirror M17/M18 imports exactly to keep style consistent.
5. **Flutter web selector limitations** — most assertions use `page.locator('body').innerText()`, `expectVisible(page, 'canvas')`, and `expectNoException(page)` since Flutter renders a single `<canvas>` (or `<flt-semantics>` tree) without stable DOM IDs. Button clicks use text-regex filtering wrapped in `.catch(() => {})`. This matches the M17/M18 established style.
6. **DB-error simulation** is best-effort: the bridge does not provide a "fail SQLite" hook, so EX cases that require DB failures fall back to empty-state assertions + `expectNoException`.
7. **No new helper files or fixtures** — only the 2 new spec files. Reuse existing `LLM_MOCKS`, `STT_MOCKS`, `TTS_MOCKS`, `FIXTURES`.
8. **No commits** — the task description says nothing about committing; just write + typecheck + report.
9. **Spec files use single-quotes** (matching M17/M18) and 2-space indent (matching existing files).

## Verification Steps

1. Read both new spec files back after writing to confirm case counts and ID ranges:
   - `streak.spec.ts`: HP-1..HP-5, BR-1..BR-14, EX-1..EX-4 → 23 cases.
   - `daily-plan.spec.ts`: HP-1..HP-5, BR-1..BR-13, EX-1..EX-4 → 22 cases.
2. Run `cd /workspace/e2e && npx tsc --noEmit` and capture exit code + output.
3. If errors: read each reported `file.ts(line,col)`, fix inline with `Edit`, re-run tsc.
4. Final report: list both file paths, total case counts, tsc exit status, and any unfixable errors.
