# Plan: Fix JSDoc comment issue in `e2e/lib/mock.ts`

## Summary

Fix a single-line JSDoc defect in `/workspace/e2e/lib/mock.ts` where a glob
pattern containing `*/` prematurely terminates the file's top-of-file JSDoc
block, causing the TypeScript parser to treat the remainder of the comment
(lines 10–21) as code. This produces cascading syntax/type errors in `mock.ts`
and every file that imports from it (14 importers, including `lib/setup.ts`
which is transitively used by nearly every spec). The fix is a one-line edit.

## Current State Analysis

### The defect

`/workspace/e2e/lib/mock.ts` lines 1–21 form a JSDoc block comment. Line 10
contains the substring `**/v1/chat/completions`:

```ts
/**
 * HTTP mock layer for E2E tests.
 * ...
 * Vendor endpoints covered:
 *   - OpenAI-compatible: POST **/v1/chat/completions, /v1/audio/speech,   // ← line 10
 *                       /v1/audio/transcriptions
 *   - Deepgram: POST wss://api.deepgram.com/** (WS — not intercepted
 *              here; rely on Dart-side mock)
 *   - Azure STT/TTS: POST **.cognitiveservices.azure.com/**
 *   - Google STT: POST **.googleapis.com/speech/**
 *   - Fish Audio TTS: POST api.fish.audio/**
 *   - ElevenLabs TTS: POST api.elevenlabs.io/**
 *
 * Per-test overrides: `setLlmResponse(page, promptSubstring, reply)` lets
 * a test inject a specific LLM response keyed on a substring of the prompt.
 */
```

The lexer scans block comments for the **first** `*/` sequence to end them.
In `**/v1` the second `*` followed by `/` forms `*/`, so the JSDoc block is
closed mid-line 10. Everything after — `v1/chat/completions, /v1/audio/speech,`
through line 21 — is then parsed as JavaScript source, which is invalid syntax.
This is the root cause of the `tsc --noEmit` failures attributed to `mock.ts`.

### Verification that only line 10 is affected

A grep for `\*/` across `mock.ts` returns 26 matches. Categorising them:

| Location | Match type | Safe? |
|---|---|---|
| Line 10 (`**/v1/...` inside JSDoc body) | `*/` mid-comment | ❌ terminates comment |
| Lines 21, 77, 104 | `*/` closing a multi-line JSDoc | ✅ legitimate close |
| Lines 24, 43, 56, 61, 65, 68, 71, 82, 87, 92, 241, 250, 261, 276 | `*/` closing single-line `/** ... */` | ✅ legitimate close |
| Lines 107, 143, 161, 171, 191, 201, 211, 221 | `*/` inside string literals (e.g. `'**/v1/chat/completions*'`) | ✅ string content, not a comment |

So **only line 10** needs to change. The `page.route('**/...')` string
literals are safe and must NOT be touched (they are Playwright glob patterns
that actually drive route matching at runtime).

### Blast radius

14 spec/lib files import from `lib/mock.ts`:

- `lib/setup.ts` (transitively imported by essentially every spec)
- `specs/onboarding/onboarding.spec.ts`, `specs/onboarding/placement.spec.ts`
- `specs/chat/text-messaging.spec.ts`, `specs/chat/voice-input.spec.ts`,
  `specs/chat/corrections.spec.ts`, `specs/chat/tts-playback.spec.ts`
- `specs/home/dashboard.spec.ts`, `specs/home/ability-goals.spec.ts`
- `specs/profile/voice-health.spec.ts`, `specs/profile/service-config.spec.ts`
- `specs/progress/pronunciation-history.spec.ts`
- `specs/avatar/emotion.spec.ts`
- `specs/settings/theme-language.spec.ts`

Because the defect is a syntax error in `mock.ts` itself, `tsc` reports
cascading errors in all of these importers (including the "318 errors in
tts-playback.spec.ts" noted in the prior session). The vast majority of those
errors are expected to vanish once `mock.ts` parses cleanly. Any errors that
remain in `tts-playback.spec.ts` after the fix are genuine issues in that file
and are **out of scope** for this task (owned by another agent).

## Proposed Changes

### File: `/workspace/e2e/lib/mock.ts`

**Single edit on line 10.** Replace the glob-style prefix `**` with the bare
URL path so the substring `*/` no longer appears inside the JSDoc body.

Before (line 10):
```
 *   - OpenAI-compatible: POST **/v1/chat/completions, /v1/audio/speech,
```

After (line 10):
```
 *   - OpenAI-compatible: POST /v1/chat/completions, /v1/audio/speech,
```

**Why this approach (vs. alternatives):**

| Option | Verdict |
|---|---|
| Remove leading `**` → `/v1/chat/completions` (chosen) | Clean, preserves endpoint path info, no `*/`. ✅ |
| Backslash-escape → `**\/v1/chat/completions` | Backslash is literal in comments; renders as `**\/` in IDE hover. Ugly. ❌ |
| Insert space → `** /v1/...` | Misleading glob-like notation that isn't a real glob. ❌ |
| Rewrite the whole comment block | Out of scope ("nothing more, nothing less"). ❌ |

The `**` prefix is only meaningful as a Playwright minimatch glob inside the
`page.route(...)` string literals (lines 107+); in the JSDoc it is purely
decorative documentation, so dropping it changes no behaviour.

**No other lines in the file are modified.** In particular:
- The other `**` occurrences on lines 12, 14, 15, 16, 17 do NOT contain `*/`
  (verified: each `**` is followed by `.`, end-of-line, or ` ` — never `/`),
  so they are left untouched.
- The `page.route('**/...')` string literals are left untouched.

## Assumptions & Decisions

1. **Scope is `mock.ts` only.** The task is to fix the JSDoc defect in
   `mock.ts`. Other files (e.g. `specs/chat/tts-playback.spec.ts`) are owned
   by other agents and will not be edited, even if they have residual errors
   after this fix.
2. **Minimal edit.** A single line is changed. No refactoring, no comment
   rewrites, no formatting churn.
3. **The fix is documentation-only.** It does not alter any runtime behaviour,
   route matching, or mock responses — only the contents of a comment.
4. **`tsc --noEmit` is the acceptance gate.** After the edit, running
   `cd /workspace/e2e && npx tsc --noEmit` should report zero errors
   originating in `lib/mock.ts` or in the 5 M01–M05 spec files I authored
   (`onboarding/onboarding.spec.ts`, `onboarding/placement.spec.ts`,
   `chat/text-messaging.spec.ts`, `chat/voice-input.spec.ts`,
   `chat/corrections.spec.ts`). Errors may still appear in
   `specs/chat/tts-playback.spec.ts` or other agents' files; those are noted
   but not fixed here.

## Verification Steps

1. Apply the one-line edit to `/workspace/e2e/lib/mock.ts` (line 10 only).
2. Re-read the edited region (lines 1–21) to confirm:
   - No `*/` substring appears between the opening `/**` (line 1) and the
     intended closing `*/` (line 21).
   - The rest of the file is byte-identical to the pre-edit version.
3. Run `cd /workspace/e2e && npx tsc --noEmit` and capture the output.
4. Confirm:
   - `lib/mock.ts` itself reports no errors.
   - `lib/setup.ts` reports no errors.
   - The 5 M01–M05 spec files I authored report no errors.
5. If `tts-playback.spec.ts` (or any other file owned by another agent) still
   reports errors, list them in the final report as out-of-scope residuals —
   do not attempt to fix them.
6. Return a summary to the user covering:
   - File edited (path + the single line changed).
   - Confirmation that `mock.ts` and the 5 M01–M05 files typecheck cleanly.
   - Any residual `tsc` errors in other files (with the error messages),
     flagged as out-of-scope.
