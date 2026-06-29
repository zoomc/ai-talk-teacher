# Review 1 — 学习闭环 / 兴趣激励 / 科学性 / 简洁性 / 功能完整度

> 评审对象: SpeakFlow (Flutter AI 口语练习应用)
> 评审日期: 2026-06-29
> 评审基线: main 分支最新代码
> 评审范围: 学习科学/产品视角，对照 `/workspace/projects.md` 规格

---

## 一、学习闭环 (Learning Closed Loop)

### 1.1 优点

- **闭环数据模型完整**：`Correction` 模型 (`lib/features/chat/domain/chat_models.dart:9-105`) 同时承载了原文/纠正/类型/解释 + SM-2 全套字段（`reviewCount`、`easinessFactor`、`intervalDays`、`nextReviewAt`），并持久化到 SQLite (`lib/core/database/database_helper.dart:106-123`)。模型设计与"练习→记录→复习→掌握"的闭环一一对应。
- **自动记录错误已打通**：`LlmService.extractCorrections` (`lib/features/chat/data/llm_service.dart:112-158`) 用 ``` ```corrections``` ``` JSON 块从 LLM 回复中提取结构化纠正；`ChatScreen._sendMessage` 在保存 AI 消息后循环写入错误库 (`lib/features/chat/presentation/screens/chat_screen.dart:345-353`)，并自动绑定 `messageId` / `sessionId`。这一步是闭环里最容易断的环节，已经接通。
- **复习入口与"到期"过滤逻辑正确**：`ChatRepository.getDueCorrections` (`lib/features/chat/data/chat_repository.dart:99-110`) 用 `next_review_at IS NULL OR next_review_at <= now` 取到期项，按 `review_count ASC` 排序，符合 SM-2 "先复习最不熟的"原则。
- **复习会话与对话流融合**：`ReviewScreen._startAIReview` / `_practiceCorrection` (`lib/features/chat/presentation/screens/review_screen.dart:163-182`) 创建带 `topic` 标记的会话；`ChatScreen` 通过 `topic.startsWith('AI Review Session')` / `'Practice:'` 检测 (`chat_screen.dart` 中 `isReviewSession` 逻辑) 并把到期纠正注入 `TutorPromptBuilder` 的 `## Review focus` 块 (`lib/features/chat/domain/tutor_prompts.dart:62-81`)。复习不是孤立列表，而是"把错误重新带回对话"，符合 spec §3.3 的"聊天式课堂"。
- **话题连续性**：`HomeScreen` 检测 active session 并弹"继续上次 / 新话题"对话框 (`lib/features/chat/presentation/screens/home_screen.dart:375-399`)，对应 spec §3.2 话题连续性。

### 1.2 问题与缺口

- 🔴 **[Critical] SM-2 调度从未在运行时被调用，闭环在"复习→掌握"环节断裂。**
  `Sm2Service.scheduleReview` (`lib/features/review/data/sm2_service.dart:7-50`) 是闭环推进的唯一入口，但全局检索显示它**只被 `test/sm2_service_test.dart` 引用**，生产代码无任何调用点。后果链：
  1. 纠正保存时 `nextReviewAt = null`、`reviewCount = 0`（`Correction` 默认值，`chat_models.dart:31-34`）。
  2. `getDueCorrections` 把 `next_review_at IS NULL` 视为"到期" → **所有错误永远到期**，复习列表只增不减。
  3. `reviewCount` 永远停在 0 → `Sm2Service.getMasteryLevel` 永远返回 `'New'`，`intervalDays` / `easinessFactor` 永不更新。
  4. `LearningStatsService.masteredCount` 用 `review_count >= 5` 统计 (`learning_stats_service.dart:62-65`) → **"已掌握"恒为 0**。
  5. `ProgressScreen` 的 Mastery Breakdown 永远 100% 落在 "New"。
  → 闭环表面完整，实际"间隔复习→巩固掌握"这一段没有发生。这是本次评审最严重的问题。

- 🔴 **[Critical] 缺少回忆质量评分 UI（SM-2 的 `quality` 0-5 输入）。**
  SM-2 算法要求每次复习后用户/系统给出回忆质量评分。`ReviewScreen` 只能"点击错误 → 进入聊天练习" (`review_screen.dart:171-182`)，练习结束后没有任何"这次说对了吗？"的反馈采集，也没有 AI 自动判分回写。因此即使补上 `scheduleReview` 调用，也缺少 `quality` 入参。spec §3.3 提到"已掌握 / 待复习 / 新增错误"的进度，前提就是要有质量反馈驱动状态流转。

- 🟠 **[Major] "新增错误"无去重 / 合并机制。**
  `ChatScreen` 直接 `saveCorrection` 每条 LLM 返回的纠正 (`chat_screen.dart:346-353`)，不检查是否已存在相同的 `original`/`corrected`。同一错误反复出现会变成多条记录，污染复习列表和统计。SM-2 的前提是"同一张卡片反复复习"，而不是"每次错都新增一张"。

- 🟠 **[Major] 复习会话标记依赖 topic 字符串前缀，脆弱。**
  `isReviewSession = topic.startsWith('AI Review Session') || topic.startsWith('Practice:')` (chat_screen.dart)。一旦用户用别的语言/自定义话题命名，或 UI 文案改动，识别就失效。`ChatSession` 模型 (`chat_models.dart:152-213`) 没有显式的 `sessionType` 字段承载"练习/复习/自由对话"语义。

- 🟡 **[Minor] `Correction.copyWith` 不能清空 `nextReviewAt` 之外的可空字段**（如 `explanation`），但目前不影响闭环。

### 1.3 严重度评级

| 问题 | 严重度 |
|------|--------|
| SM-2 调度未接入运行时，闭环断裂 | **Critical** |
| 缺少 quality 评分 UI，SM-2 无输入 | **Critical** |
| 错误无去重/合并 | Major |
| 复习会话识别靠 topic 前缀字符串 | Major |
| copyWith 不能清空其他可空字段 | Minor |

---

## 二、兴趣激励

### 2.1 优点

- **6 个差异化虚拟外教**：`TutorRepository` (`lib/features/chat/domain/tutor.dart:23-90`) 提供 Emma/James/Alex/Professor Chen/Sarah/Dr. Miller，覆盖友好/商务/日常/严格/考试/发音六种风格，用户可在 `TutorSelectionScreen` 切换。比单一 AI 角色更有代入感。
- **场景卡片有游戏化要素**：`ScenariosScreen._ScenarioCard` (`scenarios_screen.dart:146-266`) 用横向滑动卡片 + 分类分组 + 难度色标 + "已练习 N 次 / Last: today"进度标记，对应 spec §3.2 "游戏化场景卡片选择（分类 + 进度标记 + 难度标签）"。
- **首页有 Quick Start 网格 + 入场动画**：`HomeScreen._QuickActionGrid` (`home_screen.dart:271-365`) 用 `flutter_animate` 做错峰 fadeIn/slideX (`home_screen.dart:262-269`)，首屏有活力。
- **ProgressScreen 提供多维度统计**：sessions/messages/mastered/due 四宫格 + Mastery Breakdown 进度条 + Error Types 分布 (`progress_screen.dart:47-215`)，给用户"我在进步"的反馈。
- **空状态设计良好**：`ReviewScreen._buildEmptyState` (`review_screen.dart:53-93`) 在无到期错误时显示 "All caught up!" + 引导去练习，是正向激励。

### 2.2 问题与缺口

- 🔴 **[Critical → 实为 Major] 无任何游戏化进阶系统。**
  spec §2.2 借鉴流利说"闯关模式 + 每日任务"，§2.4 差异化对比里也提到游戏化。当前实现：
  - 无连续打卡（streak）
  - 无每日目标 / 每日任务
  - 无 XP / 等级 / 徽章 / 成就
  - 无排行榜或社交激励
  这对"长期坚持练习"是核心缺口。结合 §一 的闭环断裂，用户更感受不到"复习→掌握"的进步闭环。

- 🟠 **[Major] `dailyActivity` 数据已采集但未展示。**
  `LearningStatsService` 查询了近 7 天每日消息数 (`learning_stats_service.dart:92-110`)，`LearningStats.dailyActivity` 字段也存在，但 `ProgressScreen` **完全没有渲染这部分**（搜遍 `progress_screen.dart` 无 `dailyActivity` 引用）。原本最适合做"7 日活跃柱状图 / 打卡日历"的数据被浪费了。

- 🟠 **[Major] 无难度递进机制。**
  spec §3.2 "AI 自动把控话题覆盖和难度"，§2.2 借鉴流利说"自适应路径"。当前 `userLevel` 只在 placement 测试时设定一次 (`placement_screen.dart:264-282`)，之后**永不更新**。即使用户练了 100 次、已掌握 50 个错误，难度起点也不会上调。`TutorPromptBuilder._spine` 始终用同一个 levelGuidance。

- 🟡 **[Minor] 场景数量偏少。**
  spec §3.2 列举"餐厅、机场、商务会议、面试、约会等"，`database_helper.dart:151-232` 内置 8 个场景（Free Talk / Restaurant / Airport / Job Interview / Business Meeting / Shopping / Doctor / Date）。覆盖了 spec 例子，但对比 TalkPal 的"10+ 对话模式"和咕噜口语的"多元场景"，数量上无差异化优势。可扩展为可下载场景包。

- 🟡 **[Minor] Tutor 选择对对话内容的影响有限。**
  `TutorPromptBuilder.build` 把 `tutor.systemPrompt` 拼进 prompt (`tutor_prompts.dart:35-39`)，但 6 个 tutor 的 prompt 都是静态文本，不会根据用户当前弱点调整。Sarah (考试) 和 Dr. Miller (发音) 也没有任何针对考试/发音的专门流程。

### 2.3 严重度评级

| 问题 | 严重度 |
|------|--------|
| 无 streak/XP/成就/每日任务等游戏化系统 | Major |
| dailyActivity 数据采集但未展示 | Major |
| userLevel 一次设定永不更新，无自适应 | Major |
| 场景数量偏少 | Minor |
| Tutor 选择对内容影响有限 | Minor |

---

## 三、科学性 (SM-2 / 教学法)

### 3.1 优点

- **SM-2 算法实现本身正确。** `Sm2Service.scheduleReview` (`sm2_service.dart:7-50`)：
  - EF 调整公式 `EF' = EF + (0.1 - (5-q)*(0.08 + (5-q)*0.02))` 与 SuperMemo SM-2 原论文一致 (`sm2_service.dart:18`)。
  - `EF < 1.3` 时钳制到 1.3 (`sm2_service.dart:19`)，正确。
  - 间隔规则 `1 → 6 → prevInterval × EF` (`sm2_service.dart:35-41`) 符合 SM-2。
  - `quality < 3` 时重置 `reviewCount = 0`、`interval = 1` 天，但**保留 EF 下调**（不重置 EF）(`sm2_service.dart:22-32`)，这是合理的实现选择。
  - 测试覆盖完整：`test/sm2_service_test.dart` 覆盖 blackout/fail/三次成功递进/EF 下限/EF 升降方向，断言准确（如第三轮 `interval = round(6 * 2.6) = 16`）。
- **教学法 spine 设计专业。** `TutorPromptBuilder._spine` (`tutor_prompts.dart:87-121`) 明确要求"1-4 句短回复"、"以问题结尾推动对话"、"不要打断流"、"只纠真正错误不过度纠风格/口音"，并按 beginner/intermediate/advanced 给出分级指导。这套 prompt 比多数同类产品的 system prompt 都更接近专业二语教学（SLA）原则。
- **自然纠正策略落地。** spec §3.2 "Praktika 式不打断对话流" 在 `tutor_prompts.dart:111-117` 的 "How to correct" 块和 `llm_service.dart:81-92` 的 corrections JSON 协议中共同实现：LLM 先自然重述正确版本，再附 JSON 块供前端入库。比"实时打断式纠正"更友好。
- **复习 prompt 明确禁止直接 quiz。** `tutor_prompts.dart:66-73`："Do NOT list the corrections or quiz them directly — engineer the dialogue so the target language comes up in context"，符合"在语境中复用"的二语习得原则，而非机械卡片翻转。
- **`CorrectionType` 三分类合理。** grammar/vocabulary/pronunciation (`chat_models.dart:7`) 与 spec §3.2 "类型（语法/用词/发音）"完全一致。

### 3.2 问题与缺口

- 🔴 **[Critical] 算法正确但未接入产品流，等于没有。**
  见 §一。SM-2 是闭环的引擎，引擎造好了却没装到车上。`scheduleReview` 没有任何生产调用方，`reviewCount` / `easinessFactor` / `intervalDays` / `nextReviewAt` 永远是初始值。从教学科学角度，这等于"有间隔重复算法，但没有间隔重复行为"。

- 🔴 **[Critical] 缺少 quality 评分采集，违反 SM-2 算法前提。**
  SM-2 的核心输入是学习者对**特定卡片**的回忆质量（0-5）。当前没有任何机制让用户在复习某条错误后反馈"说对了/差点忘了/完全忘了"，也没有让 AI 在对话中检测到用户再次说对/说错该形式后自动打分。没有 quality，SM-2 退化成"固定间隔列表"。

- 🟠 **[Major] 纠正强度三档设置未接入 prompt。**
  spec §3.2 "纠正强度三档可调：温和 / 适中 / 严格"。`SettingsScreen` 有完整的 UI + 持久化 (`settings_screen.dart:18, 31-36, 95, 204-250`)，`correction_strength` 存进了 `user_settings` 表。但 `TutorPromptBuilder.build` (`tutor_prompts.dart:21-84`) **没有 `correctionStrength` 参数**，`LlmService._buildMessages` (`llm_service.dart:71-109`) 也不读这个设置。设置项是"装饰品"，调到严格也不会让 AI 更频繁纠错。这是 spec 明确要求且已部分实现的功能，差最后一公里。

- 🟠 **[Major] 水平定级与 spec 严重不符。**
  spec §3.1 / §3.2："AI 引导 2-3 分钟英语对话，评估：词汇量、语法准确度、流利度，结果：自动设置对话难度起点"。实际 `PlacementScreen` (`placement_screen.dart:1-282`) 是 **4 道中文选择题**（自评水平 + 使用频率 + 最大挑战 + 兴趣话题），用加权打分算 level (`placement_screen.dart:175-199`)。这违背了 spec"AI 引导对话评估"的核心设计，也丢掉了"在真实口语中评估流利度/语法准确度"的能力。这是产品定位层面的偏差。

- 🟠 **[Major] 无发音评估能力。**
  `CorrectionType.pronunciation` 是 enum 一等公民，但 `LlmService` 只接收 STT 转写文本 (`llm_service.dart`)，**没有任何音素级/声学级发音评分**。spec §2.2 也承认 ELSA 的"音素级发音分析、颜色标识"是值得借鉴的，但 §2.4 把 SpeakFlow 定位为"云端 STT（Deepgram 等）"——本质只能基于转写文本判断"是否说错词"，无法判断"发音准不准"。`Dr. Miller` 这个 pronunciation tutor (`tutor.dart:80-89`) 的 prompt 承诺"提供 phonetic transcriptions / mouth positions"，但 LLM 没有音频输入，承诺无法兑现。这是一个**产品定位 vs 实现能力的结构性矛盾**，建议要么补发音评分（成本高），要么在 prompt 里降低承诺。

- 🟡 **[Minor] `getMasteryLevel` 阈值与统计口径不一致。**
  `Sm2Service.getMasteryLevel` (`sm2_service.dart:67-74`)：`reviewCount >= 5` → Mastered。
  `LearningStatsService.masteredCount` (`learning_stats_service.dart:62-65`)：`review_count >= 5` → mastered。两者一致 ✅。
  但 `learningCount` (`learning_stats_service.dart:67-70`) 用 `review_count > 0 AND < 5`，而 `getMasteryLevel` 在 `reviewCount < 2` 返回 `'Learning'`、`< 5` 返回 `'Familiar'`。即"学习/熟悉"两级在统计里被合并成"learning"，分类粒度对不上，UI 上的 Mastery Breakdown 只有 New/Learning/Mastered 三档，丢掉了 Familiar/Struggling。口径需要统一。

- 🟡 **[Minor] `getMasteryColor` 返回 `int` 而非 `Color`** (`sm2_service.dart:77-95`)，调用方需要 `Color(Sm2Service.getMasteryColor(...))` 包一层（如 `review_screen.dart:250, 257`），API 不友好且易错。

### 3.3 严重度评级

| 问题 | 严重度 |
|------|--------|
| SM-2 算法未接入运行时 | Critical |
| 缺 quality 评分采集，违反算法前提 | Critical |
| 纠正强度三档未接入 prompt | Major |
| 定级测试是选择题而非 AI 对话评估，与 spec 不符 | Major |
| 发音 tutor 承诺音素级反馈但无音频输入 | Major |
| mastery 阈值与统计口径不一致 | Minor |
| getMasteryColor 返回 int 不友好 | Minor |

---

## 四、简洁性

### 4.1 优点

- **目录结构清晰**：`features/<feature>/{data,domain,presentation}` 分层规范，Riverpod provider 集中在 `shared/providers.dart`，符合 Flutter 社区主流约定。
- **`TutorPromptBuilder` 职责单一**：纯函数静态方法，可测试性好，`test/tutor_prompts_test.dart` 覆盖完整（persona/scenario/topic/review 各组合 + 顺序断言）。
- **数据库迁移有版本管理**：`_dbVersion = 2` + `_onUpgrade` (`database_helper.dart:248-353`)，v1→v2 的 provider_id 重映射逻辑考虑了向后兼容。
- **测试覆盖核心模型与算法**：`test/sm2_service_test.dart`、`test/correction_model_test.dart`、`test/tutor_prompts_test.dart`、`test/llm_service_test.dart` 覆盖了最关键的纯逻辑。

### 4.2 问题与缺口

- 🟠 **[Major] `HomeScreen` 有死代码 `_quickActionItem` 方法。**
  `home_screen.dart:254-269` 定义了 `_quickActionItem`，但 `_QuickActionGrid` (`home_screen.dart:271-365`) 内部用 `add(...)` 直接构造 `_QuickActionCard`，**从不调用 `_quickActionItem`**。该方法（连同其 `.animate()` 链）是遗留死代码，应删除或恢复使用。

- 🟠 **[Major] `_StatCard` 在两个文件重复定义。**
  `home_screen.dart:402-440` 和 `progress_screen.dart:218-256` 各自定义了私有 `_StatCard`，结构几乎相同（icon/label/value/color + GlassCard 布局）。应抽到 `shared/widgets/`。

- 🟠 **[Major] `LearningStats.dailyActivity` 是死数据。**
  `learning_stats_service.dart:92-110` 花了 SQL 查询 + 构造 `DailyActivity` 对象列表，但 `ProgressScreen` 完全没用（见 §2.2）。要么渲染，要么删除。

- 🟡 **[Minor] `Correction.copyWith` 的 `clearNextReviewAt` 是特例化布尔参数。**
  `chat_models.dart:50` 引入 `clearNextReviewAt` 是为了能显式置空 `nextReviewAt`（因为 `nextReviewAt` 参数为 null 时会被当作"未传"）。这种模式容易误用——其他可空字段（`explanation`、`messageId`、`sessionId`）都无法通过 `copyWith` 置空。建议统一用 `Object? nextReviewAt` + sentinel 模式，或干脆改用 `freezed`。

- 🟡 **[Minor] `Sm2Service` 全静态方法，无实例状态，但命名上像 service。**
  实际是纯函数集合，叫 `Sm2` 或 `Sm2Algorithm` 更准确。`getNextReviewText` / `getMasteryLevel` / `getMasteryColor` 是 UI 辅助方法，混在算法类里，职责不单一。

- 🟡 **[Minor] `database_helper.dart` 把 8 个场景的 systemPrompt 硬编码在 Dart 字符串里 (`database_helper.dart:150-237`)**，且 prompt 文案与 `tutor_prompts.dart` 的 spine 高度重复（都讲"correct errors naturally by restating the correct version"）。场景 prompt 应该外置（JSON / 资源文件）并复用 spine，避免文案漂移。

- 🟡 **[Minor] `chat_screen.dart` 单文件 1287 行**，混合了 character panel / 消息列表 / 输入栏 / TTS / STT / 选项菜单多个职责，建议拆分。

### 4.3 严重度评级

| 问题 | 严重度 |
|------|--------|
| `_quickActionItem` 死代码 | Major |
| `_StatCard` 跨文件重复 | Major |
| `dailyActivity` 死数据 | Major |
| `copyWith` 特例化清空参数 | Minor |
| `Sm2Service` 命名/职责混杂 | Minor |
| 场景 prompt 硬编码且与 spine 重复 | Minor |
| chat_screen.dart 过长 | Minor |

---

## 五、功能完整度 (对照 projects.md 规格)

> 仅依据本次评审范围内读到的文件判定；标 "需核实" 的项未在评审文件中确认。

### 阶段一 (MVP) — spec §七

| 规格 | 实现状态 | 备注 |
|------|---------|------|
| Flutter 项目初始化，macOS + Web 双端运行 | ✅ | 代码结构齐全 |
| 3-Profile 系统：LLM + STT + TTS 统一配置管理 | ✅ | `database_helper.dart:29-77` 三张表 + v2 迁移 |
| 主界面布局：上半屏角色插画 + 振幅嘴型动画，下半屏聊天窗口 | ⚠️ 部分 | `chat_screen.dart` 有 `_CharacterPanel` + 聊天列，未见振幅嘴型动画细节（评审范围内未读到 Live2D/振幅驱动） |
| 录音功能：按住录音 → 云端 STT → 文字显示 | ✅ | `_handleRecordToggle` + `_recordingService` (chat_screen.dart) |
| AI 对话：通过 Profile 系统接入 LLM | ✅ | `LlmService` (llm_service.dart) |
| TTS 播放：AI 回复 → 云端 TTS → 语音播放 + 嘴型动画 | ⚠️ 部分 | `_autoplayTts` 存在；嘴型动画未在评审范围确认 |
| 智能纠正：自动提取 `corrections[]` 存入错误库 | ✅ | chat_screen.dart:345-353 + llm_service.dart:112-158 |
| Profile 管理：新建/编辑/删除/切换 | ✅ | 三张 profile 表 + is_active 字段 |
| 新手引导：分步教程 | 需核实 | 评审范围内未见 onboarding 引导文件（仅 placement_screen） |
| 水平定级 | ⚠️ 偏离 spec | 实现为选择题，非 spec 的"AI 引导对话评估"（见 §3.2） |
| 对话历史本地存储 | ✅ | chat_sessions / chat_messages 表 |

### 阶段二 (学习循环) — spec §七

| 规格 | 实现状态 | 备注 |
|------|---------|------|
| 错误记录系统：自动从 AI 回复提取纠正，结构化存储 | ✅ | 已打通 |
| 复习模式：AI 虚拟外教引导聊天式复习 | ⚠️ 部分 | 入口 + prompt 块存在，但缺质量反馈闭环（§一、§三） |
| 间隔重复算法（SM-2） | ⚠️ 算法实现 + 测试完整，但**未接入运行时**（§一、§三） | 最关键缺口 |
| 会话管理：新建 / 继续上次 / 历史浏览 | ✅ | home_screen.dart continue dialog + Free Talk + Chat History 入口 |
| 场景选择 + 游戏化卡片 UI | ✅ | scenarios_screen.dart，含分类/进度/难度标签 |
| 纠正强度三档设置 | ⚠️ UI + 持久化完成，**未接入 prompt**（§3.2） | |
| 消息点击重播 TTS | ✅ | chat_screen.dart 播放按钮 |
| iOS + Android 适配测试 | 需核实 | 评审范围外 |
| Profile 导入/导出 | 需核实 | 评审范围内未确认 |

### spec §3 功能规格对照

| 规格 (§3) | 实现状态 | 备注 |
|-----------|---------|------|
| §3.1 水平定级（AI 引导对话） | ❌ 偏离 | 选择题替代 |
| §3.2 自由对话 | ✅ | Free Talk 入口 |
| §3.2 场景练习（游戏化卡片） | ✅ | 8 场景 + 卡片 UI |
| §3.2 智能纠正（自然重述） | ✅ | prompt + corrections 协议 |
| §3.2 纠正强度三档 | ⚠️ UI 完成未接 prompt | |
| §3.2 错误自动记录（原文→纠正→类型→入库） | ✅ | |
| §3.2 话题连续性 | ✅ | continue dialog |
| §3.2 AI 主导节奏 | ✅ | prompt spine "end most turns with a question" |
| §3.3 AI 引导复习 | ⚠️ 部分 | 见上 |
| §3.3 错误回顾（薄弱点融入对话） | ✅ | TutorPromptBuilder review focus 块 |
| §3.3 间隔重复（SM-2） | ⚠️ 未接入运行时 | |
| §3.3 进度统计（已掌握/待复习/新增 + 趋势） | ⚠️ 部分 | 计数有，**趋势无**（dailyActivity 未展示） |
| §3.5 纠正强度设置 | ⚠️ 未接 prompt | |
| §3.5 界面语言 中/英 | ❌ 未实现 | settings_screen.dart:107-114 明确显示 "coming in a future update" |
| §3.5 外观（系统/浅/深） | 需核实 | settings 有 theme 项 |

### 阶段三 (虚拟人物) — spec §七

| 规格 | 实现状态 | 备注 |
|------|---------|------|
| Live2D 虚拟外教模型 | ❌ 未实现 | 阶段三未启动，符合 roadmap |
| Rhubarb Lip Sync | ❌ 未实现 | 阶段三未启动 |
| 待机动画（呼吸/眨眼/微笑） | 需核实 | 评审范围内未见 |
| 情感状态切换 | ⚠️ 部分 | `_characterState` 有 idle/thinking/speaking 状态，非情感 |

### 阶段五 (持续迭代) — spec §七

| 规格 | 实现状态 | 备注 |
|------|---------|------|
| 学习统计和进度报告 | ⚠️ 部分 | 计数有，趋势/报告无 |
| 发音评分（音素级） | ❌ 未实现 | 见 §3.2 结构性矛盾 |
| 多角色选择 | ✅ | 6 tutors |
| 社区场景分享 | ❌ 未实现 | |
| 云同步 | ❌ 未实现 | spec 标 "可选" |

---

## 六、改进建议 (按优先级排序)

### P0 (必须 — 不修则产品定位不成立)

1. **接入 SM-2 调度到运行时，补齐 quality 评分闭环。**
   - 在 `ReviewScreen` 的每条 `_CorrectionCard` 练习结束后，弹出轻量评分（如 3 档："又错了 / 想起来了 / 脱口而出"映射到 quality 2/4/5），调用 `Sm2Service.scheduleReview` 并 `repo.updateCorrection`。
   - 或在 `ChatScreen` 的 review session 中，让 LLM 在 corrections JSON 里额外返回 `recall_quality` 字段，AI 自动判分回写。
   - 否则"完整学习闭环"这一核心卖点（spec §一、§2.4）不成立。

2. **修正 placement 测试与 spec 的偏差。**
   - 要么把 `PlacementScreen` 改成"AI 引导 2-3 分钟对话"形式（spec §3.1），由 LLM 在对话后输出 level；
   - 要么在 spec 里明确"选择题自评定级"是当前实现选择，避免文档与产品不一致。

### P1 (重要 — 影响学习效果与体验)

3. **把 `correction_strength` 设置接入 `TutorPromptBuilder`。** 给 `build()` 加 `correctionStrength` 参数，在 spine 里按 温和/适中/严格 调整纠正频率与严格度文案；`ChatScreen` 从 `profileRepo.getSetting('correction_strength')` 读取后传入。

4. **错误去重 / 合并。** `saveCorrection` 前按 `(original, corrected, type)` 做存在性检查；若已存在则更新 `lastSeenAt` / 出现次数（可加 `occurrenceCount` 字段），不重复插入。这是 SM-2 "同一卡片"前提。

5. **`ChatSession` 加显式 `sessionType` 字段**（free / scenario / review / practice），替代 topic 字符串前缀识别。

6. **渲染 `dailyActivity` 趋势图**（7 日活跃柱状图或打卡日历），并补 streak / 每日目标等基础游戏化。

7. **难度自适应。** 在 AI 复习会话或定期统计后，根据 masteredCount / 总错误率自动调整 `userLevel`，而非一次设定终身。

### P2 (可选 — 工程质量与一致性)

8. **删除 `HomeScreen._quickActionItem` 死代码**（`home_screen.dart:254-269`）。

9. **抽取共享 `_StatCard` 到 `shared/widgets/`**，消除 home_screen.dart 与 progress_screen.dart 的重复。

10. **统一 mastery 口径**：`LearningStatsService` 的 learning/mastered 分类与 `Sm2Service.getMasteryLevel` 对齐，ProgressScreen 的 Mastery Breakdown 显示全部分级或与统计口径一致。

11. **`Sm2Service.getMasteryColor` 改返回 `Color`**，或拆出 `MasteryUi` 辅助类把算法与 UI 颜色分离。

12. **场景 systemPrompt 外置到 JSON / 资源文件**，复用 `TutorPromptBuilder._spine`，避免文案漂移与硬编码。

13. **降低 pronunciation tutor 的 prompt 承诺**（在无音频输入的前提下，不要承诺音素级 / mouth position 反馈），或规划发音评分能力路线。

14. **拆分 `chat_screen.dart`（1287 行）** 为 character_panel.dart / message_list.dart / input_bar.dart / session_options.dart 等独立组件。

---

> 总评：代码工程质量较高，模型设计、prompt 教学法、SM-2 算法本身都达到专业水准，测试覆盖到位。但**核心卖点"学习闭环"在运行时是断的**——SM-2 调度未被任何生产代码调用，且缺少 quality 评分输入，导致"间隔复习→巩固掌握"这一段实际未发生。配合 placement 偏离 spec、纠正强度未接 prompt、dailyActivity 死数据等问题，整体处于"组件就绪但未组装"的状态。优先解决 P0 两项即可让产品真正成立。
