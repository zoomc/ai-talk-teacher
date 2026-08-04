# SpeakFlow E2E Test Specification

> **Runtime note (2026-08-04):** The supported `APP_MODE=e2e` build is a
> profile-free Simulation Runtime. It deliberately does not expose onboarding,
> provider/key forms, or external provider calls. The executable CI smoke gate
> is `npm run test:simulation`, covering the simulation banner and hidden Avatar
> Lab. The older M01/M02/M13–M17 provider/onboarding catalog below is retained
> as historical UI coverage and needs a separate production-like test build
> before it can be run against the new E2E mode.

> **Purpose**: This document is the canonical specification for the Playwright
> E2E suite under `e2e/specs/`. It enumerates every functional module
> (a "feature point"), its happy path, branch cases, and exception cases.
> Each feature point MUST be covered by ≥20 E2E test cases.
>
> **Source of truth**: This doc is derived from analysis of
> `/workspace/lib/features/**/presentation/screens/*.dart`,
> `/workspace/lib/core/router/app_router.dart`, and the supporting services
> in `/workspace/lib/core/services/` and `/workspace/lib/shared/widgets/`.
>
> **Mocking strategy**: Hybrid — Dart-side `E2eMockServices` short-circuits
> LLM/STT/TTS HTTP calls (primary path); Playwright `page.route()` intercepts
> vendor endpoints (defense-in-depth); the Flutter E2E bridge
> (`window.speakflowE2E.*`) resets/seeds SQLite for deterministic state.
>
> **Build command**:
> ```bash
> flutter build web --release --dart-define=APP_MODE=e2e --dart-define=E2E=true
> ```
>
> **Run command**:
> ```bash
> cd e2e && npm run test:simulation
> ```

## Table of Contents

1. [Feature Point Catalog](#feature-point-catalog)
2. [Modules](#modules)
   - [M01 — Onboarding Flow](#m01--onboarding-flow)
   - [M02 — Placement Test](#m02--placement-test)
   - [M03 — Chat: Text Messaging](#m03--chat-text-messaging)
   - [M04 — Chat: Voice Input & STT](#m04--chat-voice-input--stt)
   - [M05 — Chat: Inline Corrections](#m05--chat-inline-corrections)
   - [M06 — Chat: TTS Playback](#m06--chat-tts-playback)
   - [M07 — Chat: Continuous Mode & Barge-in](#m07--chat-continuous-mode--barge-in)
   - [M08 — Chat: Session Management](#m08--chat-session-management)
   - [M09 — Chat: Error States & Recovery](#m09--chat-error-states--recovery)
   - [M10 — Avatar: Idle Animation](#m10--avatar-idle-animation)
   - [M11 — Avatar: Emotion Markers](#m11--avatar-emotion-markers)
   - [M12 — Avatar: Lip Sync (Viseme)](#m12--avatar-lip-sync-viseme)
   - [M13 — Profile: LLM Profile CRUD](#m13--profile-llm-profile-crud)
   - [M14 — Profile: STT Profile CRUD](#m14--profile-stt-profile-crud)
   - [M15 — Profile: TTS Profile CRUD](#m15--profile-tts-profile-crud)
   - [M16 — Service Config: Active Switching & Delete Guard](#m16--service-config-active-switching--delete-guard)
   - [M17 — Voice Health Screen](#m17--voice-health-screen)
   - [M18 — Home: Dashboard Shell & Quick Actions](#m18--home-dashboard-shell--quick-actions)
   - [M19 — Home: Streak & Practice Log](#m19--home-streak--practice-log)
   - [M20 — Home: Today's Tasks (Daily Plan)](#m20--home-todays-tasks-daily-plan)
   - [M21 — Home: Ability Radar & Goals](#m21--home-ability-radar--goals)
   - [M22 — Settings: Theme & Language](#m22--settings-theme--language)
   - [M23 — Settings: Learning Preferences & App Section](#m23--settings-learning-preferences--app-section)
   - [M24 — Review: SM-2 Rating & Filters](#m24--review-sm-2-rating--filters)
   - [M25 — Progress: Dashboard, Heatmap & Trends](#m25--progress-dashboard-heatmap--trends)
   - [M26 — Pronunciation Detail & History](#m26--pronunciation-detail--history)
   - [M27 — Scenarios & Sentence Practice](#m27--scenarios--sentence-practice)
   - [M28 — Tutor Selection & Session Summary](#m28--tutor-selection--session-summary)
   - [M29 — Project Space](#m29--project-space)
   - [M30 — App Banners, Version & Connectivity](#m30--app-banners-version--connectivity)
3. [Coverage Matrix](#coverage-matrix)

---

## Feature Point Catalog

| ID  | Module                                         | Spec File                              | Min Cases |
| --- | ---------------------------------------------- | -------------------------------------- | --------- |
| M01 | Onboarding Flow                                | `specs/onboarding/onboarding.spec.ts`  | 20        |
| M02 | Placement Test                                 | `specs/onboarding/placement.spec.ts`   | 20        |
| M03 | Chat: Text Messaging                           | `specs/chat/text-messaging.spec.ts`    | 20        |
| M04 | Chat: Voice Input & STT                        | `specs/chat/voice-input.spec.ts`       | 20        |
| M05 | Chat: Inline Corrections                       | `specs/chat/corrections.spec.ts`       | 20        |
| M06 | Chat: TTS Playback                             | `specs/chat/tts-playback.spec.ts`      | 20        |
| M07 | Chat: Continuous Mode & Barge-in               | `specs/chat/continuous-mode.spec.ts`   | 20        |
| M08 | Chat: Session Management                       | `specs/chat/session-management.spec.ts`| 20        |
| M09 | Chat: Error States & Recovery                  | `specs/chat/error-states.spec.ts`      | 20        |
| M10 | Avatar: Idle Animation                         | `specs/avatar/idle.spec.ts`            | 20        |
| M11 | Avatar: Emotion Markers                        | `specs/avatar/emotion.spec.ts`         | 20        |
| M12 | Avatar: Lip Sync (Viseme)                      | `specs/avatar/lip-sync.spec.ts`        | 20        |
| M13 | Profile: LLM Profile CRUD                      | `specs/profile/llm-crud.spec.ts`       | 20        |
| M14 | Profile: STT Profile CRUD                      | `specs/profile/stt-crud.spec.ts`       | 20        |
| M15 | Profile: TTS Profile CRUD                      | `specs/profile/tts-crud.spec.ts`       | 20        |
| M16 | Service Config: Active Switching & Delete Guard| `specs/profile/service-config.spec.ts` | 20        |
| M17 | Voice Health Screen                            | `specs/profile/voice-health.spec.ts`   | 20        |
| M18 | Home: Dashboard Shell & Quick Actions          | `specs/home/dashboard.spec.ts`         | 20        |
| M19 | Home: Streak & Practice Log                    | `specs/home/streak.spec.ts`            | 20        |
| M20 | Home: Today's Tasks (Daily Plan)               | `specs/home/daily-plan.spec.ts`        | 20        |
| M21 | Home: Ability Radar & Goals                    | `specs/home/ability-goals.spec.ts`     | 20        |
| M22 | Settings: Theme & Language                     | `specs/settings/theme-language.spec.ts`| 20        |
| M23 | Settings: Learning Preferences & App Section   | `specs/settings/app-section.spec.ts`   | 20        |
| M24 | Review: SM-2 Rating & Filters                  | `specs/review/sm2-review.spec.ts`      | 20        |
| M25 | Progress: Dashboard, Heatmap & Trends          | `specs/progress/dashboard.spec.ts`     | 20        |
| M26 | Pronunciation Detail & History                 | `specs/progress/pronunciation-history.spec.ts` | 20 |
| M27 | Scenarios & Sentence Practice                  | `specs/scenarios/scenarios.spec.ts`    | 20        |
| M28 | Tutor Selection & Session Summary              | `specs/chat/tutor-summary.spec.ts`     | 20        |
| M29 | Project Space                                  | `specs/projects/projects.spec.ts`      | 20        |
| M30 | App Banners, Version & Connectivity            | `specs/system/banners-version.spec.ts` | 20        |

**Total**: 30 modules × ≥20 cases = **≥600 E2E test cases**.

---

## Modules

### M01 — Onboarding Flow

**Routes**: `/onboarding`
**Screen**: `lib/features/onboarding/presentation/screens/onboarding_screen.dart`

The first-run wizard. Walks the user through welcome → LLM profile → STT profile →
TTS profile. Each step has a "Skip for now" escape hatch. The wizard is also
reachable post-onboarding from Settings → "Re-run onboarding" (clears the
`onboarding_complete` flag).

#### Happy Path
1. Cold launch with no onboarding flag → redirects to `/onboarding`.
2. Welcome page renders with brand splash + "Get Started" CTA.
3. Tapping "Get Started" advances to LLM profile setup.
4. Filling LLM provider/key/model and tapping "Next" persists the profile.
5. STT setup page renders; filling fields + "Next" persists STT profile.
6. TTS setup page renders; "Use same provider & key as STT" shortcut works.
7. Final page: "Finish" → sets `onboarding_complete=true` → redirects to `/placement`.

#### Branch / Edge Cases
8. "Skip for now" on welcome page → completes onboarding with no profiles.
9. "Skip for now" on LLM page → no LLM profile created; advances to STT.
10. "Skip for now" on STT page → no STT profile; advances to TTS.
11. "Skip for now" on TTS page → completes onboarding; lands on `/placement`.
12. TTS "Use same provider as STT" copies provider/key but STT was skipped → no-op + hint.
13. Custom provider selected → base URL input becomes visible.
14. Browser language auto-detect picks locale (en/zh/ja/ko/es/fr/pt).
15. Docs URL is tappable (opens in new tab via `url_launcher`).
16. Re-run onboarding from Settings → returns to welcome page.
17. Theme is light/dark/system from persisted setting throughout the wizard.

#### Exception Cases
18. Invalid API key format (empty/short) → "Next" disabled or shows validation error.
19. Empty base URL for custom provider → validation error; cannot proceed.
20. Database write failure during profile save → error snackbar; can retry.
21. Network/HTTP failure during provider model fetch → graceful fallback; "Next" still enabled.
22. App killed mid-wizard → resumed wizard remembers last-completed step (via settings flags).
23. Concurrent tab: completing onboarding in tab A → tab B redirects on next navigation.

---

### M02 — Placement Test

**Routes**: `/placement`
**Screen**: `lib/features/onboarding/presentation/screens/placement_screen.dart`

A 5-turn AI conversation that streams each reply and emits a strict-JSON verdict
inside a ```placement``` fence. Renders a radar chart + per-dimension score table
+ 4-week learning path. Falls back to a static quiz when no LLM profile exists.
"Skip" defaults the level to `beginner`.

#### Happy Path
1. Onboarding complete + no placement → redirects to `/placement`.
2. Placement screen renders with intro + "Start" CTA.
3. Streaming AI conversation: each turn shows progressive text in the chat bubble.
4. After 5 turns, the verdict fence is parsed and the radar chart renders.
5. Per-dimension score table renders (vocab/fluency/grammar/pronunciation/confidence).
6. 4-week learning path card list renders.
7. "Finish" → sets `placement_complete=true` → redirects to `/` (home).

#### Branch / Edge Cases
8. "Skip" button → defaults level to `beginner`; sets `placement_complete=true`.
9. No LLM profile configured → fallback static quiz renders.
10. Static quiz: 4 self-assessment questions → level computed from answers.
11. Radar chart renders with all-zero scores (defensive lower bound).
12. Long AI reply (400+ tokens) → does not overflow the chat bubble.
13. JSON verdict missing one dimension → missing dimension shows "N/A".
14. verdict `level` field outside known set → defaults to `intermediate`.
15. AI reply with emoji → renders correctly in the bubble.
16. AI reply with code fence (non-placement) → stripped from bubble.
17. Mid-conversation app backgrounded → conversation state preserved on resume.
18. User answers very short ("yes") → AI still progresses conversation.

#### Exception Cases
19. LLM HTTP 401 (auth) → typed error banner with "Configure" CTA.
20. LLM HTTP 429 (rate limit) → "Retry" CTA + retry-with-backoff runs automatically.
21. LLM timeout (>30s) → timeout error UI; can retry.
22. Malformed JSON in verdict (no radar chart can be built) → fallback to text-only result.
23. Network offline mid-placement → offline banner; cannot send next message.

---

### M03 — Chat: Text Messaging

**Routes**: `/chat/:sessionId`
**Screen**: `lib/features/chat/presentation/screens/chat_screen.dart` + `lib/widgets/chat/`

The core conversation surface. Text mode is a toggle away from voice mode.
AI replies stream progressively; corrections render inline under the user message.

#### Happy Path
1. From Home "Start Conversation" → creates a session → `/chat/:id`.
2. Chat screen renders: header (tutor name + status), message list, input bar.
3. Typing in input bar → send button opacity toggles (ValueListenableBuilder).
4. Tapping send → user bubble appears; AI streaming reply begins.
5. AI reply streams token-by-token into the AI bubble.
6. After stream completes, corrections JSON block is parsed + saved to DB.
7. TTS autoplay fires after the first sentence boundary (decoupled from loading).
8. `_isLoading` clears as soon as AI message is saved (input bar reusable immediately).

#### Branch / Edge Cases
9. Empty input → send button is disabled (cannot send empty message).
10. Very long input (>2000 chars) → input bar scrolls; message persists.
11. Multi-line input (Shift+Enter) → text field grows; send on Enter (desktop).
12. Chat history capped at last 40 messages → older messages not loaded.
13. New correction deduped against existing `(original, corrected, type)` → occurrence count incremented.
14. Typing during AI streaming → input bar still usable (decoupled).
15. Send button shows "sending" state during the request window.
16. Switching text/voice mode mid-typing preserves text draft.
17. Theme switch (dark/light) mid-conversation → bubbles re-render correctly.
18. Long conversation (40 messages) → no OOM; list scrolls smoothly.
19. App backgrounded mid-stream → stream resumes on foreground.

#### Exception Cases
20. LLM HTTP 401 → typed `AppError` (auth) snackbar with "Configure" CTA.
21. LLM HTTP 429 → "Retry" CTA; auto-retry with 1/2/4/8/16s backoff.
22. LLM HTTP 500 → "Server error" snackbar with "Retry".
23. LLM timeout → "Request timed out" with manual "Retry" affordance.
24. Empty LLM response (content == "") → `LlmException('Empty response')` shown.
25. Malformed LLM JSON → stream gracefully skips malformed chunks.
26. Network offline → `_OfflineHint` banner appears above input bar; send disabled.
27. DB write failure saving message → error snackbar; message lost (no silent retry).

---

### M04 — Chat: Voice Input & STT

**Routes**: `/chat/:sessionId`
**Widget**: `_ChatInputBar` (voice mode default)

Voice-first chat: 72px circular mic button with pulse animation. Press-and-hold
to record, release to stop+transcribe. STT transcript becomes the user message.

#### Happy Path
1. Voice mode is the default on chat entry → mic button visible.
2. Press-and-hold mic → button turns red; ripple pulse animation starts.
3. Release mic → recording stops; STT transcribe begins; transcript appears as user bubble.
4. STT transcript with grammar error → correction renders under the user bubble.
5. Successful STT → AI reply streams + TTS autoplay fires.
6. Mic permission granted → recording proceeds.
7. Text mode toggle (keyboard icon) → switches to text input.

#### Branch / Edge Cases
8. Quick tap (no hold) → no recording; no error.
9. Quick release during mic startup → reliably stops + transcribes (P0 fix).
10. Long recording (60s) → auto-stops at configured max duration.
11. Silence for 5s → still records; STT may return empty.
12. STT returns empty transcript → actionable hint ("move closer to mic / quieter env").
13. STT transcript very long → still becomes one user bubble (scrolls if needed).
14. STT transcript with code/special chars → rendered as-is in bubble.
15. Toggle voice→text→voice mid-recording → recording cancelled; no transcript.
16. Continuous mode auto-rearms mic after TTS completes → hands-free conversation.
17. Recording while keyboard is up → keyboard dismissed first.
18. Browser without `getUserMedia` → mic button disabled with tooltip.
19. Recording starts while another tab is recording → second tab gets permission error.

#### Exception Cases
20. Mic permission denied → typed `AppError` (mic-permission) with "Open Settings" CTA.
21. Mic permission dismissed (no decision) → re-prompts on next tap.
22. STT HTTP 401 → "STT auth error" snackbar with "Configure" CTA.
23. STT HTTP 5xx → "STT server error" with "Retry" affordance.
24. STT timeout → "Transcription timed out" snackbar.
25. STT returns malformed JSON → empty transcript; same hint as empty case.
26. Recording service throws (codec/sample-rate unsupported) → typed error.
27. Network offline during STT upload → offline banner; recording discarded.

---

### M05 — Chat: Inline Corrections

**Routes**: `/chat/:sessionId`
**Widget**: `_CorrectionInline`, `ChatBubble`

Grammar/vocabulary/pronunciation/fluency corrections render inline under the
user message. Tapping a word in the user bubble opens a phoneme detail overlay.

#### Happy Path
1. User sends message with grammar error → AI reply + correction card render.
2. Correction card shows: original (struck-through), corrected (green), type icon.
3. Correction type colors: grammar/vocab/pronunciation/fluency distinct.
4. Severity badge (low/medium/high) renders on the card.
5. Tapping correction → expands to show explanation.
6. Correction saved to DB with `original`, `corrected`, `type`, `skill`, `severity`.

#### Branch / Edge Cases
7. Multiple corrections on same message → all render as stacked cards.
8. Correction with empty explanation → explanation row hidden.
9. Correction with very long original/corrected → text wraps; no clipping.
10. Correction type "fluency" → uses `AppColors.info` (distinct from grammar).
11. Correction skill tag (`grammar/subject-verb-agreement`) renders as chip.
12. Duplicate correction (same original+corrected+type) → occurrence count `×N` shown.
13. Tapping a word in user bubble → phoneme detail overlay opens.
14. Phoneme overlay shows per-phoneme scores with color bands (green/amber/red).
15. Phoneme overlay A/B replay buttons (user vs AI audio).
16. Correction persisted across app restarts.
17. `correction_strength` setting affects which errors are flagged.
18. Star (favorite) toggle on correction → `is_favorite` flips in DB.
19. Long-press correction → context menu (favorite / report / share).

#### Exception Cases
20. Malformed `corrections` JSON in LLM reply → no correction cards render.
21. `corrections` JSON missing `original` field → that correction skipped.
22. Corrections JSON present but empty array → no cards; AI reply still renders.
23. Correction with unknown type string → defaults to "grammar" with neutral color.
24. DB write failure on `saveCorrectionDedup` → snackbar; correction not lost (in-memory until next save).
25. Phoneme score set references non-existent message → no overlay; tap is no-op.

---

### M06 — Chat: TTS Playback

**Routes**: `/chat/:sessionId`
**Service**: `TtsService`, `TtsPlaybackService`

AI reply auto-plays TTS after the first sentence boundary. Manual play/pause
per message. Failure tracked per-message-id with inline retry.

#### Happy Path
1. AI reply streams → after first sentence, `_autoplayTts` fires.
2. TTS audio plays via `just_audio`; avatar enters `speaking` state.
3. Playback completes → avatar returns to `idle`.
4. Manual play button visible on each AI message.
5. Tapping play on a previous AI message → replays TTS.
6. TTS speed follows `tts_speed` setting (0.75× / 1.0× / 1.25× / 1.5×).

#### Branch / Edge Cases
7. Continuous mode + TTS completes → mic auto-rearms (E1 auto-listen).
8. Barge-in: tap mic during TTS → playback stops immediately.
9. TTS speed change mid-playback → applies via `setSpeed` (no re-synthesis).
10. TTS for long reply (>500 chars) → plays full audio; avatar stays speaking.
11. Multiple AI messages in rapid succession → only latest autoplays.
12. TTS audio cached → replaying same text is instant (cache hit).
13. Viseme timeline pushed to AvatarStage on TTS success.
14. Viseme timeline cleared on playback completion / error.
15. `low_bandwidth` setting on → TTS still plays (only 3D avatar drops).
16. User navigates away mid-TTS → playback stops; no orphan audio.
17. App backgrounded mid-TTS → playback pauses; resumes on foreground.
18. Volume muted at OS level → playback proceeds silently; visemes still animate.

#### Exception Cases
19. TTS HTTP 401 → "TTS auth error" snackbar; inline retry on the message.
20. TTS HTTP 5xx → "TTS server error" with inline retry.
21. TTS timeout (>60s) → "TTS timed out" with retry.
22. TTS returns empty audio → `TtsException`; inline retry.
23. just_audio decode error → avatar stuck in `speaking` (known follow-up); retry clears.
24. Network offline when TTS requested → offline banner; autoplay skipped.
25. Malformed audio bytes (not mp3/wav) → decode error; inline retry.

---

### M07 — Chat: Continuous Mode & Barge-in

**Routes**: `/chat/:sessionId`
**Widget**: `_ChatInputBar` continuous-mode chip

E1 auto-listen, E2 barge-in, E5 continuous mode toggle, E3 decoupled loading/TTS.

#### Happy Path
1. Continuous mode chip visible in input bar; default ON.
2. TTS completes in continuous mode → mic auto-rearms after 500ms.
3. User speaks → STT runs → AI replies → TTS plays → loop continues.
4. Toggling chip OFF → no auto-rearm; user must tap mic manually.
5. Barge-in: tap mic during TTS → TTS stops + mic starts recording.

#### Branch / Edge Cases
6. Continuous mode ON but mic permission denied → no auto-rearm; chip stays ON.
7. Continuous mode ON + empty STT transcript → no AI reply; mic re-rearms after hint.
8. Continuous mode ON + STT error → error snackbar; mic re-rearms after timeout.
9. Toggle chip during TTS playback → does not stop current TTS.
10. Toggle chip during recording → recording continues; chip state applies next cycle.
11. Continuous mode OFF + barge-in tap → mic starts (still works without auto-rearm).
12. App backgrounded mid-continuous-loop → loop pauses; resumes on foreground.
13. User navigates away mid-loop → loop stops; no orphan recordings.
14. Long continuous session (10+ turns) → no memory leak.
15. Continuous mode + correction saved → mic re-rearms after correction persisted.
16. E3 decoupling: `_isLoading` clears on save; `_playingMessageId` tracks TTS separately.
17. TTS error during continuous loop → loop continues with next user turn.
18. User taps send (text) during continuous loop → text sent; loop continues after TTS.
19. Mic permission revoked mid-loop → loop stops; permission CTA shown.

#### Exception Cases
20. STT returns 5 consecutive empty transcripts → no infinite loop; chip auto-OFF.
21. LLM error during continuous loop → error snackbar; mic re-rearms for retry.
22. TTS error during continuous loop → inline retry; loop waits for user action.
23. Network drops mid-loop → offline banner; loop pauses; resumes on reconnect.

---

### M08 — Chat: Session Management

**Routes**: `/chat/:sessionId`, history screen, session options sheet
**Services**: `ChatRepository`, `SessionContinuityService`

Create / archive / delete / recover sessions. Session options bottom sheet
(GlassBottomSheet). Crash recovery via `SessionSnapshot`.

#### Happy Path
1. Home "Start Conversation" → creates session + records practice → `/chat/:id`.
2. Session options sheet opens (three-dot menu in chat header).
3. Sheet shows: rename, archive, delete, tutor selection link.
4. Rename session → `topic` updates; header title refreshes.
5. Archive session → `archived_at` set; session hidden from active list.
6. Delete session → confirmation dialog → cascade delete (messages+corrections).
7. Crash recovery: snapshot exists → "Restore previous session?" prompt on entry.

#### Branch / Edge Cases
8. Session with `is_guest=1` → 3-minute countdown banner; expired → archived.
9. Guest trial captures non-guest profiles → restored on trial end.
10. `_GuestTimerBar` rebuilds only the banner, not the full screen (P1 perf fix).
11. Archived session visible in history "archived" filter.
12. Delete session with no confirmation → not allowed (dialog always shows).
13. Rename to empty string → falls back to "Free Talk" default.
14. Rename to very long string → truncated in header; full text in sheet.
15. Session metadata (duration, message count, correction count) updates incrementally.
16. Auto-summary generated on archive (heuristic from topic + turn count + corrections).
17. Session snapshot saved after each AI turn (crash recovery).
18. Snapshot cleared on session delete (no orphan snapshots).
19. Multiple sessions for same scenario → all visible in history.

#### Exception Cases
20. Delete session DB failure → snackbar; session not deleted.
21. Recovery prompt: snapshot exists but session was deleted → recovery declined; snapshot cleared.
22. Recovery prompt: user declines → snapshot cleared; fresh session starts.
23. Archive session with active TTS → TTS stops; archive proceeds.
24. Guest trial expires mid-recording → recording saved; session archived.
25. Session options sheet opened during TTS → sheet modal does not pause TTS.

---

### M09 — Chat: Error States & Recovery

**Routes**: `/chat/:sessionId`
**Service**: `withRetry`, `AppError`

`withRetry` wraps STT/TTS/LLM with 1/2/4/8/16s exponential backoff (5 attempts).
Auth + mic-permission errors are non-retryable. `AppError.redact` strips sk-/Bearer.

#### Happy Path
1. LLM 500 → "Retry" snackbar; auto-retry runs (1s, 2s, 4s, 8s, 16s).
2. "重试中…" progress shown during backoff.
3. Retry succeeds on attempt 3 → AI reply renders; no error UI.
4. Auth error (401/403) → no retry; "Configure" CTA shown.
5. Mic permission error → no retry; "Open Settings" CTA shown.
6. All errors redacted (no `sk-...` or `Bearer ...` in UI).

#### Branch / Edge Cases
7. Rate limit (429) → retryable; respects `Retry-After` if present.
8. Network timeout → retryable; "Request timed out" message.
9. Network offline → not retryable; offline banner.
10. Server error (5xx) → retryable; "Server error" message.
11. 5 retries exhausted → "Failed" UI + manual retry button.
12. Stream text accumulated between retries → reset (no garbled reply).
13. STT 5xx → retryable; "Transcription failed, retrying…".
14. TTS 5xx → retryable; "TTS failed, retrying…".
15. AppError.redact strips `sk-...`, `Bearer ...`, `?key=...` patterns.
16. Error snackbar auto-dismisses after 4s (unless action tapped).
17. Concurrent errors (LLM + TTS) → both surface; LLM error wins UI priority.
18. Error during continuous mode → loop pauses; resumes on retry success.
19. Retry button on exhausted error → restarts retry chain from attempt 1.

#### Exception Cases
20. Error message contains raw API key → redacted before reaching UI.
21. Error during streaming → partial reply preserved; retry only fetches remainder (best-effort).
22. Multiple concurrent retries (LLM + STT) → independent backoff timers.
23. App killed during retry → on next launch, no orphan retry; user must tap retry.
24. Retry succeeds but response is empty → `LlmException('Empty response')`.
25. Retry counter never exceeds 5 (no infinite loop).

---

### M10 — Avatar: Idle Animation

**Widget**: `AvatarStage` (`lib/features/avatar/presentation/widgets/avatar_stage.dart`)
**Service**: `IdleAnimationController`

Breathing (3.3s sine), blinking (deterministic ~3.5s), head micro-turn
(yaw/pitch/roll at 8/11/13s), body sway (7s). Per-phase multipliers.

#### Happy Path
1. Chat screen idle (no voice activity) → avatar breathing + occasional blink.
2. Head micro-turn visible (yaw/pitch/roll never exactly repeat).
3. Body sway visible (7s period).
4. AvatarStage renders the layered 2D upper-body tutor as fallback (no bundled
   Live2D model).
5. Live2D model present under `assets/live2d/tutor/` → native rendering branch.

#### Branch / Edge Cases
6. Breathing amplitude scales `ParamBreath` 0.0↔1.0 around 0.5 baseline.
7. Blink interval deterministic (~3.5s mean) → tests stable.
8. Blink duration 120ms ramp + 40ms hold.
9. Head yaw period 8s, pitch 11s, roll 13s (never repeats exactly).
10. Body sway period 7s.
11. Idle multiplier (full motion) vs listening (attentive tilt + reduced smile).
12. Thinking phase: slower blinks.
13. Speaking phase: smileScale=0 (visemes own mouth); headScale=0.2; breathing retained.
14. IdleFrame is pure-Dart (no timers) → deterministic in tests.
15. `sample(elapsed, {phase, emotion})` returns parameter → value map.
16. Custom config (periods, amplitudes) overrides defaults.
17. AvatarStage composes idle + emotion + viseme every tick.
18. Idle base → emotion override → viseme mouth override (merge order).
19. Fallback renderer composes breath-driven sway + head-roll tilt + layered
    body/face parts with parameter-driven mouth shapes.

#### Exception Cases
20. Live2D loader fails (missing model) → fallback renderer; no blank screen.
21. Missing optional model/asset → layered renderer and status pill (never blank).
22. Ticker disposed during animation → no exceptions on next tick.
23. `IdleAnimationController.sample` with negative elapsed → clamps to 0.

---

### M11 — Avatar: Emotion Markers

**Service**: `EmotionController`, `TutorEmotion` (7 states: neutral/happy/thinking/encouraging/confused/focused/waiting)
**Parser**: `parseEmotionMarker`, `stripEmotionMarkers`, `emotionFromText`

LLM prefixes each reply with `[emotion:id]`. Markers stripped before save/display/TTS.

#### Happy Path
1. LLM reply `[emotion:happy] That's great!` → avatar shows happy; bubble shows `That's great!`.
2. Emotion transitions use 250ms `easeOutCubic` easing.
3. `neutral` → `happy` → `neutral` cycle visible.
4. `waiting` state used when avatar is idle waiting for user.
5. `thinking` state during LLM streaming.

#### Branch / Edge Cases
6. `parseEmotionMarker("(emotion:happy)")` paren form also works.
7. Case-insensitive: `[Emotion:Happy]` parses to `happy`.
8. Whitespace-tolerant: `[ emotion : happy ]` parses.
9. Multiple markers in one reply → first one wins.
10. `stripEmotionMarkers` removes markers + collapses double spaces.
11. `emotionFromText` prefers explicit marker over keyword matching.
12. Keyword fallback: "great" → happy, "hmm" → thinking, "yes" → encouraging.
13. Amplitude-driven emotion overrides `neutral` only (keywords win otherwise).
14. Easing curves: `linear`, `easeInOutQuad`, `easeOutCubic` configurable.
15. Custom poses via `kDefaultEmotionPoses` table (7 emotions covered).
16. Pose lerping blends mouthForm/eyeSmile/browY/cheek/headPitchBias/headRollBias.
17. Markers stripped before DB save (corrections JSON unaffected).
18. Markers stripped before TTS (no spoken markers).
19. `waiting` emotion biases smile baseline lower (attentive, not happy).

#### Exception Cases
20. Unknown emotion id (`[emotion:foo]`) → ignored; keyword fallback applies.
21. Malformed marker (`[emotion:happy`) → not parsed; treated as plain text.
22. Empty marker (`[emotion:]`) → ignored.
23. Marker in corrections JSON block → not parsed (only main reply scanned).

---

### M12 — Avatar: Lip Sync (Viseme)

**Service**: `RhubarbService`, `VisemeTimelinePlayer`, `kRhubarbToLive2DMap`
**Pipeline**: TTS audio → rhubarb CLI → viseme timeline → Live2D mouth params

32-entry LRU cache keyed by audio hash. 80ms ramp between cues. Falls back to
amplitude-driven mouth if rhubarb unavailable.

#### Happy Path
1. TTS plays → `unawaited(_maybeAnalyzeVisemes(...))` runs rhubarb on audio bytes.
2. Viseme timeline pushed to AvatarStage via global key.
3. Mouth shape transitions smoothly (80ms ramp between cues).
4. Playback completes → viseme timeline cleared.
5. Repeated TTS of same text → cache hit; no re-analysis.

#### Branch / Edge Cases
6. 9 rhubarb visemes (A–H) + X (silence) all mapped to Live2D params.
7. `mouthOpenY` / `mouthForm` / `mouthFormL` / `mouthFormR` driven per viseme.
8. `visemeToPainter` maps to legacy `VirtualCharacter.Viseme` enum for fallback.
9. `parseRhubarbJson` defensively parses (never throws).
10. Missing `start` cue → kept; falls back to previous cue's end.
11. Missing `value` cue → skipped.
12. Non-numeric `start` → skipped.
13. Empty timeline → `VisemeTimeline.empty`.
14. Leading silence cue inserted when missing.
15. Cues sorted by start time.
16. 32-entry LRU cache evicts oldest on full.
17. `cacheKeyFor(text)` stable across runs (audio hash).
18. Web platform: rhubarb runner is stub (no native CLI) → amplitude fallback.
19. Amplitude fallback: synthesized 50ms tick stream drives jawOpen.

#### Exception Cases
20. Rhubarb CLI missing → `VisemeTimeline.empty`; amplitude fallback active.
21. Rhubarb returns malformed JSON → `VisemeTimeline.empty`.
22. Audio bytes empty → no analysis; amplitude fallback.
23. TTS error → timeline cleared (no orphan mouth movement).

---

### M13 — Profile: LLM Profile CRUD

**Routes**: `/service-config`, `/profile-form/llm`
**Screen**: `ServiceConfigScreen`, `ProfileFormScreen`

Create / read / update / delete LLM profiles. Provider catalog drives the
provider picker. Active profile marked with badge.

#### Happy Path
1. Service config screen → "LLM" tab → list of LLM profiles.
2. "Add Profile" → `/profile-form/llm` → form renders.
3. Select provider (e.g., DeepSeek) → base URL + default model auto-filled.
4. Enter name + API key + (optional) custom model → "Save".
5. Profile saved to `llm_profiles` table; appears in list.
6. Tap profile → edit form pre-filled.
7. Edit name → "Save" → list updates.
8. Delete profile (non-active) → confirmation → removed from list.

#### Branch / Edge Cases
9. Provider catalog includes: deepseek, openai, glm, kimi, baichuan, yi, volcengine_doubao, custom.
10. Custom provider → base URL input required.
11. Default model corrected for deepseek (`deepseek-chat`, not `deepseek-v4-flash`).
12. Default model corrected for kimi (`moonshot-v1-8k`, not `kimi-k2.6`).
13. Profile name defaults to "DeepSeek Default" / "OpenAI Backup" etc.
14. API key stored in secure storage (not plaintext SQLite).
15. Multiple profiles for same provider → allowed.
16. Profile with empty model → defaults at runtime (deepseek-chat etc.).
17. "Test Connection" button → calls `/models` endpoint.
18. Connection test success → "✓ Connected" snackbar.
19. Connection test 401 → "API key rejected" error.

#### Exception Cases
20. Save with empty name → validation error; cannot save.
21. Save with empty API key → validation error.
22. Save with invalid base URL (no scheme) → validation error.
23. Edit during DB transaction → safe (queued); no corruption.
24. Delete active profile → blocked with "switch active first" hint.
25. DB write failure → error snackbar; retry available.

---

### M14 — Profile: STT Profile CRUD

**Routes**: `/service-config`, `/profile-form/stt`
**Screen**: `ServiceConfigScreen`, `ProfileFormScreen`

STT profile CRUD. Vendors: Deepgram, OpenAI Whisper, Google, Azure, plus
volcengine/xfyun/tencent (relay-only).

#### Happy Path
1. Service config → "STT" tab → list of STT profiles.
2. "Add Profile" → `/profile-form/stt` → form renders.
3. Select Deepgram → default model `nova-2`, language `en-US`.
4. Enter API key → "Save" → profile persisted.
5. Azure selected → region field appears.
6. Language picker (en-US, en-GB, zh-CN, ja-JP, etc.).
7. Edit existing STT profile → form pre-filled.

#### Branch / Edge Cases
8. Deepgram auth: "Token <key>" (not Bearer).
9. OpenAI Whisper: language shortened to ISO-639-1 (`en-US` → `en`).
10. Azure: region required; URL templated with `{region}`.
11. Google: API key as `?key=` query param.
12. volcengine_stt / xfyun_stt / tencent_stt → "not directly supported" error with relay guidance.
13. Custom OpenAI-compatible endpoint → base URL input required.
14. `extra_config` JSON field for advanced options.
15. Multiple STT profiles → allowed.
16. Active STT profile marked with badge.
17. Whisper `response_format=json` always set.
18. Deepgram `smart_format=true` always set.
19. Azure content-type `audio/wav; codecs=audio/pcm; samplerate=16000`.

#### Exception Cases
20. Save with empty API key → validation error.
21. Azure without region → "Azure region is required" error.
22. Domestic provider (volcengine/xfyun/tencent) selected → "not supported" error.
23. Connection test 401 → "API key rejected".
24. Connection test 5xx → "server error".
25. DB write failure → error snackbar.

---

### M15 — Profile: TTS Profile CRUD

**Routes**: `/service-config`, `/profile-form/tts`
**Screen**: `ServiceConfigScreen`, `ProfileFormScreen`

TTS profile CRUD. Vendors: Fish Audio, ElevenLabs, OpenAI TTS, Azure, Google,
Aliyun CosyVoice, Deepgram Aura, plus relay-only domestic providers.

#### Happy Path
1. Service config → "TTS" tab → list of TTS profiles.
2. "Add Profile" → `/profile-form/tts` → form renders.
3. Select Fish Audio → default model `s1`, voice `voice-1`.
4. Enter API key + voice ID → "Save" → profile persisted.
5. ElevenLabs selected → default voice `21m00Tcm4TlvDq8ikWAM`.
6. Azure TTS selected → region + SSML voice field.
7. Speed slider (0.75× – 1.5×) with 0.05 increments.

#### Branch / Edge Cases
8. Fish Audio endpoint `/api/open/tts` (not `/tts`).
9. ElevenLabs endpoint `/v1/text-to-speech/{voice_id}`.
10. Azure SSML: speed → percentage (`+10%`, `-20%`).
11. Azure SSML: XML entities escaped (`&` → `&amp;`).
12. Google TTS: audioContent base64 decoded.
13. Aliyun CosyVoice: returns URL → HTTP-GET the URL.
14. Deepgram Aura: endpoint `/v1/speak?model=...`, auth "Token <key>".
15. OpenAI-compatible: endpoint `/audio/speech`, response_format mp3.
16. volcengine_tts / xfyun_tts / tencent_tts → "not supported" error.
17. `voice_name` display field separate from `voice_id`.
18. Active TTS profile marked with badge.
19. Default voice per provider (from `providerDef.defaultVoice`).

#### Exception Cases
20. Save with empty API key → validation error.
21. Speed out of range (0.5 or 2.0) → clamped to [0.75, 1.5].
22. Domestic provider selected → "not supported, use relay" error.
23. Connection test 401 → "API key rejected".
24. Aliyun CosyVoice returns no audio URL → "did not return audio URL" error.
25. DB write failure → error snackbar.

---

### M16 — Service Config: Active Switching & Delete Guard

**Routes**: `/service-config`
**Screen**: `ServiceConfigScreen`

Tabbed UI for LLM/STT/TTS profiles. Active profile switching wrapped in DB
transaction (atomic). Active profile deletion prevented.

#### Happy Path
1. Service config renders with three tabs (LLM / STT / TTS).
2. Active profile marked with badge + radio button.
3. Tap inactive profile's "Set Active" → DB transaction updates `is_active`.
4. Switching is atomic: either both old+new update or neither.
5. Popup menu on each profile: Edit, Set Active, Delete.
6. Delete inactive profile → confirmation → removed.
7. Edit profile → navigates to profile form.

#### Branch / Edge Cases
8. Active profile's "Delete" menu item is disabled with "switch active first" hint.
9. Switching active profile invalidates dependent providers (chat LLM/STT/TTS).
10. Switching LLM profile → next chat uses new profile (no restart).
11. Switching TTS profile → next TTS uses new profile.
12. Switching STT profile → next STT uses new profile.
13. Profile list shows: name, provider, model, active badge.
14. Tabs persist across navigation (returns to last-active tab).
15. Empty profile list → "Add your first profile" CTA.
16. Long profile name → truncated with ellipsis.
17. Profile with very long API key → masked in UI (sk-...XXXX).
18. "Test Connection" button per profile.
19. Connection test running → spinner; button disabled.

#### Exception Cases
20. DB transaction fails mid-switch → rollback; original active preserved.
21. Delete during switch → blocked (transaction in progress).
22. Edit during switch → allowed (read-only form pre-fill).
23. Connection test 5xx → "server error" snackbar.
24. Connection test timeout → "timed out" snackbar.
25. Concurrent switches (rapid taps) → only first completes; others ignored.

---

### M17 — Voice Health Screen

**Routes**: `/voice-health`
**Screen**: `VoiceHealthScreen`

Voice health guidance: hydration, warm-up exercises, rest recommendations.

#### Happy Path
1. Settings → "Voice Health" tile → navigates to `/voice-health`.
2. Screen renders: hydration tracker, warm-up exercise list, rest timer.
3. Hydration tracker: tap glass → count increments.
4. Warm-up exercise list: 5 exercises with descriptions.
5. Rest timer: 5-minute countdown.

#### Branch / Edge Cases
6. Hydration goal reached (8 glasses) → celebration animation.
7. Warm-up exercise tap → detail view with audio guide.
8. Rest timer pause/resume.
9. Rest timer completes → notification + "Practice Again" CTA.
10. Hydration count persists across screen exits.
11. Hydration resets at midnight (local time).
12. Rest timer backgrounded → pauses; resumes on foreground.
13. Warm-up exercise audio plays via TTS.
14. Voice health tips section (5 static tips).
15. Daily streak visible (consecutive days hitting hydration goal).
16. Long exercise description → scrolls; no clipping.
17. Empty state if no exercises configured.
18. Locale-aware content (en/zh/ja/ko/es/fr/pt).
19. Theme-aware colors throughout.

#### Exception Cases
20. TTS not configured → audio guide disabled with hint.
21. Hydration count DB failure → in-memory until next save.
22. Rest timer app killed → no orphan timer; resets on next entry.
23. Unknown locale → falls back to English content.

---

### M18 — Home: Dashboard Shell & Quick Actions

**Routes**: `/`
**Screen**: `HomePage`

Six sections: streak, quick actions, today's tasks, ability radar, review queue,
goal. Pull-to-refresh invalidates all dashboard providers.

#### Happy Path
1. Onboarding + placement complete → `/` renders HomePage.
2. Streak section visible at top.
3. Three quick-action buttons: "Start Conversation", "Review Corrections", "Pronunciation Practice".
4. Today's tasks section (1-5 prioritized).
5. Ability radar section.
6. Pending review queue section.
7. Goal section.

#### Branch / Edge Cases
8. "Start Conversation" → creates session → `/chat/:id`.
9. "Review Corrections" → `/review` (badge shows due count).
10. "Pronunciation Practice" → `/practice` + records practice.
11. Pull-to-refresh → all dashboard providers invalidate.
12. Refresh during loading → no duplicate requests.
13. Empty state (no corrections, no sessions) → empty-state copy per section.
14. Quick-action button disabled while loading.
15. `_QuickActionGrid` uses LayoutBuilder (correct card sizing).
16. iPad portrait → single column; landscape → grid.
17. iPhone SE (320pt) → no clipping (FittedBox on stat values).
18. Active persona badge visible (Mr. Sterling / Ms. Lily / Coach Max).
19. Recommended-scenarios strip visible when content enabled.

#### Exception Cases
20. Provider error → error state per section (not full-screen error).
21. Loading state → shimmer placeholders.
22. Pull-to-refresh during error → retries; clears error if success.
23. Goal section with no goal set → "Set a goal" prompt.
24. Recommended scenarios with no scenarios → strip hidden.
25. Practice log DB failure → streak section shows "—" gracefully.

---

### M19 — Home: Streak & Practice Log

**Routes**: `/`
**Service**: `StreakService`, `practice_log` table

30-day dot grid with 7/14/21/28 milestone badges. Practice recorded on chat
start, pronunciation practice open, correction rating.

#### Happy Path
1. Streak section renders 30-day dot grid.
2. Today's dot filled if practice recorded today.
3. 7/14/21/28 milestone badges visible when reached.
4. Streak count (consecutive days) visible.
5. Practice recorded when starting a conversation.

#### Branch / Edge Cases
6. Practice recorded when opening pronunciation practice.
7. Practice recorded when rating a correction.
8. Streak failure (DB error) → swallowed; never blocks primary flow.
9. Streak denormalized on each `practice_log` row (cheap reads).
10. Missed day → streak resets to 0 (next practice starts new streak).
11. Two practices same day → only one streak increment.
12. 30-day grid shows past 30 days (rolling window).
13. Milestone badge color distinct from regular dot.
14. Streak service failures best-effort (no UI error).
15. Practice log duration_seconds recorded.
16. `completed` flag on practice log.
17. Streak updates immediately after practice recorded (no refresh needed).
18. Locale-aware day labels.
19. Theme-aware colors.

#### Exception Cases
20. Practice log DB failure → streak not updated; no error shown.
21. Streak computation overflow (very long streak) → capped at 999.
22. Date boundary (midnight) → correctly attributes to new day.
23. Multiple practices across midnight → correctly counted in respective days.

---

### M20 — Home: Today's Tasks (Daily Plan)

**Routes**: `/`
**Service**: `DailyPlanService`

1-5 prioritized tasks: P1 SRS reviews, P2 recent-mistake drill, P3 voice-health
pre-flight, P4 sentence practice, P5 free-talk/scenario.

#### Happy Path
1. Today's tasks section renders 1-5 prioritized cards.
2. Each card shows: title, duration estimate, P1-P5 priority pill.
3. P1 (due SRS reviews) surfaces when reviews are due.
4. P2 (recent-mistake drill) surfaces when recent errors exist.
5. P3 (voice-health pre-flight) surfaces conditionally.

#### Branch / Edge Cases
6. P4 (sentence practice) always available.
7. P5 (free-talk / scenario) default task when no higher-priority items.
8. `recentErrorCount` counts corrections seen in last 3 days.
9. Content enabled → P5 uses `startScenario` action with scenario id.
10. Content disabled → P5 uses `startConversation` action.
11. Tapping P1 task → navigates to `/review`.
12. Tapping P5 task → creates session + navigates to `/chat/:id`.
13. Tapping P4 task → navigates to `/practice`.
14. Tapping P3 task → navigates to `/voice-health`.
15. `DailyPlanService.buildFromRepository` pulls content settings + recommended scenario.
16. Daily scenario count (1-10, default 3) affects P5 task.
17. Active teacher persona affects task wording.
18. Tasks re-prioritize on refresh.
19. Empty state: no tasks → "All caught up!" message.

#### Exception Cases
20. Recent errors DB failure → P2 task skipped (not shown).
21. SRS queue DB failure → P1 task skipped.
22. Content settings DB failure → defaults applied (content enabled, count 3).
23. Scenario DB failure → P5 falls back to free-talk.

---

### M21 — Home: Ability Radar & Goals

**Routes**: `/`
**Services**: `abilityScoresProvider`, `UserGoalService`, `recommendedScenariosProvider`

4-axis radar (pronunciation/grammar/vocabulary/fluency). Blends placement scores
with correction-type distribution and skill mastery.

#### Happy Path
1. Ability radar renders 4 axes.
2. Placement scores populate initial radar.
3. Corrections nudge dimensions down proportional to error share.
4. Skill mastery rolls up via `<dimension>/` prefix matching.
5. `abilityScoresProvider` blends placement 50/50 with skill mastery averages.

#### Branch / Edge Cases
6. Goal section shows current goal (or "no goal" prompt).
7. Set-goal dialog: 4 ChoiceChips (interview/travel/daily/ielts) + optional target.
8. Tapping a goal chip → highlights; "Save" enables.
9. Goal saved → `user_goal` table insert (history-preserving).
10. Recommended scenarios filter by goal's preferred category.
11. Interview goal → career scenarios.
12. Travel goal → travel scenarios.
13. IELTS goal → general scenarios.
14. Daily goal → daily scenarios.
15. No goal → all scenarios recommended.
16. Tapping recommended scenario → starts conversation with that scenario.
17. Goal section invalidates on pull-to-refresh.
18. Radar chart reuses `PlacementRadarChart` CustomPainter.
19. Goal history preserved (`getActiveGoal` reads latest by `created_at`).

#### Exception Cases
20. No placement scores → radar all-zero (defensive).
21. No corrections → radar reflects placement scores only.
22. No skill mastery → radar reflects placement + corrections only.
23. Goal category has no matching scenarios → all scenarios recommended.
24. Goal DB failure → "no goal" prompt shown.

---

### M22 — Settings: Theme & Language

**Routes**: `/settings`
**Screen**: `SettingsScreen`

Theme switching (light/dark/system) is immediate (no restart). Language
switching (7 locales) is immediate. Browser language auto-detected on web.

#### Happy Path
1. Settings → "Appearance" section → theme picker.
2. Tap "Light" → app immediately re-renders in light theme.
3. Tap "Dark" → immediate dark theme.
4. Tap "System" → follows OS preference.
5. Settings → "Language" section → 7 locales (zh/en/ja/ko/es/fr/pt).

#### Branch / Edge Cases
6. Tap "English" → app immediately re-renders all strings in English.
7. Tap "中文" → all strings in Chinese.
8. Theme persisted via `theme` setting key.
9. Language persisted via `app_language` setting key.
10. Browser language auto-detected on first launch (web only).
11. Language priority: persisted > browser > OS > zh.
12. `themeModeProvider` is a StateProvider<ThemeMode>.
13. `localeProvider` is a StateProvider<AppLocale>.
14. Settings screen watches both providers (live update).
15. Theme change mid-chat → chat screen re-renders correctly.
16. Language change mid-chat → chat strings translate (chat content preserved).
17. Locale picker shows native names (中文, English, 日本語, etc.).
18. Theme picker shows preview swatches.
19. RadioListTile dialog for language selection.

#### Exception Cases
20. Invalid persisted theme value → defaults to "system".
21. Invalid persisted language value → defaults to browser/OS.
22. Browser language not in supported set → falls back to zh.
23. Theme change during DB write → safe (theme is in-memory state).

---

### M23 — Settings: Learning Preferences & App Section

**Routes**: `/settings`
**Screen**: `SettingsScreen`

Correction strength (gentle/moderate/strict), TTS speed, content management
(enable/disable, daily count, persona picker), re-run onboarding, retake
placement, About dialog, app updates section.

#### Happy Path
1. "Learning" section → correction strength picker (gentle/moderate/strict).
2. "Learning" section → TTS speed slider (0.75× – 1.5×).
3. "Content Management" section → content enable/disable toggle.
4. "Content Management" → daily recommendation count (1-10, default 3).
5. "Content Management" → active teacher persona picker (3 personas).

#### Branch / Edge Cases
6. Correction strength persists via `correction_strength` setting.
7. TTS speed persists via `tts_speed` setting; applies via `TtsPlaybackService.setSpeed`.
8. Content toggle OFF → home content section hidden.
9. Daily count slider → 1-10 range; default 3.
10. Persona picker → 3 options (Mr. Sterling strict, Ms. Lily encourage, Coach Max humor).
11. "Re-run onboarding" tile → clears onboarding flag → `/onboarding`.
12. "Retake placement" tile → clears placement flag → `/placement`.
13. "About" tile → dialog with version + description.
14. About dialog shows `Version $kAppVersion`.
15. "App" section (web only) → "Check for updates" tile.
16. "Check for updates" → manual `checkNow()`; subtitle shows live state.
17. "Show install banner again" tile → `InstallPromptService.resetDismissal()`.
18. "App" section hidden on non-web.
19. Placeholder tiles marked "(coming soon)" (Interface Language, Export).

#### Exception Cases
20. Correction strength invalid value → defaults to "moderate".
21. TTS speed invalid → defaults to 1.0×.
22. Persona DB failure → falls back to default persona.
23. Check for updates 404 → "Up to date" or "Server unavailable" message.

---

### M24 — Review: SM-2 Rating & Filters

**Routes**: `/review`
**Screen**: `ReviewScreen`

SM-2 quality rating (Again/Hard/Good/Easy → 1/3/4/5) on due corrections.
Favorite-only FilterChip. Mastery badges. After rating, dashboard providers
invalidate.

#### Happy Path
1. `/review` renders list of due corrections.
2. Each card shows: original, corrected, type, severity, mastery badge.
3. Quality rating bar: Again / Hard / Good / Easy.
4. Tap "Good" → `Sm2Service.scheduleReview` + `updateCorrection`.
5. Card removed from "due now" list.
6. SnackBar shows next review time.
7. Occurrence-count badge (`×N`) renders when `occurrenceCount > 1`.

#### Branch / Edge Cases
8. "Again" (quality 1) → interval resets to 1 day.
9. "Hard" (quality 3) → interval stays small; EF decreased.
10. "Good" (quality 4) → interval grows; EF stable.
11. "Easy" (quality 5) → interval grows fast; EF increased.
12. `_ratingInFlight` Set guards against double-taps.
13. Favorite-only FilterChip → filters `is_favorite=1`.
14. Mastery badges: New / Learning / Familiar / Mastered / Expert.
15. `getDueCorrections` sorts by favourite + importance + least-reviewed + recency.
16. `getFavoriteCorrections` for favorites filter.
17. After rating, `reviewQueueProvider` invalidates.
18. After rating, `dueReviewQueueCountProvider` invalidates.
19. After rating, `abilityScoresProvider` invalidates.

#### Exception Cases
20. Empty review queue → "No items due" empty state.
21. DB failure during `updateCorrection` → card not removed; error snackbar.
22. Concurrent rating taps (rapid) → only first completes; others ignored.
23. Filtered (favorites) with no favorites → empty state.
24. SM-2 EF clamped to [1.3, 2.5] (no overflow).
25. SM-2 interval capped at 365 days (no infinite intervals).

---

### M25 — Progress: Dashboard, Heatmap & Trends

**Routes**: `/progress`
**Screen**: `ProgressScreen`

Mastery breakdown (New/Learning/Mastered), error type distribution, 7-day
activity chart, calendar heatmap (60 days), weekly trend chart, weak-area card.

#### Happy Path
1. `/progress` renders mastery breakdown.
2. Error type distribution (grammar/vocab/pronunciation/fluency).
3. 7-day activity chart (messages=cyan, corrections=orange).
4. Calendar heatmap (60 days, 4 intensity levels).
5. Weekly trend chart (bar chart + summary stat chips).
6. Weak-area card (type icon, description, frequency, severity).

#### Branch / Edge Cases
7. `statsProvider` invalidated on every entry (P0 fix).
8. `ref.invalidate(statsProvider)` in `didChangeDependencies` (not `build()`).
9. 7-day chart zero-fills missing days.
10. Heatmap 4 intensity levels based on duration.
11. Weekly trend summary: active days, avg minutes, correction count.
12. Weak areas scanned from all corrections (`analyzeWeakAreas`).
13. Weak areas upserted into `weak_areas` table.
14. `generateReviewSuggestions` produces prioritized actions.
15. `ProgressService.getHeatmapData` 60-day lookback.
16. Pull-to-refresh invalidates progress providers.
17. Empty state (no corrections) → "Start practicing to see progress".
18. Loading state → shimmer placeholders.
19. Error state → per-section error (not full-screen).

#### Exception Cases
20. `getAllCorrections()` replaced with SQL COUNT (P1 perf fix) → no OOM on large datasets.
21. DB failure → error state per section.
22. Very large correction count (>10000) → still fast (SQL aggregation).
23. Heatmap with no practice log → all gray dots.

---

### M26 — Pronunciation Detail & History

**Routes**: `/pronunciation/:sessionId`, `/history`
**Screens**: `PronunciationDetailScreen`, `HistoryScreen`

Pronunciation detail: overall score ring, per-phoneme breakdown, common errors,
trend chart. History: search/filter, metadata chips, session summary, "Score"
button to pronunciation detail.

#### Happy Path
1. `/pronunciation/:id` renders overall score ring.
2. Per-phoneme breakdown with IPA + avg score + occurrence count.
3. Phoneme color tags: green (good) / amber (fair) / red (poor).
4. Common errors list (5 most common, worst first).
5. Trend chart of recent pronunciation scores.
6. `/history` renders enriched session list.

#### Branch / Edge Cases
7. History search bar (full-text on topic).
8. History filter (active/archived/all).
9. Metadata chips per session (duration, message count, corrections).
10. Session summary display (truncated to 2 lines).
11. "Score" button → `/pronunciation/:sessionId`.
12. `getEnrichedSessionHistory` joins metadata.
13. `PronunciationReport` auto-built from `phoneme_score_sets` + `phoneme_scores`.
14. `ProgressService.buildPronunciationReport` from existing data.
15. `PhonemeScoreBand` enum (green/amber/red).
16. `PhonemeScorer` derives synthetic scores from pronunciation corrections.
17. `ChatBubble` color-tags words by score band.
18. Tapping a word → detail overlay with per-phoneme scores + A/B replay.
19. `deleteSession` cleans up phoneme rows (no orphans).

#### Exception Cases
20. No pronunciation data for session → "No pronunciation data" empty state.
21. No sessions in history → "No conversations yet" empty state.
22. Search with no matches → "No results for '<query>'".
23. Session metadata DB failure → metadata chips hidden; session still listed.
24. Phoneme score set references non-existent message → no detail overlay.

---

### M27 — Scenarios & Sentence Practice

**Routes**: `/scenarios`, `/practice`
**Screens**: `ScenariosScreen`, `SentencePracticeScreen`

10 structured scenarios (self_intro, order_coffee, book_hotel, phone_call,
ask_directions, social_icebreaker, job_interview, business_meeting, shopping,
doctor). Each ships 5-7 core expressions. Sentence practice: read expression,
record, get score.

#### Happy Path
1. `/scenarios` renders scenario cards (title, category, difficulty).
2. Tap scenario → starts conversation with that scenario.
3. Scenario prompt feeds into LLM system prompt.
4. `/practice` renders sentence practice screen.
5. Expression displayed → user records → STT transcribes → score shown.
6. Score < 80 → "Try again" CTA.

#### Branch / Edge Cases
7. 10 scenarios across all required topics.
8. Each scenario has 5-7 core expressions with zh translation.
9. Scenario tags (JSON array) render as chips.
10. Scenario goal (`interview`/`travel`/`daily`/`ielts`) visible.
11. Category filter (daily/business/travel/general).
12. Difficulty filter (A1/A2/B1/B2/C1/C2).
13. Scenario review queue (separate from correction review queue).
14. `archiveSession` syncs `scenario_review_queue` (averages item scores).
15. `startScenario` action carries scenario id.
16. Sentence practice expression audio URL playback.
17. `practice_type` field on scenario_items.
18. Practice score persists on `scenario_items.score`.
19. Daily recommendation count limits visible scenarios.

#### Exception Cases
20. No scenarios configured → "No scenarios yet" empty state.
21. Scenario DB failure → scenarios hidden; free-talk still works.
22. STT failure during sentence practice → "Try again" CTA.
23. Scenario with malformed tags JSON → tags hidden.

---

### M28 — Tutor Selection & Session Summary

**Routes**: `/tutor-selection`, `/summary/:sessionId`
**Screens**: `TutorSelectionScreen`, `SessionSummaryScreen`

6 predefined tutors (Emma/James/Alex/Professor Chen/Sarah/Dr. Miller).
Selection persists. Session summary: score, correction count, topic tags,
adaptive difficulty.

#### Happy Path
1. Chat header → "Tutor" tap → `/tutor-selection`.
2. 6 tutor cards render (name, style, avatar).
3. Tap tutor → `selected_tutor_id` persisted.
4. Returns to chat → header + avatar refresh.
5. Chat end → `/summary/:id` renders.
6. Summary shows: duration, message count, correction count, score.

#### Branch / Edge Cases
7. Tutor styles: Friendly, Professional, Casual, Strict, Exam Prep, Pronunciation.
8. `await profileRepo.setSetting('selected_tutor_id', tutor.id)` before pop.
9. `ChatScreen` reloads tutor identity on resume.
10. Tutor selection didn't refresh UI before P0 fix → now refreshes.
11. Summary auto-generated via `generateSessionSummary` heuristic.
12. Summary includes topic tags.
13. Summary includes adaptive difficulty level.
14. Summary "Review corrections" CTA → `/review`.
15. Summary "Practice again" CTA → new session with same scenario.
16. Session metadata (duration, counts) joined in summary.
17. `tutor-selection` reachable from chat header (not just onboarding).
18. Tutor card tap → visual selection state (highlight).
19. Long tutor style description → wraps; no clipping.

#### Exception Cases
20. No tutor selected → defaults to first tutor (Emma).
21. Tutor DB failure → fallback tutor; no error.
22. Summary DB failure → "Summary unavailable" message.
23. Session with 0 messages → summary shows "No activity".
24. Summary for archived session → still accessible via history.

---

### M29 — Project Space

**Routes**: `/projects`, `/project/:projectId`
**Screens**: `ProjectsScreen`, `ProjectDetailScreen`, `ProjectFormDialog`,
`ProjectCard`, `ProjectIconPicker`, `ProjectColorPicker`, `JoinProjectSheet`,
`ActivityTile`

Project CRUD with icon/color picker, activity feed, join sheet, links,
archive. `ProjectContentType` / `ProjectActivityType` round-trip in snake_case.

#### Happy Path
1. `/projects` renders project cards (name, icon, color, status).
2. "New Project" FAB → `ProjectFormDialog` opens.
3. Fill name + description + goal → icon picker → color picker → "Save".
4. Project created → appears in list.
5. Tap project card → `/project/:id` detail screen.
6. Detail screen: header, description, activity feed, links.
7. Activity feed shows recent project activities.
8. "Archive" action → project status → "archived".

#### Branch / Edge Cases
9. Icon picker: 30+ Material icons.
10. Color picker: 10 palette colors (`ProjectPalette`).
11. Project goal: interview/travel/daily/ielts.
12. Project status: active/paused/archived.
13. Project topics (JSON array) render as chips.
14. `ProjectContentType` (link/activity) round-trips in snake_case.
15. `ProjectActivityType` round-trips in snake_case.
16. `getProjectsForContent` raw query uses snake_case.
17. `JoinProjectSheet` for joining existing project.
18. Project links (URL + label) CRUD.
19. Project activities CRUD with type + timestamp.

#### Exception Cases
20. Empty project list → "Create your first project" CTA.
21. Project form validation: name required.
22. Project form validation: name max length.
23. Delete project → confirmation dialog.
24. Edit project → form pre-filled.
25. DB failure during create → error snackbar; retry available.

---

### M30 — App Banners, Version & Connectivity

**Routes**: global (`MaterialApp.router` builder)
**Widgets**: `AppBanners`, `_UpdateBanner`, `_InstallBanner`
**Services**: `VersionService`, `InstallPromptService`, `ConnectivityService`

Non-occluding banner overlay. `_MeasureSize` reports banner height; injects
into child's `MediaQuery.padding.top`. Route-aware suppression on `/onboarding`
and `/placement`.

#### Happy Path
1. App launches → `AppBanners` wraps router child.
2. Server has newer version → `_UpdateBanner` shows "X → Y" arrow.
3. Tap "Update" → `applyUpdate()` → SW waiting → `forceReload()`.
4. SW not waiting → `triggerSwUpdate()` + wait `onUpdateReady` (8s timeout) → reload.
5. PWA install available → `_InstallBanner` shows after 30s delay.
6. Tap "Install" → native prompt → accepted/dismissed.
7. iOS Safari → "Show steps" → 3-step Add-to-Home-Screen walkthrough.

#### Branch / Edge Cases
8. Banners never appear on `/onboarding` or `/placement` (route-aware suppression).
9. `_MeasureSize` injects height into `MediaQuery.padding.top` (AppBar shifts down).
10. Banner text `maxLines: 2` (no truncation on iPhone SE).
11. Version dismiss persists across sessions (keyed by version string).
12. Newer future version re-shows banner (different key).
13. SW-only dismissals are session-scoped (`_swDismissedThisSession`).
14. Visibility-gated polling (pauses when tab hidden, resumes + immediate check on resume).
15. 404 / error path clears server state (no phantom banner).
16. `swUpdateWaiting` preserved across 404 path (independent of server).
17. `compareVersions(a, b)` semver + build-metadata tiebreaker.
18. `ConnectivityService` watches `navigator.onLine` + online/offline events.
19. `isOfflineProvider` convenience provider for chat offline hint.

#### Exception Cases
20. Non-web platform → `platformUnsupported=true`; banners hidden.
21. SW not registered → `applyUpdate()` falls back to cache-bust reload.
22. `onUpdateReady` 8s timeout → reload anyway (best-effort).
23. Install prompt dismissed → persisted; "Show install banner again" tile in Settings.
24. In-app browser (Instagram/Facebook/LinkedIn/X/Snapchat) → iOS install false-positive excluded.
25. `GoRouterState.of` from outside router → wrapped in try/catch (no crash).

---

## Coverage Matrix

| Module | Happy | Branch | Exception | Total |
| ------ | ----- | ------ | --------- | ----- |
| M01 Onboarding              | 7  | 10 | 6  | 23 |
| M02 Placement               | 7  | 11 | 5  | 23 |
| M03 Chat: Text              | 8  | 11 | 8  | 27 |
| M04 Chat: Voice             | 7  | 12 | 8  | 27 |
| M05 Chat: Corrections       | 6  | 13 | 6  | 25 |
| M06 Chat: TTS               | 6  | 12 | 7  | 25 |
| M07 Chat: Continuous        | 5  | 14 | 4  | 23 |
| M08 Chat: Session Mgmt      | 7  | 12 | 5  | 24 |
| M09 Chat: Errors            | 6  | 13 | 6  | 25 |
| M10 Avatar: Idle            | 5  | 14 | 4  | 23 |
| M11 Avatar: Emotion         | 5  | 14 | 4  | 23 |
| M12 Avatar: Lip Sync        | 5  | 14 | 4  | 23 |
| M13 Profile: LLM CRUD       | 8  | 11 | 6  | 25 |
| M14 Profile: STT CRUD       | 7  | 12 | 5  | 24 |
| M15 Profile: TTS CRUD       | 7  | 12 | 5  | 24 |
| M16 Service Config          | 7  | 12 | 5  | 24 |
| M17 Voice Health            | 6  | 13 | 4  | 23 |
| M18 Home: Dashboard         | 7  | 12 | 5  | 24 |
| M19 Home: Streak            | 5  | 14 | 4  | 23 |
| M20 Home: Daily Plan        | 5  | 13 | 4  | 22 |
| M21 Home: Ability & Goals   | 5  | 14 | 4  | 23 |
| M22 Settings: Theme/Lang    | 5  | 14 | 4  | 23 |
| M23 Settings: Learning      | 5  | 14 | 4  | 23 |
| M24 Review: SM-2            | 7  | 12 | 6  | 25 |
| M25 Progress: Dashboard     | 6  | 13 | 4  | 23 |
| M26 Pronunciation & History | 6  | 13 | 5  | 24 |
| M27 Scenarios & Practice    | 6  | 13 | 4  | 23 |
| M28 Tutor & Summary         | 6  | 13 | 5  | 24 |
| M29 Project Space           | 8  | 11 | 5  | 24 |
| M30 Banners & Version       | 7  | 12 | 5  | 24 |
| **TOTAL**                   | **175** | **349** | **136** | **716** |

Every module has ≥22 cases (well above the ≥20 floor). The suite covers
**716 E2E test cases** across 30 feature points.

---

## Test Infrastructure

### Build

```bash
# From repo root
flutter build web --release --dart-define=E2E=true
```

The `E2E=true` dart-define activates:
- `lib/core/e2e/e2e_bridge_web.dart` (exposes `window.speakflowE2E.*` JS hooks)
- `lib/core/e2e/e2e_mock_services_web.dart` (Dart-side LLM/STT/TTS short-circuit)

### Run

```bash
cd e2e
npm install                       # one-time
npx playwright install chromium   # one-time (or `--with-deps`)
npm test                          # all projects, list reporter
npm run test:fast                 # chromium only (fastest feedback)
npm run test:all                  # all 4 browser projects
npm run test:mobile               # mobile-chrome project only
```

### Per-test pattern

```typescript
import { test, expect } from '@playwright/test';
import { setupE2EApp } from '../lib/setup';
import { capture } from '../lib/screenshots';
import { expectText, expectNoException } from '../lib/assertions';
import * as bridge from '../lib/e2e-bridge';
import { LLM_MOCKS, STT_MOCKS } from '../fixtures/fixtures';

test.describe('M03 — Chat: Text Messaging', () => {
  test.beforeEach(async ({ page }) => {
    await setupE2EApp(page, 'onboarded', { route: '/chat/test-session' });
  });

  test('HP-1: send a text message and receive streamed AI reply', async ({ page }) => {
    await bridge.seedChatSessions(page, [{ id: 'test-session', /* ... */ }]);
    await bridge.setMockLlmResponse(page, 'hello', LLM_MOCKS.greeting);
    await page.getByRole('textbox').fill('Hello!');
    await page.getByRole('button', { name: /send/i }).click();
    await expectText(page, LLM_MOCKS.greeting);
    await expectNoException(page);
    await capture(page, 'm03-hp1-send-text');
  });

  // ... 19+ more cases
});
```

### Screenshot review

Every happy-path test calls `capture(page, '<module>-<case-id>')` at the end.
Screenshots land in `e2e/screenshots/`. The Phase 5 review step eyeballs
each one to verify rendering quality (no clipped text, no dark-on-dark, etc.).

### Mocking layers (defense in depth)

1. **Dart-side short-circuit** (primary): `E2eMockServices.cannedLlmReply`
   returns canned responses; LLM/STT/TTS services never issue HTTP.
2. **HTTP intercept** (fallback): `e2e/lib/mock.ts` registers `page.route()`
   for all vendor endpoints; canned JSON / silent WAV returned.
3. **SQLite reset/seed** (deterministic state): `bridge.resetDb()` +
   `bridge.seed*()` write directly to SQLite via the E2E bridge.
