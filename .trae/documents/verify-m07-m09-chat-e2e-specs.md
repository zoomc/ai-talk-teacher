# Plan: Verify & Finalize M07–M09 Chat E2E Spec Files

## Summary

The user requested 3 Playwright E2E spec files for the SpeakFlow Flutter web app
(M07 Continuous Mode & Barge-in, M08 Session Management, M09 Error States & Recovery).
**Exploration confirms all 3 files already exist on disk** with the required test
counts and structure. The remaining work is verification: run TypeScript compilation
and fix any errors that originate in the 3 new files.

## Current State Analysis (from Phase 1 exploration)

All 3 target files exist and were inspected line-by-line:

| File | HP | BR | EX | Total | Required | Status |
|------|----|----|----|----|----------|--------|
| `/workspace/e2e/specs/chat/continuous-mode.spec.ts` | 5 | 14 | 4 | 23 | ≥23 (5/14/4) | ✅ Meets |
| `/workspace/e2e/specs/chat/session-management.spec.ts` | 7 | 12 | 6 | 25 | ≥24 (7/12/5) | ✅ Meets (6 EX vs 5 min) |
| `/workspace/e2e/specs/chat/error-states.spec.ts` | 6 | 13 | 6 | 25 | ≥25 (6/13/6) | ✅ Meets |

The M08 file implements 6 EX cases (EX-20…EX-25) which covers all spec'd cases in
`docs/e2e-spec.md` lines 426-432; the summary table on line 1334 says "5 EX" but the
detailed list has 6. Implementing all 6 is correct and exceeds the ≥24 minimum.

### Requirements verified against each file
- ✅ ≥20 test cases per file (all have 23–25)
- ✅ Mix of HP/BR/EX per `docs/e2e-spec.md` M07/M08/M09 sections
- ✅ Uses established helper library imports (identical import block to
  `onboarding.spec.ts` / `text-messaging.spec.ts`)
- ✅ Mocks all data via E2E bridge (`bridge.setMockTtsAudio`, `bridge.setMockSttResult`,
  `bridge.setMockLlmResponse`, `bridge.seedChatSessions`, `bridge.seedMessages`,
  `bridge.setMockMode`, `bridge.getSnapshot`, etc.) + Playwright HTTP intercepts
  (`mockNetworkError`, `mockNetworkTimeout`, `page.route`) for defense in depth
- ✅ `expectNoException(page)` asserted in every test case (verified in all 73 tests)
- ✅ `capture(page, ...)` called at the end of every happy-path test
  (HP-1…HP-5 in M07, HP-1…HP-7 in M08, HP-1…HP-6 in M09)

### Helper function availability confirmed
All imported helpers exist in their respective modules:
- `lib/setup.ts`: `setupE2EApp`, `setupEmptyApp`, `navigate`, `DESKTOP_VIEWPORT`, `MOBILE_VIEWPORT`
  (same imports as `specs/onboarding/onboarding.spec.ts` which compiles cleanly)
- `lib/screenshots.ts`: `capture`, `captureFullPage` ✅
- `lib/assertions.ts`: `expectVisible`, `expectText`, `expectNotVisible`, `expectRoute`,
  `expectNoException`, `expectElementCount`, `expectMinCount` ✅
- `lib/e2e-bridge.ts`: `resetDb`, `seedChatSessions`, `seedMessages`, `setMockMode`,
  `setMockLlmResponse`, `setMockSttResult`, `setMockTtsAudio`, `getSnapshot`,
  `setSetting`, `completeOnboarding` ✅
- `lib/mock.ts`: `setLlmResponse`, `setSttTranscript`, `setTtsAudio`, `mockNetworkError`,
  `mockNetworkTimeout`, `resetOverrides` ✅
- `fixtures/fixtures.ts`: `FIXTURES`, `LLM_MOCKS`, `STT_MOCKS`, `TTS_MOCKS` ✅
  - `LLM_MOCKS.greeting`, `LLM_MOCKS.long`, `STT_MOCKS.short`, `STT_MOCKS.empty`,
    `STT_MOCKS.withError`, `TTS_MOCKS.silent` all defined ✅
  - `FIXTURES['with-chat-history']` with `.chatSessions` array used in M08 BR-11 ✅

### File-local helpers (defined inline, no external deps)
- M07: `grantMic`, `pressAndHoldMic`, `toggleContinuousChip`, `sendText`
- M08: `seedSession`, `sendText`, `openSessionOptions`, `clickText`, `ACTIVE_SESSION` constant
- M09: `grantMic`, `sendText`, `pressAndHoldMic`, `llmJson`

These use `import('@playwright/test').BrowserContext` / `Page` type-only imports
which are erased at compile time — no runtime cost, no missing types.

## Proposed Changes

### Step 1 — Verify TypeScript compilation (READ-ONLY check)
Run `cd /workspace/e2e && npx tsc --noEmit` to type-check the whole suite.

### Step 2 — Triage any reported errors
- **Errors in the 3 new files** (`continuous-mode.spec.ts`, `session-management.spec.ts`,
  `error-states.spec.ts`): fix immediately by editing only the offending lines.
  Expected categories to watch for:
  - Unused imports (e.g., `setupEmptyApp`, `DESKTOP_VIEWPORT`, `MOBILE_VIEWPORT`,
    `expectVisible`, `expectText`, `expectNotVisible`, `expectElementCount`,
    `expectMinCount`, `setLlmResponse`, `setSttTranscript`, `setTtsAudio`,
    `mockNetworkTimeout`, `FIXTURES`) — the import block mirrors the established
    pattern, so unused-import errors would also appear in sibling specs; if `tsc`
    flags them only in the new files, remove the unused names.
  - Type mismatches on `bridge.getSnapshot<DbSnapshot>()` return shape.
- **Pre-existing errors in other files** (e.g., `lib/mock.ts`, `specs/avatar/idle.spec.ts`
  per the prior session's notes): leave untouched — out of scope. Confirm they are
  unrelated by checking they do not involve the 3 target files.

### Step 3 — Re-run `tsc --noEmit` until the 3 new files are clean
Only the 3 target files must compile cleanly. If pre-existing errors in unrelated
files persist, document them but do not fix.

### Step 4 — Report
Report: which files were verified/edited, the final per-file test counts
(M07: 5/14/4=23, M08: 7/12/6=25, M09: 6/13/6=25), and the `tsc` outcome for the
3 new files.

## Assumptions & Decisions
- **Decision**: Do NOT regenerate the 3 files from scratch — they already meet every
  functional requirement (test counts, helper usage, screenshots, expectNoException).
  Regenerating would risk regressions. Only fix compile errors if `tsc` reports any
  in these files.
- **Decision**: The 6 EX cases in M08 (vs. the summary table's "5 EX") are kept —
  they match the detailed case list in `docs/e2e-spec.md` and exceed the ≥24 minimum.
- **Decision**: Pre-existing errors outside the 3 target files are out of scope and
  will not be touched.
- **Assumption**: `npm install` has already been run in `/workspace/e2e` (per prior
  session). If `npx tsc` fails with "tsc not found", run `npm install` first.

## Verification steps
1. `cd /workspace/e2e && npx tsc --noEmit 2>&1 | grep -E 'specs/chat/(continuous-mode|session-management|error-states)'`
   — should return **no lines** (the 3 new files compile cleanly).
2. If step 1 returns lines, edit the offending file(s) and re-run `npx tsc --noEmit`.
3. Final report includes the per-file test counts and confirms the 3 files are clean.
