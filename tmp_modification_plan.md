# SpeakFlow 修改与改善计划

> 基于 4 份评审文件 (`tmp_review1_learning.md` / `tmp_review2_ui.md` / `tmp_review3_config.md` / `tmp_review4_ai_usage.md`) 汇总，对照 `projects.md` 规格，按优先级与工作量制定可执行计划。
> 制定日期: 2026-06-29

---

## 一、P0 必修项 (核心可用性 / 首次体验 / 性能阻断)

### P0-1 接通 SM-2 调度到运行时 + 补 quality 评分 UI (学习闭环核心)
- **问题**: `Sm2Service.scheduleReview` (`lib/features/review/data/sm2_service.dart:7-50`) 全工程仅被测试代码引用；`Correction` 创建后 `reviewCount/easinessFactor/intervalDays/nextReviewAt` 永不更新；`ProgressScreen` "Mastered" 永远 0；所有 corrections 永远 "New"。
- **修改方案**:
  1. 在 `ReviewScreen` 的 `_CorrectionCard` 增加"评分操作条" (Again / Hard / Good / Easy → quality 1/3/4/5)，点击后调用 `Sm2Service.scheduleReview` + `repo.updateCorrection`，本地 `setState` 刷新该卡片状态。
  2. 复习会话中，让 LLM 在 corrections JSON 中可选返回 `recall_quality` 字段 (AI 自动判分回写)，作为评分兜底。
  3. `LearningStatsService` 的 `masteredCount/learningCount` SQL 会在接通后自动恢复正确。
- **影响文件**:
  - `lib/features/chat/presentation/screens/review_screen.dart` (新增评分 UI + 接 Sm2Service)
  - `lib/features/chat/data/chat_repository.dart` (确认 `updateCorrection` 存在)
  - `lib/features/chat/domain/chat_models.dart` (确认 `copyWith` 支持 SM-2 字段更新)
- **验证**: `test/sm2_service_test.dart` 已存在；新增 review_screen 集成测试可选。

### P0-2 修复"删除会话"两处假按钮
- **问题**: `history_screen.dart:82-87` 弹 "Delete not implemented"；`chat_screen.dart:599-606` "Delete Session" 仅 `Navigator.pop`。
- **修改方案**:
  1. `ChatRepository` 增加 `deleteSession(sessionId)` 方法 (DELETE chat_sessions + 级联 chat_messages / corrections)。
  2. `history_screen.dart` 确认删除后调用 `repo.deleteSession`，从本地 list 移除，Snack 提示 "Deleted"。
  3. `chat_screen.dart` 会话选项 sheet 的 Delete Session 调同一方法后 `context.go('/home')`。
- **影响文件**: `chat_repository.dart`, `history_screen.dart`, `chat_screen.dart`

### P0-3 修复 Tutor 选择流程
- **问题**: `tutor_selection_screen.dart:70-73` `_selectTutor` 只 `context.pop(tutor.id)`，调用方未接收，`selected_tutor_id` 从未被该页写入 → 用户切 tutor 无效。
- **修改方案**: `_selectTutor` 改为 `await repo.setSetting('selected_tutor_id', tutor.id)` 后 `context.pop()`；`chat_screen.dart:166` 在 `push().then()` 中 `setState` 刷新 `_tutorName/_tutorAvatar`。
- **影响文件**: `tutor_selection_screen.dart`, `chat_screen.dart`

### P0-4 修正 DeepSeek / Kimi 默认模型名
- **问题**: `provider_catalog.dart:70` `deepseek-v4-flash` (不存在)；`:89` `kimi-k2.6` (可疑)。新用户首聊 404。
- **修改方案**: 改为 `deepseek-chat` 与 `moonshot-v1-8k` (官方稳定模型)。
- **影响文件**: `lib/features/profile/domain/provider_catalog.dart`

### P0-5 接通 correction_strength 到 prompt
- **问题**: `settings_screen.dart` 保存 `correction_strength`，但 `TutorPromptBuilder.build` 不读取，spine 不区分三档。
- **修改方案**:
  1. `TutorPromptBuilder.build` 增加 `correctionStrength` 参数 (默认 `moderate`)。
  2. spine "How to correct" 段按 gentle/moderate/strict 调整文案 (gentle: 仅纠影响理解的错误；strict: 纠每个错误含 style/collocation)。
  3. `chat_screen.dart` `_sendMessage` 读 `correction_strength` setting 后传入。
- **影响文件**: `tutor_prompts.dart`, `chat_screen.dart`, `test/tutor_prompts_test.dart`

### P0-6 接通 tts_speed 全局设置
- **问题**: Settings 存 `tts_speed`，但 `TtsService.synthesize` 用 `profile.speed`，全局设置不生效。
- **修改方案**: `ChatScreen._autoplayTts` / 消息播放处读取 `tts_speed`，传入 `TtsPlaybackService.setSpeed` (用 just_audio `setSpeed`)；或在 synthesize 时合并 `profile.speed * globalSpeed` (clamp 0.5-2.0)。优先用 player 侧 `setSpeed` (无需重新合成，省 token)。
- **影响文件**: `tts_playback_service.dart` (加 `setSpeed`), `chat_screen.dart` (播放前 setSpeed)

### P0-7 修复输入框按键触发整屏 rebuild + 全量纠错重查
- **问题**: `chat_screen.dart:55-57` `controller.addListener(setState)` 每键重建整屏；`_ChatMessageList` 的 `FutureBuilder` 每次重建调 `getAllCorrections()` 全表查。
- **修改方案**:
  1. 移除 `addListener(setState)`，发送按钮的 enable 状态改用 `ValueListenableBuilder<bool>` 订阅 `controller` 的 `text.isEmpty`。
  2. `_ChatMessageList` 的 corrections 改为 `ref.watch(correctionsByMessageProvider)` 缓存，或在 `_ChatScreenState` init 时一次加载存为字段，列表用 key 避免 rebuild。
- **影响文件**: `chat_screen.dart`

### P0-8 录音按钮接入脉冲/涟漪动效 (消除 GlowButton 死代码)
- **问题**: `chat_screen.dart:1098-1121` 静态按钮；`glass_widgets.dart:73-160` `GlowButton` 有脉冲但从未被使用。
- **修改方案**: 把录音按钮替换为 `GlowButton` (已有脉冲)，并在按下时叠加 2-3 层同心圆 `AnimatedBuilder` 涟漪；尺寸恢复 64px (符合规范)。
- **影响文件**: `chat_screen.dart`, `glass_widgets.dart` (GlowButton 可能加 ripple 参数)

### P0-9 历史截断 (O(N²) token 防爆)
- **问题**: `chat_repository.dart:75-84` `getMessages` 无 LIMIT，每轮全量历史。
- **修改方案**: `getMessages` 增加 `limit` 参数 (默认 40，约 20 轮)；`chat_screen.dart` 调用时传 limit。
- **影响文件**: `chat_repository.dart`, `chat_screen.dart`, `llm_service.dart`

### P0-10 Progress 统计修复 (dailyActivity 渲染 + masteredCount 接通)
- **问题**: SM-2 接通后 masteredCount 自动恢复；但 `dailyActivity` 字段在 `ProgressScreen` 未渲染。
- **修改方案**:
  1. P0-1 接通后 `masteredCount` 自动正确。
  2. `ProgressScreen` 增加 7 日活跃柱状图 (用 `dailyActivity` 数据，简单 `Container` 高度比例)。
  3. `dailyActivity.corrections` 由 SQL 真实查询 (corrections 表按 created_at date 分组)。
- **影响文件**: `progress_screen.dart`, `learning_stats_service.dart`

---

## 二、P1 重要项 (一致性 / token / 体验)

### P1-1 max_tokens 对齐 Spine
- `llm_service.dart:31` 1000 → 400 (与 "1-4 句" 一致)。
- 可选: 改为 `LlmProfile` 字段可配 (本计划暂不改 profile 模型，仅调默认值)。

### P1-2 移除每轮重发的纠错指令 (省 ~180 tokens/轮)
- `llm_service.dart:81-92` 把 corrections JSON 协议说明**移到 Spine 内** (`tutor_prompts.dart` 的 _spine 末尾)，避免每轮在 `_buildMessages` 重复追加。
- 或保留在 LlmService 但只在 spine 中引用一次。二选一，消除重复。

### P1-3 统一纠错指令 (消除 Spine vs LlmService 矛盾)
- Spine "give a one-line explanation in your reply" 与 LlmService "explanation in JSON" 矛盾。
- 决策: **口语回复保持自然不内联解释，结构化解释只进 JSON** (用户在 UI 卡片看解释，不打断对话流)。修改 spine 文案。

### P1-4 气泡入场动画
- `_ChatBubble` 加 `.fadeIn().slideY(begin: 0.1, duration: 250.ms)` (flutter_animate 已引入)。

### P1-5 路由转场恢复
- `app_router.dart:67-84` `NoTransitionPage` → 带转场的 `CustomTransitionPage` (300ms fade/slide)。

### P1-6 加载态统一 Shimmer
- 7 处 `CircularProgressIndicator` 替换为 `ShimmerBox` 骨架屏 (chat/scenarios/review/history/progress/service_config/profile_form)。

### P1-7 错误态与空态补全
- Scenarios 加空状态；error 文案友好化 + 重试按钮；chat 空状态加 "Start Free Talk" CTA。

### P1-8 Theme 即时切换
- `main.dart` `_themeMode` 改为 Riverpod `themeModeProvider` 或 `ValueNotifier`；`SettingsScreen` 保存后通知 notifier 即时生效。

### P1-9 Inter 字体注册
- `pubspec.yaml` 加 `google_fonts` 依赖，或下载 Inter 字体到 `assets/fonts/` 并在 `flutter.fonts` 注册。

### P1-10 占位入口处理
- "Interface Language" / "Export Learning Data" 项加 `Badge(disabled)` 或暂时移除，避免误判 bug。

### P1-11 Correction 去重
- `saveCorrection` 前按 `(original, corrected, type)` 查重；已存在则更新 `lastSeenAt` + `occurrenceCount` (新增字段)，不重复插入。

### P1-12 Corrections 围栏改标准 JSON
- ` ```corrections ` → ` ```json ` + 在 fence 内约定 schema；正则相应更新。或用 `<corrections>` XML tag。

---

## 三、P2 打磨项 (本计划暂缓，记录待后续迭代)

| 项 | 备注 |
|---|---|
| LLM Streaming (SSE) | 大改 `LlmService`，需测试多 provider，单独立项 |
| Placement 重写为 AI 对话评估 | 大改，需设计 2-3 分钟对话 + LLM 输出 JSON schema |
| i18n (中文/English) | 需引入 `flutter_localizations` + 全文案 .arb，大工程 |
| liquid_glass_widgets 采用 | 视觉升级，需引入新依赖 + 重写 GlassCard |
| reduce-motion 支持 | 全项目动画加 `MediaQuery.disableAnimations` 判断 |
| 发音评分 (音素级) | spec 阶段五，需音频模型 |
| `chat_screen.dart` 拆分 (1287 行) | 重构，单独 PR |
| Signature 动效 / Lottie | 设计资源依赖 |
| Retry (指数退避) | LLM/STT/TTS 各加，跨服务 |
| LlmUsage 持久化 | DB 表 + Settings 展示 |
| 请求取消 (CancelToken) | service 层改造 |

---

## 四、本次执行范围 (实际会改的代码)

由于单次会话工作量限制，本次**实际执行 P0 全部 + P1 关键项**:

**会做**:
- P0-1 SM-2 接通 + quality 评分 UI
- P0-2 删除会话
- P0-3 Tutor 选择
- P0-4 DeepSeek/Kimi 模型名
- P0-5 correction_strength 接 prompt
- P0-6 tts_speed 接通
- P0-7 输入框 rebuild 修复
- P0-8 录音按钮脉冲
- P0-9 历史截断
- P0-10 Progress 修复 (dailyActivity 渲染 + corrections 真实查询)
- P1-1 max_tokens 400
- P1-2 移除每轮重发纠错指令 (合并到 spine)
- P1-3 统一纠错指令 (解释只进 JSON)
- P1-8 Theme 即时切换
- P1-10 占位入口处理 (移除/禁用)
- P1-11 Correction 去重

**不做 (记录为后续工作)**:
- LLM Streaming (P1-4 路由转场 / P1-5 Shimmer / P1-6 空态 / P1-9 Inter 字体 / P1-12 围栏 — 部分做)
- Placement 重写、i18n、liquid_glass、reduce-motion、Streaming、Retry、发音评分 — 大工程，本次不做，CHANGELOG 注明。

---

## 五、验证策略

由于沙箱未安装 Flutter 工具链 (`which flutter dart` 均无)，本次无法跑 `flutter analyze` / `flutter build`。验证策略:
1. 静态代码 review: 检查每个修改点的语法、类型、import、命名。
2. 逻辑对照: 对照计划逐项核对"是否改了 / 改对了吗"。
3. 现有测试: `test/` 下有 sm2 / tutor_prompts / llm_service / correction_model 测试，修改后检查是否破坏 (无法运行，靠人工对照)。
4. 在 CHANGELOG 与 projects.md 中如实标注"未做编译验证"，下次有 Flutter 环境时补 `flutter analyze` + PC/Android build。

---

## 六、执行顺序 (依赖关系)

1. 先改底层 (model / repository / service): `chat_repository.deleteSession`, `getMessages(limit)`, `provider_catalog` 模型名, `tts_playback_service.setSpeed`, `learning_stats_service` corrections 查询。
2. 再改 prompt / service 层: `tutor_prompts` (correctionStrength + 合并纠错指令), `llm_service` (max_tokens + 移除重复纠错指令)。
3. 再改 UI 层: `chat_screen` (输入框 rebuild / 录音按钮 / delete / tts speed / correction_strength 读取), `review_screen` (SM-2 评分 UI), `history_screen` (delete), `tutor_selection_screen` (setSetting), `progress_screen` (dailyActivity 图), `settings_screen` (theme notifier / 占位项), `main.dart` (themeMode provider), `app_router` (可选转场)。
4. 更新测试: `tutor_prompts_test.dart` (correctionStrength 断言)。
5. 更新 `projects.md` + `CHANGELOG.md`。
6. commit + push。
