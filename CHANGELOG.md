# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### 3D virtual tutor + light/glass consistency + onboarding flow + voice chat flow

Conducted a comprehensive pass addressing 5 user requirements: (1) unify all
pages to light background, (2) iOS 26 Liquid Glass across all pages, (3) a
real 3D humanoid female AI tutor with 20 visemes + 20 gestures driven by
text/audio, (4) first-run + in-settings onboarding flow review, (5) natural
real-time voice conversation flow modelled on Praktika/Speak/ELSA Speak. A
temporary dev-plan checklist guided implementation; three review rounds
(correctness / UI-interaction / polish) and multi-pass static verification
were performed.

#### Added — 3D virtual tutor (workflow C)
- **Three.js + Ready Player Me GLB** with ARKit + Oculus Visemes morph
  targets, embedded via `HtmlElementView` (web) + `webview_flutter`
  (iOS/Android/macOS) — one shared `assets/3d/avatar.html` bundle for both
  platforms. WebGL GPU rendering (60fps, idle drops to 30fps); GLB streamed
  from RPM CDN (~2-5MB, cacheable); three.js ~150KB gzip from jsDelivr —
  minimal disk/traffic footprint.
- **20 visemes** (Oculus 15 + smile/laugh/sad/surprise/disgust) +
  **20 gestures** (idle/wave/nod/tiltHead/raiseHand/pointUp/thinkPose/
  openPalm/shake/bounce + crossArms/clap/thumbsUp/bow/handOnHip/adjustHair/
  lookAround/stretch/yawn/wink), driven by text (char→viseme, keyword→gesture)
  and synthesized audio amplitude.
- `lib/shared/widgets/virtual_character_3d.dart` (354 lines): conditional
  import selects web/mobile platform host; 8s isReady polling then painter
  fallback; `_AvatarMode` enum (loading/ready3d/fallback).
- `virtual_character_3d_web.dart` / `_mobile.dart` / `_platform.dart`:
  per-instance `AvatarHost` with `setState/setViseme/setGesture/
  setAudioLevel/isReady/buildView/dispose`. Web uses `js_util` eval bridge
  over an iframe; mobile uses `runJavaScript`.
- `virtual_character.dart`: `visemeForChar` + `gestureForKeyword` promoted
  to public static so the 3D widget reuses the same mapping as the painter
  fallback (single source of truth).
- `tts_playback_service.dart`: synthesized amplitude stream (50ms tick,
  slow envelope + fast jitter) drives the 3D avatar's jawOpen since
  just_audio doesn't expose real-time PCM amplitude.
- `chat_screen.dart`: `_CharacterPanel` now renders `VirtualCharacter3D`
  with the amplitude stream wired in (both sideBySide + compact layouts).

#### Changed — onboarding flow (workflow D)
- `placement_screen.dart`: wired `placement.*` i18n keys (D7); added Skip
  button (D9); removed `createSession` — lands on Home so the user opens a
  chat when ready (D10); light-theme text colors.
- `settings_screen.dart`: added "Re-run onboarding" tile (D14, clears
  onboarding + placement flags → /onboarding), "Retake placement" tile
  (D9), and a real About dialog with version + description (D12).
- `chat_screen.dart`: persistent voice-not-configured banner above the
  message list (D11) with tap-to-configure, replacing transient snackbars.
- `onboarding_screen.dart`: docs URL is now tappable via `url_launcher`
  (D4, underlined link).

#### Changed — voice chat flow (workflow E)
- **E1 auto-listen**: after TTS completes, in continuous mode the mic
  auto-rearms for hands-free conversation (Praktika/Speak pattern).
- **E2 barge-in**: tapping mic during TTS stops playback first so the user
  can interrupt the AI mid-sentence.
- **E3 decoupled loading/TTS**: `_autoplayTts` is now fire-and-forget;
  `_isLoading` clears as soon as the AI message is saved, so the input bar
  is immediately usable (TTS state tracked via `_playingMessageId`).
- **E5 continuous mode toggle**: a compact chip in the input bar flips
  auto-listen + barge-in on/off (per-session preference).
- **E11 AppError mapper** (`lib/features/chat/domain/app_error.dart`):
  maps exceptions to typed errors (auth/rate-limit/server/timeout/offline/
  mic-permission) with localized messages + Retry/Configure/Open-Settings
  actions.
- **E12**: all `_safeError(e)` SnackBars replaced with `_showAppError(e)`.
- **E13**: empty STT transcript now shows an actionable hint ("move closer
  to the mic / speak louder / quieter environment") instead of a bare error.
- **E16**: LLM request timeout reduced 60s → 30s for faster failure feedback.
- **E17**: `AppError.redact` strips sk-/Bearer/key patterns before any error
  text reaches the UI.

#### Changed — service config (workflow D)
- `service_config_screen.dart`: active profile's Delete is now disabled in
  the popup menu with a "switch active first" hint (D15) instead of
  surfacing the error only after confirmation.

### i18n + light-theme polish + virtual character rebuild + voice-first chat

Conducted a comprehensive pass addressing 8 user requirements:
onboarding contrast/skip/TTS-reuse/Deepgram-TTS/STT-TTS-URL/domestic
providers, browser-language auto-detection (zh/en/ja/ko/es/fr/pt) with
in-settings switching, light-theme UI overhaul (iOS26 + flat), a real
CustomPainter virtual character with 20 visemes + 10 gestures + text-
driven lip-sync, voice-first chat input, auto-play TTS on AI reply,
speech-to-text with inline grammar correction, and overall product
polish. Three review rounds (imports/i18n-keys/AppColors, cross-file
consistency, UI/interaction) were performed and all HIGH+MEDIUM issues
fixed.

#### Added — i18n infrastructure
- **Single-file localization system** `lib/core/i18n/app_localizations.dart`
  (~1620 lines): `AppLocale` enum (zh/en/ja/ko/es/fr/pt) + `AppLocalizations`
  class with `t(key)` / `tArg(key, args)` + `_translations` map (~150 keys
  per locale, zh fallback). `supportedLocales`, `delegate`, `isSupported`
  (fixed a bug where `isSupported` always returned true).
- **Browser language auto-detection** via conditional-import bridge
  (`browser_language_bridge_stub.dart` + `_web.dart` using
  `dart:js_interop` to read `navigator.language` / `navigator.languages`).
  Startup priority: persisted `app_language` > browser language > OS
  locale (PlatformDispatcher) > `AppLocale.zh`.
- **`localeProvider`** (StateProvider<AppLocale>) in `shared/providers.dart`,
  seeded via `ProviderScope.overrides` in `main()`. `MaterialApp.router`
  wired with `localizationsDelegates` (AppLocalizations + flutter
  Global*), `supportedLocales`, `locale`.
- **In-settings language switcher** with a RadioListTile dialog of 7
  AppLocales; persists `app_language` and updates the provider live.
- ~150 i18n keys covering onboarding/settings/chat/home/scenarios/
  review/progress/profile/common; 5 new keys this round
  (correction.type_grammar/vocabulary/pronunciation,
  common.default_profile_name, onboarding.docs). All user-facing strings
  across onboarding, settings, chat, home, scenarios, review, progress
  migrated to `t()`/`tArg()`.

#### Added — light theme completion
- `app_colors.dart`: new light-* fields (lightBgTertiary, lightBgSurface,
  lightGlassBgHover, lightAccentPrimary #5A4BD1, lightAccentSecondary,
  lightTextMuted, lightTextOnAccent, lightGlowPurple/Cyan/Green,
  lightGradientBg, lightGradientPrimary, lightBubbleAi/User/Correction).
  lightGlassBg 70%→80%; lightGlassBorder changed from invisible white to
  visible #1A000000.
- `app_theme.dart`: lightTheme completed with 8 component themes
  (card/input/elevated/outlined/text/icon/divider/snackBar) — all
  elevation:0, large radii (iOS26 flat style).
- All screens made theme-aware: Scaffold/Container backgrounds, dialog
  backgrounds, input bar, text field text/hint colors, character panel
  label, progress bar track — every hardcoded dark color that was
  invisible on light bg now has an isLight branch (chat_screen,
  home/scenarios/review/progress/history/tutor_selection, settings,
  virtual_character).

#### Added — virtual character rebuild (CustomPainter)
- `shared/widgets/virtual_character.dart` (~1090 lines) rewritten as a
  real human figure (head, hair, eyes, brows, nose, mouth, cheeks,
  torso, arms, hands) via CustomPainter.
- **20 visemes**: closed/slightOpen/smallOpen/mediumOpen/wideOpen/
  roundedSmall/roundedLarge/wide/flat/smile/smileOpen/frown/pucker/
  teeth/tongueUp/tongueOut/biteLip/openTeeth/oval/wideFlat.
- **10 gestures**: idle/wave/nod/tiltHead/raiseHand/pointUp/thinkPose/
  openPalm/shake/bounce.
- **Text-driven lip-sync**: `_visemeForChar` maps chars to visemes
  (vowels a/e/i/o/u, consonants m/b/p/f/v/l/n/t/d/s/z/c/r/th, CJK
  fallback). `_gestureForKeyword` maps keywords (你好/hello→wave,
  对/yes→nod, 嗯/hmm→thinkPose, 看/look→pointUp, 谢谢/thank→openPalm,
  不/no→shake, great/棒→raiseHand, default→bounce).
- 4 AnimationControllers (breath 3s, glow 1800ms, gesture 700-1400ms,
  viseme 90ms). Public API backward-compatible (tutorName/state/
  accentColor/size/showLabel + new optional speakingText).
- **Performance**: glow only runs when active (idle stays dim, saving
  per-frame repaints); viseme advances off `addStatusListener(completed)`
  — one tick per 90ms cycle instead of every animation frame.

#### Added — provider catalog expansion (domestic + Deepgram TTS)
- LLM +3 (all openaiCompatible, cn): volcengine_doubao, baichuan, yi.
- STT +3 (vendor, cn): volcengine_stt, xfyun_stt, tencent_stt.
- TTS +4: deepgram_tts (vendor, global, aura-asteria-en) with real
  implementation (POST {base}/v1/speak?model=..., Authorization: Token);
  volcengine_tts, xfyun_tts, tencent_tts (vendor, cn).
- All new providers satisfy `provider_catalog_test.dart` constraints.

#### Added — onboarding improvements
- "Skip for now" on welcome page (completes onboarding with no profiles)
  and on each service page.
- STT URL input field; TTS "Use same provider & key as STT" shortcut
  with a provider-id mapping (deepgram→deepgram_tts, etc.).
- STT/TTS custom providers always show URL input.
- Theme-aware contrast (heading/body/field/hint colors).

#### Added — voice-first chat
- `_ChatInputBar` now defaults to voice mode (`_InputMode.voice`): a 72px
  circular mic button with a pulse animation (turns red while recording).
  Text mode is a toggle away (keyboard icon top-right).
- AI reply auto-plays TTS (`_autoplayTts` on new AI message); the spoken
  text drives the character's lip-sync via `_speakingText`.
- User speech is transcribed and shown as a user bubble; grammar
  corrections render inline under the user message (`_CorrectionInline`).

#### Fixed — review round 3 (light-theme contrast + performance)
- chat_screen Scaffold / input bar / bottom sheet / text field were
  hardcoded to dark colors — invisible on light theme. All theme-aware.
- home/scenarios/review/progress/history/tutor_selection had hardcoded
  dark gradients — all branch to lightGradientBg.
- settings loading-state gradient now theme-aware.
- virtual character tutor-name label was dark-theme light text on a
  light card — now branches to lightTextPrimary.

#### Verification status
- Flutter/Dart toolchain is NOT available in this sandbox, so
  `flutter analyze` / `flutter test` could not be run. Verification was
  done by rigorous code review: all imports resolve, all i18n keys
  exist in the catalog, all AppColors fields exist, VirtualCharacter API
  matches, cross-file consistency confirmed (STT→TTS mapping identical
  in onboarding and profile_form; speakingText flow correct;
  localeProvider types match; new providers satisfy test constraints).
  The next session with a Flutter toolchain should re-run `flutter
  analyze` + `flutter test` before release.

---

### Comprehensive review pass (learning loop / UI / config / AI usage)

Conducted a 4-axis review (learning closed-loop, UI/art/interaction,
config/prompt/token efficiency, AI usage realism) and fixed all P0
blockers plus key P1 items. See `tmp_modification_plan.md` for the full
plan and `tmp_review1..4_*.md` for the underlying reviews.

#### Added — learning closed-loop (P0-1, P0-10)
- **SM-2 spaced repetition is now wired to runtime**. Previously
  `Sm2Service.scheduleReview` was only invoked by tests; `Correction`
  records were created with the default SM-2 fields and never advanced.
  - `ReviewScreen` now shows a quality rating bar
    (Again / Hard / Good / Easy → SM-2 quality 1 / 3 / 4 / 5) on each
    due correction. Tapping a button calls
    `Sm2Service.scheduleReview` + `ChatRepository.updateCorrection`,
    then removes the card from the "due now" list and shows a SnackBar
    with the next review time.
  - `_ratingInFlight` Set guards against double-taps while the
    `updateCorrection` write is in flight.
  - Occurrence-count badge (`×N`) renders when a correction has been
    seen more than once (driven by the v3 schema fields).
  - As a consequence, `LearningStatsService.masteredCount/learningCount`
    SQL now returns real values instead of always 0.
- **Progress dashboard: 7-day activity chart**. The `dailyActivity`
  field was queried but never rendered. Added a `_ActivityChart`
  stacked bar (messages = cyan, corrections = warm orange) that
  zero-fills missing days for the last 7 days, with tooltip + legend.

#### Added — UI / interaction (P0-8, P1-8, P1-10)
- **Recording button now pulses while recording**. Replaced the static
  record button with a `_RecordButton` StatefulWidget + custom
  `_RipplePainter` (sonar-pulse ripple animation). Removed the dead
  `GlowButton` class from `glass_widgets.dart` (~88 lines) — its visual
  pattern is now implemented inline where it is actually used.
- **Theme switching is now immediate**. Previously changing the theme
  in Settings required an app restart. Added a global
  `themeModeProvider` (StateProvider<ThemeMode>) in `shared/providers.dart`,
  seeded from the persisted preference via `ProviderScope.overrides` in
  `main()`. `SpeakFlowApp` is now a `ConsumerWidget` that watches the
  provider; `SettingsScreen` updates the notifier on save.
- **Placeholder entries are now visually marked**. "Interface Language"
  and "Export Learning Data" subtitles now read "(coming soon)" so users
  do not mistake them for bugs.

#### Fixed — correctness / first-run experience (P0-2, P0-3, P0-4)
- **Delete Session actually deletes now**. Both entry points
  (`history_screen.dart` and `chat_screen.dart` session options sheet)
  were no-ops — one showed a "Delete not implemented" SnackBar, the
  other just popped the sheet. Added `ChatRepository.deleteSession(id)`
  which deletes the session row plus its messages and corrections
  (cascade), and wired both UIs to it with an `AlertDialog` confirm.
- **Tutor selection now persists**. `TutorSelectionScreen._selectTutor`
  only called `context.pop(tutor.id)` and the caller never consumed the
  return value, so `selected_tutor_id` was never written from this page.
  Now `await profileRepo.setSetting('selected_tutor_id', tutor.id)`
  before popping, and `ChatScreen` reloads tutor identity on resume.
- **DeepSeek / Kimi default model names corrected**.
  `provider_catalog.dart` shipped `deepseek-v4-flash` (does not exist)
  and `kimi-k2.6` (unstable identifier) as defaults — new users hit a
  404 on their first chat. Changed to `deepseek-chat` and
  `moonshot-v1-8k` (official stable model identifiers).

#### Fixed — prompt / token efficiency (P0-5, P1-1, P1-2, P1-3)
- **`correction_strength` setting now affects the system prompt**.
  Settings saved the value but `TutorPromptBuilder.build` ignored it;
  the spine was identical for gentle / moderate / strict. Added a
  `correctionStrength` parameter and three spine variants:
  - `gentle` — only flag errors that clearly block understanding; let
    minor slips go.
  - `moderate` (default) — flag errors that affect meaning or naturalness.
  - `strict` — flag every error including style / collocation.
  The spine also now explicitly tells the tutor **not** to speak the
  explanation aloud (it goes only into the structured `corrections`
  JSON), keeping the spoken reply natural.
- **`max_tokens` aligned with the spine's "1-4 sentences" instruction**
  (1000 → 400). The previous value let the model ramble past the
  intended short-reply budget.
- **Removed the per-turn duplicate correction instructions**. The
  `corrections` JSON schema was re-sent on every assistant turn via
  `_buildMessages`, costing ~180 tokens/turn. Moved the contract into
  the system prompt (it is byte-identical across turns, so providers
  that support prompt caching can cache it) and removed the duplicate
  from `LlmService`.
- **Unified the correction strategy between Spine and LlmService**.
  The spine said "give a one-line explanation in your reply" while
  `LlmService` said "explanation goes in the JSON" — contradiction.
  Decision: the spoken reply stays natural and does **not** inline
  explanations; structured explanations live only in the `corrections`
  JSON, surfaced as UI cards. Updated the spine wording accordingly.

#### Fixed — settings wiring (P0-6)
- **`tts_speed` global setting now applies to playback**. Settings
  saved the value but `TtsService.synthesize` only used `profile.speed`,
  so the global control did nothing. Added `TtsPlaybackService.setSpeed`
  (just_audio `setSpeed`) and `ChatScreen._loadTtsSpeed()` reads the
  setting on screen entry and applies it. Player-side `setSpeed` is
  used (no re-synthesis, no extra tokens).

#### Fixed — performance (P0-7, P0-9, P1-11)
- **Input keystrokes no longer rebuild the entire ChatScreen**.
  `TextEditingController.addListener(setState)` was rebuilding the
  whole screen (and its child message list) on every keystroke.
  Removed the listener; the send button is now wrapped in a
  `ValueListenableBuilder<TextEditingValue>` so only the button
  opacity toggles. Combined with the next fix, typing is now O(1)
  per keystroke instead of O(N).
- **Corrections are no longer re-queried on every chat rebuild**.
  `_ChatMessageList` used a `FutureBuilder` that ran
  `getAllCorrections()` on every rebuild (i.e. on every keystroke
  before the previous fix). Replaced with a session-scoped
  `_correctionsByMessageProvider` (FutureProvider.family) that caches
  the result and is only invalidated after a new correction is saved.
  Added `ChatRepository.getCorrectionsForSession(sessionId)` for the
  scoped query.
- **Chat history is now capped** to the last 40 messages (~20 turns)
  via `ChatRepository.getMessages(limit: 40)`. Prevents the O(N²) token
  growth that would otherwise blow the context window in long
  sessions.
- **Corrections are de-duplicated on save**. Previously every chat
  turn that contained the same error inserted a new row. Added
  `ChatRepository.saveCorrectionDedup()` which matches on
  `(original, corrected, type)` and, on hit, increments
  `occurrenceCount` and updates `lastSeenAt` instead of inserting.
  `ChatScreen._sendMessage` now uses this path.

#### Tests
- `test/tutor_prompts_test.dart`: added a new
  `TutorPromptBuilder.build — correctionStrength` test group (7 cases)
  covering gentle / moderate / strict variants, case-insensitivity,
  unknown-strength fallback, that the corrections JSON contract appears
  exactly once in the spine, and that the spine tells the tutor not to
  speak the explanation aloud.

#### Verification status
- **Static review**: every modified file was re-read after the edit and
  checked for syntax / type / import correctness against the plan.
- **Existing tests**: `test/sm2_service_test.dart`,
  `test/correction_model_test.dart`, `test/llm_service_test.dart`,
  `test/provider_catalog_test.dart` were re-read to confirm the
  changes do not break their assumptions; the new
  `correctionStrength` tests were added to `tutor_prompts_test.dart`.
- **Compile verification** (run this session after installing Flutter
  3.44.4 + Dart 3.12.2 into the sandbox):
  - `flutter analyze`: **0 errors / 0 warnings**, 25 pre-existing
    `info`-level lints (unchanged from before this pass). One real
    compile error was found and fixed during this step —
    `_correctionGuidance` in `tutor_prompts.dart` used line-continuation
    backslashes inside a normal `'...'` string, which Dart parsed as
    multiple unterminated string literals; rewrote the three returns as
    triple-quoted `'''...'''` strings.
  - `flutter test`: **all 78 tests pass** (1 pre-existing failure in
    `provider_catalog_test.dart` — the test asserted every catalog entry
    has a non-empty `defaultBaseUrl`, but the `custom` escape-hatch
    entry is intentionally empty; updated the test to skip `custom`).
  - `flutter build web --release`: **succeeds** —
    `✓ Built build/web` in ~85s (42 MB output). Only a Wasm dry-run
    warning about `flutter_secure_storage_web` using `dart:html` (this
    is a pre-existing third-party limitation, not introduced by this
    pass; JS build still succeeds).
  - `flutter build apk --release`: **not completed** — the Android SDK
    was installed (platform-tools, platforms;android-34, build-tools
    34.0.0) and licenses accepted, but the Gradle wrapper could not
    download the Gradle 9.1.0 distribution (~130 MB) within the
    session's network budget. This is an environment limitation, not a
    code issue — the same source tree built APKs successfully in prior
    sessions. The next session with a warm Gradle cache should re-run
    `flutter build apk --release` and `flutter build ios --no-codesign`
    before release.

---

### iPhone / iPad responsive + SPA / PWA pass

Conducted a focused pass on (1) iPhone/iPad responsive adaptation
across portrait/landscape and screen-size classes (no hard-stretch —
each form factor gets its own layout regime), and (2) SPA-ification of
the web build (offline-first shell, real version-check + update
mechanism, install-prompt guidance). Three review rounds were
performed; see the commit message for the per-round breakdown.

#### Added — iPhone / iPad responsive
- **Centralized form-factor classification** in
  `lib/core/util/responsive.dart`: a `FormFactor` enum
  (phone / tablet / desktop) classified by the *long edge* so an iPad
  reports the same form factor in portrait (768×1024) and landscape
  (1024×768). `shouldUseSideBySide`, `shouldHideStackedCharacterPanel`,
  `characterSize`, `characterPanelHeight`, `gridColumnCount`,
  `statCardColumnCount`, `bubbleMaxWidthFraction`, `useBottomNav`,
  `useNavRail`, `minTapTarget` helpers drive per-screen layouts.
- **iPad mini portrait stacks instead of side-by-side** — at 768pt
  wide, a 280pt panel + 488pt chat feels cramped, so portrait tablets
  <900pt stack the character panel above the chat. Landscape tablets
  (≥1024pt) and portrait tablets ≥900pt keep side-by-side.
- **iPhone landscape short viewport handling** — at ~390pt tall the
  stacked character panel eats half the screen, so it's hidden
  entirely and the chat breathes; the AppBar still identifies the
  tutor.
- **NavRail SafeArea** fix — `MainShell` has no AppBar to consume the
  top inset, so `_SideNavRail` now uses `SafeArea(child: …)` (top:
  true) instead of `SafeArea(top: false, …)`. Brand mark + nav items
  no longer hide under the status bar on iPad.
- **`_StatCard` overflow fix** — value Text wrapped in `FittedBox` +
  `maxLines: 1` so large mastery counts don't clip on iPhone SE.
- **`_QuickActionGrid` uses `LayoutBuilder`** instead of
  `MediaQuery.sizeOf(context).width` so card sizing is correct inside
  the outer `Padding(EdgeInsets.all(AppSpacing.lg))` (was double-
  subtracting the horizontal padding).
- **Background gradient moved outside `ConstrainedBox`** on
  `progress_screen`, `history_screen`, `tutor_selection_screen` —
  previously the gradient only spanned ~1040pt in the center of an
  iPad landscape (1366pt), leaving bare scaffold sides. Now the
  gradient covers the full Scaffold body and only the inner content
  is constrained.
- **iOS HIG 44pt minimum touch targets** enforced on banner action
  buttons, banner dismiss, record button, send button, listen button,
  rating buttons via `Responsive.minTapTarget`.

#### Added — SPA / PWA shell
- **`web/manifest.json`** — full PWA manifest: name/short_name
  SpeakFlow, theme_color/background_color #0A0E1A (brand deep-space-
  blue), `display: standalone`, `display_override:
  ["window-controls-overlay", "standalone", "minimal-ui"]`,
  `orientation: "any"`, shortcuts (Free Talk / Review / Scenarios),
  192/512 icons + maskable variants.
- **`web/index.html`** — complete rewrite with brand splash
  (pulsing logo + wordmark + tagline + animated dots, safe-area aware
  via `env(safe-area-inset-*)`), `viewport-fit=cover` for notch /
  Dynamic Island, theme-color meta, apple-mobile-web-app-* meta,
  apple-touch-icon, pre-Flutter bridge scripts (`version_check.js` +
  `install_prompt.js`, deferred), `flutter-first-frame` listener
  removes splash, **15s safety fallback** `setTimeout(_removeSplash,
  15000)` so the splash never blocks forever if Flutter stalls.
- **`web/version.json`** — server-side version marker
  (`version`, `buildTime`, `commit`, `notes`) polled by the client
  every 5 min.
- **`web/version_check.js`** — SW update bridge on
  `window.__speakflowUpdate`: `hasWaitingSW()`,
  `onUpdateReady(cb)`, `forceReload()` (posts `SKIP_WAITING` to
  waiting SW, then cache-bust reloads with `?sf_refresh=<ts>`,
  cleans the URL via `history.replaceState` on the reloaded page),
  `triggerSwUpdate()` (calls `registration.update()`),
  `onVisibilityChange(cb)` (real visibility changes only — no
  redundant immediate fire on subscribe).
- **`web/install_prompt.js`** — PWA install bridge on
  `window.__speakflowInstall`: `canPromptNative()`,
  `promptNative()` (returns Promise<'accepted'|'dismissed'|
  'unavailable'>), `isIOSSafari()` (includes iPadOS 13+ MacIntel
  heuristic, excludes in-app browsers like Instagram/Facebook/
  LinkedIn/X/Snapchat), `isStandalone()`,
  `onAvailabilityChange(cb)`. Captures `beforeinstallprompt`,
  prevents the mini-infobar, stashes the deferred event.

#### Added — version check + real update mechanism (Dart side)
- **`lib/core/services/version_service.dart`** —
  `VersionService extends StateNotifier<VersionState>`:
  - Polls `/version.json?ts=<cache-buster>` every 5 min.
  - **Visibility-gated polling** — pauses the timer when the tab is
    hidden, resumes + fires an immediate check on resume.
  - **404 / error path clears server state** so a stale successful
    poll doesn't leave a phantom banner for a version that no longer
    exists. SW signal (`swUpdateWaiting`) is preserved across this
    path (independent of the server).
  - **`compareVersions(a, b)`** — semver comparison with build-
    metadata tiebreaker (`1.0.0+2 > 1.0.0+1`, `1.0.1 > 1.0.0+99`).
  - **`applyUpdate()`** — two-case: if SW already waiting →
    `forceReload()`; else → `triggerSwUpdate()` + wait for
    `onUpdateReady` (8s Completer timeout) + `forceReload()`. This
    avoids the race where a reload fires before the SW has downloaded
    the new shell.
  - **`dismissUpdate()`** — server-version dismissals persist across
    sessions (keyed by version string, so a *newer* future version
    re-shows the banner). SW-only dismissals are session-scoped
    (`_swDismissedThisSession` flag) because the SW is still waiting
    and `hookSW` re-fires `onUpdateReady` on next page load.
- **`lib/core/services/install_prompt_service.dart`** —
  `InstallPromptService extends StateNotifier<InstallPromptState>`:
  30s delay timer before showing the banner (so first-time visitors
  aren't ambushed), persisted dismissal, `resetDismissal()` so users
  who dismissed by mistake have an undo path (wired up from Settings).
  Reports `platformUnsupported=true` on non-web so the banner is
  hidden.
- **`lib/core/services/connectivity_check.dart`** —
  `ConnectivityService extends StateNotifier<bool>` for online/offline
  detection on web (`navigator.onLine` + online/offline window
  events). `isOfflineProvider` convenience provider.
- **Conditional-import bridge pattern** — `*_stub.dart` +
  `*_web.dart` pairs for version / install / connectivity bridges so
  the same service compiles on all platforms. Web variants use
  `dart:js_interop` (`@JS` annotations, `.toJS` / `.toDart`); stubs
  are no-ops.
- **`lib/shared/widgets/app_banners.dart`** — non-occluding banner
  overlay system:
  - `_MeasureSize` (`SingleChildRenderObjectWidget` +
    `RenderProxyBox`) reports banner height during `performLayout()`
    via `scheduleMicrotask` (no post-frame-callback rebuild churn).
  - The measured height is injected into the child's
    `MediaQuery.padding.top` so the Scaffold/AppBar shifts down —
    taps land on the AppBar instead of the banner.
  - **Route-aware suppression**: banners never appear on
    `/onboarding` or `/placement` (first-run full-screen flows with
    no AppBar).
  - `_UpdateBanner` — shows `currentVersion → serverVersion` arrow.
  - `_InstallBanner` — native: "Install" button; iOS: "Show steps"
    opens a modal bottom sheet with a 3-step Add-to-Home-Screen
    walkthrough.
  - Banner text `maxLines: 2` so the version detail doesn't truncate
    on iPhone SE (320pt); the `_MeasureSize` reporter handles the
    height change automatically.
- **`lib/main.dart`** — `AppBanners` lives inside
  `MaterialApp.router`'s `builder` (not wrapping it from outside) so
  its context is within the GoRouter subtree — that's what lets
  `GoRouterState.of(context)` work for route-aware suppression.

#### Added — chat offline hint
- **`lib/features/chat/presentation/screens/chat_screen.dart`** —
  `_ChatInputBar` is now a `ConsumerWidget` that watches
  `isOfflineProvider`; when offline, an `_OfflineHint` banner
  (cloud_off icon, warning color) renders above the input Row so the
  user knows their next send will fail until connectivity returns.

#### Added — Settings: App section
- **`lib/features/settings/presentation/screens/settings_screen.dart`**
  — new `_AppSection` ConsumerWidget with:
  - **"Check for updates"** tile — manual `checkNow()` with live
    state in the subtitle (Checking… / New version X available / Up
    to date (server: X) / Tap to check now) + SnackBar feedback.
  - **"Show install banner again"** tile — calls
    `InstallPromptService.resetDismissal()` so users who dismissed
    the install banner can re-trigger it. Only rendered when
    `installState.hasDismissed && !installState.isStandalone`.
  - Whole section hidden on non-web (providers report
    `platformUnsupported`).
- Removed the "Interface Language" and "Export Learning Data"
  placeholder tiles — they read as real tappable affordances but
  only showed a "coming soon" SnackBar, which felt like a bug.
  They'll re-add when the real features land.
- "About → SpeakFlow" subtitle now shows the real bundled version
  (`Version $kAppVersion`) instead of a hardcoded `1.0.0`.

#### Fixed — Round 3 review (HIGH severity)
- **`GoRouterState.of(context)` from outside `MaterialApp.router`** —
  moved `AppBanners` into `MaterialApp.router`'s `builder` and
  wrapped `GoRouterState.of` in try/catch (the call throws when
  rendered before the router attaches). Without this the app would
  crash on startup.
- **Double keyboard inset in `_ChatInputBar`** — the Scaffold has
  `resizeToAvoidBottomInset: true` (which shrinks the body by
  `viewInsets.bottom`) AND the input bar was manually adding
  `viewInsets.bottom` as padding, causing the text field to float
  ~340pt above the keyboard on mobile web. Now uses
  `safeBottom + AppSpacing.md` only.
- **Missing favicons** — `index.html` referenced `favicon.png` and
  `favicon.svg` that don't exist (404s). Repointed to the existing
  `icons/Icon-192.png` and `icons/Icon-512.png`.
- **Tutor selection didn't refresh chat UI** — `context.push(
  '/tutor-selection')` was fire-and-forget, so after picking a new
  tutor the AppBar title + character panel kept showing the old one
  until the user left & re-entered the chat. Now `await`s the push
  and calls `_loadTutorIdentity()` on resume.
- **PWA manifest shortcuts were no-ops** — `/?action=review` and
  `/?action=scenarios` landed on the home screen and were ignored.
  Added a `redirect` in `AppRouter` that maps `action=review` →
  `/review` and `action=scenarios` → `/scenarios`.

#### Fixed — Round 3 review (MEDIUM severity)
- **`statsProvider` stale on `ProgressScreen`** — added
  `ref.invalidate(statsProvider)` on every entry so stats refresh
  after the user reviews corrections on `ReviewScreen`.
- **In-app browser false-positive for iOS install** — `isIOSSafari()`
  now excludes Instagram / Facebook / LinkedIn / X / Snapchat in-app
  browsers (their Share sheet doesn't surface "Add to Home Screen"
  usefully).
- **Redundant immediate `checkNow()` on page load** —
  `version_check.js`'s `onVisibilityChange` no longer fires the
  callback once on subscribe (the Dart side's own `_init()` already
  does an initial check, so this was a redundant double-poll on
  every page load).
- **`location.reload(true)` is deprecated + `?sf_refresh=` lingered
  in URL** — `forceReload()` now uses `history.replaceState` to drop
  the cache-bust param on the reloaded page, and calls
  `location.reload()` without the deprecated `forceReload` argument.
- **Confusing shared-preferences key** —
  `sf_install_last_version_dismissed` (which actually stores the
  *version-update* dismissal, not the install-prompt dismissal)
  renamed to `sf_version_last_dismissed` for unambiguous ownership.

#### Tests
- `test/version_service_test.dart` (new, 14 tests): `compareVersions`
  equality / major-dominates / minor / patch / build-tiebreaker /
  semver-precedence / missing-patch / non-numeric / real-world
  ordering; `VersionState.copyWith` preserves `currentVersion` /
  preserves unspecified fields / defaults are sane; `kAppVersion`
  default format.

#### Verification status
- `flutter analyze`: **0 errors / 0 warnings**, 25 pre-existing
  `info`-level lints (unchanged).
- `flutter test`: **all 92 tests pass** (78 prior + 14 new
  `version_service_test.dart`).
- `flutter build web --release`: **succeeds** — `✓ Built build/web`
  (~47s). All PWA assets present in `build/web/`: `manifest.json`,
  `version.json`, `version_check.js`, `install_prompt.js`,
  `flutter_service_worker.js`, icons. Wasm dry-run warning about
  `flutter_secure_storage_web` is pre-existing and unrelated.

---

### Earlier in [Unreleased]

### Added
- Cloud sync (optional, deferred to future version)

### Fixed
- **Frontend compilation errors** (introduced in f59ca6c):
  - `service_config_screen.dart`: build method was missing the closing `)`
    for the `Center` widget, leaving an unbalanced bracket chain and an
    "Expected to find ')'" analyzer error.
  - `profile_form_screen.dart`: build method had a misaligned bracket chain
    (Scaffold/Center/ConstrainedBox/SingleChildScrollView/Form/Column) and
    was missing one `)` to close the `Center` widget; indentation re-aligned.
  - `stt_service.dart` & `tts_service.dart`: `ProviderKind` was undefined
    because `profile_models.dart` imports but does not re-export
    `provider_catalog.dart` (Dart imports are non-transitive). Added the
    explicit `import '../../profile/domain/provider_catalog.dart';` to both
    services, resolving 10 `Undefined name 'ProviderKind'` errors.
- After fixes, `dart analyze lib/` reports 0 errors / 0 warnings (only
  pre-existing `info`-level lints remain).

### Verified
- Web: `flutter build web --release` succeeds (✓ Built build/web, ~87s).

---

## [0.8.0] - 2026-06-28

### Added
- **Virtual Character**: Animated AI tutor placeholder
  - Breathing animation (gentle scale pulse)
  - Glow effect with state-based colors
  - State indicators (idle/listening/thinking/speaking)
  - Integrated into ChatScreen

---

## [0.7.0] - 2026-06-28

### Added
- **Multi-role Tutor Selection**: 6 predefined AI tutors
  - Emma (Friendly): warm, encouraging, patient
  - James (Professional): structured, business-focused
  - Alex (Casual): like talking to a friend
  - Professor Chen (Strict): detail-oriented, high standards
  - Sarah (Exam Prep): IELTS/TOEFL specialist
  - Dr. Miller (Pronunciation): phonetics expert

- TutorSelectionScreen: Visual selection interface
- TutorRepository: Tutor management with default fallback

---

## [0.6.0] - 2026-06-28

### Added
- **Learning Reports + Progress Tracking**:
  - LearningStatsService: Comprehensive statistics
  - ProgressScreen: Visual progress dashboard
  - Mastery breakdown (New/Learning/Mastered)
  - Error type distribution (grammar/vocabulary/pronunciation)
  - Daily activity tracking (last 7 days)
  - Due for review count

- Home Screen: Added Learning Progress quick action

---

## [0.5.0] - 2026-06-28

### Added
- **Animation polish**: flutter_animate for smooth entry animations
  - Home header: fade-in + scale animation
  - Quick action cards: staggered fade-in + slide
  - ShimmerBox: real shimmer animation

### Fixed (UI Review)
- TTS play button now wired to actual playback method
- Onboarding redirect in GoRouter (un-onboarded users sent to /onboarding)
- textMuted contrast improved (#5A6478 -> #7A8494, meets WCAG AA 4.5:1)
- Record button: tap instead of long-press + tooltip for discoverability

### Fixed (Business Review)
- SM-2: easinessFactor + intervalDays fields added to Correction model
- SM-2: proper interval calculation using persisted EF across reviews
- Secure Storage: API keys stored in Keychain/EncryptedSharedPrefs (not plaintext SQLite)
- Profile switching: wrapped in database transaction (atomic)
- Active profile deletion prevented
- LLM: null-safe API response parsing
- LLM: pronunciation typo fixed in system prompt
- STT/TTS: Azure region configurable via extraConfig
- TTS: SSML rate uses proper percentage format
- TTS: XML entity fix (&apos; -> &#39;)
- All error messages now include response body for debugging

---

## [0.3.0] - 2026-06-28

### Added
- **SM-2 Spaced Repetition Service**:
  - Quality-based scheduling (0-5 rating)
  - Easiness factor adjustment
  - Mastery level tracking (New/Learning/Familiar/Mastered/Expert)
  - Next review time calculation

- **Review Screen Enhancement**:
  - Mastery level badges with color coding
  - Next review time display
  - Review session creation

---

## [0.2.0] - 2026-06-28

### Added
- **LLM Service**: OpenAI-compatible API with correction extraction
  - Automatic grammar/vocabulary/pronunciation error detection
  - Correction extraction from ```corrections JSON blocks
  - Model fetching support
  - 30s timeout with proper error handling

- **STT Service**: Multi-provider speech-to-text
  - Deepgram (recommended)
  - OpenAI Whisper
  - Google Cloud Speech
  - Azure Speech

- **TTS Service**: Multi-provider text-to-speech
  - Fish Audio (recommended)
  - ElevenLabs
  - OpenAI TTS
  - Azure TTS (SSML support)

- **Chat Screen**: Connected to real LLM API
  - Dynamic system prompts from scenarios
  - Automatic correction recording
  - Error handling with user feedback

---

## [0.1.0] - 2026-06-28

### Added
- Flutter 3.44.4 project with macOS, Web, iOS, Android support
- Project structure: core/, features/, shared/, assets/
- Theme system: AppColors, AppTextStyles, AppTheme (dark/light)
- Glassmorphism UI components: GlassCard, GlowButton, StatusPill
- 3-Profile system: LLM, STT, TTS profile management
- Database layer: SQLite with sqflite
- Navigation: GoRouter with bottom nav shell
- Feature modules:
  - Chat: Home, Chat, Scenarios, Review screens
  - Profile: Service config, Profile form screens
  - Settings: Settings screen with sections
  - Onboarding: Welcome + API key setup + Placement test
- Default scenarios: Free Talk, Restaurant, Airport, Job Interview, etc.
- Riverpod state management
- Web build verified successful

---

## [0.1.0] - 2026-06-28

### Added
- Initial project setup and specification document (`projects.md`)
- Agent workflow documentation (`agent.md`)
- `.gitignore` with OS, IDE, Claude Code, and CodeGraph exclusions
- CodeGraph initialization (`.codegraph/`)

#### Product Specification (`projects.md`)
- **Product positioning**: AI English speaking practice app with virtual tutor
- **Core features spec**:
  - Main practice interface with AI character + chat area
  - Dialogue practice modes (free talk, scenario-based)
  - Smart correction strategy (Praktika-style natural restatement)
  - Review mode with SM-2 spaced repetition
  - AI provider Profile system (OpenAI-compatible protocol)
  - Session continuity (resume previous topics)
- **STT/TTS strategy** (updated from local models):
  - Default: System built-in (Apple Speech / Android SpeechRecognizer / Web Speech API)
  - Optional upgrade: Deepgram (STT), Fish Audio / ElevenLabs (TTS)
  - Zero configuration, zero cost by default
- **UI design specification**:
  - Design language: Glassmorphism + platform adaptive
  - iOS/macOS: Liquid Glass style (iOS 26)
  - Android: Material You + glass effect
  - Color system: Deep space blue gradient, purple/cyan dual accent
  - Chat bubble styles (AI= purple, user= cyan, correction= green)
  - Recording button with pulse glow animation
  - AI state indicator animations (listening/thinking/speaking)
  - Animation specifications (page transitions, bubble appearance, etc.)
- **Data architecture**: SQLite + system Keychain for API keys
- **Technical stack**: Flutter 3.x + Dart
- **Development plan**: 5 phases (MVP → Learning Loop → Virtual Character → Launch → Iteration)
- **Cost estimation**: $0 operational cost (user-supplied API keys)
- **Risk assessment**: 8 identified risks with mitigation strategies

#### Competitive Analysis (新增)
- **流利说深度分析**:
  - 产品矩阵：流利说英语、懂你英语A+、雅思、阅读、企业版
  - AI自适应学习系统：定级测试→自适应路径→Level 1-8分级
  - 纠错机制：音素级发音评分、颜色标识、ETS认证
  - 学习设计：15-20分钟碎片化、闯关模式、艾宾浩斯复习
  - 商业模式：C端订阅 + B2B企业培训
- **可栗口语分析**:
  - GPT大模型驱动的自然对话（非脚本式）
  - 现代UI设计，对话自由度高
- **咕噜口语分析**:
  - AI角色扮演 + 场景化练习
  - 游戏化场景选择，低心理门槛
- **竞品对比**：11维度对比表（AI技术、对话方式、发音评估、纠错策略等）
- **差异化定位**：6个核心差异点（学习闭环、3-Profile、虚拟外教、自然纠正等）

#### 3-Profile 系统设计（重构）
- **统一服务配置**：LLM / STT / TTS 三套独立 Profile，统一管理界面
- **云端 STT 供应商**：Deepgram（首推）、OpenAI Whisper、Google Cloud Speech、Azure Speech
- **云端 TTS 供应商**：Fish Audio（首推）、ElevenLabs、OpenAI TTS、Azure TTS
- **为什么不用系统内置 STT/TTS**：初学者发音不准、语法错误多、中英混说，系统 STT 无法胜任
- **用户成本**：~$2.5-6/月（中度使用），平台零运营成本

#### Design Reference (`docs/design-reference.md`)
- **Design inspiration sources**:
  - Glassmorphism, iOS 26 Liquid Glass, Vercel Geist, Shadcn/ui
  - AI app UI references (ChatGPT, Claude.ai, Perplexity, Praktika, Speak)
- **Design systems reference**:
  - Radix Colors, Fluent UI Acrylic, IBM Carbon
  - awesome-design-systems (5000+ stars), awesome-flutter (40k+ stars)
- **Glassmorphism implementation guide**:
  - Complete Design Tokens (dark/light mode parameters)
  - Flutter `BackdropFilter` implementation code
  - Platform-specific notes (iOS/Android/Web/Performance)
- **Color system**:
  - 16-color complete palette + semantic mapping
  - 12-level gray scale (Radix reference)
  - Special effects colors (glow purple/cyan/green)
- **Typography**: Inter/SF Pro, 6-level font size hierarchy
- **Spacing & radius**: 4px base spacing system, tiered radius specs
- **Flutter package recommendations** (2026 latest versions):
  - `liquid_glass_widgets` v0.19.1 — iOS 26 Liquid Glass UI kit (primary)
  - `shadcn_ui` v0.55.0 — Shadcn-style components (931 likes)
  - `forui` v0.23.0 — Minimal Shadcn-style components (407 likes)
  - `flex_color_scheme` v8.4.0 — Material 3 theme generator (Flutter Favorite)
  - `flutter_animate` v4.5.2 — Declarative animations (Flutter Favorite)
  - `lottie` v3.4.0 — Lottie animation player
  - `shimmer` v2.0.0 — Skeleton loading shimmer effect
  - `animated_text_kit` v4.2.2 — Text animations
  - `dynamic_color` v1.8.1 — Android Dynamic Color support
- **Animation reference**:
  - Recording interaction (idle/pressed/released states)
  - AI state indicator animations
  - Page transition specifications
- **Design tools & resources**: Glassmorphism generator, Radix Colors, Realtime Colors, Figma Community, LottieFiles, Heroicons, Lucide Icons
- **Accessibility**: WCAG AA contrast, animation disable support, touch target sizes

### Changed
- STT/TTS: Replaced local model approach (SenseVoice/faster-whisper/Kokoro/CosyVoice) with system-default + optional cloud upgrade strategy
- Product differentiation: Updated from "fully local deployment" to "zero config, zero cost by default"
- Tech stack: Added `liquid_glass_widgets` for glass effects, removed local model dependencies
- Cost estimation: Simplified to $0 operational cost (user-supplied keys + system built-in STT/TTS)
- Risk assessment: Updated for new STT/TTS strategy and Glassmorphism performance considerations

### Removed
- Local model STT engines: SenseVoice, faster-whisper
- Local model TTS engines: Kokoro TTS, CosyVoice
- References to local Python model setup and ONNX Runtime

---

## Commit History

| Hash | Date | Message |
|------|------|---------|
| `192a1ba` | 2026-06-28 | init: project setup with spec and agent workflow docs |
| `e8a9feb` | 2026-06-28 | docs: update STT/TTS strategy, add UI design spec and design reference |
| `7f00852` | 2026-06-28 | docs: update Flutter packages to 2026 latest versions |
| `46d8f5b` | 2026-06-28 | docs: add CHANGELOG.md |
| `e1f9bdf` | 2026-06-28 | docs: add deep competitive analysis of 可栗口语/咕噜口语/流利说 |
| `149a210` | 2026-06-28 | docs: update CHANGELOG with competitive analysis details |
| `e456956` | 2026-06-28 | docs: add level placement test and game-style scene selection |
| `700d120` | 2026-06-28 | refactor: redesign to unified 3-Profile system |
| `c53c983` | 2026-06-28 | feat: Stage 1 - Flutter project initialization + foundation |
| `ba3f865` | 2026-06-28 | feat: Stage 2 - LLM/STT/TTS service integration |
| `7d21756` | 2026-06-28 | feat: Stage 3 - SM-2 spaced repetition + review system |
| `7a95a84` | 2026-06-28 | fix: correct import paths in service files |
| `164ebae` | 2026-06-28 | feat: Stage 4 - STT recording + TTS playback integration |
| `3eab12c` | 2026-06-28 | fix: address UI and business review blockers |
| `6280efb` | 2026-06-28 | feat: Stage 5 - animation polish + UI refinement |
| `2730a39` | 2026-06-28 | feat: Stage 6 - learning reports + progress tracking |
| `1ad7ff8` | 2026-06-28 | feat: Stage 7 - multi-role tutor selection |
| `a5b5d14` | 2026-06-28 | feat: Stage 8 - virtual character placeholder with animations |
