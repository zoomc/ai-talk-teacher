# Review 4 — AI 使用合理性 / 学习实际帮助 / 用户体验

> 评审对象: SpeakFlow
> 评审日期: 2026-06-29
> 评审范围: 仅 AI 使用合理性、对学习的实际帮助、用户侧使用感受三个维度
> 评审依据: 实际源码 + projects.md 规格

---

## 一、各种 AI 使用合理性

### 1.1 优点

1. **LLM 一体多用，职责合理**：单个 LLM 同时承担角色扮演、自然对话、实时纠正、结构化 corrections 输出（`llm_service.dart:81-93`）。符合 spec 6.3 节"参考 gemini-teacher 单 LLM 多任务"的设计意图。
2. **Prompt 架构分层清晰**：`TutorPromptBuilder.build` 把 spine + persona + scenario + review focus 顺序拼接（`tutor_prompts.dart:21-84`），可读、可测试。
3. **自然纠正策略真落地**：spine 明确指示 "Do NOT interrupt the flow to lecture. Model the correct form by reusing it naturally" 并给出 example（`tutor_prompts.dart:111-117`），符合 Praktika 式策略。
4. **Level adaptation 真生效**：beginner / intermediate / advanced 三档指导文本被注入到 system prompt（`tutor_prompts.dart:123-151`），且 `chat_screen.dart:321` 真的从 settings 读取 `userLevel` 传入。
5. **STT/TTS 多供应商适配真实**：Deepgram（`Token` 鉴权）/ Azure（`Ocp-Apim-Subscription-Key` + SSML）/ Google（API key query）/ ElevenLabs（`xi-api-key`）/ Fish Audio / Aliyun CosyVoice 各自实现，不是统一 stub（`stt_service.dart:20-187`、`tts_service.dart:20-284`）。各供应商鉴权细节、端点、响应字段差异都被正确处理。
6. **testConnection 真实联网**：LLM 走 `/v1/models`，Deepgram 走 `/v1/projects`，ElevenLabs 走 `/v1/voices`，且把 401/403 翻译成可读错误（`llm_service.dart:199-226`、`stt_service.dart:194-248`、`tts_service.dart:309-363`）。
7. **Review 会话真把 due corrections 喂给 LLM**：`chat_screen.dart:312-329` 检测 topic 前缀，调用 `getDueCorrections(limit: 10)`，传入 `TutorPromptBuilder.build(isReviewSession: true, dueCorrections: ...)`；prompt 指示 LLM "engineer the dialogue so the target language comes up in context"（`tutor_prompts.dart:63-81`）。这部分不是 cosmetic。
8. **Correction 结构化提取**：LLM 被要求在回复末尾附 ```corrections JSON``` 块，前端用正则解析后存入 SQLite（`llm_service.dart:112-158`），并和 AI 消息 / session 关联（`chat_screen.dart:346-353`）。

### 1.2 问题（placement / review / correction / tutor persona）

1. **Placement 完全是 stub，LLM 没参与**：spec 3.1 / 3.2 承诺"AI 引导 2-3 分钟英语对话，评估词汇量、语法准确度、流利度"。实际 `placement_screen.dart:17-52` 是 4 道本地硬编码选择题（"How would you describe your level?" / "How often do you speak English?" 等），`_computeLevel` (`placement_screen.dart:175-199`) 是纯加权评分函数。**没有任何 LLM 调用、没有对话、没有真实英语能力评估**。这与 spec 严重不符，是核心卖点被降级为入门问卷。
2. **SM-2 间隔重复算法是死代码**：`Sm2Service.scheduleReview()`（`sm2_service.dart:7-50`）全工程从未被调用——`grep Sm2Service` 仅 5 处引用，全部是 `getMasteryColor` / `getMasteryLevel` / `getNextReviewText` 这些**展示用 helper**。也就是说 `review_count`、`easiness_factor`、`interval_days`、`next_review_at` 在 correction 创建后永远不会被更新。spec 3.3 承诺的"SM-2 算法安排复习间隔"实际不存在。
3. **Review 会话无反馈闭环**：复习路径只是创建一个新 chat session 让 LLM 看到 due corrections（`review_screen.dart:163-182`），但**复习结束后没有任何机制把 corrections 标记为"已复习"**——`chat_screen.dart` 整个 review 路径没有调用 `repo.updateCorrection` 或 `Sm2Service.scheduleReview`。后果：同一批 corrections 永远 due，下次进 Review 看到的还是它们。
4. **Correction strength 三档设置是死代码**：Settings 保存到 `correction_strength`（`settings_screen.dart:249`），但 `TutorPromptBuilder`（`tutor_prompts.dart` 全文）从不读取该 setting，spine 也不区分 gentle/moderate/strict。三档纠正强度纯属装饰。
5. **TTS speed 全局设置是死代码**：Settings 保存 `tts_speed`（`settings_screen.dart:309`），但 `TtsService.synthesize` 用的是 `profile.speed`（`tts_service.dart:61`、`93`、`206`），全局 `tts_speed` 从不被读取。用户调了没反应。
6. **Correction 提取脆弱且静默失败**：依赖 LLM 严格按 ```corrections ... ``` 块格式输出（`llm_service.dart:116` 正则）。小模型（DeepSeek-V3 以下、本地小模型）经常不遵守，此时 `extractCorrections` 返回空 list，仅 `debugPrint` 一行警告（`llm_service.dart:152-153`），用户看不到任何提示。没有 fallback（如二次调用、JSON mode、function calling）。
7. **Pronunciation correction 不可靠**：LLM 仅基于转录文本判断 pronunciation 错误并产出 `type: pronunciation`（`llm_service.dart:134-136`）。但 LLM 没听到音频，无法做音素级判断——它只能猜发音。spec 自己在阶段五才提"音素级发音评分"，但当前已经在让 LLM 标 pronunciation 类型，会误导用户。
8. **Tutor persona 部分冲突**：6 个 tutor 的 systemPrompt 较泛化（`tutor.dart:32-88`）。`strict_coach` 写"correct every mistake and explain why it's wrong"，但 spine 写"never shame a mistake" + "Do NOT interrupt the flow to lecture"——两者叠加后 LLM 行为不可预测。`exam_prep` 的 Sarah 写"provide band score estimates"，但没有任何评分 schema 支撑，模型只能编造分数。

### 1.3 严重度

| 问题 | 严重度 |
|---|---|
| Placement 完全是 stub（spec 承诺 AI 对话评估） | **P0** |
| SM-2 死代码（学习闭环根本不存在） | **P0** |
| Review 无反馈闭环（复习不更新进度） | **P0** |
| correction_strength 死代码 | P1 |
| tts_speed 全局设置死代码 | P1 |
| Correction 提取脆弱无 fallback | P1 |
| Pronunciation correction 不可靠 | P2 |
| Tutor persona 内部冲突 | P2 |

---

## 二、对学习的实际帮助

### 2.1 优点

1. **纠正以 inline 卡片呈现在 AI 气泡内**：原文红色删除线 + 正确版本绿色 + 类型 label + 可选 explanation（`chat_screen.dart:930-1043` `_CorrectionInline`）。视觉清晰、可操作。
2. **Review 列表分类展示**：按类型 / 掌握度 / 下次复习时间分类（`review_screen.dart:185-318` `_CorrectionCard`），用户能扫到要练什么。
3. **Level adaptation 真影响 LLM 输出**：beginner 档 prompt 强制"simple words, short sentences, slow, one idea per turn"（`tutor_prompts.dart:123-127`），advanced 档鼓励 conditionals / hedging / register shifts（`tutor_prompts.dart:135-139`）。这是真实的因材施教。
4. **Topic continuity 真实**：session 带 topic，可继续（`chat_repository.dart:38-51`），spec 3.2 "话题连续性" 落地。
5. **Scenario 真实存在**：DB 种子 8 个场景（restaurant / airport / job_interview 等，`database_helper.dart:150-237`），prompt 注入场景上下文（`tutor_prompts.dart:42-51`）。
6. **TTS 缓存让重复听几乎零延迟**：`TtsPlaybackService.playCached` 内存 + 磁盘双缓存（`tts_playback_service.dart:39-80`），用户反复点 🔊 听正确发音时流畅。

### 2.2 问题

1. **学习闭环断裂（核心问题）**：用户练完 → LLM 产 corrections → 存库 → 进 Review → LLM 看到并自然练习 → **但复习后 review_count 不增、next_review_at 不更新、easiness_factor 不变**。也就是说，"练习→记录→复习→巩固"中的"巩固"环节断开——用户永远在练同一批 due corrections，系统永远不认为他掌握了任何东西。这是 spec 宣称的"完整学习闭环"最大的破洞。
2. **Progress 页 "Mastered" 永远为 0**：`LearningStatsService` 的 SQL `WHERE review_count >= 5`（`learning_stats_service.dart:62-65`）和 `WHERE review_count > 0 AND review_count < 5`（`:67-70`），而 review_count 永远是 0（SM-2 没接通）。后果：所有 corrections 永远显示为 "New"，"Mastered" 数字永远 0，用户感受不到任何进步。学习激励完全失效。
3. **学习统计部分虚假**：
   - `dailyActivity.corrections` 硬编码 `0`，注释 "Could be enhanced"（`learning_stats_service.dart:107`）——但 UI 上不展示 dailyActivity 图表（`progress_screen.dart` 全文无 `dailyActivity` 引用），所以是死字段。
   - `correctionsByType` 真实但只显示数字，无趋势。
4. **Correction 无质量评分入口**：SM-2 需要 `quality` 0-5 输入，但 UI 全工程没有 Again/Hard/Good/Easy 评分按钮。即便接通 SM-2，用户也无从表达"这条我会了"。
5. **Export learning data 未实现**：Settings 显示 "Export coming soon"（`settings_screen.dart:147-150`）。spec 3.5 承诺"导出学习记录"。
6. **Pronunciation 类纠正无音频反馈**：标 pronunciation 类型却没有重听自己录音 vs TTS 对比的入口。
7. **Correction 去重缺失**：同一条错误（如 "I goes"）每次出现都会被 LLM 标记并 `saveCorrection` 一次（`chat_screen.dart:346-353` 是直接 insert），错误库会重复堆积，Review 列表会被同一错误刷屏。

### 2.3 严重度

| 问题 | 严重度 |
|---|---|
| 学习闭环断裂（复习不更新进度） | **P0** |
| Mastered 永远 0、所有 corrections 永远 "New" | **P0** |
| 无 quality 评分入口 | P1 |
| dailyActivity.corrections 虚假 + 字段不渲染 | P1 |
| Export learning data 未实现 | P1 |
| Correction 不去重 | P2 |
| Pronunciation 无音频对比 | P2 |

---

## 三、用户侧使用感受

### 3.1 Onboarding 摩擦

- **流程合理**：4 步向导 Welcome → LLM → STT → TTS（`onboarding_screen.dart:80-86`）。LLM 必填，STT/TTS 可跳过（带确认对话框 `_confirmMissingService` `:520-543`，文案清晰说明后果）。
- **Catalog 自动填充降摩擦**：选 provider 后自动填 base URL / model / voice（`onboarding_screen.dart:58-62`、`:451-500`），用户只需贴 key。
- **分组下拉友好**：国内 / 国外 / 本地 三组（`onboarding_screen.dart:341-376`），对中国用户友好，包含"中转站 / 自托管"提示。
- **问题**：
  - 无"跳过整个 onboarding"按钮。LLM key 空着走确认对话框可继续，但完成后 home 无 LLM 还得回头配。
  - Profile 名硬编码 "Default"（`onboarding_screen.dart:455`、`:472`、`:487`），用户后续建第二个 profile 时难区分。
  - 无 API key 注册引导链接（spec 9 风险表承诺"附注册链接"），只在 dropdown 旁显示 docsUrl 文本（`:291-299`），不可点击。

### 3.2 错误信息友好度

- **可操作的配置错误**：聊天中缺 LLM/STT/TTS 时弹 SnackBar + "Configure" 按钮 → `/service-config`（`chat_screen.dart:551-570` `_showConfigNeeded`），是整个 app 最友好的错误处理。
- **API key 失败可读**：`testConnection` 把 401/403 翻成 "Authentication failed (401). Check your API key."（`llm_service.dart:207-212`）。
- **错误信息截断防溢出**：`_safeError` 截 160 字符（`chat_screen.dart:616-620`、`profile_form_screen.dart:960-963`）。
- **问题**：
  - STT/TTS vendor 错误直接 dump `response.body`（`stt_service.dart:63-66`、`tts_service.dart:67-70`），可能含技术细节或 provider 内部错误码，普通用户看不懂。
  - Import JSON 失败只显示 "Invalid JSON"（`service_config_screen.dart:473-477`），不告诉哪一行错。
  - 录音权限拒绝错误 "Microphone permission not granted"（`recording_service.dart:21`）未引导用户去系统设置开启。

### 3.3 延迟感知

- **全串行，无流式**：录音 → STT → LLM → TTS 全部串行（`chat_screen.dart:376-446`、`:256-374`）。每轮 5-15s 等待。
- **Typing indicator 缓解感知**：三点弹性动画（`chat_screen.dart:732-812` `_TypingBubble`），但 LLM 非流式 → 用户等到整段 response 完成才看到字（`llm_service.dart:20-34`，`max_tokens: 1000`）。长回复体验差。
- **STT 非流式**：录完整段才转录（`stt_service.dart` 全部是非流式 POST）。spec 9 风险表承诺"Deepgram 实时流式"，未实现。
- **TTS 缓存命中几乎零延迟**：重复播放同一条 AI 回复流畅（`tts_playback_service.dart:39-80`）。
- **Auto-play TTS 在 AI 回复后立即开始**（`chat_screen.dart:359` `await _autoplayTts`），无延迟但可能"突然出声"——尤其在公共场合或戴耳机时较突兀，无开关可关。

### 3.4 i18n 实现情况

- **完全未实现**。全工程无 `AppLocalizations` / `.arb` / locale 切换（grep `Locale|AppLocalizations|i18n` 仅命中 `tts_service.dart` 一处，且是 STT/TTS 语言代码不是 UI locale）。
- Settings 的 "Interface Language" tile 点击只弹 "Interface language switching coming in a future update" SnackBar（`settings_screen.dart:104-117`），subtitle 硬编码 "English"。
- spec 3.5 明确承诺"界面语言 | 中文 / English"（`projects.md:365`）。**未交付**。
- 当前文案混用中英（onboarding "中转站"、region label "— China (国内) —"、其余全英文），无系统化 i18n。对中国目标用户群不友好。

### 3.5 无障碍

- **Chat screen 较好**：录音 / 发送 / TTS 播放按钮都有 `Semantics(button, label, hint)`（`chat_screen.dart:879-918`、`:1087-1124`、`:1167-1189`）；character panel 是 `liveRegion`，盲人能听到"Listening / Thinking / Speaking" 状态切换（`:1254-1258`）。
- **其他屏几乎无 Semantics**：onboarding / placement / review / settings / service_config / profile_form / progress 都缺系统性 Semantics 包装。Dropdown / RadioListTile 默认有标签但自定义 GlassCard 点击区无 label。
- **无 reduce-motion 支持**：`_TypingBubble` 无条件 `..repeat()` 动画（`chat_screen.dart:751`），未查询 `MediaQuery.disableAnimations`。
- **颜色编码有文本备用**：错误类型用红/黄/青 + 文本 label "Grammar" / "Vocabulary" / "Pronunciation"（`chat_screen.dart:945-954`），色盲友好。OK。
- **触摸目标达标**：录音 / 发送按钮 48x48（`chat_screen.dart:1099`、`:1177`），超 44 最小。
- **小字问题**：`_CorrectionInline` 类型 label 10pt（`chat_screen.dart:992`），偏小。

### 3.6 其他体验问题

- **App 仅配 LLM 也能用**：STT 缺 → 用户可打字（`chat_screen.dart:399-408` 弹配置提示但用户仍能输入）；TTS 缺 → `_autoplayTts` 静默 return（`:453-457`），用户能看到文字。降级路径设计好。
- **Reconfigure 容易**：Settings → Service Configuration → Add/Edit Profile，且每条 profile 都有 Test Connection。Chat 屏缺服务时 SnackBar 带 Configure 快捷按钮。Good。
- **Theme 切换需重启**：`Settings._showThemeDialog` 只 `setState(() => _theme = local)` + 保存到 repo（`settings_screen.dart:361-365`），而 `SpeakFlowApp._themeMode` 在 `main.dart:64-83` 是独立的，没有 notifier 桥接。改完主题需重启 app 才生效。
- **场景选择 UI 缺失**：spec 3.2 承诺"游戏化场景卡片选择（分类 + 进度标记 + 难度标签）"，但 grep 未发现 scenario_selection / ScenarioSelection 屏幕。DB 种了 8 个场景但用户无入口选——除非从 home 屏的某个入口（未在本评审文件清单内）进入。
- **Profile 删除限制**：不能删除当前激活 profile，错误信息友好（`service_config_screen.dart:571-578`）。Good。

---

## 四、关键功能真实性核查 (Real vs Stub)

| 功能 | 真实实现 / 桩 | 证据 (file:line) |
|---|---|---|
| LLM 对话（OpenAI 兼容） | ✅ 真实 | `llm_service.dart:13-68`、`chat_screen.dart:331-335` |
| LLM testConnection | ✅ 真实 | `llm_service.dart:199-226` |
| STT 多供应商（Deepgram/Azure/Google/Whisper） | ✅ 真实 | `stt_service.dart:20-187` |
| TTS 多供应商（Fish/ElevenLabs/Azure/Google/Aliyun/OpenAI） | ✅ 真实 | `tts_service.dart:20-284` |
| TTS 本地缓存 | ✅ 真实 | `tts_playback_service.dart:39-80` |
| 录音（WAV 16kHz mono） | ✅ 真实 | `recording_service.dart:15-69` |
| Correction 结构化提取 | ✅ 真实（但脆弱） | `llm_service.dart:112-158` |
| Correction inline 展示 | ✅ 真实 | `chat_screen.dart:930-1043` |
| Correction 列表展示 | ✅ 真实 | `review_screen.dart:185-318` |
| Tutor persona 注入 | ✅ 真实 | `tutor_prompts.dart:35-39`、`chat_screen.dart:300-308` |
| Scenario 注入 | ✅ 真实 | `tutor_prompts.dart:42-51`、`database_helper.dart:150-237` |
| Level adaptation | ✅ 真实 | `tutor_prompts.dart:87-151`、`chat_screen.dart:321` |
| Review 把 due corrections 喂给 LLM | ✅ 真实 | `chat_screen.dart:316-329`、`tutor_prompts.dart:63-81` |
| Profile 导入/导出（JSON） | ✅ 真实 | `service_config_screen.dart:378-479`、`profile_repository.dart:257-330` |
| **水平定级（AI 对话评估）** | ❌ **桩（4 道自评选择题）** | `placement_screen.dart:17-199`（无 LLM 调用） |
| **SM-2 间隔重复算法** | ❌ **桩（死代码）** | `sm2_service.dart:7-50` 全工程从未调用 |
| **复习后更新 review_count / next_review_at** | ❌ **桩（无 updateCorrection 调用）** | `chat_screen.dart` review 路径无调用 |
| **Correction strength 三档** | ❌ **桩（死代码）** | `settings_screen.dart:249` 保存，`tutor_prompts.dart` 不读取 |
| **TTS speed 全局设置** | ❌ **桩（死代码）** | `settings_screen.dart:309` 保存，`tts_service.dart:61` 用 profile.speed |
| **界面语言切换（中文/English）** | ❌ **未实现** | `settings_screen.dart:109-115` SnackBar "coming soon" |
| **导出学习数据** | ❌ **未实现** | `settings_screen.dart:147-150` "coming soon" |
| **场景选择 UI（游戏化卡片）** | ❌ **未实现** | grep 无 scenario_selection 屏幕 |
| Learning stats | ⚠️ 真实但部分虚假 | `learning_stats_service.dart:40-123`（masteredCount/learningCount 永远 0；dailyActivity.corrections 硬编码 0 且字段不渲染） |
| Theme 即时切换 | ⚠️ 部分（需重启） | `main.dart:72` `setThemeMode` 定义但 Settings 不调用 |

---

## 五、改进建议（按优先级）

### P0（核心学习闭环必须修）

1. **接通 SM-2 算法**：复习会话结束后，在 ChatScreen 退出 / session 归档时，让用户对本次 due corrections 逐条打分（Again / Hard / Good / Easy → quality 0/3/4/5），调用 `Sm2Service.scheduleReview` + `repo.updateCorrection`。否则"完整学习闭环"是 false advertising。
2. **重写 Placement 为真实 AI 评估**：让 LLM 引导 2-3 分钟对话（可复用 chat_screen），结束时让 LLM 输出 `{level, strengths, weaknesses}` JSON。当前自评与 spec 严重不符。
3. **修复 Progress 统计**：SM-2 接通后 `review_count` 会真实更新，"Mastered" 自动恢复。同时 `dailyActivity.corrections` 应真实查询 corrections 表，并在 progress_screen 渲染图表（当前是死字段）。

### P1（影响用户信任与可用性）

4. **接通 correction_strength**：在 `TutorPromptBuilder` 中读取 `correction_strength` setting 并改写 prompt（gentle → "only flag clear errors that block understanding"；strict → "correct every error including minor style/collocation"）。
5. **接通 tts_speed 全局设置**：`TtsService.synthesize` 用 `profile.speed * globalTtsSpeed` 或 `min/max` 合并；或直接删除该 Settings 项避免混淆（profile.speed 已够用）。
6. **实现 i18n**：接入 `flutter_localizations` + `gen_l10n`，至少覆盖 onboarding / chat / settings / placement 关键文案。spec 已承诺中文/English，目标用户群是中国英语学习者，无中文 UI 是重大缺失。
7. **流式 LLM**：改用 SSE/streaming（OpenAI 协议 `stream: true`），首 token <1s，让字逐个出现。当前非流式 + max_tokens 1000，长回复 5-10s 等待体验差。
8. **Correction 提取加 fallback**：LLM 没输出 corrections block 时，可选地发第二轮 "Extract corrections as JSON from this conversation" 调用，或用 OpenAI `response_format: json_schema`（兼容协议支持时）。
9. **Theme 即时切换**：用 Riverpod `themeModeProvider` 或 `ValueNotifier<ThemeMode>` 把 `SpeakFlowApp._themeMode` 暴露给 Settings 即时 `setState`。
10. **Correction 去重**：saveCorrection 前按 `(original, corrected)` 哈希查重，已存在则只更新 `last_seen_at`，避免错误库被同一错误刷屏。

### P2（体验打磨）

11. **无障碍**：给 onboarding / placement / review / settings / service_config / progress 屏补 `Semantics`；所有循环动画尊重 `MediaQuery.disableAnimations`。
12. **STT/TTS vendor 错误信息**：解析 JSON body 提取 `error.message`，不直接 dump raw body。
13. **Pronunciation correction**：要么移除该类型（LLM 纯文本无法可靠判断发音），要么接入音素级评分（spec 阶段五）。当前会给用户错误信号。
14. **Auto-play TTS 开关**：Settings 加开关，让用户可关闭"AI 回复后自动播放"，避免公共场合突然出声。
15. **Export learning data**：实现 JSON 导出（spec 已承诺）。可复用 `exportAllProfilesJson` 模式。
16. **Onboarding Profile 默认名**：用 provider displayName（如 "DeepSeek Default"）而非硬编码 "Default"。
17. **录音权限错误引导**：错误信息加"请到系统设置 → 隐私 → 麦克风开启"指引。
18. **场景选择 UI**：补 spec 承诺的游戏化场景卡片选择屏，否则 DB 种的 8 个场景用户看不到入口。

---

## 附：核心结论

**最严重的两条**：

1. **学习闭环名义上完整，实质断裂**。LLM 真的产 corrections、真的存库、Review 真的把 due corrections 喂给 LLM——但复习后 SM-2 不接通，`review_count` 永远是 0，Progress 页 "Mastered" 永远是 0，所有 corrections 永远显示 "New"。用户练 100 次同一条错误，系统仍认为他一无所知。**这是 spec 核心卖点"完整学习闭环"的最大破洞，必须 P0 修复。**

2. **Placement 是 stub，与 spec 严重不符**。spec 反复强调"AI 引导简短对话评估水平"，实际是 4 道自评选择题，LLM 完全没参与。**这是 spec 卖点被降级为入门问卷，必须 P0 修复。**

其余（correction_strength / tts_speed / i18n / export / 场景选择 UI / theme 即时切换）属于"承诺了没交付"或"设置了不生效"类问题，影响用户信任，应按 P1/P2 逐步补齐。
