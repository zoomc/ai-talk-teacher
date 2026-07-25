# SpeakFlow UI/UX / Visual Design Issue Report — Execution Plan

## 1. Summary

基于对 `/workspace/lib/` 下 SpeakFlow Flutter 源代码的系统性阅读，生成一份至少包含 200 条编号发现的 UI/UX / 视觉设计 / 动画 / 响应式 / 组件问题报告，输出到 `/tmp/speakflow-e2e-run/ui-ux-source-issues.md`（中文）。报告仅做静态审查与输出，不修改业务逻辑。

## 2. Current State Analysis

已完成 Phase 1 探索，阅读并理解了以下关键文件：

- `lib/core/theme/app_colors.dart` — 暗/亮双主题色板、玻璃拟态色、语义色、气泡色、渐变色。
- `lib/core/theme/app_text_styles.dart` — 全局字体规范（Inter，固定尺寸）。
- `lib/core/theme/app_theme.dart` — ThemeData 配置（ColorScheme、文本、输入框、按钮、卡片、Divider、SnackBar 等）。
- `lib/core/util/responsive.dart` — Breakpoint / FormFactor / Orientation 判断、side-by-side 策略、响应式尺寸 token。
- `lib/core/constants/app_constants.dart` — AppSpacing、AppRadius、AppDurations 常量。
- `lib/widgets/chat/chat_bubble.dart` — 聊天气泡、流式文本、音素评分、纠错卡片、TTS 播放/重试、输入中指示器。
- `lib/widgets/chat/chat_input_bar.dart` — 语音/文字输入切换、录音按钮、连续模式、离线提示、重试提示。
- `lib/features/chat/presentation/screens/chat_screen.dart` — 聊天主屏、角色面板、响应式布局、游客计时条。
- `lib/shared/widgets/virtual_character.dart` — 2D 手绘虚拟角色、20 个 viseme、27 个 gesture、呼吸/发光动画。
- `lib/features/avatar/presentation/widgets/avatar_stage.dart` — AvatarStage、Live2D 占位、参数化嘴型叠加、状态标签。

已发现的主要视觉/交互风险：
- 多处硬编码尺寸/颜色/圆角，未走 theme/responsive token；
- 暗色/亮色切换时部分组件仍使用固定色（如 `_StageIcon` 白色背景）；
- 小屏/横屏/折叠屏/桌面分屏适配存在潜在风险（如 224×62 固定语音按钮）；
- 动画/空态/错误态/加载态覆盖不完整；
- 部分 touch target、Semantics、焦点管理待加强；
- 组件风格（GlassCard、AlertDialog、原生 Material Dialog）存在割裂。

## 3. Proposed Work Plan

### 3.1 补充阅读文件清单

按模块并行读取剩余文件，确保覆盖用户要求的所有维度（layouts, spacing, typography, colors, components, animations, responsive design, avatar visuals, chat UI, buttons/inputs, loading/empty/error states, theme, mobile touch targets）：

1. **Router / Entry**
   - `lib/main.dart`
   - `lib/core/router/app_router.dart`

2. **Shared Widgets**
   - `lib/shared/widgets/glass_widgets.dart`
   - `lib/shared/widgets/app_banners.dart`
   - `lib/shared/widgets/voice_status_indicator.dart`
   - `lib/shared/widgets/virtual_character_3d*.dart`（4 个平台文件）

3. **Chat Widgets / Screens**
   - `lib/widgets/chat/chat_header.dart`
   - `lib/widgets/chat/chat_message_list.dart`
   - `lib/features/chat/presentation/screens/history_screen.dart`
   - `lib/features/chat/presentation/screens/progress_screen.dart`
   - `lib/features/chat/presentation/screens/review_screen.dart`
   - `lib/features/chat/presentation/screens/scenarios_screen.dart`
   - `lib/features/chat/presentation/screens/sentence_practice_screen.dart`
   - `lib/features/chat/presentation/screens/session_summary_screen.dart`
   - `lib/features/chat/presentation/screens/tutor_selection_screen.dart`

4. **Home / Onboarding / Profile / Settings / Project Space**
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

5. **Avatar / Animation**
   - `lib/features/avatar/domain/emotion_controller.dart`
   - `lib/features/avatar/domain/idle_animation.dart`

### 3.2 问题审查维度

对每份文件按以下维度逐项检查并记录：

- **Layouts**：对齐、约束、溢出、嵌套 Column/Row、SafeArea 处理；
- **Spacing**：是否使用 AppSpacing、是否存在魔数、边距是否一致；
- **Typography**：是否使用 theme text style、是否硬编码字号/字重/行高、动态字体适配；
- **Colors**：是否使用 theme 色、硬编码色值、暗/亮模式一致性、对比度；
- **Components**：自定义组件与 Material 3 规范一致性、复用度、风格割裂；
- **Animations**：AnimationController 生命周期、过渡缺失、动画节奏、性能；
- **Responsive Design**：是否使用 Responsive helper、横竖屏/折叠屏/桌面适配；
- **Avatar Visuals**：虚拟角色绘制、嘴型/表情/手势、3D 平台差异、资源缺失回退；
- **Chat UI**：气泡、输入栏、消息列表、头部、状态指示、TTS/纠错交互；
- **Buttons / Inputs**：touch target 尺寸、焦点、键盘交互、禁用态、loading 态；
- **Loading / Empty / Error States**：骨架屏/进度/空视图/错误提示覆盖与一致性；
- **Theme**：主题子系统完整性、未配置子主题、局部覆盖；
- **Mobile Touch Targets**：最小 44×44、按钮间距、误触风险。

### 3.3 输出格式

写入 `/tmp/speakflow-e2e-run/ui-ux-source-issues.md`，每条发现必须包含：

- **编号**：1 ~ N（N ≥ 200）
- **分类**：Layout / Spacing / Typography / Color / Component / Animation / Responsive / Avatar / Chat / Button-Input / Loading-Empty-Error / Theme / Touch-Target / Accessibility / Consistency
- **严重级别**：critical / major / minor
- **描述**：具体观察到的 UI/UX 缺陷（中文）
- **文件位置**：`file:///workspace/lib/...` 链接，必要时含行号
- **建议改进**：可执行的修复方向（中文）

报告结构：

```markdown
# SpeakFlow UI/UX / 视觉设计源代码审查报告

## 审查方法
...

## 问题清单

### 001. [分类][严重级别] 标题
- **描述**：...
- **文件位置**：file:///workspace/lib/...
- **建议改进**：...

...

## 统计
- 总数：N
- 严重级别分布：critical X / major Y / minor Z
- 分类分布：...
```

### 3.4 执行步骤

1. **批量并行读取剩余文件**：每次 3–5 个文件，按 3.1 分组进行；
2. **边读边记录问题**：按 3.2 维度在内部笔记中整理发现；
3. **汇总去重**：同一根因合并，不同文件出现的同类问题按文件拆分，确保独立可落地；
4. **撰写中文报告**：按 3.3 格式写入目标文件；
5. **校验**：
   - 条目数 ≥ 200；
   - 每条均含编号、分类、严重级别、描述、文件位置、建议改进；
   - 文件位置使用 `file:///workspace/lib/...` 格式；
   - 严重级别与分类分布合理，无大量重复；
   - 最终返回：总条目数和文件路径。

## 4. Assumptions & Decisions

- 审查仅基于源代码静态分析，不运行应用、不截图、不执行 UI 测试；
- 对标通用 UI/UX 最佳实践（Material 3、WCAG 对比度、iOS HIG 触摸目标、响应式布局等），不抓取竞品；
- 问题描述用中文；文件路径保留原始英文；
- 同一缺陷在不同文件出现视为多条独立 issue，以保证 200+ 颗粒度；
- 不修改源代码，仅输出审查报告；
- 输出目录 `/tmp/speakflow-e2e-run/` 如不存在则自动创建。

## 5. Verification Steps

- [ ] 完成 3.1 中所有文件的阅读；
- [ ] 生成 `/tmp/speakflow-e2e-run/ui-ux-source-issues.md`；
- [ ] 统计条目数 ≥ 200；
- [ ] 抽样检查至少 10 条，确认 6 个字段完整且建议具体可执行；
- [ ] 确认文件位置链接格式统一为 `file:///workspace/lib/...`；
- [ ] 最终响应仅包含总条目数和文件路径。
