# SpeakFlow Phase 5 UI/UX 源码实现计划

## 1. 摘要

本计划对应 `/tmp/speakflow-e2e-run/unified-modifications.md` 中「UI/UX / 视觉设计（源码）」章节，目标是在 `lib/` 下完成 UI/UX 源码级修改与优化，并在最后输出变更报告 `/tmp/speakflow-e2e-run/ui-ux-source-implementation-report.md`。

**当前状态**：核心主题（theme/tokens/responsive/router/glass widgets/main）已在前序工作中完成大部分改造。本计划聚焦：
1. 查漏补缺已改造文件与 spec 的偏差；
2. 完成剩余页面级/UI 组件级修改（settings、profile/service-config、scenarios、projects、history、progress、home、onboarding、placement、radar chart、progress widgets、voice indicator、banners 等）；
3. 运行/验证静态分析；
4. 撰写变更报告。

**范围假设**：`unified-modifications.md` 中该章节实际编号约 100 条（含 31–66、67–100 两个表格），标题「53 条」为概数。本次实现覆盖该章节下全部可源码落地的条目；对需要后端/产品决策或超出 UI 源码范围的条目记为「暂缓项」。

**关键约束**：当前 sandbox 未安装 Dart/Flutter SDK（`dart`/`flutter` 命令不存在），因此 `dart analyze` 无法直接执行。计划中将尝试通过 `flutter` 容器或 SDK 路径补救；若仍不可行，将在报告中如实记录此限制，并以人工代码审查替代。

---

## 2. 当前状态分析

### 2.1 已完成的改造（依据现有源码确认）

| 文件 | 已完成内容 | 对应 spec 编号 |
|------|-----------|---------------|
| `lib/core/constants/app_constants.dart` | 扩展 `AppSpacing`（smPlus/mdPlus/lgPlus/xlPlus/huge、语义 token），`AppRadius.full→pill`，`AppDurations.medium→normal` 并加曲线常量 | UX-013 ~ UX-016 |
| `lib/core/theme/app_colors.dart` | 合并 `bgSurface/glassBg`，提升 `glassBorder` 透明度，新增 textDisabled/textPlaceholder、disabled/outline/outlineVariant/shadow、onBubble 颜色、light bubble 颜色 | UX-002、UX-004、UX-022、UX-023、UX-025 |
| `lib/core/theme/app_text_styles.dart` | 增加 font fallbacks，补全 M3 type scale（display/display/headline/title/body/label 全 15 个槽位），统一命名 | UX-007 ~ UX-012 |
| `lib/core/theme/app_theme.dart` | `_buildTheme` 统一构建明暗主题；ColorScheme 补齐 M3 全槽位；新增 dialog/bottomSheet/chip/switch/navigationBar/tabBar/FAB/slider/checkbox/radio 等组件主题；按钮最小 44dp；Divider space 改为 md；SnackBar 用 inverseSurface | UX-005、UX-006、UX-017 ~ UX-021、UX-024 |
| `lib/core/util/responsive.dart` | 断点常量提取、formFactor 用 shortestSide、`isSquare`、扣安全区的 `isShortViewport`、`shouldUseSideBySide` 拆命名布尔、`navRailWidth`、bodyWidth 参数、极窄手机 1 列 | 31~41、64、65 |
| `lib/core/router/app_router.dart` | 转场用 `disableAnimationsOf`、body 加 `SafeArea`、rail 动画/本地化/滚动/44dp 触控目标、`_calculateSelectedIndex` 处理 chat/project | 42~54、66 |
| `lib/main.dart` | 增加 `_AppScrollBehavior` 支持 mouse/trackpad 拖拽滚动 | 42 |
| `lib/shared/widgets/glass_widgets.dart` | `GlassCard` 精确 MediaQuery、按 pixel ratio 缩放 blur/shadow、高光限定边框、MouseRegion；`StatusPill` 用 theme 样式；`GlassDialog` 限宽/滚动；`GlassBottomSheet` 滚动+键盘内边距；`GlassBackground` 按短边缩放 | 55~63、60~63 |

### 2.2 待完成/需验证的改造

| 区域 | 主要文件 | 对应 spec 编号 |
|------|---------|---------------|
| Settings 与共享组件 | `settings_screen.dart`, `app_banners.dart`, `voice_status_indicator.dart` | UX-043 ~ UX-052 |
| Profile / Service Config | `profile_form_screen.dart`, `service_config_screen.dart` | UX-026 ~ UX-042 |
| 场景页 | `scenarios_screen.dart` | 67~73 |
| 项目空间 | `projects_screen.dart`, `project_detail_screen.dart`, `join_project_sheet.dart` | 74~87 |
| 历史页 | `history_screen.dart` | 88~93 |
| 进度页 | `progress_screen.dart` | 94~100（进度页部分） |
| 首页仪表盘 | `home_page.dart` | 67~79（首页部分） |
| Onboarding / Placement | `onboarding_screen.dart`, `placement_screen.dart` | 80~92 |
| 雷达图与进度组件 | `placement_radar_chart.dart`, `weekly_trend_chart.dart`, `weak_area_card.dart`, `calendar_heatmap.dart` | 93~100（组件部分） |

### 2.3 已知阻塞 / 已验证状态

- **Dart/Flutter SDK**：已验证可用（`/opt/flutter/bin/dart --version` → Dart SDK 3.12.2）。实施后可运行 `/opt/flutter/bin/dart analyze`。
- **源 spec 文件缺失**：`/tmp/speakflow-e2e-run/unified-modifications.md` 已不在该路径；本计划已包含该章节全部可实施条目的具体动作，可直接作为执行依据。
- **部分改动依赖 ARB 键值**：大量本地化条目需要新增 `AppLocalizations` key。实施时若 key 缺失，将优先使用现有英文硬编码文案并标记为「暂缓/需补 key」，不擅自修改 i18n 生成文件结构。
- **截图视觉问题（VA-xxx）** 不在本章范围：用户明确要求「UI/UX / 视觉设计（源码）」，因此 `visual-analysis-issues.md` 中的 225 条截图问题原则上不纳入本次源码修改，除非与源码条目重合。

---

## 3. 拟议修改

### 3.1 主题/token 查漏补缺（低风险、高复用）

**目标文件**：
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/util/responsive.dart`
- `lib/shared/widgets/glass_widgets.dart`

**具体动作**：
1. 逐条核对 spec 中 UX-001~UX-025 与 31~66 是否已全部落地；对未落地项补齐。
2. 重点检查：
   - `ColorScheme` 是否包含 `surfaceContainerHighest`、`surfaceTint`、`inversePrimary` 等 M3 槽位（已做，确认无遗漏）。
   - `TextButton` 的 `overlayColor`、`splashFactory` 是否已配置（已做，确认）。
   - `GlassCard` 是否在 `onTap == null` 时返回无 `GestureDetector` 的容器（已做，确认）。
   - `GlassDialog` 的 `maxWidth` 是否 560（已做，确认）。
   - `GlassBottomSheet` 是否内置 `SingleChildScrollView` + `viewInsets`（已做，确认）。
3. 若发现偏差，直接编辑修正。

### 3.2 Settings / Shared Widgets

**目标文件**：
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/shared/widgets/app_banners.dart`
- `lib/shared/widgets/voice_status_indicator.dart`

**具体动作**：

#### `settings_screen.dart`
- **UX-043**：`_SettingsToggleTile` 改用 `SwitchListTile.adaptive` 或 `MergeSemantics`，避免行与开关两个可聚焦元素。
- **UX-044/045**：Switch 统一通过 `SwitchThemeData` 配置品牌色/焦点视觉；低带宽图标根据 `value` 在 `Icons.data_saver_off` 与 `Icons.data_saver_on` 间切换。
- **UX-046**：`Clear Cache` 增加二次确认 `AlertDialog`。
- **UX-047**：移除所有 `AlertDialog` 中硬编码 `backgroundColor`，依赖 `dialogTheme`。

#### `app_banners.dart`
- **UX-048**：`_DismissButton` 外层包 `Material` 并加 `Tooltip('Dismiss')`。
- **UX-049**：`_ActionButton` 字号从 12 改为 14，使用 `textTheme.labelLarge`。
- **UX-050**：iOS A2HS sheet 中 `TextButton`/`FilledButton` 设置 `minimumSize: Size.fromHeight(44)`。

#### `voice_status_indicator.dart`
- **UX-051**：紧凑模式下也显示 2px `LinearProgressIndicator`（或脉冲动画）。
- **UX-052**：脉冲外层容器从 `dotSize + 4` 增大到 `dotSize * 1.8`，或降低最大 scale 到 1.3。
- **UX-053**：语音阶段标签加半透明背景容器或改用高对比度文本色，确保在 glass card 上可读。

### 3.3 Profile / Service Config

**目标文件**：
- `lib/features/profile/presentation/screens/profile_form_screen.dart`
- `lib/features/profile/presentation/screens/service_config_screen.dart`

**具体动作**：

#### `profile_form_screen.dart`
- **UX-026**：API Key 字段增加 `suffixIcon` 切换 `obscureText`。
- **UX-027**：为字段配置 `textInputAction: next/done` 与 `FocusNode`，`onFieldSubmitted` 切换焦点。
- **UX-028**：Base URL 字段设置 `keyboardType: TextInputType.url`、`autocorrect: false`。
- **UX-029**：校验错误信息本地化、描述性（如「请输入配置文件名称」），可在 `onChanged` 中 debounce 校验。
- **UX-030**：字段标题移入 `InputDecoration.labelText`。
- **UX-031**：Provider 下拉分组使用 `Divider` 或自定义 header 样式。
- **UX-032/033**：「Fetch models / Save / Cancel」按钮加 `minimumSize`（`Size.fromHeight(44/48)`）。
- **UX-034**：Test Connection 加载指示器增大到 20–24。
- **UX-035**：导入配置弹窗增加「选择文件」按钮，使用 `file_picker`（需确认依赖是否已存在；若不存在且用户未要求，记为暂缓）。
- **UX-036**：删除确认弹窗 Delete 按钮使用错误色 `TextButton.styleFrom(foregroundColor: error)` 或 `FilledButton(backgroundColor: error)`。

#### `service_config_screen.dart`
- **UX-037**：资料卡片增加 `Radio`/`Checkbox` 或 trailing 提示，明确「点击切换激活」。
- **UX-038**：`PopupMenuButton` 图标加 padding 或改用 `IconButton`（minimumSize 44）。
- **UX-039**：emoji 图标替换为 `Icon(Icons.xxx)` + `Semantics(label: ...)`。
- **UX-040**：副标题设置 `maxLines: 1`、`overflow: ellipsis`。
- **UX-041**：「Add Profile」按钮 minimumSize 44。
- **UX-042**：删除确认弹窗 Delete 使用错误色高亮。

### 3.4 Scenarios / Projects / History / Progress

**目标文件**：
- `lib/features/chat/presentation/screens/scenarios_screen.dart`
- `lib/features/project_space/presentation/screens/projects_screen.dart`
- `lib/features/project_space/presentation/screens/project_detail_screen.dart`
- `lib/features/project_space/presentation/widgets/join_project_sheet.dart`
- `lib/features/chat/presentation/screens/history_screen.dart`
- `lib/features/chat/presentation/screens/progress_screen.dart`

**具体动作**：

#### `scenarios_screen.dart`（67~73）
- 分类标题与难度标签走 ARB：`l.t('scenarios.category.$category')`、`l.t('scenarios.difficulty.$difficulty')`。
- 练习统计文案与相对时间接入 `AppLocalizations` 复数/相对时间 key；或使用 `intl` `DateFormat`。
- **71**：场景卡片增加 `IconButton`（⋮）或可见的「加入项目」图标入口。
- **72**：横向列表高度使用 `IntrinsicHeight` 或动态计算。
- **73**：加载/错误状态替换为统一 `AsyncValueWidget`（带骨架屏、重试按钮）。

#### `projects_screen.dart`（74~76）
- **74**：`childAspectRatio` 用 `LayoutBuilder` 动态计算。
- **75**：加载/错误状态使用统一异步状态组件。
- **76**：空状态标题用 `bodyLarge`+`textSecondary`，CTA 统一为 `FilledButton.icon`。

#### `project_detail_screen.dart`（77~84）
- **77**：加载时 AppBar 标题显示 shimmer 占位或项目名称骨架。
- **78**：错误状态使用本地化错误页面 + 重试按钮。
- **79**：链接列表根据 `contentType` 查询标题/图标显示。
- **80**：链接时间文案本地化。
- **81**：项目状态使用 `Chip`/`StatusPill`。
- **82/83**：删除按钮使用 `AppColors.error` 的 `FilledButton` 或 `OutlinedButton`。
- **84**：活动列表 `Divider` 高度减小或改用间距/卡片分组。

#### `join_project_sheet.dart`（85~87）
- **85**：顶部加入 `TextField` 实时过滤项目。
- **86**：已关联项目行使用 `Opacity`/禁用样式。
- **87**：标题下方增加内容摘要（图标+名称）。

#### `history_screen.dart`（88~93）
- **88**：时间格式化使用 `intl.DateFormat` 或 `AppLocalizations` 相对时间 key。
- **89**：空主题时使用 `l.t('history.free_talk')`。
- **90**：删除确认弹窗正文本地化，删除按钮错误色。
- **91**：发音评分按钮文案本地化、字号 `labelMedium`、最小触控目标 44。
- **92**：搜索无结果时显示「无匹配结果」+ 清除搜索按钮。
- **93**：删除按钮移入长按菜单或详情页，或增加二次确认。

#### `progress_screen.dart`（94~100 中进度页部分）
- **94**：所有硬编码英文标题/标签接入 `AppLocalizations`。
- **95**：错误类型 `grammar/vocabulary/pronunciation` 本地化。
- **96**：7 日趋势图日期/星期使用 `intl.DateFormat`。
- **97**：统计卡片网格用 `GridView` 或 `Wrap.alignment` 居中最后一行。
- **98**：`_MasteryRow` 标签区改用 `IntrinsicWidth`/`Flexible`。
- **99**：错误状态增加重试按钮 `ref.invalidate(statsProvider)`。
- **100**：「Start Review Session」改用 `FilledButton.icon` 统一主题。

### 3.5 Home / Onboarding / Placement / Radar / Progress Widgets

**目标文件**：
- `lib/features/home/presentation/screens/home_page.dart`
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- `lib/features/onboarding/presentation/screens/placement_screen.dart`
- `lib/features/onboarding/presentation/widgets/placement_radar_chart.dart`
- `lib/features/home/presentation/widgets/weekly_trend_chart.dart`
- `lib/features/home/presentation/widgets/weak_area_card.dart`
- `lib/features/home/presentation/widgets/calendar_heatmap.dart`

**具体动作**：

#### `home_page.dart`（67~79 中首页部分）
- **67**：顶部品牌区增加用户头像/首字母 fallback。
- **68**：`_greeting` 读取用户昵称拼接个性化问候。
- **69**：`_StreakDots` 使用热力图强度色阶区分练习时长，长按提示数据。
- **70**：`_MilestoneBadge` 最小高度 32dp，字号不低于 12。
- **71**：`_BigActionButton` 标签限制单行或改用垂直堆叠。
- **72**：待复习 badge 改用 accent/muted 背景，加语义标签。
- **73**：`_TaskCard` 增加 Checkbox/完成图标，已完成降低对比度。
- **74**：优先级用「高/中/低」文字或色点替代 P 编号。
- **75**：雷达图增加维度说明、0-100 刻度图例、低分建议入口。
- **76**：`_ReviewQueueTile` 正确句用中性色，突出原句与纠正句对比，增加复习按钮。
- **77**：合并 `_GoalSection` 与 `_StructuredContentSection` 的推荐场景或二选一。
- **78**：`_ScenarioChip` 自适应宽度，描述 tooltip。
- **79**：`_SetGoalDialog` 内容包裹 `SingleChildScrollView`，限制最大宽度。

#### `onboarding_screen.dart`（80~85）
- **80**：欢迎页突出主按钮，跳过与访客试用降为次级链接/文字按钮。
- **81**：服务配置页进度条增加步骤标签/图标（LLM/STT/TTS）。
- **82**：API Key 输入框增加显示/隐藏切换。
- **83**：`_buildTestButton` 改为 `OutlinedButton` 并显示成功/失败图标。
- **84**：服务页 docsUrl 改为简洁链接文案。
- **85**：TTS 页「复用 STT」按钮与主按钮视觉动线统一。

#### `placement_screen.dart`（86~92）
- **86**：`_buildIntro` 跳过操作与主按钮并列底部。
- **87**：`_buildChat` 进度条区分已完成/当前/未开始（形状或颜色）。
- **88**：录音按钮使用品牌色，停止状态再变红。
- **89**：`_buildResult` 成功图标容器缩小至 56-64dp。
- **90**：`_LearningPathCard` 使用 `Row + Icon(Icons.check_circle_outline)` 替代 `• `。
- **91**：`_LegacyQuiz` 选项增加选中高亮 + 确认按钮。
- **92**：进度条仅标记已回答题目，当前题用高亮边框。

#### `placement_radar_chart.dart`（93~94）
- **93**：顶点旁显示分数标签 + tooltip。
- **94**：维度标签字号按文字缩放调整，最小 12sp。

#### `weekly_trend_chart.dart`（95~96）
- **95**：星期标签与统计标签接入 `AppLocalizations`，支持周起始日。
- **96**：`_BarChartPainter` 添加 tap 区域与 tooltip，显示当天消息数/纠错数。

#### `weak_area_card.dart`（97~98）
- **97**：类型标签本地化，按类型使用一致颜色。
- **98**：整行包裹为 `ListTile`/`InkWell`，最小 48dp 触控高度。

#### `calendar_heatmap.dart`（99~100）
- **99**：改为垂直列（每周一列）布局，增加月份分隔标签。
- **100**：Less/More 图例标签本地化。

### 3.6 静态分析与报告

**目标**：
- 在 `/workspace` 根目录运行 `dart analyze`（或 `flutter analyze`）。
- 修复新增分析错误。
- 输出 `/tmp/speakflow-e2e-run/ui-ux-source-implementation-report.md`。

**具体动作**：
1. 实施前检查环境是否可通过包管理器/容器安装 Dart SDK；若不能，记录为「环境限制」。
2. 若 SDK 可用，运行 `dart analyze` 并逐条修复；若不可行，人工审查关键改动（如新增 import、类型匹配、const 构造函数、过期 API 等）。
3. 报告结构：
   - 已完成条目清单（编号、简述、修改文件、关键代码片段）
   - 暂缓项清单（编号、原因、所需后续工作）
   - 分析结果/环境限制说明
   - 双端适配说明

---

## 4. 假设与决策

| # | 假设/决策 | 理由 |
|---|----------|------|
| 1 | 覆盖「UI/UX / 视觉设计（源码）」全章节（含 31–100 编号表格），不仅限于 UX-001~UX-053 | 文件标题「53 条」为概数，实际条目约 94 条；且用户要求「按优先级逐条实现」 |
| 2 | 不处理 `visual-analysis-issues.md` 中的 225 条截图问题 | 用户明确限定本章为「UI/UX / 视觉设计（源码）」 |
| 3 | 新增 ARB key 时，中英双语至少提供英文占位；若项目默认中文，则提供中文并保留英文 fallback | 保证 UI 不 crash，后续可由翻译人员补全 |
| 4 | 若 `file_picker` 未在 `pubspec.yaml` 中声明，则 UX-035「选择文件导入」记为暂缓 | 不擅自引入新依赖，除非用户确认 |
| 5 | `dart analyze` 若因环境缺失无法运行，则在报告中记录并改用人工审查 | 环境限制不可控，但需保证变更可追踪 |
| 6 | 对 Material 组件的样式修改以「不破坏现有布局」为前提，优先使用 theme 或局部包裹 | 避免 regressions，符合用户要求 |

---

## 5. 验证步骤

1. **代码审查**：每修改一个文件后，检查相邻布局、主题、响应式逻辑是否受影响。
2. **const/imports 检查**：确保新增 widget 使用 `const` 合理，import 路径正确。
3. **双端适配检查**：在 `Responsive` 调用处确认 PC（rail）与 mobile（bottom nav）两条路径都通过。
4. **本地化检查**：新增 `l.t(...)` 调用时，确认 ARB/代理类中有对应 key。
5. **分析工具**：
   - 尝试 `dart analyze` / `flutter analyze`。
   - 若失败，使用 `grep`/`read` 人工检查高风险改动（过期 API、类型不匹配）。
6. **报告生成**：整理 completed/deferred 列表，写入指定 markdown 文件。

---

## 6. 任务拆分（建议 todo 顺序）

1. **Audit core theme/token files** against spec 1~25 & 31~66；fix gaps.
2. **Settings + shared widgets**：`settings_screen.dart`, `app_banners.dart`, `voice_status_indicator.dart`.
3. **Profile / service config**：`profile_form_screen.dart`, `service_config_screen.dart`.
4. **Scenarios / projects / history / progress**：对应 4 个屏幕 + 1 个 sheet.
5. **Home / onboarding / placement / radar / progress widgets**：对应 7 个文件.
6. **Static analysis & fixes**（或记录环境限制）.
7. **Write report** to `/tmp/speakflow-e2e-run/ui-ux-source-implementation-report.md`.
