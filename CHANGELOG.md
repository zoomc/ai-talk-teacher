# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Flutter project initialization
- AI dialogue system implementation
- STT/TTS system integration
- UI implementation (Glassmorphism + platform adaptive)

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
