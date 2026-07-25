# Plan: Synchronize SpeakFlow E2E bridge/fixtures with real DB schema

## Summary

The SpeakFlow Flutter app’s real SQLite schema lives in `lib/core/database/database_helper.dart` (version 10). The E2E bridge (`lib/core/e2e/e2e_bridge_web.dart`) and TypeScript fixtures (`e2e/fixtures/*`) have already been aligned with the schema in earlier work. The remaining drift is in individual spec files that still use stale inline type literals and seed data:

- Snapshot table key `messages` → real table is `chat_messages`
- Snapshot table key `settings` → real table is `user_settings`
- `chat_sessions` rows still containing `tutor_id` / `archived_at`
- `corrections` rows still containing `severity` and/or `updated_at`
- `review_queue` rows still containing `last_reviewed_at` instead of `created_at`

This plan scopes the remaining edits, rebuilds the E2E web app, and verifies the avatar-emotion subset passes.

## Current state analysis

Real schema highlights (from `lib/core/database/database_helper.dart`):

| Table | Relevant columns / notes |
|-------|--------------------------|
| `chat_sessions` | `id`, `topic`, `scenario_id`, `status`, `level_tag`, `created_at`, `updated_at`, `is_guest`. **No `tutor_id`, no `archived_at`**. |
| `chat_messages` | `id`, `session_id`, `role`, `content`, `audio_path`, `created_at`. |
| `corrections` | `id`, `session_id`, `message_id`, `original`, `corrected`, `type`, `explanation`, `skill`, `review_count`, `easiness_factor`, `interval_days`, `next_review_at`, `occurrence_count`, `last_seen_at`, `importance`, `is_favorite`, `favorite_at`, `created_at`. **No `severity`, no `updated_at`**. |
| `review_queue` | `id`, `correction_id`, `due_at`, `interval_days`, `repetitions`, `ease_factor`, `created_at`. **No `last_reviewed_at`**. |
| `user_settings` | `key` PK, `value`. |

The bridge already uses these exact table names (`_allTables`, `_seedTable`, `_setSetting`, `_completeOnboarding`). The fixture interfaces in `e2e/fixtures/fixtures.ts` and the JSON in `e2e/fixtures/mock-data.json` also match.

What is still out of sync:

1. **`e2e/specs/*/...` snapshot keys** use `messages` and `settings` instead of `chat_messages` / `user_settings`.
2. **Inline `DbSnapshot` correction/session types** still declare `severity`, `updated_at`, `tutor_id`, `archived_at`, `last_reviewed_at`.
3. **Hard-coded seed rows** in specs include those dropped columns, which causes both TypeScript errors and SQLite insert failures at runtime.
4. **TypeScript errors confirmed** by `npx tsc --noEmit`:
   - `specs/progress/dashboard.spec.ts(42,7): 'severity' does not exist in type 'CorrectionRow'`
   - `specs/progress/pronunciation-history.spec.ts(156,9): 'severity' does not exist in type 'CorrectionRow'`
   - `specs/review/sm2-review.spec.ts(50,5): 'severity' does not exist in type 'CorrectionRow'`
   - `specs/review/sm2-review.spec.ts(72,5): 'last_reviewed_at' does not exist in type 'ReviewQueueRow'`

The runtime failures are the bigger risk: `bridge.seedCorrections` with a `severity` or `updated_at` field will make SQLite throw, and `snap.messages` / `snap.settings` will always be `undefined` because the bridge returns `chat_messages` / `user_settings`.

## Proposed changes

### 1. Bridge / fixtures comments (no functional change)

- `e2e/fixtures/fixtures.ts`
  - Update header comment list: `messages` → `chat_messages`, `settings` → `user_settings`.
  - Update `FixtureBundle.settings` comment to "`user_settings` table key/value pairs".
- `e2e/lib/e2e-bridge.ts`
  - Update JSDoc for `setSetting` from "`settings` table" to "`user_settings` table".

### 2. `e2e/specs/system/banners-version.spec.ts`

- In `BR-12` seed session, delete `tutor_id: null` and `archived_at: null`.
- Rename `DbSnapshot.settings` → `user_settings`.
- Update `snap.settings` accesses at lines ~218 and ~394 to `snap.user_settings`.

### 3. `e2e/specs/chat/continuous-mode.spec.ts`

- Rename `DbSnapshot.messages` → `chat_messages`.
- Update `snap.messages` accesses at lines ~131, ~272, ~324 to `snap.chat_messages`.

### 4. `e2e/specs/chat/corrections.spec.ts`

- Rename `DbSnapshot.messages` → `chat_messages`.
- Remove `severity: string` from the inline correction snapshot type.
- Fix the two direct `bridge.seedCorrections` rows:
  - `BR-12` (around line 211) and `EX-25` (around line 382).
  - Remove `severity` and `updated_at`.
  - Add `favorite_at: null` and `message_id: null` so the rows match `CorrectionRow`.
- Keep `severity` inside `replyWithCorrections` LLM JSON strings; those are parsed by the app and do not go directly into SQLite.

### 5. `e2e/specs/chat/voice-input.spec.ts`

- Rename `DbSnapshot.messages` → `chat_messages`.
- Update `snap.messages` accesses at lines ~108 and ~209 to `snap.chat_messages`.

### 6. `e2e/specs/chat/error-states.spec.ts`

- Rename `DbSnapshot.messages` → `chat_messages`.
- Update `snap.messages` accesses at lines ~246 and ~389 to `snap.chat_messages`.

### 7. `e2e/specs/home/streak.spec.ts`

- Rename `StreakSnapshot.settings` → `user_settings`.
- Fix `BR-2` seeded correction (around line 173): remove `severity` and `updated_at`; add `favorite_at: null` and `message_id: null`.

### 8. `e2e/specs/home/ability-goals.spec.ts`

- Remove the local `CorrectionRow` interface and import `CorrectionRow` from `../../fixtures/fixtures`.
- Update `MIXED_CORRECTIONS`:
  - Remove `severity` and `updated_at` from both rows.
  - Add `favorite_at: null` and `message_id: null`.

### 9. `e2e/specs/review/sm2-review.spec.ts`

- In `dueCorrection`:
  - Remove `severity` from the correction object.
  - Remove `updated_at` from the correction object.
  - Add `favorite_at: null` and `message_id: null`.
  - In the queue object, replace `last_reviewed_at: null` with `created_at: PAST_DUE`.

### 10. `e2e/specs/progress/dashboard.spec.ts`

- Update `buildCorrections`:
  - Remove `severity` property and the ternary that sets it.
  - Remove `updated_at`.
  - Add `message_id: null` and `favorite_at: null`.

### 11. `e2e/specs/progress/pronunciation-history.spec.ts`

- Fix `pronunciationCorrections` row (around line 148): remove `severity` and `updated_at`; add `favorite_at: null`.
- Rename `Snapshot.settings` → `user_settings` for consistency.

### 12. `e2e/specs/settings/app-section.spec.ts`

- Rename `DbSnapshot.settings` → `user_settings`.
- Update all `snap.settings` accesses (lines ~115, ~126, ~147, ~296, ~306, ~394) to `snap.user_settings`.

### 13. `e2e/specs/settings/theme-language.spec.ts`

- Update `snapshot.settings` accesses at lines ~194 and ~206 to `snapshot.user_settings`.

### 14. `e2e/specs/onboarding/onboarding.spec.ts`

- Rename `DbSnapshot.settings` → `user_settings`.
- Update `snap.settings` accesses at lines ~266 and ~301 to `snap.user_settings`.

### 15. `e2e/specs/onboarding/placement.spec.ts`

- Rename `DbSnapshot.settings` → `user_settings`.
- Update `snap.settings` access at line ~213 to `snap.user_settings`.

### 16. `e2e/specs/projects/projects.spec.ts`

- Rename `DbSnapshot.settings` → `user_settings`.

### Files that are already correct and need no changes

- `lib/core/database/database_helper.dart` (explicitly out of scope)
- `lib/core/e2e/e2e_bridge_web.dart`
- `e2e/fixtures/fixtures.ts` (row types)
- `e2e/fixtures/mock-data.json`
- `e2e/specs/avatar/emotion.spec.ts`
- `e2e/specs/chat/text-messaging.spec.ts`
- `e2e/specs/chat/session-management.spec.ts`
- `e2e/specs/chat/tutor-summary.spec.ts`
- `e2e/specs/scenarios/scenarios.spec.ts`
- `e2e/specs/home/daily-plan.spec.ts`

## Assumptions & decisions

1. **Do not rename the fixture bundle property `messages`/`settings`.** `FixtureBundle.messages` and `FixtureBundle.settings` are internal test-bundle keys, not DB column/table names. The bridge already maps `messages` → `chat_messages` and writes settings to `user_settings`, so renaming them would require touching `setup.ts`, `mock-data.json`, and every fixture consumer without improving schema alignment.
2. **Keep `severity` inside LLM reply JSON strings.** Those strings are parsed by the app; they are not inserted into SQLite. Removing them is unnecessary and would weaken the severity-badge tests.
3. **Do not add bridge aliases for `messages`/`settings`.** The source of truth is the real table names; specs should read `chat_messages` and `user_settings`.
4. **No schema changes in `database_helper.dart`.** Per the task constraints, only E2E artifacts change.
5. **Build flag:** the E2E web build must use `--dart-define=E2E=true` so `window.speakflowE2E` is exposed.

## Verification steps

1. **Type-check the E2E harness** (catches remaining column mismatches before runtime):
   ```bash
   cd /workspace/e2e && npx tsc --noEmit
   ```
   Expected: zero errors.

2. **Rebuild the Flutter web E2E build**:
   ```bash
   export PATH="/opt/flutter/bin:$PATH"
   cd /workspace
   flutter build web --dart-define=E2E=true --no-wasm-dry-run
   ```
   Expected: build succeeds.

3. **Run the avatar emotion subset**:
   ```bash
   cd /workspace/e2e
   npx playwright test specs/avatar/emotion.spec.ts --project=chromium --reporter=list
   ```
   Expected: all tests in `emotion.spec.ts` pass. If any fail, inspect:
   - `e2e/test-results/error-context.md`
   - Playwright trace / screenshot artifacts under `e2e/test-results/`
   - Browser console logs for SQLite or bridge errors.

4. **Optional smoke run** (after the subset passes, to confirm the broader spec fixes did not break):
   ```bash
   npx playwright test specs/chat/text-messaging.spec.ts specs/chat/session-management.spec.ts specs/scenarios/scenarios.spec.ts specs/home/daily-plan.spec.ts --project=chromium --reporter=list
   ```

## Deliverable

A concise final report listing:
- Every file modified under `e2e/` and `lib/core/e2e/` (if any bridge tweak is needed).
- The result of `npx tsc --noEmit`.
- The result of `flutter build web ...`.
- The pass/fail count for `specs/avatar/emotion.spec.ts`.
- Any blockers encountered and what remains unresolved.
