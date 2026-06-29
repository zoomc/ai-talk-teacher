# Review 2 — UI 美观度 / 鲜明动感 / 艺术设计感 / 交互合理性 / 流畅度

> 评审对象: SpeakFlow
> 评审日期: 2026-06-29
> 对照设计规范: docs/design-reference.md
> 评审范围: theme / constants / responsive / glass_widgets / virtual_character / 全部主要 screens / router

---

## 一、UI 美观度

### 1.1 优点

- **色彩体系与规范高度一致**：`app_colors.dart:7-38` 完整实现了深空蓝背景 (`#0A0E1A/#111827/#1A2035`)、紫 (`#6C5CE7`) 青 (`#00D2FF`) 强调色、语义色 (success/warning/error/info)、glow (purple/cyan/green 30%)、`gradientBg` 与 `gradientPrimary`，与 `design-reference.md` §四色板逐项对齐。
- **GlassCard 是真毛玻璃**：`glass_widgets.dart:47-66` 使用 `ClipRRect` + `BackdropFilter(blur 20)` + `0.06` 白底 + `0.08` 白边 + 可选 glow shadow，与规范 §3.1/§3.2 token 完全吻合。
- **间距/圆角 token 化**：`app_constants.dart:1-19` 定义 `AppSpacing`(4 基数) 与 `AppRadius`，全项目统一引用，没有出现散落 magic number 体系。
- **字号层级规范**：`app_text_styles.dart:6-63` 的 display/heading/title/body/caption/overline 字号字重与规范 §5.2 一一对应。
- **玻璃卡片在主屏贯穿**：Home/Scenarios/Review/Progress/History/Settings/Tutor/Placement 普遍用 `GlassCard`，视觉语言一致。
- **状态色映射语义清晰**：纠错卡 grammar→error / vocabulary→warning / pronunciation→cyan（`chat_screen.dart:934-942`、`review_screen.dart:191-199`），符合规范 §4.2。
- **可访问性色彩改进**：`app_colors.dart:32` 注释说明 `textMuted` 已从 `#5A6478` 提升到 `#7A8494` 以满足 ~4.5:1。
- **现代色彩 API**：全项目 36 处统一使用 `withValues(alpha:)`，无遗留 `withOpacity`。

### 1.2 问题

- **【P1】Inter 字体实际未加载**：`app_text_styles.dart:4` 声明 `fontFamily = 'Inter'`，但 `pubspec.yaml` 既未声明 `google_fonts` 也未在 `fonts:` 段注册 Inter 资源（grep `Inter` 在 pubspec 无命中）。结果是全部文本静默回退到系统 sans-serif，规范 §5.1 的“英文字体 Inter/SF Pro”未落地，跨平台字体不一致。
- **【P2】大量内联 TextStyle 硬编码字号**：`chat_screen.dart:205`(13)、`chat_screen.dart:990`(10)、`chat_screen.dart:1119`、`glass_widgets.dart:205-206`(13)、`scenarios_screen.dart:217`(11)、`review_screen.dart:237-238`(11)、`tutor_selection_screen.dart:168-169`(11)、`history_screen.dart` 等普遍直接写 `fontSize: N`，绕过 `AppTextStyles`，破坏字体一致性。
- **【P2】录音按钮尺寸与规范不符**：`chat_screen.dart:1099-1100` 录音按钮 `48x48`，而规范 §8.1 与 §10 明确要求录音按钮 `64px`；`glass_widgets.dart:85` 的 `GlowButton` 默认 64 却未被采用。
- **【P2】玻璃材质未贯穿到条/栏/弹窗**：
  - 聊天输入栏用纯色 `bgSecondary`（`chat_screen.dart:1078`），未玻璃；
  - AppBar 透明但无 blur，与玻璃卡片视觉断层；
  - 会话选项 BottomSheet 用 `bgTertiary` 纯色（`chat_screen.dart:575-576`）；
  - 所有 `AlertDialog`（`home_screen.dart:379`、`history_screen.dart:62`、`service_config_screen.dart:399/424/529`、`profile_form_screen.dart:765`、`onboarding_screen.dart:527`、`settings_screen.dart:208/266/326`）均为 `bgTertiary` 纯色卡片，无玻璃处理，与“Glassmorphism 整体基调”割裂。
- **【P2】硬编码非 token 颜色**：`tutor_selection_screen.dart:95` 给 `pronunciation` 风格写死 `Color(0xFF9C27B0)`，未走 `AppColors`；`profile_form_screen.dart:433-436` import 对话框内联 `monospace` 字体名。
- **【P2】加载态样式不统一**：规范 §4.2 要求“加载骨架屏 gray-5→gray-6 微光扫描 (Shimmer)”，`ShimmerBox` 已实现（`glass_widgets.dart:216-243`）但仅在 `home_screen.dart:177` 使用一次；其余 7 处 loading 全用原生 `CircularProgressIndicator`（`chat_screen.dart:704`、`scenarios_screen.dart:137`、`review_screen.dart:44`、`history_screen.dart:108`、`progress_screen.dart:38`、`service_config_screen.dart:64`、`profile_form_screen.dart:197`），与玻璃/科技风格不符。
- **【P2】chat 空状态偏简陋**：`chat_screen.dart:644-670` 仅一个灰图标 + 两行文字，无插画、无 CTA 按钮，对比 `review_screen.dart:53-92`、`history_screen.dart:110-136` 都带按钮，体验不一致。

### 1.3 严重度

| 项 | 严重度 |
|----|-------|
| Inter 字体未加载（影响全部文本） | P1 |
| 录音按钮尺寸/弹窗玻璃断层/内联字号/加载态不统一 | P2 |
| 空状态简陋、硬编码颜色 | P2 |

---

## 二、鲜明动感程度 (动画/状态切换)

### 2.1 优点

- **VirtualCharacter 三套独立动画**：呼吸 (`virtual_character.dart:52-59`, 3s)、外发光脉冲 (`61-68`, 1.5s)、嘴型 (`71-77`, 220ms)，并在 `didUpdateWidget` 中按 speaking 状态启停嘴型 (`81-91`)，体现了“生命感”。
- **状态→颜色映射正确**：`virtual_character.dart:101-112` idle=紫 / listening=青 / thinking=紫 / speaking=绿，与规范 §4.2 “AI 思考中紫脉冲 / 说话中绿脉冲 / 监听中青”完全一致。
- **打字指示器有节奏感**：`_TypingBubble`（`chat_screen.dart:734-812`）三点错峰弹跳（每点延迟 0.15 周期，1.2s 循环），比静态三点更有活力。
- **Home 入场动画**：`home_screen.dart:86-88` 头部 logo `fadeIn(600ms)+scale(0.8→1)`；`home_screen.dart:268` Quick Action 卡片 `fadeIn+slideX` 错峰 150ms 递增 (300/450/600/750/900ms)，符合规范 §8.3 “气泡/卡片弹性入场”的精神。
- **状态过渡用 AnimatedContainer**：`virtual_character.dart:144-162` 与 `204-248` 用 200–300ms `AnimatedContainer` 做颜色/阴影过渡，避免突变。
- **Onboarding/Placement 进度条**：`onboarding_screen.dart:237-252`、`placement_screen.dart:73-88` 都有 4 段进度条随步骤点亮。

### 2.2 问题

- **【P0】聊天录音按钮是静态的，规范 §8.1 录音动效几乎完全未实现**：`chat_screen.dart:1098-1121` 是一个普通 `Container` + 单个静态 `BoxShadow`，**没有**：
  - 待机呼吸光晕 (opacity 0.3→0.6 循环 2s)；
  - 按下 scale 0.95 + 涟漪 2-3 层同心圆扩散；
  - 松手青色脉冲 + 消散。
  - 唯一带脉冲的 `GlowButton`（`glass_widgets.dart:73-160`，含 `_glowAnimation` 0.3↔0.6 循环）**从未被任何页面引用**（grep 确认仅定义文件命中），属于死代码。
- **【P1】聊天气泡无入场动画**：规范 §8.3 要求“气泡出现：底部弹性滑入 + opacity (250ms spring)”。`_ChatMessageList` 用 `ListView.builder` 直接 rebuild（`chat_screen.dart:678-700`），新气泡瞬切出现，无 `flutter_animate` 入场，与 Home 卡片动画风格脱节。
- **【P1】路由转场被显式关闭**：`app_router.dart:67-84` 全部 shell 路由用 `NoTransitionPage`，规范 §8.3 要求“主页→设置：右侧毛玻璃面板滑入 300ms ease-out / 主页→历史：左侧滑入”。当前 Tab 切换是瞬切。
- **【P1】AI 状态背景未做“微渐变流动”**：规范 §8.2 要求“思考中：紫色渐变背景缓慢流动 / 说话中：绿色渐变背景”。`VirtualCharacter` 的背景是固定 `_stateColor.alpha 0.1` 纯色（`virtual_character.dart:150`），只有 boxShadow 脉冲，没有渐变背景动画。
- **【P2】无音频波形可视化**：规范 §8.2 “监听中：录音波纹随声音大小变化”完全未实现；嘴型只是 `Transform.scale` 0.85↔1.15 tween（`virtual_character.dart:75-77,178-186`），并非真正嘴型同步。
- **【P2】`StatusPill` 死代码**：`glass_widgets.dart:163-213` 定义了带状态点的 pill，但 `VirtualCharacter` 自建了等价组件（`virtual_character.dart:204-248`），`StatusPill` 从未被使用，浪费且不一致。
- **【P2】无 Lottie / signature 动效**：规范 §7.1 推荐 `lottie 3.4.0`，pubspec 未引入；除入场 fade/slide 外无标志性动效（如录音波纹、AI 思考流光、纠错高亮闪现）。

### 2.3 严重度

| 项 | 严重度 |
|----|-------|
| 录音按钮无脉冲/涟漪（规范核心交互动效缺失），GlowButton 死代码 | P0 |
| 气泡无入场动画 / 路由无转场 / AI 状态无渐变背景 | P1 |
| 无音频波形 / StatusPill 死代码 / 无 Lottie | P2 |

---

## 三、艺术设计感

### 3.1 优点

- **品牌识别清晰**：紫(#6C5CE7)+青(#00D2FF)+深空蓝(#0A0E1A) 的三色体系有“AI 科技感”定位，`gradientPrimary` 作为 logo/发送按钮底色（`chat_screen.dart:1181`、`home_screen.dart:75`、`app_router.dart:267`）形成一致签名。
- **glass + glow 视觉语言统一**：`GlassCard` 的 `glowColor` 参数让“选中/活跃”状态用同色光晕表达（`service_config_screen.dart:207` active profile 紫光、`tutor_selection_screen.dart:126` 按 tutor 风格变色光晕），有设计主张。
- **VirtualCharacter 状态色语义**：把 AI 的 listening/thinking/speaking 用色彩传达，是同类 AI 应用里少见的“状态可视化”设计意图。

### 3.2 问题

- **【P1】规范力荐的 `liquid_glass_widgets` 完全未采用**：`design-reference.md` §7.1 将其列为“首选”（shader 折射、Liquid Morph 果冻变形、动态光照、内容感知亮度）。实际 `pubspec.yaml` 仅引入 `shimmer` + `flutter_animate`，玻璃效果是基础 `BackdropFilter` 单层模糊，规范的“艺术野心”未落地。
- **【P1】原生 Material 组件未做玻璃化主题**：`CircularProgressIndicator`、`ListTile`（`settings_screen.dart:421`）、`AlertDialog`、`RadioListTile`（`settings_screen.dart:219-236`）、`PopupMenuButton`（`service_config_screen.dart:279`）、`NavigationBar`（`app_router.dart:157`）大量直接使用 Material 默认样式，与玻璃卡片世界并存时显得“半成品”。
- **【P2】角色缺乏个性**：`VirtualCharacter` 本质是一个 emoji（如 `👩‍🏫`）放在发光圆里（`virtual_character.dart:182-186`），规范参考 Praktika/Speak 的“角色 + 流体动画”未体现；不同 tutor 仅靠 emoji + accentColor 区分，辨识度低。
- **【P2】全项目使用 Material Icons，无自定义图标/插画系统**：规范 §九推荐 Lucide/Heroicons，实际全部 `Icons.xxx`，缺少品牌专属图形语言。
- **【P2】缺少 signature moment**：没有标志性视觉时刻（如录音全屏波纹、AI 思考流光、纠错高亮动画），整体观感是“标准 Material Dark + 玻璃卡片”，与同类 AI 应用区分度不足。
- **【P2】对话框/弹窗视觉断层**：主界面是玻璃 + 渐变背景，点开任何 dialog/bottomSheet 立刻变成纯色 `bgTertiary` 卡片（如 `chat_screen.dart:575`、`home_screen.dart:379`），破坏沉浸感。

### 3.3 严重度

| 项 | 严重度 |
|----|-------|
| liquid_glass_widgets 未采用 / Material 组件未玻璃化 | P1 |
| 角色无个性 / 无自定义图标 / 无 signature moment / 弹窗断层 | P2 |

---

## 四、交互合理性 (流程/空状态/错误反馈)

### 4.1 优点

- **配置缺失带可操作 CTA**：`chat_screen.dart:551-570` 当 LLM/STT/TTS 未配置时，SnackBar 附“Configure”按钮一键跳 `/service-config`，6 秒停留，体验优于纯报错。
- **键盘快捷键**：`chat_screen.dart:103-111` Esc 取消录音，桌面/Web 友好。
- **删除前确认**：`history_screen.dart:59-81`、`service_config_screen.dart:526-585`、`profile_form_screen` 均有 confirm dialog。
- **Onboarding 分级确认**：`onboarding_screen.dart:422-447` LLM 缺失强阻断、STT/TTS 缺失软提示，引导合理。
- **语音输入后回焦点**：`chat_screen.dart:417` 转写后 `requestFocus` 回输入框，便于编辑后回车发送。
- **会话恢复**：`home_screen.dart:43-50` 检测到 active session 弹“继续/新话题”。
- **响应式布局**：`responsive.dart` + `app_router.dart:120-184` 桌面用 NavRail、手机用 BottomNav，chat 宽屏侧栏 / 窄屏顶栏切换。

### 4.2 问题

- **【P0】删除会话功能实际未实现**：
  - `history_screen.dart:82-87` 用户确认删除后弹出 `SnackBar(content: Text('Delete not implemented'))`，功能缺失却暴露长按入口；
  - `chat_screen.dart:599-606` 会话选项 BottomSheet 的“Delete Session” `onTap: () => Navigator.pop(context)`，**点了直接关 sheet，什么都没做**。两条路径都是假按钮。
- **【P0】Tutor 选择流程断裂**：`chat_screen.dart:166` 用 `context.push('/tutor-selection')` 打开选择页，但 `tutor_selection_screen.dart:70-73` 的 `_selectTutor` 仅 `context.pop(tutor.id)` 把 id 作为返回值丢回去——而 `push` 调用方根本没接收 `.then(...)`，也没有写入 `selected_tutor_id`。实际生效靠 `ChatScreen._loadTutorIdentity`（`chat_screen.dart:70-86`）读 `selected_tutor_id`，但该 setting 从未被这个页面写入，导致**用户在 chat 里点切换 tutor 后选了也没用**（除非别处写入，但本批文件未见）。
- **【P1】Scenarios 无空状态**：`scenarios_screen.dart:62-135` 列表为空时直接渲染空 `grouped`，页面只剩标题，无“暂无场景”提示或 CTA。
- **【P1】错误态简陋且暴露原始异常**：`scenarios_screen.dart:138`、`progress_screen.dart:39`、`chat_screen.dart:705` 仅 `Text('Error: $e')` 居中显示，无重试按钮、无友好文案；`chat_screen.dart:616-620` 虽截断到 160 字符但仍直接吐 `e.toString()`，可能含 provider 提示。
- **【P1】多处占位“假入口”**：`settings_screen.dart:108-117` “Interface Language”→SnackBar“coming in a future update”；`settings_screen.dart:144-150` “Export Learning Data”→“coming soon”。占位项未禁用或加 Coming soon 角标，用户会误以为是 bug。
- **【P2】录音缺电平/时长反馈**：`chat_screen.dart:1098-1121` 录音中只有按钮变红 + 状态文字“Listening...”，无录音时长计时、无音量电平条，用户无法判断是否在收音。
- **【P2】录音无最大时长限制**：长时间录音无自动停止/提示，易产生超长音频导致 STT 失败。
- **【P2】chat 空状态无 CTA**：`chat_screen.dart:644-670` 仅文字“Type a message or tap the mic button”，没有“开始 Free Talk”按钮，与新用户首屏预期不符。
- **【P2】长按删除不可发现**：`history_screen.dart:170` `onLongPress` 触发删除，无任何视觉/hint 提示，移动端用户难以发现。
- **【P2】Tutor 卡无选中态**：`tutor_selection_screen.dart:124-201` `_TutorCard` 不接收当前选中 id，无法高亮已选 tutor。
- **【P2】placement 选项无回看/修改**：`placement_screen.dart:165-173` 选择即自动前进，无法返回修改上一题（只能 `_currentQuestion++`，无 back 按钮，与 onboarding 的 Back 按钮不一致）。

### 4.3 严重度

| 项 | 严重度 |
|----|-------|
| 删除会话两处假按钮 / Tutor 选择不生效 | P0 |
| Scenarios 无空状态 / 错误态暴露原始异常 / 占位假入口 | P1 |
| 录音无电平时长 / chat 空状态无 CTA / 长按不可发现 / Tutor 无选中态 / placement 不可回看 | P2 |

---

## 五、交互流畅度 (性能/rebuild/focus)

### 5.1 优点

- **防止 listener 堆积**：`chat_screen.dart:530-545` `_attachPlayerStateListener` 每次 play 前 `_playerStateSub?.cancel()`，并在 `dispose`（`chat_screen.dart:90`）取消，修复了注释所述的内存泄漏。
- **动画 controller 正确释放**：`virtual_character.dart:94-99`、`glass_widgets.dart:112-116`、`chat_screen.dart:755-758` 均在 dispose 释放。
- **内容宽度约束**：`chat_screen.dart:221-224,238-241`、`home_screen.dart:59-62`、`progress_screen.dart:30-33` 等用 `ConstrainedBox(maxWidth: contentMaxWidth)` 保证桌面可读。
- **气泡宽度受 LayoutBuilder 约束**：`chat_screen.dart:838-841` 用 `constraints.maxWidth * bubbleMaxWidthFraction`，桌面不撑满。
- **键盘弹起输入栏可见**：`chat_screen.dart:177` `resizeToAvoidBottomInset: true`，`chat_screen.dart:1067-1075` 手动合并 `viewInsets` 与 safe area。

### 5.2 问题

- **【P0】输入框每次按键触发整屏重建**：`chat_screen.dart:55-57`
  ```dart
  _messageController.addListener(() {
    if (mounted) setState(() {});
  });
  ```
  这会让外层 `_ChatScreenState.build` 重建——即 **Scaffold + AppBar + CharacterPanel + _ChatMessageList 全部 rebuild**。更严重的是 `_ChatMessageList` 内部用 `FutureBuilder<Map<String,List<Correction>>>`（`chat_screen.dart:674-703`）每次 rebuild 都重新执行 `_loadCorrectionsByMessage`（`chat_screen.dart:709-721` 调 `repo.getAllCorrections()` 拉全表），**即每个按键都触发一次全量纠错查询**，在长会话中会造成明显卡顿。应将 send 按钮的 `canSend` 状态用 `ValueListenableBuilder` 局部订阅，而非整屏 `setState`。
- **【P1】VirtualCharacter 三个 controller 永久 repeat**：`virtual_character.dart:59`(`breathing`) 与 `68`(`glow`) 即使 idle 也持续 `repeat(reverse:true)`，3s+1.5s 两个 ticker 常驻，电量/CPU 持续消耗。建议 idle 时降速或暂停光晕、仅保留呼吸。
- **【P1】`_QuickActionGrid` 桌面端宽度计算有 bug 风险**：`home_screen.dart:349-364` 计算 `SizedBox.width` 用的是 `MediaQuery.sizeOf(context).width - screenHorizontalPadding*2 - AppSpacing.md*(cols-1) - AppSpacing.lg*2`，但该 grid 的外层已被 `ConstrainedBox(maxWidth: contentMaxWidth)`（`home_screen.dart:59-62`）夹住，且桌面端左侧还有 NavRail（`app_router.dart:131-149`）。结果是基于“全屏宽”算出的卡片宽 > 实际可用宽，可能导致溢出或卡片过宽；应基于 `LayoutBuilder` 的 `constraints.maxWidth` 计算。
- **【P1】命名约定破坏**：`home_screen.dart:271` 方法名 `_QuickActionGrid()`（下划线后大写 Q）违反 Dart lowerCamelCase 约定，且与同文件 `_quickActionItem`（`home_screen.dart:254`，小写 q）不一致，易误读。
- **【P1】build 内触发副作用**：`home_screen.dart:43-50` 在 `build` 内 `activeSession.whenData(...)` 调用 `_showContinueDialog`，虽用 `_promptedForActiveSession` flag + `addPostFrameCallback` 保护，仍属于 build 内副作用，Riverpod 下应改用 `ref.listen` 在 listener 中触发。
- **【P2】大量 setState 驱动整屏状态**：`review_screen.dart:18-35`、`history_screen.dart:18-37`、`service_config_screen.dart:24-50`、`settings_screen.dart:17-42` 都用本地 `_isLoading` + 列表字段 + `setState`，列表变更触发整屏 rebuild；可下沉到 Riverpod `AsyncNotifier` 以利用 provider 缓存。
- **【P2】对话框无 focus trap / 焦点恢复**：`AlertDialog` 与 `showModalBottomSheet`（`chat_screen.dart:573`、`settings_screen.dart` 多处）关闭后焦点不还原到触发控件，键盘导航断裂。
- **【P2】`_TypingBubble` controller 永久 repeat**：`chat_screen.dart:748-752` `_controller..repeat()`，虽仅在 thinking 时挂载，但若 `isAiThinking` 长时间 true 会持续跑；可接受但值得注意。
- **【P2】无 `MediaQuery.accessibleNavigation` / `reduce-motion` 处理**：规范 §十要求“读取系统 reduce-motion 设置，关闭动画”，全项目未读取该设置，呼吸/脉冲/打字点动画无法被无障碍用户关闭。

### 5.3 严重度

| 项 | 严重度 |
|----|-------|
| 输入框按键触发整屏 rebuild + 全量纠错重查 | P0 |
| VirtualCharacter 常驻 repeat / 桌面 grid 宽度 bug / 命名违规 / build 内副作用 | P1 |
| setState 驱动整屏 / 无 focus trap / 无 reduce-motion | P2 |

---

## 六、设计规范对照差距表

| 规范要求 | 实现状态 | 文件:行 |
|---------|---------|---------|
| Glassmorphism `BackdropFilter` blur 20 | ✅ 已实现 | `glass_widgets.dart:49-50` |
| 玻璃 border `rgba(255,255,255,0.08)` | ✅ 已实现 | `glass_widgets.dart:56-60` |
| glow-purple/cyan/green 30% | ✅ 已实现 | `app_colors.dart:36-38` |
| 色板 12 级灰阶 | ❌ 未定义灰阶 token（仅 textPrimary/Secondary/Muted） | `app_colors.dart:30-33` |
| 英文字体 Inter / SF Pro | ❌ 声明 Inter 但 pubspec 未注册，回退系统字体 | `app_text_styles.dart:4` / `pubspec.yaml` |
| 字号层级 display/heading/title/body/caption/overline | ✅ 已实现 | `app_text_styles.dart:6-63` |
| 间距 4 基数 + 圆角 8/12/16/20 | ✅ 已实现 | `app_constants.dart:1-19` |
| 录音按钮 64px + 圆形 | ❌ chat 用 48px | `chat_screen.dart:1099` |
| 录音待机呼吸光晕 (0.3→0.6, 2s) | ❌ 录音按钮静态阴影；`GlowButton` 有脉冲但未使用 | `chat_screen.dart:1106-1115` / `glass_widgets.dart:99-110` |
| 录音按下涟漪 2-3 层 | ❌ 未实现 | `chat_screen.dart:1098-1121` |
| AI 思考：紫色渐变背景流动 + 3 点脉冲 | ⚠️ 仅 3 点脉冲，无渐变背景流动 | `virtual_character.dart:150` / `chat_screen.dart:734-812` |
| AI 说话：绿色渐变背景 + 嘴型同步 | ⚠️ 仅绿色 boxShadow + scale tween，非真同步 | `virtual_character.dart:109,178-186` |
| 监听中：青色渐变 + 录音波纹随声音 | ❌ 无音频波形可视化 | `virtual_character.dart:105` |
| 气泡出现：底部弹性滑入 + opacity (250ms spring) | ❌ 无入场动画 | `chat_screen.dart:678-700` |
| 页面转场：右侧/左侧毛玻璃面板滑入 300ms | ❌ 路由用 `NoTransitionPage` 显式关闭 | `app_router.dart:67-84` |
| 加载骨架屏 Shimmer gray-5→gray-6 | ⚠️ `ShimmerBox` 已实现但仅用 1 处，其余用 `CircularProgressIndicator` | `glass_widgets.dart:216-243` / `home_screen.dart:177` |
| `liquid_glass_widgets` shader 玻璃（首选） | ❌ pubspec 未引入 | `pubspec.yaml` |
| 错误词同时用红色 + 下划线 + (error) 标签 | ⚠️ 有红色+删除线，无“(error)”文字标签 | `chat_screen.dart:999-1013` |
| 触摸目标 ≥ 44x44 | ✅ 录音/发送 48x48，TTS listen 按钮 44x36 | `chat_screen.dart:1099,1177,889-892` |
| 文字对比度 WCAG AA 4.5:1 | ⚠️ textMuted 已改善，textSecondary #8892A4 未注释验证 | `app_colors.dart:31-32` |
| 动画可关闭 (reduce-motion) | ❌ 未读取系统设置 | 全项目 |
| 玻璃层文字加 0.8+ 底色 | ⚠️ GlassCard 内文字直接落在 0.06 白底上，深色文字可读但浅色未额外加底 | `glass_widgets.dart:51-63` |

---

## 七、改进建议 (按优先级)

### P0（阻断核心体验，应立即修）

1. **修复“删除会话”假按钮**：`history_screen.dart:82-87` 实现 `repo.deleteSession`，或移除长按入口；`chat_screen.dart:599-606` 的 “Delete Session” 要么实现要么删除菜单项。
2. **修复 Tutor 选择流程**：`tutor_selection_screen.dart:70-73` 选定后应 `await repo.setSetting('selected_tutor_id', tutor.id)` 再 pop；`chat_screen.dart:166` 改用 `context.push('/tutor-selection').then(...)` 在返回后 `setState` 刷新 `_tutorName/_tutorAvatar`，或直接读 provider。
3. **录音按钮接入脉冲/涟漪动效**：把 `chat_screen.dart:1098-1121` 的静态按钮替换为已存在的 `GlowButton`（`glass_widgets.dart:73-160`），并补充按下时的 2-3 层同心圆 `AnimatedBuilder` 涟漪（参考规范 §8.1）。这同时消除 `GlowButton` 死代码。
4. **消除输入框按键整屏 rebuild**：`chat_screen.dart:55-57` 改为 `ValueListenableBuilder<bool>` 仅订阅 `controller.text`，让 send 按钮局部重建；`_ChatMessageList` 内的 `FutureBuilder` 改为 `ref.watch(correctionsByMessageProvider)` 缓存，避免每次按键全量重查 corrections。

### P1（影响一致性与流畅度，近期修）

5. **注册 Inter 字体**：在 `pubspec.yaml` 的 `flutter.fonts:` 段声明 Inter（或引入 `google_fonts`），让 `app_text_styles.dart:4` 的 `fontFamily` 真正生效。
6. **气泡入场动画**：用 `flutter_animate` 给 `_ChatBubble` 加 `.fadeIn().slideY(begin: 0.1, duration: 250.ms)`（规范 §8.3）。
7. **路由转场**：将 shell 路由的 `NoTransitionPage` 替换为带 300ms `CustomTransitionPage`（侧滑/淡入），符合规范 §8.3。
8. **AI 状态背景渐变流动**：`VirtualCharacter` 的外层 `Container` 改为 `AnimatedBuilder` 驱动的 `LinearGradient`，让 thinking/speaking 有流动渐变背景（规范 §8.2）。
9. **加载态统一为 Shimmer**：把 `chat/scenarios/review/history/progress/service_config` 的 `CircularProgressIndicator` 替换为 `ShimmerBox` 骨架屏（规范 §4.2）。
10. **错误态与空态补全**：Scenarios 加空状态；scenarios/progress/error 改为友好文案 + “重试”按钮；chat 空状态加“开始 Free Talk”CTA。
11. **占位入口处理**：`settings_screen.dart:108-117,144-150` 的“coming soon”项要么加 `Badge/Disabled`，要么移除，避免误判 bug。
12. **桌面 grid 宽度修正**：`home_screen.dart:349-364` 改用 `LayoutBuilder` 取 `constraints.maxWidth` 计算卡片宽，修正 NavRail + contentMaxWidth 双重约束下的溢出。
13. **VirtualCharacter idle 降速**：`virtual_character.dart:61-68` 在 `state == idle` 时暂停或降频 glow controller，节省电量。
14. **重命名**：`home_screen.dart:271` `_QuickActionGrid` → `_quickActionGrid`（lowerCamelCase）。

### P2（打磨与艺术提升，迭代修）

15. **对话框/弹窗玻璃化**：封装一个 `GlassAlertDialog` / `GlassBottomSheet`，把 `bgTertiary` 纯色替换为 `BackdropFilter` 玻璃，消除视觉断层。
16. **引入音频波形/电平**：录音中显示音量电平条 + 时长计时；可选引入 `liquid_glass_widgets` 或自绘波形（规范 §8.2）。
17. **角色个性化**：给每个 tutor 配独立 Lottie/插画，嘴型同步用 `tts_playback_service` 的 audio amplitude 驱动，而非固定 tween。
18. **补全灰阶 token**：`app_colors.dart` 增加 gray-1..gray-12，替换内联 `bgTertiary/bgSecondary` 混用。
19. **统一内联字号**：把 `chat_screen.dart:205,990`、`scenarios_screen.dart:217` 等内联 `fontSize` 收敛进 `AppTextStyles`（如新增 `label`/`badge` 样式）。
20. **reduce-motion 支持**：读取 `MediaQuery.accessibleNavigation` 与平台 `reduceMotion`，关闭呼吸/脉冲/打字点动画（规范 §十）。
21. **删除死代码**：未使用的 `StatusPill`（`glass_widgets.dart:163-213`）要么接入 `VirtualCharacter` 替换其自建 pill，要么删除。
22. **placement 可回看**：`placement_screen.dart` 增加 Back 按钮，允许修改上一题答案。
23. **Tutor 卡选中态**：`tutor_selection_screen.dart:124-201` 接收当前 selected id，已选的卡片高亮 glow。
24. **history 长按可发现性**：在 list 项加 `IconButton(delete)` 或在 AppBar 加“编辑模式”，替代隐式 `onLongPress`。

---

> 综合评价：SpeakFlow 在色彩体系、间距/圆角 token、GlassCard 基础毛玻璃、VirtualCharacter 状态色映射上与设计规范高度对齐，是一套“可用的 Glassmorphism 暗色 AI 应用”。但与规范的**艺术目标**（liquid_glass shader、录音涟漪/波形、AI 渐变流动、气泡弹性入场、路由毛玻璃转场）差距明显；同时存在两处**功能性假按钮**（删除会话、tutor 选择不生效）和一处**性能 P0**（输入按键触发整屏 rebuild + 全量纠错重查），需优先修复。
