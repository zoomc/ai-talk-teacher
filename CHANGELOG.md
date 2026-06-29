# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
