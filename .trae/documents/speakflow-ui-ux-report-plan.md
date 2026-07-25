# SpeakFlow UI/UX / 视觉设计问题报告执行计划

## 1. Summary（目标与输出）

通读 `/workspace/lib/` 下的 Flutter 源码（主题、widgets、screens、动画），对标一流语言学习与 AI 陪伴类 App（如 Duolingo、Elsa Speak、Replika、Character.AI、Memrise 等），输出一份批判性、可落地的 UI/UX / 视觉设计问题报告。

- **输出文件**：`/tmp/speakflow-e2e-run/ui-ux-source-issues.md`
- **最低要求**：至少 200 条编号发现，每条包含：Category、Severity（critical/major/minor）、Description、带 `file://` 绝对路径链接的 File reference、Suggested improvement。
- **覆盖维度**：layouts、spacing、typography、colors、components、animations、responsive design、avatar visuals、chat UI、buttons/inputs、loading/empty/error states、theme、mobile touch targets、scroll behavior。
- **语言**：中文。

## 2. Current State Analysis（已探明现状）

已阅读的关键文件与当前模式：

| 文件 | 作用 | 已发现的可审查点 |
|---|---|---|
| `lib/core/theme/app_colors.dart` | 深色/浅色完整调色板、glass、accent、semantic、gradient、chat bubble 色 | 透明度过低、AA/AAA 对比度、gradient 耗电、语义色统一性 |
| `lib/core/theme/app_text_styles.dart` | Inter 字体阶梯（display/heading/title/body/caption/overline/button） | 字号层级、行高、字重可读性、缺少响应式字体缩放 |
| `lib/core/theme/app_theme.dart` | Material 3 明暗两套 ThemeData | ColorScheme 与直接 AppColors 混用、卡片/输入框/按钮主题 |
| `lib/core/constants/app_constants.dart` | Spacing / Radius / Durations tokens | token 是否足以覆盖复杂布局、缺少 elevation/shadow tokens |
| `lib/core/util/responsive.dart` | Breakpoint / FormFactor / side-by-side / character panel 尺寸 | 断点是否覆盖折叠屏、字号未随 breakpoint 调整、panel 比例 |
| `lib/features/chat/presentation/screens/chat_screen.dart` | 聊天主屏、CharacterPanel、键盘/安全区、横竖屏 | 信息密度、panel 隐藏策略、滚动自动到底、banner 堆叠 |
| `lib/widgets/chat/chat_bubble.dart` | 气泡、流式文字、音素染色、纠错卡片、TTS 按钮 | 气泡对比度、纠错视觉噪音、TTS 按钮可触区域、音素颜色可访问性 |
| `lib/widgets/chat/chat_input_bar.dart` | 语音/文字切换、录音按钮、连续模式、离线提示 | 触控目标、录音按住交互、文案层级、连续模式 discoverability |
| `lib/widgets/chat/chat_header.dart` | AppBar 导师身份与状态点 | 标题截断、状态点语义、返回与更多按钮密度 |
| `lib/widgets/chat/chat_message_list.dart` | 消息列表、空态、typing indicator | 空态插画品质、错误态仅文字、加载态无骨架屏 |
| `lib/features/avatar/presentation/widgets/avatar_stage.dart` | Live2D fallback、嘴型叠加、状态 pill | placeholder 图片单一、嘴型叠加位置硬编码、状态文字未本地化 |
| `lib/shared/widgets/virtual_character.dart` | 自定义 painter 头像、viseme/gesture | 角色风格与品牌一致性、gesture 循环生硬、缺少情绪面部细节 |
| `lib/shared/widgets/glass_widgets.dart` | GlassCard / GlassDialog / GlassBottomSheet / ShimmerBox / GlassBackground | blur 性能、减少动效适配、阴影统一、卡片内边距 |
| `lib/features/home/presentation/screens/home_page.dart` | 仪表盘、streak、能力雷达、任务卡片 | 信息层级、图表标签密度、空态、按钮标签折行 |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | 首次配置向导 | 表单拥挤、进度指示器、默认 emoji 图标、深色文字在浅背景 |
| `lib/features/onboarding/presentation/screens/placement_screen.dart` | AI 定级对话（摘要已提供） | 聊天空态、结果图表、错误/重试提示 |
| `lib/features/settings/presentation/screens/settings_screen.dart` | 设置列表、开关、对话框 | 列表分组视觉、dialog 样式不统一、subtitle 截断 |
| `lib/features/profile/presentation/screens/profile_form_screen.dart` | 配置文件表单 | label 对齐、API key 可见性、测试按钮状态、下拉分组 |

## 3. Proposed Changes（执行步骤）

### Step 1：补全源码遍历
使用 Glob + Read 扫清剩余 UI/视觉相关文件，确保没有遗漏可审查点：

- `lib/main.dart` — 主题切换、全局字体、导航结构。
- `lib/core/router/app_router.dart` — 转场动画、深链接/返回行为。
- `lib/core/i18n/app_localizations.dart` — 文案键与复数/参数支持。
- `lib/features/chat/presentation/screens/tutor_selection_screen.dart`
- `lib/features/chat/presentation/screens/scenarios_screen.dart`
- `lib/features/chat/presentation/screens/sentence_practice_screen.dart`
- `lib/features/chat/presentation/screens/review_screen.dart`
- `lib/features/chat/presentation/screens/progress_screen.dart`
- `lib/features/chat/presentation/screens/history_screen.dart`
- `lib/features/chat/presentation/screens/session_summary_screen.dart`
- `lib/features/home/presentation/screens/pronunciation_detail_screen.dart`
- `lib/features/home/presentation/widgets/*.dart`（日历热力图、趋势图、弱项卡片）
- `lib/features/onboarding/presentation/widgets/placement_radar_chart.dart`
- `lib/features/profile/presentation/screens/service_config_screen.dart`
- `lib/features/profile/presentation/screens/voice_health_screen.dart`
- `lib/features/project_space/presentation/screens/*.dart` 与 `widgets/*.dart`
- `lib/shared/widgets/app_banners.dart`、`voice_status_indicator.dart`
- `lib/features/avatar/domain/*.dart` 与 `data/*.dart` — 动画曲线、采样频率、参数映射。

### Step 2：构建 200+ 条发现清单
按以下维度分类，每条必须基于源码中的具体行/文件：

1. **Color & Contrast**：对比度不足、透明度过低、语义色误用、渐变耗电。
2. **Typography**：字号阶梯不清晰、长文本行宽过大/过小、字重层级弱、缺少响应式字体。
3. **Layout & Spacing**：信息密度不均、内边距不一致、卡片对齐问题、banner 堆叠。
4. **Components**：GlassCard 阴影/边框不一致、按钮高度不统一、输入框焦点环、chip 尺寸。
5. **Avatar & Animation**：placeholder 形象单一、嘴型同步精度、动画循环生硬、缺少眨眼/呼吸细节。
6. **Chat UI**：气泡方向/圆角、纠错卡片视觉噪音、TTS 按钮可触区域、流式光标样式、空态插画。
7. **Inputs & Touch Targets**：录音按钮 48dp 合规性、连续模式 discoverability、语音/文字切换手势。
8. **Responsive & Adaptive**：断点对折叠屏/平板、panel 比例、字体未随宽度缩放、横屏键盘遮挡。
9. **Loading / Empty / Error**：骨架屏缺失、错误态仅文字、空态无插画/行动按钮、retry 样式不统一。
10. **Theme & Accessibility**：明暗主题切换抖动、reduce-motion 适配不完整、屏幕阅读器标签缺失。
11. **Scroll & Navigation**：自动滚动打断用户、列表无回弹/滚动指示、页面转场生硬。
12. **Onboarding & Settings**：表单拥挤、进度指示器信息不足、设置分组边界不清、开关说明文案。

Severity 判定标准：
- **critical**：影响可访问性（对比度低于 WCAG AA）、导致功能不可用（触控目标 < 44dp 且核心操作）、数据丢失风险。
- **major**：显著降低主流机型体验（信息密度、空态、响应式缺陷、关键动画断裂）。
- **minor**：视觉打磨、品牌一致性、边缘场景优化。

### Step 3：写入报告文件
- 目标目录 `/tmp/speakflow-e2e-run/` 若不存在则创建。
- 采用 Markdown 编号列表，每条结构：
  ```markdown
  1. **Category**: 颜色与对比度  
     **Severity**: critical  
     **Description**: ...  
     **File reference**: `file:///workspace/lib/core/theme/app_colors.dart:7`  
     **Suggested improvement**: ...
  ```
- 保持中文，引用行号以已读文件实际行号为准；若批量引用多处，用 `file:///workspace/lib/...:line` 给出最直接的一处。

### Step 4：自检与验证
- 使用脚本/命令统计编号条目数量，确保 `>= 200`。
- 抽查每条是否同时包含 Category、Severity、Description、File reference（含 `file://`）、Suggested improvement。
- 检查 Markdown 文件可正常打开、无乱码、链接为绝对路径。
- 最终回复中报告总条数与输出路径。

## 4. Assumptions & Decisions

- 本次审查为**源码级静态 UI/UX 审查**，不运行 App，也不保证运行时实际表现与源码完全一致。
- 对标“顶级 App”指将其常见最佳实践作为参照，不针对具体竞品版本。
- 所有 `file://` 链接使用仓库根目录 `/workspace` 下的绝对路径，便于在 IDE/浏览器中直接打开。
- 不修改任何源码，只生成报告。
- 若发现源码中同一模式在多文件重复出现，可归类为一条或分别列出，优先保证覆盖 200 条且指向不同文件/行号。

## 5. Verification Steps（验收标准）

- [ ] `/tmp/speakflow-e2e-run/ui-ux-source-issues.md` 存在且大小 > 0。
- [ ] 文件内编号条目数 >= 200。
- [ ] 每条包含 Category、Severity、Description、File reference（含 `file://`）、Suggested improvement。
- [ ] Severity 仅使用 critical/major/minor 三者之一。
- [ ] 所有文件引用路径均为 `/workspace/lib/...` 的绝对路径。
- [ ] 报告语言为中文。
- [ ] 最终回复给出总条数与文件路径。
