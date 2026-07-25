# SpeakFlow UI/UX 源代码审查计划

## 1. Summary

对 `/workspace/lib/` 下的 SpeakFlow Flutter 应用进行系统性 UI/UX、视觉设计、动画与响应式审查，识别至少 200 个独立问题，并按统一格式写入 `/tmp/speakflow-e2e-run/ui-ux-source-issues.md`（中文）。审查标准对标顶级语言学习与 AI 陪伴类应用（如 Duolingo、Elsa Speak、Character.AI、HelloTalk），聚焦真实可执行、可落地的改进项。

## 2. Current State Analysis

通过 Phase 1 已阅读以下关键文件，发现代码具备以下特征与潜在审查点：

- **Theme & Color** (`lib/core/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart`)
  - 暗色/亮色双主题已定义，但部分语义色（如 `textMuted`）对比度、玻璃拟态渐变在可访问性/低带宽模式下的降级路径值得审查。
  - 字体尺寸固定，未按 Material 3 的 `display/medium/small` 细分，缺少对动态字体（ accessibility ）的适配。
  - 主题中未统一配置 `BottomNavigationBarTheme`、`FloatingActionButtonTheme`、`ChipTheme` 等子主题，局部 widget 容易“各自为政”。

- **Responsive** (`lib/core/util/responsive.dart`)
  - 已提供 breakpoint、form factor、orientation 判断及 side-by-side 布局策略。
  - 仍存在多处硬编码尺寸（如 chat input 的 224×62、scenario card 的 140 宽），需逐屏核查是否全部使用 responsive helper。

- **Glass Widgets** (`lib/shared/widgets/glass_widgets.dart`)
  - `GlassCard`、`GlassDialog`、`GlassBottomSheet`、`ShimmerBox` 已抽象。
  - 但 `GlassCard` 直接监听 pointer 事件实现 pressed 态，缺少 InkWell 的水波纹/焦点反馈；`StatusPill` 等小组件未接入主题，形成视觉碎片。

- **Chat 核心界面** (`lib/features/chat/presentation/screens/chat_screen.dart`, `lib/widgets/chat/chat_bubble.dart`, `chat_input_bar.dart`)
  - 聊天布局支持 side-by-side / stacked / drop-panel 三种形态，但 `_CharacterPanel` 在 compact 模式下的悬浮操作按钮、`_StageIcon` 颜色在暗色/亮色下硬编码为白色，缺少主题化。
  - 聊天气泡圆角、边框、阴影在暗色下偏淡，在亮色下可能对比度不足。
  - `ChatInputBar` 的语音按钮为固定 224×62，未适配小屏/横屏；录音/停止文案与提示文案重复，信息密度低。
  - 动画：录音脉冲、typing bubble、光标闪烁均存在，但缺少入场/出场过渡，错误/空状态多为静态文本。

- **Home Dashboard** (`lib/features/home/presentation/screens/home_page.dart`)
  - 组件丰富（streak、quick actions、ability radar、review queue、goal、structured content）。
  - 多处使用 `ShimmerBox` 与 `CircularProgressIndicator` 混用，loading 状态不统一；error 状态多为 `SizedBox.shrink()`，用户无感知。
  - 快速操作按钮文字在窄屏可能被截断；雷达图缺少空状态与图例。

- **Settings** (`lib/features/settings/presentation/screens/settings_screen.dart`)
  - 设置项分组清晰，但所有 dialog 使用原生 `AlertDialog`，在暗色/亮色下背景色手动指定，容易与 `GlassDialog` 风格割裂。
  - 多个 dialog 内重复设置 `RadioGroup` 与 `activeColor`，未统一封装。
  - `_testCurrentProfile` 的加载 dialog 为硬编码 Material Dialog，未使用 `GlassDialog` / `ShimmerBox`。

## 3. Proposed Work Plan

### 3.1 文件清单（必须全部阅读）

按以下顺序读取并记录问题：

1. **Theme / Foundation**
   - `lib/core/theme/app_colors.dart`
   - `lib/core/theme/app_text_styles.dart`
   - `lib/core/theme/app_theme.dart`
   - `lib/core/theme/theme.dart`
   - `lib/core/constants/app_constants.dart`
   - `lib/core/util/responsive.dart`
   - `lib/core/i18n/app_localizations.dart`

2. **Shared Widgets / Primitives**
   - `lib/shared/widgets/glass_widgets.dart`
   - `lib/shared/widgets/app_banners.dart`
   - `lib/shared/widgets/voice_status_indicator.dart`
   - `lib/shared/widgets/virtual_character.dart`
   - `lib/shared/widgets/virtual_character_3d*.dart`（全 4 个平台文件）

3. **Chat Widgets**
   - `lib/widgets/chat/chat_bubble.dart`
   - `lib/widgets/chat/chat_input_bar.dart`
   - `lib/widgets/chat/chat_header.dart`
   - `lib/widgets/chat/chat_message_list.dart`
   - `lib/widgets/chat/chat_providers.dart`

4. **Chat Screens**
   - `lib/features/chat/presentation/screens/chat_screen.dart`
   - `lib/features/chat/presentation/screens/history_screen.dart`
   - `lib/features/chat/presentation/screens/progress_screen.dart`
   - `lib/features/chat/presentation/screens/review_screen.dart`
   - `lib/features/chat/presentation/screens/scenarios_screen.dart`
   - `lib/features/chat/presentation/screens/sentence_practice_screen.dart`
   - `lib/features/chat/presentation/screens/session_summary_screen.dart`
   - `lib/features/chat/presentation/screens/tutor_selection_screen.dart`

5. **Home / Onboarding / Profile / Settings / Project Space**
   - `lib/features/home/presentation/screens/home_page.dart`
   - `lib/features/home/presentation/screens/pronunciation_detail_screen.dart`
   - `lib/features/home/presentation/widgets/*.dart`
   - `lib/features/onboarding/presentation/screens/onboarding_screen.dart`
   - `lib/features/onboarding/presentation/screens/placement_screen.dart`
   - `lib/features/onboarding/presentation/widgets/placement_radar_chart.dart`
   - `lib/features/profile/presentation/screens/profile_form_screen.dart`
   - `lib/features/profile/presentation/screens/service_config_screen.dart`
   - `lib/features/profile/presentation/screens/voice_health_screen.dart`
   - `lib/features/settings/presentation/screens/settings_screen.dart`
   - `lib/features/project_space/presentation/screens/*.dart`
   - `lib/features/project_space/presentation/widgets/*.dart`

6. **Avatar / Animation**
   - `lib/features/avatar/presentation/widgets/avatar_stage.dart`
   - `lib/features/avatar/domain/emotion_controller.dart`
   - `lib/features/avatar/domain/idle_animation.dart`

7. **Router / Main**
   - `lib/core/router/app_router.dart`
   - `lib/main.dart`

### 3.2 问题分类与字段

每条 issue 必须包含以下字段（中文输出）：

- **编号**：1 ~ N（N ≥ 200）
- **类型**：Layout / Color / Typography / Animation / Interaction / Component / Responsiveness / Accessibility / Localization / State / Empty-Error / Consistency / Performance
- **严重度**：critical / major / minor
- **描述**：具体观察到的 UI/UX 缺陷
- **文件**：相关文件路径（可含行号范围）
- **建议改进**：可执行的修复方向

### 3.3 输出格式

写入 `/tmp/speakflow-e2e-run/ui-ux-source-issues.md`，结构如下：

```markdown
# SpeakFlow UI/UX 源代码审查报告

## 审查方法
...

## 问题清单

### 1. [类型][严重度] 标题
- **描述**：...
- **文件**：...
- **建议改进**：...

...

## 统计
- 总数：N
- 严重度分布：critical X / major Y / minor Z
- 类型分布：...
```

### 3.4 执行步骤

1. **批量读取文件**：按 3.1 分组并行读取（每次 3–5 个文件）。
2. **边读边记录**：对每个文件，从以下维度逐项检查：
   - 是否存在硬编码尺寸/颜色/间距；
   - 是否未处理 loading / error / empty 状态；
   - 动画是否有 `AnimationController` 未释放风险；
   - 是否缺少 `Semantics`、焦点、键盘无障碍；
   - 是否未适配横屏、折叠屏、桌面、平板分屏；
   - 组件风格是否与主题/玻璃设计体系不一致；
   - 文案是否硬编码、未走 `AppLocalizations`；
   - 图标/按钮点击区域是否小于 44pt；
   - 是否存在视觉层次混乱、信息密度过高/过低。
3. **汇总去重**：将相同根因的问题合并为一条；若不同文件出现同类问题，按文件拆分确保“独立问题”。
4. **撰写中文报告**：按 3.3 格式写入目标文件。
5. **校验**：
   - 条目数 ≥ 200；
   - 每个条目包含类型、严重度、描述、文件、建议；
   - 文件路径全部以 `/workspace/lib/...` 开头；
   - 严重度与类型分布合理，不存在大量重复同一问题。

## 4. Assumptions & Decisions

- 审查仅基于源代码静态分析，不运行应用或截图对比。
- “顶级应用对标”指在输出描述中引用通用最佳实践（对比度、可达性、动画节奏、信息层级等），不实际抓取竞品截图。
- 所有 issue 用中文撰写；文件路径保留原始英文。
- 同一缺陷在不同文件出现视为多条独立 issue，以保证 200+ 的颗粒度与可落地性。
- 不修改任何业务逻辑，仅输出审查报告。
- 输出目录 `/tmp/speakflow-e2e-run/` 如不存在则自动创建。

## 5. Verification Steps

- [ ] 读取完 3.1 中所有文件。
- [ ] 生成 `/tmp/speakflow-e2e-run/ui-ux-source-issues.md`。
- [ ] 使用 `grep -c '^### '` 或 Dart 脚本统计条目数 ≥ 200。
- [ ] 抽样检查 10 条 issue，确认包含全部 5 个字段且建议具体可执行。
- [ ] 确认文件内无英文描述主体（仅文件路径可保留英文）。
