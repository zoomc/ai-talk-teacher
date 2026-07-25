# Comprehensive E2E Coverage Plan — SpeakFlow

> **Plan mode deliverable.** This document defines a decision-complete implementation plan for a comprehensive Playwright E2E suite covering every feature point of SpeakFlow with hybrid (HTTP + Flutter-bridge) mocking, ≥20 cases per feature point, screenshot + element assertions, and full doc/changelog/merge workflow.

## Summary

SpeakFlow is a Flutter web app (8 feature modules, 18 routes) with an existing but shallow Playwright suite (18 specs, 159 tests, **zero mocking, route-only assertions, single browser**). This plan rebuilds the E2E layer to:

1. Add a Flutter-side E2E bridge (compiled only with `--dart-define=E2E=true`) exposing JS hooks to reset/seed SQLite and short-circuit LLM/STT/TTS services.
2. Upgrade Playwright infra: HTTP intercepts for vendor APIs, multi-browser projects, screenshot capture, fixture data, deterministic helpers.
3. Author a temp spec doc (`docs/e2e-spec.md`) enumerating every feature point with happy-path + branch + exception cases.
4. Generate **≥500 tests across ~27 feature points** (≥20 cases each) by dispatching parallel subagents per module.
5. Run all tests, capture screenshots, review rendering quality, fix issues.
6. Update `project.md` + `CHANGELOG.md`, commit, merge to `main`, push.

## Current State Analysis

### Toolchain state (verified)
- **Flutter SDK: NOT installed** (`command not found: flutter`)
- **Dart: NOT installed** (`dart not found`)
- **Node.js v24.15.0** + **Playwright 1.62.0** (via `npx`) — available
- **`/workspace/build/web/` does NOT exist** — existing e2e tests cannot run as-is
- **`/workspace/e2e/node_modules/` does NOT exist** — `npm install` needed
- **Git state**: on `main`, up-to-date with `origin/main`, working tree clean

### Existing e2e (18 specs, 159 tests)
| Strengths | Critical gaps |
|---|---|
| All 18 routes exercised | **No mocking** — no `page.route()`, no fixtures |
| Edge-case ID testing (long/unicode/null) | Weak assertions (route + no "Exception" text) |
| Multi-viewport (320–1440px) | No real UI interactions (URL nav only) |
| i18n-aware skip detection | Chromium-only — no Firefox/WebKit |
| Crash-resistance focus | Heavy `waitForTimeout` anti-pattern |
| | No visual/screenshot verification |
| | Error swallowing via `.catch(() => {})` |
| | `remaining-coverage.spec.ts` explicitly padding to hit 150+ |

### Feature module inventory (from `/workspace/lib/features/`)
| Module | Routes | Key services/screens |
|---|---|---|
| `avatar` | (embedded) | `AvatarStage`, `Live2DLoader`, `RhubarbService`, `VisemeTimelinePlayer`, `EmotionController`, `IdleAnimation` |
| `chat` | `/chat/:id`, `/scenarios`, `/review`, `/history`, `/tutor-selection`, `/practice`, `/summary/:id`, `/progress`, `/pronunciation/:id` | `ChatRepository`, `LlmService`, `SttService`, `TtsService`, `TtsPlaybackService`, `RecordingService`, `DailyPlanService`, `LearningStatsService`, `SessionContinuityService`, `Sm2Service` |
| `home` | `/` | `HomePage`, `StreakService`, `SkillMasteryService`, `UserGoalService`, `ProgressService`, calendar/trend/weak-area widgets |
| `onboarding` | `/onboarding`, `/placement` | `OnboardingScreen` (4-step PageView), `PlacementScreen` (AI/legacy fallback) |
| `profile` | `/service-config`, `/voice-health`, `/profile-form/:type` | `ProfileRepository`, `ProviderCatalog`, `ConnectionTester`, `ProfileFormScreen`, `VoiceHealthScreen` |
| `project_space` | `/projects`, `/project/:id` | `ProjectRepository`, `ProjectsScreen`, `ProjectDetailScreen` (4-tab), `ProjectFormDialog`, `JoinProjectSheet` |
| `review` | `/review` | `Sm2Service` (SM-2 algorithm) |
| `settings` | `/settings` | `SettingsScreen` (theme/locale/low-bandwidth/providers) |

### Mocking surface
- **SQLite (web)**: `sqflite_common_ffi_web` stores in IndexedDB; reachable via `window` after Dart exposes a JS interop hook
- **HTTP services**: `LlmService` (OpenAI-compatible `/chat/completions`), `SttService` (Deepgram/Azure/Google/OpenAI), `TtsService` (Fish Audio/ElevenLabs/Azure/OpenAI) — all `http` package, interceptable via `page.route()`
- **Secure storage**: API keys via `flutter_secure_storage` (web uses `window.localStorage`-backed shim)

## Feature Points (27 total — each gets ≥20 tests = ≥540 tests)

Grouped by module; each feature point is a sub-feature that has its own screen OR distinct user-visible behavior:

### `chat` module (10 points → ≥200 tests)
1. **chat-send-message** — text input → send → LLM reply renders
2. **chat-voice-record** — mic permission, record start/stop, WAV capture
3. **chat-stt-transcription** — STT result insertion, vendor dispatch
4. **chat-llm-response** — streaming + non-streaming render, error fallback
5. **chat-tts-playback** — TTS play/pause, speed control, avatar lip-sync amplitude
6. **chat-corrections** — in-bubble correction rendering, severity, favourite toggle
7. **chat-session-summary** — `/summary/:id` highlights/improvements/nextSentence
8. **chat-scenarios** — `/scenarios` picker, scenario launch
9. **chat-history** — `/history` list, filter, archive
10. **chat-tutor-selection** — `/tutor-selection` persona pick, profile launch
11. **chat-sentence-practice** — `/practice` isolated sentence drilling

### `home` module (5 points → ≥100 tests)
12. **home-dashboard** — `/` streak bar, quick actions, daily plan
13. **home-daily-plan** — 1–5 prioritized task cards, badges
14. **home-calendar-heatmap** — 30-day grid, tap-day tooltip
15. **home-weak-area** — weak-area card with skill buckets
16. **home-weekly-trend** — weekly trend chart rendering

### `onboarding` module (2 points → ≥40 tests)
17. **onboarding-flow** — Welcome → LLM → STT → TTS step navigation
18. **onboarding-placement** — AI placement chat + legacy quiz fallback

### `profile` module (4 points → ≥80 tests)
19. **profile-form-llm** — `/profile-form/llm` create/edit, validation, save
20. **profile-form-stt-tts** — `/profile-form/stt|tts`, provider switch
21. **profile-service-config** — `/service-config` profile list, activate/delete
22. **profile-voice-health** — `/voice-health` mic diagnostics

### `project_space` module (3 points → ≥60 tests)
23. **projects-list** — `/projects` grid, empty state, FAB create
24. **project-detail** — `/project/:id` 4 tabs (Overview/Links/Activity/Settings)
25. **project-join-sheet** — `JoinProjectSheet` from summary/review/scenarios

### `review` module (1 point → ≥20 tests)
26. **review-sm2** — `/review` SM-2 card rating flow, queue progression

### `settings` module (1 point → ≥20 tests)
27. **settings-preferences** — `/settings` theme/locale/low-bandwidth toggles

### `avatar` module (1 point → ≥20 tests)
28. **avatar-stage** — idle/listening/thinking/speaking phases, low-bandwidth fallback

### Cross-cutting (additive, not counted in per-feature minimum)
- `navigation-shell.spec.ts` — tab switching, deep links, back nav
- `redirect-guard.spec.ts` — onboarding/placement gate, deep-link bypass
- `responsive.spec.ts` — 5 viewports × 5 shell pages
- `cross-browser.spec.ts` — Firefox + WebKit smoke per route

## Proposed Changes

### Phase 0 — Pre-flight (executor runs first, single sequential batch)
**Goal**: toolchain + clean main + dependencies.

1. Verify on `main`, pull latest: `git -C /workspace checkout main && git -C /workspace pull --ff-only`
2. Install Flutter SDK (Linux, no Android Studio): download `flutter_linux_<stable>.tar.xz` to `/opt/flutter`, extract, export `PATH=/opt/flutter/bin:$PATH` (also persist to `~/.bashrc` for subagents)
3. `flutter --version` sanity check; accept Android licenses (skip if not needed for web)
4. `flutter pub get` in `/workspace`
5. `cd /workspace/e2e && npm install` (installs `@playwright/test` + new deps)
6. `npx playwright install chromium firefox webkit` — download all 3 browser engines
7. Confirm `flutter doctor -v` shows Chrome available; install if missing

**Verification gate**: `flutter --version` succeeds, `ls /workspace/e2e/node_modules/@playwright` shows `test`, `npx playwright --version` prints 1.62+.

### Phase 1 — Flutter E2E bridge (gated by `--dart-define=E2E=true`)
**Goal**: expose deterministic JS hooks for SQLite reset/seed + service short-circuit.

**Files to create:**
- `lib/core/e2e/e2e_bridge.dart` — conditional-export stub (default no-op; active when `E2E=true`)
- `lib/core/e2e/e2e_bridge_web.dart` — real implementation using `dart:js_interop`:
  - `@JS('window.speakflowE2E')` namespace
  - Exposes: `resetDatabase()`, `seedFixture(String name, String json)`, `seedProjects(String json)`, `seedChatSessions(String json)`, `seedCorrections(String json)`, `seedReviewQueue(String json)`, `setMockMode(bool enabled)`, `getDatabaseSnapshot()` (returns JSON of all tables)
  - Internally calls `DatabaseHelper.database` then `db.delete(...)` / `db.insert(...)` per table
- `lib/core/e2e/e2e_bridge_stub.dart` — empty stub for non-web/non-E2E builds
- `lib/core/e2e/e2e_mock_services.dart` — when `kE2E` is true, wraps `LlmService`/`SttService`/`TtsService` to return canned responses (deterministic JSON for each scenario) instead of HTTP

**Files to modify:**
- `lib/main.dart` — after `WidgetsFlutterBinding.ensureInitialized()`, call `E2eBridge.maybeInit()` (no-op when E2E=false). When E2E=true, also call `E2eBridge.exposeHooks()` after `runApp` so JS can drive state.
- `lib/features/chat/data/llm_service.dart`, `stt_service.dart`, `tts_service.dart` — wrap top of each public method with `if (E2eMockServices.enabled) return E2eMockServices.cannedX(...);` (single-line guard; no behavior change in production).
- `lib/shared/providers.dart` — add `e2eModeProvider` (read from `const bool.fromEnvironment('E2E')`).

**Build command:**
```bash
flutter build web --release --base-href / \
  --dart-define=E2E=true \
  --web-renderer canvaskit \
  --no-tree-shake-icons
```
Output goes to `/workspace/build/web/` (which `start-server.mjs` already serves).

**Verification gate**: open `http://localhost:8080` in headless Chromium, eval `await window.speakflowE2E.resetDatabase()` — should resolve; `await window.speakflowE2E.getDatabaseSnapshot()` returns JSON with all empty tables.

### Phase 2 — Playwright infrastructure upgrade
**Goal**: multi-browser, mocking, screenshots, deterministic helpers.

**Files to create:**
- `e2e/fixtures/fixtures.ts` — exports typed fixture sets: `guestProfile`, `onboardedProfile`, `sampleProjects(5)`, `sampleChatSessions(10)`, `sampleCorrections(20)`, `sampleReviewQueue(15)`, `sampleScenarios`, `llmMockResponses` (map of prompt → canned reply), `sttMockTranscript`, `ttsMockAudioBase64`
- `e2e/fixtures/mock-data.json` — raw JSON data referenced by `fixtures.ts`
- `e2e/lib/mock.ts` — `setupHttpMocks(page)` registers `page.route()` for `**/chat/completions`, `**/v1/audio/speech`, `**/v1/audio/transcriptions`, Deepgram/Azure/Google/Fish/ElevenLabs endpoints. Routes dispatch on request body hash → return canned fixture. Also `setLlmResponse(page, prompt, reply)` for per-test override.
- `e2e/lib/e2e-bridge.ts` — typed wrapper around `page.evaluate(() => window.speakflowE2E.X(...))`. Functions: `resetDb(page)`, `seedFixture(page, name)`, `seedProjects(page, json)`, `seedChatSessions(page, json)`, `seedCorrections(page, json)`, `seedReviewQueue(page, json)`, `setMockMode(page, true)`, `getSnapshot(page)`.
- `e2e/lib/screenshots.ts` — `capture(page, name)` saves to `e2e/screenshots/<name>.png` (always capture, not just on failure). `captureFullPage(page, name)` for scrollable screens. `compareOrSkip(name)` for future visual regression (initially just snapshot).
- `e2e/lib/assertions.ts` — `expectVisible(page, selector)`, `expectText(page, text)`, `expectRoute(page, route)`, `expectNoException(page)`, `expectElementCount(page, selector, n)`.
- `e2e/lib/setup.ts` — `setupE2EApp(page, fixtureName)` orchestrates: `resetDb` → `seedFixture(fixtureName)` → `setMockMode(true)` → `setupHttpMocks` → `waitForApp` → return ready page. Replaces old `setupSeededApp`.

**Files to modify:**
- `e2e/playwright.config.ts`:
  - Add `firefox` and `webkit` projects (same viewport + launch args)
  - Add a `mobile-chrome` project (375×812, `isMobile: true`)
  - Increase `webServer.timeout` to 60000 (Flutter web boot is slow)
  - Add `screenshot: 'only-on-failure'` per project (already global)
  - Add `outputDir: 'test-results'`
- `e2e/package.json`:
  - Add `devDependencies`: `@playwright/test` (bump), `typescript` (for type-check), `prettier`
  - Add scripts: `test:fast` (chromium only, no retries), `test:all` (all browsers), `test:update-screens`
- `e2e/helpers.ts` — keep but mark `@deprecated` for `completeOnboarding`/`completePlacement` (still used by a few legacy specs until rewritten); new code uses `e2e/lib/setup.ts`.
- `e2e/start-server.mjs` — no changes needed (already serves `../build/web/`)

**Archive existing specs** (preserve history, avoid running shallow versions):
- Move all existing `*.spec.ts` to `e2e/legacy/` (git mv)
- Add `e2e/legacy/README.md` (single file) explaining they're superseded — wait, project rule says don't create docs unless requested. Just move them; the new specs replace them.

**Verification gate**: `npx playwright test --list` shows zero legacy specs and lists new specs; `npx playwright test smoke` passes a single smoke spec.

### Phase 3 — Temp spec doc
**Goal**: written record of every feature point with happy path + branches + exceptions.

**File to create:** `docs/e2e-spec.md` (this is a project artifact the user explicitly requested — "整理出现有所有式样及细节，写到一个临时文档")

Structure per feature point (27 sections):
```
## FP-<n>: <name>
**Module**: <module>
**Route(s)**: <routes>
**Services**: <services involved>
### Happy path
1. <step>
2. <step>
...
### Branches (旁支)
- <branch 1>: <behavior>
- <branch 2>: <behavior>
### Exceptions (异常)
- <exception 1>: <expected handling>
- <exception 2>: <expected handling>
### Test cases (≥20)
- [ ] TC1: <description> [happy/branch/exception]
- [ ] TC2: ...
...
```

**Dispatch**: single search subagent reads every file under `/workspace/lib/features/` + service files + repository files, produces the spec doc. Doc is reviewed by main agent before Phase 4.

**Verification gate**: file exists, has 27 `## FP-` sections, each section lists ≥20 test cases tagged happy/branch/exception.

### Phase 4 — E2E test generation (parallel subagents)
**Goal**: implement all 27 feature-point spec files with ≥20 cases each.

**Dispatch strategy** — 8 parallel `general_purpose_task` subagents (one per module, since chat has 10–11 feature points, it gets one big subagent):

| Subagent | Feature points | Output files |
|---|---|---|
| A | chat-send-message, chat-voice-record, chat-stt-transcription, chat-llm-response, chat-tts-playback | `e2e/specs/chat-messaging.spec.ts`, `e2e/specs/chat-voice.spec.ts`, `e2e/specs/chat-stt.spec.ts`, `e2e/specs/chat-llm.spec.ts`, `e2e/specs/chat-tts.spec.ts` |
| B | chat-corrections, chat-session-summary, chat-scenarios, chat-history, chat-tutor-selection, chat-sentence-practice | `e2e/specs/chat-corrections.spec.ts`, `e2e/specs/chat-summary.spec.ts`, `e2e/specs/chat-scenarios.spec.ts`, `e2e/specs/chat-history.spec.ts`, `e2e/specs/chat-tutor.spec.ts`, `e2e/specs/chat-practice.spec.ts` |
| C | home-dashboard, home-daily-plan, home-calendar-heatmap, home-weak-area, home-weekly-trend | `e2e/specs/home-dashboard.spec.ts`, `e2e/specs/home-daily-plan.spec.ts`, `e2e/specs/home-calendar.spec.ts`, `e2e/specs/home-weak-area.spec.ts`, `e2e/specs/home-trend.spec.ts` |
| D | onboarding-flow, onboarding-placement | `e2e/specs/onboarding-flow.spec.ts`, `e2e/specs/onboarding-placement.spec.ts` |
| E | profile-form-llm, profile-form-stt-tts, profile-service-config, profile-voice-health | `e2e/specs/profile-llm.spec.ts`, `e2e/specs/profile-stt-tts.spec.ts`, `e2e/specs/profile-service-config.spec.ts`, `e2e/specs/profile-voice-health.spec.ts` |
| F | projects-list, project-detail, project-join-sheet | `e2e/specs/projects-list.spec.ts`, `e2e/specs/project-detail.spec.ts`, `e2e/specs/project-join.spec.ts` |
| G | review-sm2, settings-preferences | `e2e/specs/review-sm2.spec.ts`, `e2e/specs/settings.spec.ts` |
| H | avatar-stage + cross-cutting (navigation-shell, redirect-guard, responsive, cross-browser) | `e2e/specs/avatar-stage.spec.ts`, `e2e/specs/navigation-shell.spec.ts`, `e2e/specs/redirect-guard.spec.ts`, `e2e/specs/responsive.spec.ts`, `e2e/specs/cross-browser.spec.ts` |

**Per-subagent instructions** (sent verbatim in `query`):
- Read `/workspace/docs/e2e-spec.md` for your assigned feature points
- Read `/workspace/e2e/lib/setup.ts`, `mock.ts`, `e2e-bridge.ts`, `screenshots.ts`, `assertions.ts`, `fixtures/fixtures.ts` to understand the available helpers
- Read the relevant Flutter source files under `/workspace/lib/features/<module>/` for actual UI text, widget structure, and behavior
- Each spec file MUST:
  - Use `setupE2EApp(page, '<fixtureName>')` in `beforeEach` (resets DB + seeds fixtures + enables mock mode)
  - Have ≥20 `test(...)` cases per assigned feature point (one spec file = one feature point)
  - Tag each test: `[happy]`, `[branch]`, or `[exception]` in the test title
  - Capture a screenshot at the end of each happy-path test via `capture(page, '<fp>-<tc>')`
  - Assert ≥1 visible element per test (not just route + no-exception)
  - Cover: happy path (3–5 cases), branches (8–12 cases), exceptions (5–8 cases)
  - Mock all HTTP via `setupHttpMocks(page)` (no real network calls)
  - Use `E2eBridge` to seed/inspect SQLite state
  - Run on chromium project by default; cross-browser handled by `cross-browser.spec.ts`
- Do NOT modify Flutter source code; if you find a gap, document it in `/workspace/docs/e2e-spec.md` under a `### Found gaps` subsection
- Do NOT run the tests — only write the spec files. Running happens in Phase 5.

**Verification gate per subagent**: each assigned spec file exists, has ≥20 tests, all tagged, no syntax errors (verified by `npx playwright test --list`).

### Phase 5 — Run + verify + screenshot review
**Goal**: all tests green, screenshots captured, rendering quality verified.

1. `cd /workspace/e2e && npx playwright test --project=chromium --reporter=list 2>&1 | tee test-run-1.log`
2. Parse failures; bucket by:
   - **Test bug** (selector wrong, missing await) → fix test
   - **Flutter app bug** (real defect) → file in `/workspace/docs/e2e-spec.md` `### Found defects` and either fix or skip with `test.fixme`
   - **Mock gap** (HTTP route missing) → extend `mock.ts`
3. Re-run failing subset; iterate until chromium green.
4. `npx playwright test --project=firefox --project=webkit 2>&1 | tee test-run-crossbrowser.log`
5. Review screenshots: open `e2e/screenshots/` and have a search subagent inspect 1 screenshot per feature point per viewport (mobile + desktop). Verify:
   - No blank/white screens
   - No overflow (yellow-black stripes in debug; clipped content in release)
   - Branding/colors match design-reference.md palette
   - All expected elements visible
6. For any rendering issue: file in `### Found rendering issues` and fix either the test (assertion wrong) or the Flutter source (real bug).
7. Final full run: `npx playwright test 2>&1 | tee test-final.log` — must be 100% green (skips allowed for known-defect cases).

**Verification gate**: `test-final.log` shows 0 failures (skips ≤ 5% of total, each documented in spec doc).

### Phase 6 — Final review + fixes
**Goal**: holistic review of new e2e code, fixes for any quality issues.

Dispatch 1 `general_purpose_task` subagent to:
1. Re-read all new spec files under `e2e/specs/`
2. Check for: anti-patterns (excessive `waitForTimeout`, error swallowing, weak assertions), missing tags, missing screenshots, tests < 20 per feature point
3. Check `e2e/lib/*` for: type safety, helper reusability, mock coverage completeness
4. Check Flutter bridge code (`lib/core/e2e/*`) for: no behavior change in production builds (E2E=false), no security exposure (bridge only exposed when E2E=true), proper error handling in JS hooks
5. Apply fixes directly (subagent has edit tools)
6. Re-run `npx playwright test --project=chromium` to confirm fixes don't regress

**Verification gate**: review subagent reports `OK` with no outstanding issues; final chromium run still green.

### Phase 7 — Documentation + merge + push
**Goal**: update docs, commit, merge, push.

**Files to modify:**
- `project.md` — add new section `## E2E 测试` under architecture:
  - Tooling: Playwright 1.62 + Flutter E2E bridge
  - Build command: `flutter build web --release --dart-define=E2E=true`
  - Run command: `cd e2e && npx playwright test`
  - Coverage: 27 feature points × ≥20 cases = ≥540 tests, 3 browsers
  - Mock strategy: hybrid (HTTP intercept + Flutter JS bridge for SQLite + service short-circuit)
  - Screenshot artifacts: `e2e/screenshots/`
  - Pointer to `docs/e2e-spec.md` for case inventory
- `CHANGELOG.md` — add under `[Unreleased]`:
  ```
  ### Added — E2E comprehensive coverage (2026-07-25)
  - Flutter E2E bridge (`lib/core/e2e/`) compiled only with `--dart-define=E2E=true`;
    exposes `window.speakflowE2E.{resetDatabase,seedFixture,seedProjects,...}` JS hooks
    for deterministic SQLite state; short-circuits LLM/STT/TTS services with canned
    responses.
  - Playwright infra upgrade: 3 browser projects (chromium/firefox/webkit) + mobile
    viewport; HTTP mock layer (`e2e/lib/mock.ts`) intercepting all vendor endpoints;
    screenshot capture per happy-path test.
  - 27 spec files covering 27 feature points (≥20 cases each, ≥540 tests total):
    chat (11), home (5), onboarding (2), profile (4), project_space (3), review (1),
    settings (1), avatar (1) + cross-cutting (navigation/redirect/responsive/cross-browser).
  - `docs/e2e-spec.md` — written inventory of every feature point with happy path,
    branches, exceptions, and tagged test cases.
  - Moved 18 legacy spec files to `e2e/legacy/` (superseded by new specs).

  ### Changed
  - `e2e/playwright.config.ts`: added firefox/webkit/mobile projects; bumped
    webServer timeout to 60s.
  - `lib/main.dart`: calls `E2eBridge.maybeInit()` after binding init (no-op unless
    E2E=true).
  - `lib/features/chat/data/{llm,stt,tts}_service.dart`: single-line E2E guard at
    top of each public method (no behavior change in production).

  ### Verification
  - `npx playwright test`: 540+ tests across 3 browsers, 100% green (skips ≤5%).
  - Screenshot review: 27 feature points × 2 viewports verified.
  ```

**Git workflow:**
1. `git -C /workspace checkout -b feat/comprehensive-e2e`
2. `git -C /workspace add lib/core/e2e/ lib/main.dart lib/features/chat/data/llm_service.dart lib/features/chat/data/stt_service.dart lib/features/chat/data/tts_service.dart lib/shared/providers.dart e2e/ docs/e2e-spec.md project.md CHANGELOG.md`
3. `git -C /workspace commit -m "test(e2e): comprehensive Playwright suite with hybrid mocking (≥540 tests, 3 browsers)

- Add Flutter E2E bridge (--dart-define=E2E=true) exposing JS hooks for SQLite reset/seed + service short-circuit
- Upgrade Playwright infra: 3 browser projects, HTTP mock layer, screenshot capture
- Add 27 spec files (≥20 cases each) covering all feature points
- Add docs/e2e-spec.md inventory of happy path + branches + exceptions
- Move 18 legacy specs to e2e/legacy/ (superseded)
- Update project.md + CHANGELOG.md"`
4. `git -C /workspace checkout main && git -C /workspace pull --ff-only`
5. `git -C /workspace merge --no-ff feat/comprehensive-e2e -m "Merge feat/comprehensive-e2e: comprehensive Playwright E2E suite"`
6. `git -C /workspace push origin main`

**Verification gate**: `git log -1 origin/main` shows the merge commit; `git status` clean.

## Assumptions & Decisions

### Assumptions
1. **Flutter SDK installable** in sandbox — Linux x64 tarball from `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_<ver>-stable.tar.xz`. If download blocked, fall back to `git clone https://github.com/flutter/flutter.git -b stable /opt/flutter` (slower but works).
2. **No `flutter pub get` cache** — first run downloads all deps; ~200MB.
3. **Playwright browsers installable** — `npx playwright install` downloads ~300MB across 3 engines.
4. **`--dart-define=E2E=true`** is tree-shaken away in production builds (verified by single-line `const bool.fromEnvironment` check).
5. **Existing unit tests under `/workspace/test/`** are NOT in scope — only e2e. Don't touch them.
6. **The deployed production app at `https://zoomlab.top/talk/`** is NOT used for testing — we test the local E2E build only.
7. **Git push permission** — user explicitly authorized "merge to main and push"; if push is rejected (protected branch), surface error and ask.

### Decisions
1. **Sub-feature granularity** (~27 points × 20 = ≥540 tests) — per user clarification.
2. **Hybrid mocking** (HTTP intercept + Flutter E2E bridge) — per user clarification. Requires Flutter code changes (Phase 1) + `--dart-define=E2E=true` build.
3. **Screenshot + element assertions** — per user clarification. Screenshots saved to `e2e/screenshots/`, no pixel-diff baseline (deferred).
4. **3 browsers** (chromium + firefox + webkit) — current suite only has chromium; multi-browser is industry standard and a cheap upgrade.
5. **Archive (not delete) legacy specs** — moved to `e2e/legacy/` to preserve history and allow comparison. New specs replace them.
6. **One spec file per feature point** (not per module) — finer granularity makes ≥20 enforcement obvious and test failures easier to localize.
7. **8 parallel subagents in Phase 4** — balances throughput with subagent context limits. Chat module split across 2 subagents (A+B) because it has 10+ feature points.
8. **No visual regression baselines** in v1 — pixel diff is flaky and would balloon scope. Screenshots are captured and reviewed manually in Phase 5. Baselines can be added later.
9. **`webServer.reuseExistingServer: !CI`** kept — local dev can reuse a running server; CI always starts fresh.
10. **No CI integration** in this plan — user didn't ask; focus is on local reproducibility. Can be added later.

## Verification Steps (final)

After Phase 7, the executor must confirm:

1. `cd /workspace/e2e && npx playwright test --reporter=list` — exit code 0, ≥540 tests pass, skips ≤5% (each documented).
2. `ls /workspace/e2e/screenshots/ | wc -l` — ≥54 screenshots (≥1 per feature point × 2 viewports minimum, more for happy paths).
3. `git -C /workspace log --oneline -5` — shows feat branch commits + merge to main + push.
4. `git -C /workspace status` — clean.
5. `grep -c "## FP-" /workspace/docs/e2e-spec.md` — returns 27.
6. `grep -c "^- \[ \] TC" /workspace/docs/e2e-spec.md` — returns ≥540.
7. `ls /workspace/e2e/specs/*.spec.ts | wc -l` — returns ≥27 (plus cross-cutting specs).
8. `ls /workspace/e2e/legacy/*.spec.ts | wc -l` — returns 18 (archived).
9. `grep "E2E 测试" /workspace/project.md` — finds the new section.
10. `grep "comprehensive Playwright" /workspace/CHANGELOG.md` — finds the new entry.

## File inventory (what gets created/modified)

**Created (Flutter side, 5 files):**
- `lib/core/e2e/e2e_bridge.dart`
- `lib/core/e2e/e2e_bridge_web.dart`
- `lib/core/e2e/e2e_bridge_stub.dart`
- `lib/core/e2e/e2e_mock_services.dart`
- (implicit) `lib/core/e2e/e2e_mock_services_stub.dart` if needed for non-web

**Modified (Flutter side, 5 files):**
- `lib/main.dart` — add `E2eBridge.maybeInit()` call
- `lib/features/chat/data/llm_service.dart` — add E2E guard
- `lib/features/chat/data/stt_service.dart` — add E2E guard
- `lib/features/chat/data/tts_service.dart` — add E2E guard
- `lib/shared/providers.dart` — add `e2eModeProvider`
- `lib/features/profile/data/profile_repository.dart` — possibly add `seedForE2E()` helper (only if direct DB insert is awkward from bridge)

**Created (e2e side, ~40 files):**
- `e2e/fixtures/fixtures.ts`
- `e2e/fixtures/mock-data.json`
- `e2e/lib/mock.ts`
- `e2e/lib/e2e-bridge.ts`
- `e2e/lib/screenshots.ts`
- `e2e/lib/assertions.ts`
- `e2e/lib/setup.ts`
- `e2e/specs/*.spec.ts` — 27+ spec files (one per feature point + cross-cutting)

**Modified (e2e side, 3 files):**
- `e2e/playwright.config.ts` — add projects, bump timeouts
- `e2e/package.json` — add deps + scripts
- `e2e/helpers.ts` — mark deprecated (no removal)

**Moved (e2e side, 18 files):**
- `e2e/*.spec.ts` → `e2e/legacy/*.spec.ts` (all existing specs)

**Created (docs, 1 file):**
- `docs/e2e-spec.md` — feature point inventory + test case list

**Modified (docs, 2 files):**
- `project.md` — add E2E section
- `CHANGELOG.md` — add Unreleased entry

**Total: ~50 files touched** (5 created Flutter + 6 modified Flutter + 35 created e2e + 3 modified e2e + 18 moved e2e + 1 created doc + 2 modified docs).

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Flutter SDK install fails (no network) | Medium | Fall back to `git clone https://github.com/flutter/flutter.git -b stable`; if that fails, halt and ask user |
| `flutter build web` fails (deps issue) | Low | `flutter pub get` first; if specific dep fails, pin version in `pubspec.yaml` |
| E2E bridge breaks production build | Low | `--dart-define=E2E=true` only; `const bool.fromEnvironment('E2E')` is `false` by default → entire bridge is tree-shaken away in production |
| Playwright browser download blocked | Low | `npx playwright install` has mirrors via `PLAYWRIGHT_DOWNLOAD_HOST` env var |
| Test count < 540 | Medium | Phase 4 subagents must list ≥20 per spec; Phase 6 review enforces |
| Cross-browser failures (Firefox/WebKit) | Medium | Run chromium first in Phase 5; cross-browser issues are usually font/CSS — fix in Flutter source if real bug, otherwise scope to chromium-only for that spec |
| Screenshot disk space | Low | Each PNG ~50–200KB; 540 tests × 1 screenshot = ~100MB max; acceptable |
| Subagent context overflow | Medium | 8 subagents, each handles 1–6 feature points; if overflow, split further |
| `git push` rejected (protected branch) | Low | Surface error; don't force-push; ask user to unprotect or push to a PR branch |
