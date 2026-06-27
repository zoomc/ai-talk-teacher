# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Cloud sync (optional, deferred to future version)

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
