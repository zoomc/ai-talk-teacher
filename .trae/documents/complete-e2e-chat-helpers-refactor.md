# E2E Chat Helpers Refactor Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or implement inline) to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize Flutter accessibility dismissal and chat-message sending in `/workspace/e2e/helpers.ts`, update all chat-related specs to use the shared helpers, and verify the refactor with TypeScript + a Playwright smoke test.

**Architecture:** Move the inline `enableAccessibility` and `sendChatMessage` helpers from `specs/avatar/emotion.spec.ts` into `helpers.ts` as shared exports. Replace every inline chat-input sequence (find textbox → type → press Enter → click send) across chat specs with `sendChatMessage(page, text)`. Ensure each chat spec calls `enableAccessibility(page)` before interacting with the chat surface. Leave non-chat text inputs (profile forms, onboarding, projects, etc.) untouched.

**Tech Stack:** Playwright (TypeScript), Flutter web (hash routing), custom E2E bridge (`lib/e2e-bridge.ts`).

---

## Current State Analysis

Based on Phase 1 exploration of the workspace:

- `/workspace/e2e/helpers.ts` already exports `enableAccessibility(page)` and `sendChatMessage(page, text)`.
- `sendChatMessage` currently:
  - calls `enableAccessibility`,
  - switches from voice to text mode if no `textbox` is found,
  - uses `input.fill(text)` for fast input,
  - presses `Enter` and clicks the first send button,
  - finishes with `settle(page, 2500)`.
- `/workspace/e2e/specs/avatar/emotion.spec.ts` and `/workspace/e2e/specs/avatar/lip-sync.spec.ts` already import and use `sendChatMessage` and no longer define local `sendAndWait` helpers.
- The chat specs (`text-messaging`, `session-management`, `continuous-mode`, `corrections`, `error-states`, `tts-playback`) already import and call `sendChatMessage`.
- `text-messaging.spec.ts` already calls `enableAccessibility(page)` in its `beforeEach`.
- Several other chat specs do **not** explicitly call `enableAccessibility` in `beforeEach`; they rely on `sendChatMessage` calling it internally, which is fine for tests that only send messages, but any test that inspects the input bar before sending may still fail if the accessibility placeholder blocks interaction.
- `tutor-summary.spec.ts` and `voice-input.spec.ts` are chat-adjacent but do not type into the chat input bar, so they should not use `sendChatMessage`.

Remaining risk areas:
1. Long-text test in `text-messaging.spec.ts` (`BR-10`) must use `input.fill` rather than `keyboard.type` to avoid the 90 s timeout.
2. Specs that assert on the input bar before any message is sent need `enableAccessibility` in `beforeEach`.
3. Non-chat text inputs (e.g., rename dialogs in `session-management.spec.ts`) must remain unchanged.
4. Pre-existing TypeScript errors in non-chat specs (`progress/dashboard.spec.ts`, `progress/pronunciation-history.spec.ts`, `review/sm2-review.spec.ts`) should be ignored.
5. Smoke test may hit a port conflict on `8080` if a previous server is still running.

---

## Task 1: Verify Shared Helpers in `helpers.ts`

**Files:**
- Read: `/workspace/e2e/helpers.ts`
- Modify (if needed): `/workspace/e2e/helpers.ts`

- [ ] **Step 1: Confirm exports exist and signatures are correct**

```typescript
import { Page } from '@playwright/test';

export async function enableAccessibility(page: Page): Promise<void> { ... }

export async function sendChatMessage(page: Page, text: string): Promise<void> { ... }
```

Expected: both functions are exported and `sendChatMessage` uses `settle` from the same file.

- [ ] **Step 2: Ensure `sendChatMessage` uses `input.fill(text)`**

The implementation should contain:

```typescript
const input = textbox.first();
await input.click({ timeout: 5000 }).catch(() => {});
await input.fill(text);
await page.keyboard.press('Enter');
await page.getByRole('button', { name: /send|发送/i }).first().click({ timeout: 1500 }).catch(() => {});
await settle(page, 2500);
```

If it still uses `page.keyboard.type(text)`, replace it with `input.fill(text)`.

- [ ] **Step 3: Run TypeScript check on helpers file only**

Run: `cd /workspace/e2e && npx tsc --noEmit helpers.ts`
Expected: no errors.

---

## Task 2: Verify Avatar Specs Use Shared Helpers

**Files:**
- Read: `/workspace/e2e/specs/avatar/emotion.spec.ts`
- Read: `/workspace/e2e/specs/avatar/lip-sync.spec.ts`
- Modify (if needed): the files above

- [ ] **Step 1: Confirm imports**

Both files should contain:

```typescript
import { settle, sendChatMessage } from '../../helpers';
```

`emotion.spec.ts` should also import `enableAccessibility` if it calls it directly (currently it does):

```typescript
import { settle, enableAccessibility, sendChatMessage } from '../../helpers';
```

- [ ] **Step 2: Confirm no local `sendAndWait` helper remains**

Search for:

```typescript
async function sendAndWait
```

Expected: no matches in either file.

- [ ] **Step 3: Replace any remaining local calls with `sendChatMessage(page, text)`**

Expected: all message sends go through `sendChatMessage`.

---

## Task 3: Audit Chat Specs for `sendChatMessage` and `enableAccessibility`

**Files:**
- Read/Modify:
  - `/workspace/e2e/specs/chat/text-messaging.spec.ts`
  - `/workspace/e2e/specs/chat/session-management.spec.ts`
  - `/workspace/e2e/specs/chat/continuous-mode.spec.ts`
  - `/workspace/e2e/specs/chat/corrections.spec.ts`
  - `/workspace/e2e/specs/chat/error-states.spec.ts`
  - `/workspace/e2e/specs/chat/tts-playback.spec.ts`

- [ ] **Step 1: Confirm every chat-message send uses `sendChatMessage(page, text)`**

Search each file for patterns that should be replaced:

```typescript
page.getByRole('textbox').first().fill(...)
page.keyboard.type(...)
page.keyboard.press('Enter')
page.getByRole('button', { name: /send/i }).click()
```

Only refactor sequences that are clearly sending a chat message. Leave profile-form inputs, rename dialogs, onboarding fields, etc. untouched.

- [ ] **Step 2: Add `enableAccessibility(page)` to `beforeEach` where needed**

Add it to the `beforeEach` of any spec whose tests inspect or interact with the chat input bar before the first `sendChatMessage` call. At minimum, update:

- `text-messaging.spec.ts` (already present — verify)
- `session-management.spec.ts`
- `continuous-mode.spec.ts`
- `corrections.spec.ts`
- `error-states.spec.ts`
- `tts-playback.spec.ts`

Example addition:

```typescript
test.beforeEach(async ({ page }) => {
  await setupE2EApp(page, 'onboarded', { route: CHAT_ROUTE });
  await bridge.setMockTtsAudio(page, TTS_MOCKS.silent);
  await enableAccessibility(page);
});
```

- [ ] **Step 3: Leave `voice-input.spec.ts` and `tutor-summary.spec.ts` unchanged**

`voice-input.spec.ts` exercises the mic, not the text input.
` tutor-summary.spec.ts` tests tutor selection and summary screens, not chat message sending.

---

## Task 4: Run Project-Wide TypeScript Check

**Files:**
- `/workspace/e2e/tsconfig.json`

- [ ] **Step 1: Run the TypeScript compiler**

Run: `cd /workspace/e2e && npx tsc --noEmit`

Expected:
- No errors in `helpers.ts` or any chat/avatar spec.
- Pre-existing errors in `specs/progress/dashboard.spec.ts`, `specs/progress/pronunciation-history.spec.ts`, and `specs/review/sm2-review.spec.ts` are out of scope and can be ignored.

- [ ] **Step 2: If new errors appear in touched files, fix them**

Common fixes:
- Missing import of `enableAccessibility` or `sendChatMessage`.
- Duplicate identifier if a local helper was not fully removed.
- Incorrect `Page` import (must come from `@playwright/test`).

---

## Task 5: Resolve Port Conflicts and Run Smoke Test

**Files:**
- `/workspace/e2e/playwright.config.ts`
- `/workspace/e2e/start-server.mjs`

- [ ] **Step 1: Ensure `reuseExistingServer` is configured for non-CI runs**

`playwright.config.ts` line 87 should read:

```typescript
reuseExistingServer: !process.env.CI,
```

If it is `false` unconditionally, change it to the expression above.

- [ ] **Step 2: Free port 8080 if needed**

Run: `fuser -k 8080/tcp 2>/dev/null || true`
This is a best-effort cleanup before the test run.

- [ ] **Step 3: Run the requested smoke test**

Run:

```bash
cd /workspace/e2e && npx playwright test specs/avatar/emotion.spec.ts specs/chat/text-messaging.spec.ts --project=chromium --reporter=list
```

Expected: all tests in both files pass (emotion has 23 tests; text-messaging has ~27 tests).

---

## Task 6: Investigate and Fix Smoke-Test Failures

**Files:**
- `/workspace/e2e/test-results/**/error-context.md`
- Any failing spec from Task 5

- [ ] **Step 1: Read `error-context.md` for each failed test**

Path pattern:

```
/workspace/e2e/test-results/specs-<suite>-<test-name>-chromium/error-context.md
```

- [ ] **Step 2: Classify the failure**

Common root causes and fixes:

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| `expect(locator).toBeVisible() failed` for text input | Accessibility placeholder still blocking; voice mode default | Add/ensure `enableAccessibility(page)` in `beforeEach`; ensure `sendChatMessage` switches to text mode. |
| `keyboard.type: Test timeout of 90000ms exceeded` | Long text typed character-by-character | Use `input.fill(text)` in `sendChatMessage`. |
| `http://localhost:8080 is already used` | Old test server still bound | Kill process on port 8080; verify `reuseExistingServer: !process.env.CI`. |
| Send button not found | Input still in voice mode | Confirm `sendChatMessage` clicks the "switch to text input" button when no textbox exists. |
| AI reply not visible | Mock not wired before send | Ensure `bridge.setMockLlmResponse(page, key, reply)` is called before `sendChatMessage`. |

- [ ] **Step 3: Apply the minimal fix and re-run the smoke test**

Repeat Task 5 until both specs pass.

---

## Task 7: Final Verification and Report

- [ ] **Step 1: Run TypeScript check one final time**

Run: `cd /workspace/e2e && npx tsc --noEmit`
Expected: no new errors in touched files.

- [ ] **Step 2: Capture the final smoke-test output**

Run the smoke test again and save/quote the final line count (e.g., `23 passed, 27 passed`).

- [ ] **Step 3: Report changed files and result**

Final report should list:
- `/workspace/e2e/helpers.ts`
- `/workspace/e2e/specs/avatar/emotion.spec.ts`
- `/workspace/e2e/specs/avatar/lip-sync.spec.ts`
- Any chat spec modified in Task 3.
- Final smoke-test command and pass/fail summary.

---

## Assumptions & Decisions

1. **Only chat message sends are refactored.** Non-chat text inputs (profile CRUD, onboarding, placement, project forms, session rename dialogs) are intentionally left unchanged.
2. **`enableAccessibility` may be called redundantly.** It is safe to call both in `beforeEach` and inside `sendChatMessage` because the helper is a no-op when the placeholder is absent.
3. **`input.fill` is preferred over `keyboard.type`.** This keeps the long-text test under the 90 s timeout.
4. **Voice-first specs stay voice-first.** `voice-input.spec.ts` exercises the microphone and should not be converted to `sendChatMessage`.
5. **Pre-existing TypeScript errors outside the chat/avatar scope are ignored.** They are unrelated to this refactor.
6. **No production code changes.** The task is limited to the `/workspace/e2e` test suite unless a runtime bug is uncovered that blocks every test.
