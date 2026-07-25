# SpeakFlow Phase 5 视觉分析（截图）修改计划

## 摘要

本计划继续执行 SpeakFlow Phase 5 视觉优化任务：
1. 修复所有阻塞 `dart analyze` 的问题，包括用户列出的 6 处 Phase 5 回归以及当前新增的 5 处 `profile_form_screen.dart` 编译错误。
2. 从 `visual-analysis-issues.md` 的 220 条发现中，落地剩余**高影响、高频、易修复**的视觉问题，集中在间距、颜色、文字截断、圆角、空状态、加载态等维度。
3. 修改同时覆盖 PC 端（宽屏、NavRail、侧栏）与移动端（紧凑宽度、底部输入栏、短屏 landscape）。
4. 不改动 e2e 测试代码。
5. 最终输出变更报告到 `/tmp/speakflow-e2e-run/visual-analysis-implementation-report.md`。

---

## 当前状态分析

### `dart analyze` 现状

在 `/workspace` 根目录运行 `/opt/flutter/bin/dart analyze` 得到 **23 issues**：

- **5 处 error（新出现，位于 `profile_form_screen.dart`）**
  - `jsonEncode` 未定义（缺少 `dart:convert` 导入）。
  - `saveLlmProfile` / `saveSttProfile` / `saveTtsProfile` 返回值被当作 `void` 使用（`saved.id` 报错）。
  - `ProfileRepository` 未定义（缺少导入）。
  - 这些错误会阻塞编译，必须先修复以完成验证。

- **6 处 Phase 5 视觉改动引入的回归**
  1. `lib/core/constants/app_constants.dart` — `Curve`/`Curves` 未导入。
  2. `lib/core/theme/app_theme.dart` — `CupertinoPageTransitionsBuilder` 未导入。
  3. `lib/main.dart` — `PointerDeviceKind` 未导入。
  4. `lib/widgets/chat/chat_input_bar.dart` — `Switch.activeColor` 已弃用。
  5. `lib/features/avatar/presentation/widgets/avatar_stage.dart` — 重复导入 `flutter/scheduler.dart`。
  6. `lib/features/chat/presentation/screens/chat_screen.dart` — 重复导入 `chat_repository.dart`。
  - 根据当前源码读取，上述 6 处已有部分修复，但需验证完整性（如 `Switch` 是否完全替换为 `thumbColor`/`trackColor`）。

- **12 处项目原有 info/warning**
  - `use_build_context_synchronously`、`deprecated dart:html`、`unnecessary_library_name`、settings 中废弃的 `RadioListTile.groupValue/onChanged` 等。
  - 这些属于项目既有问题，本次任务**不处理**。

### 已完成的 Phase 5 视觉改动

- `chat_bubble.dart`：气泡圆角统一、纠错卡片颜色亮暗适配、音素评分颜色适配、TTS 按钮文本截断、触摸目标尺寸。
- `chat_input_bar.dart`：输入栏高度约束、发送按钮禁用态、Switch 替代 Continuous 图标、语音按钮宽度自适应、录音按钮颜色适配。
- `chat_message_list.dart`：品牌化 `_EmptyConversation`、`_LoadingConversation`、`_ErrorConversation`。
- `chat_header.dart`：底部分隔线、标题行居中对齐、状态点颜色适配。
- `avatar_stage.dart`：状态胶囊颜色/阴影/文本截断、thinking/listening 动效点、fallback 背景亮暗适配。
- `chat_screen.dart`：语音未配置提示条颜色适配、游客计时条文本截断。
- `app_localizations.dart`：新增 `common.retry_hint` 等文案。

### 剩余可落地的视觉问题

基于 `visual-analysis-issues.md` 的 220 条发现，筛选出以下**高影响、易修复**项目（按文件分组）：

#### 1. 主题颜色遗漏（高影响、易修复）
- `chat_screen.dart` 侧栏与聊天区分隔线固定使用 `AppColors.glassBorder`，亮色主题下应使用 `AppColors.lightGlassBorder`。
- `chat_input_bar.dart` 语音模式下的 "Release to send" 提示文字固定使用 `AppColors.textSecondary`。
- `chat_input_bar.dart` Continuous Switch 启用态标签固定使用 `AppColors.accentPrimary`。
- `chat_bubble.dart` `_TtsRetryButton` 的 warning 颜色固定使用 `AppColors.warning`。
- `chat_bubble.dart` `TypingBubble` 的强调色和边框固定使用 `AppColors.accentPrimary`。

#### 2. 文字截断与自适应（高影响、易修复）
- `chat_input_bar.dart` "Release to send" 提示文字缺少截断。
- `chat_input_bar.dart` 重试进度提示 `retryHint` 已截断，需保持。
- `chat_bubble.dart` 纠错卡片类型标签/解释文本已做截断，需验证。

#### 3. 空状态/加载态文案与引导（中影响、易修复）
- `chat.start_hint` 文案可补充 "type or tap the mic" 引导（VA-104）。
- 空状态图标已品牌化，保持不变。

#### 4. 间距与布局一致性（中影响、易修复）
- `chat_bubble.dart` 用户消息右侧外边距可微调（VA-055）。
- `chat_message_list.dart` 同一说话者连续消息间距已调整为 `xxs`，不同说话者为 `md`，需验证。
- `chat_input_bar.dart` 文本模式下语音按钮与输入框间距已为 `sm`，保持。

#### 5. 圆角一致性（低影响、易修复）
- `avatar_stage.dart` fallback 与主渲染区域圆角保持一致，已处理。
- `chat_input_bar.dart` 输入框圆角为 `xl`，与气泡 `lg` 有差异，但属于设计选择，本次不动。

#### 6. 触摸目标与按钮尺寸（中影响、易修复）
- `chat_input_bar.dart` 键盘切换图标按钮 `IconButton` 默认有 48dp 热区，已满足。
- `chat_bubble.dart` 纠错卡片图标按钮已加 `minTapTarget`，需验证。

---

## 拟议变更

### Phase A — 修复 `dart analyze` 阻塞问题

#### A.1 验证并补齐 6 处 Phase 5 回归

| # | 文件 | 修复内容 | 状态 |
|---|------|----------|------|
| 1 | `lib/core/constants/app_constants.dart` | 顶部添加 `import 'package:flutter/animation.dart';` | 已修复，验证 |
| 2 | `lib/core/theme/app_theme.dart` | 顶部添加 `import 'package:flutter/cupertino.dart';` | 已修复，验证 |
| 3 | `lib/main.dart` | 顶部添加 `import 'package:flutter/gestures.dart';` | 已修复，验证 |
| 4 | `lib/widgets/chat/chat_input_bar.dart` | `Switch` 弃用 `activeColor`，改为 `thumbColor` + `trackColor` 的 `WidgetStateProperty` | 已修复，验证 |
| 5 | `lib/features/avatar/presentation/widgets/avatar_stage.dart` | 删除重复 `import 'package:flutter/scheduler.dart';` | 已修复，验证 |
| 6 | `lib/features/chat/presentation/screens/chat_screen.dart` | 删除重复 `import '../../data/chat_repository.dart';` | 已修复，验证 |

#### A.2 修复 `profile_form_screen.dart` 5 处新错误

- 在文件顶部添加 `import 'dart:convert';` 以使用 `jsonEncode`。
- 在文件顶部添加 `import '../../data/profile_repository.dart';` 以使用 `ProfileRepository`。
- 检查 `saveLlmProfile` / `saveSttProfile` / `saveTtsProfile` 的返回类型；如果当前返回 `Future<void>`，则无法访问 `saved.id`。
  - 若返回 void：改用 `await repo.saveLlmProfile(...); final savedId = ...;` 或让 repository 返回保存后的 ID。
  - 实际源码中 `repo.saveLlmProfile(...)` 很可能返回 `Future<String>` 或 `Future<Profile>`。需要读取 `ProfileRepository` 的实现确认签名，然后修正 `_saveProfile` 中的变量类型与 `_maybeActivateOnFirstSave` 调用。

### Phase B — 落地剩余视觉问题

#### B.1 `lib/features/chat/presentation/screens/chat_screen.dart`

**问题**：宽屏布局中侧栏与聊天区的 `VerticalDivider` 颜色未适配亮色主题。

**修改**：
```dart
const VerticalDivider(
  width: 1,
  color: isLight ? AppColors.lightGlassBorder : AppColors.glassBorder,
),
```

由于 `VerticalDivider` 在 build 方法中，需要获取 `isLight` 变量。

**覆盖 VA 编号**：VA-002（分隔不一致）、VA-159（垂直分隔线）。

#### B.2 `lib/widgets/chat/chat_input_bar.dart`

**问题 1**：语音模式下 "Release to send" 提示文字颜色未适配亮色主题，且未截断。

**修改**（约第 300 行）：
```dart
Text(
  isRecording
      ? l.t('chat.stop_recording')
      : l.t('chat.release_to_send'),
  style: TextStyle(
    color: isLight
        ? AppColors.lightTextSecondary
        : AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  textAlign: TextAlign.center,
)
```

**覆盖 VA 编号**：VA-034（release 提示字号/颜色）、通用颜色适配。

**问题 2**：Continuous Switch 启用态标签颜色未适配亮色主题。

**修改**（约第 664 行）：
```dart
color: enabled
    ? (isLight ? AppColors.lightAccentPrimary : AppColors.accentPrimary)
    : (isLight ? AppColors.lightTextSecondary : AppColors.textSecondary),
```

**覆盖 VA 编号**：VA-035/206（Continuous 开关反馈）。

#### B.3 `lib/widgets/chat/chat_bubble.dart`

**问题 1**：`_TtsRetryButton` 的 warning 颜色未适配亮色主题。

**修改**（约第 580 行）：
```dart
final color = isLight ? AppColors.lightWarning : AppColors.warning;
```

**覆盖 VA 编号**：通用颜色适配。

**问题 2**：`TypingBubble` 的强调色和边框未适配亮色主题。

**修改**（约第 650 行）：
```dart
final accent = isLight ? AppColors.lightAccentPrimary : AppColors.accentPrimary;
```

**覆盖 VA 编号**：VA-118/124/125（AI 输入指示、Thinking 状态）。

**问题 3**：用户消息气泡右侧外边距偏小，贴边感明显。

**修改**：在 `ChatBubble.build` 的 `Container` 外边距中，根据 `isUser` 增加右侧 `AppSpacing.sm`：
```dart
margin: EdgeInsets.only(
  bottom: AppSpacing.sm,
  right: isUser ? AppSpacing.sm : 0,
),
```

**覆盖 VA 编号**：VA-055（用户消息右侧外边距）。

#### B.4 `lib/core/i18n/app_localizations.dart`

**问题**：空状态提示未说明可以文字输入（VA-104）。

**修改**：更新 `chat.start_hint` 中英文文案：
- zh: "输入文字或点击麦克风开始对话"
- en: "Type a message or tap the mic to start speaking"

### Phase C — 验证与报告

1. 运行 `/opt/flutter/bin/dart analyze`。
2. 确认：
   - `profile_form_screen.dart` 无 error。
   - 6 处 Phase 5 回归无 error/warning。
   - 没有新增 error。
   - 剩余 issue 仅为项目原有 info/warning（约 12 条）。
3. 生成 `/tmp/speakflow-e2e-run/visual-analysis-implementation-report.md`：
   - 执行摘要与覆盖的 VA 编号。
   - 已完成修改清单（编号/简述/文件/关键代码）。
   - 本次修复的 analyze 回归（含 `profile_form_screen.dart` 5 处）。
   - 暂缓项（需素材/后端/设计的问题）。
   - 最终 `dart analyze` 结果。

---

## 假设与决策

- **范围控制**：优先修复阻塞 analyze 的错误，再处理高影响/易修复的视觉问题；不处理需要新素材、后端支持或复杂动画的项（如 Live2D 口型、音量波形、情绪素材切换）。
- **`profile_form_screen.dart` 错误**：虽然不在用户列出的 6 处回归中，但它们是当前 analyze 中的真实 error 且位于近期修改的文件中，会阻塞编译验证，因此必须修复。
- **不改动 e2e 测试代码**：严格遵循用户要求，仅修改 `lib/` 与 i18n 文案。
- **颜色适配原则**：所有使用 `AppColors.accentPrimary`、`AppColors.warning`、`AppColors.textSecondary`、`AppColors.glassBorder` 的硬编码位置，在亮色主题下统一切换为对应的 `AppColors.light*` 变量。
- **移动端优先**：任何尺寸/间距调整必须通过 `Responsive` 工具或 `LayoutBuilder` 保证在窄屏下不溢出、不截断。
- **报告真实性**：报告中列出的“已完成编号”只包含本次实际落地的视觉优化，不会虚构未实现项。

---

## 验证步骤

1. 执行 Phase A 的 analyze 修复。
2. 执行 Phase B 的视觉问题修改。
3. 在 `/workspace` 运行 `/opt/flutter/bin/dart analyze`。
4. 确认：
   - `app_constants.dart`、`app_theme.dart`、`main.dart`、`chat_input_bar.dart`、`avatar_stage.dart`、`chat_screen.dart`、`profile_form_screen.dart` 不再报 error。
   - 没有新的 error 产生。
   - 剩余 info/warning 数量与项目原有基数一致。
5. 生成并写入报告文件。
6. 再次 `dart analyze` 确认报告写入未影响分析结果。
