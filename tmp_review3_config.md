# Review 3 — 配置合理性 / AI配置习惯 / 提示词科学性 / Token效率与节省

> 评审对象: SpeakFlow (AI 英语口语练习 App, OpenAI-compatible LLM + 云端 STT/TTS, 3-Profile 独立配置)
> 评审日期: 2026-06-29
> 评审范围: 仅限配置 / 提示词 / Token 三个维度

---

## 一、配置设置合理性

### 1.1 优点

- **3-Profile 架构清晰** (`profile_models.dart:8-368`): LLM / STT / TTS 三类 Profile 各自独立,字段定义完整 (id / providerId / baseUrl / apiKey / model / isActive / timestamps),`ProviderKind` 区分 `openaiCompatible` vs `vendor`,扩展性好。
- **Provider Catalog 覆盖面合理** (`provider_catalog.dart`): LLM 覆盖 DeepSeek / Zhipu GLM / Moonshot / Qwen / SiliconFlow / OpenAI / Groq / Together / Mistral / Ollama / LM Studio / Custom;STT 覆盖 OpenAI Whisper / Groq Whisper / Deepgram / Azure / Google / SiliconFlow;TTS 覆盖 OpenAI / Fish Audio / ElevenLabs / Azure / Google / Aliyun CosyVoice / SiliconFlow。CN + Global + Local 三档分组 (`ProviderRegion`),对国内用户友好。
- **API Key 安全存储到位** (`profile_repository.dart:40, 106, 171`): Key 存入 `SecureStorageService`,SQLite 只存 `***stored***` 占位符,不落盘明文。
- **URL 归一化鲁棒** (`openai_endpoint.dart:19-29`): 自动补 `/v1`,容忍 `/v4` 厂商路径,去除多余斜杠;`openai_endpoint_test.dart` 覆盖完整。
- **Catalog 默认值自动填充** (`onboarding_screen.dart:58-62`, `profile_form_screen.dart:115-129`): 选 provider 后 baseUrl / model / voice 自动回填,降低用户填表成本。
- **Test Connection 带延迟反馈** (`profile_form_screen.dart:811`, `service_config_screen.dart:487-511`): Stopwatch 测时,提示 `✓ Connected (XXXms, N models)`。
- **Import/Export 掩码 Key** (`profile_repository.dart:261-264`): 导出时 `前4****后4` 掩码,避免明文泄露。
- **Legacy 字段向后兼容** (`profile_models.dart:193-213, 332-351`): 旧版 `provider` 枚举能映射到新 `providerId`,迁移平滑。
- **Form 校验合理** (`profile_form_screen.dart:594-598`): API Key 必填校验,编辑模式可留空保留旧 Key (`_hasExistingKey`)。

### 1.2 问题

- **Catalog 默认模型名疑似错误** (`provider_catalog.dart:70, 89`):
  - `deepseek` 默认 `defaultModel: 'deepseek-v4-flash'` — DeepSeek 官方当前模型为 `deepseek-chat` (V3) / `deepseek-reasoner` (R1),`deepseek-v4-flash` 不存在,首次聊天会 404。
  - `moonshot_kimi` 默认 `defaultModel: 'kimi-k2.6'` — Moonshot 官方模型为 `moonshot-v1-8k/32k/128k` 或 `kimi-k2`,`k2.6` 版本号可疑。
  - 这些是 onboarding 默认值,新用户直接踩坑。
- **Onboarding 不做连通性校验** (`onboarding_screen.dart:451-500`): 保存 Profile 前不调用 `testConnection`,用户可能存入错误配置,直到聊天时才发现。`Test Connection` 按钮在 Form 上但非强制。
- **`SttProfile.region` 用正则解析 JSON** (`profile_models.dart:139-150`): 用 `RegExp(r'"region"\s*:\s*"([^"]+)"')` 提取 region,若 `extraConfig` 含嵌套引号或不同格式会失效。应直接 `jsonDecode`。`TtsProfile.region` (`:279-283`) 同样问题。
- **TTS 缓存 key 用 hashCode 有碰撞风险** (`tts_playback_service.dart:14-18`): `${hashCode.toRadixString(16)}_${length}` 作为缓存键,不同文本理论可能碰撞,导致播放错误音频。概率低但非零。
- **`clearCache` 不递归** (`tts_playback_service.dart:109-123`): `listSync()` 只列直接子项,`tts_cache/` 子目录内的文件不会被清理;且 `file.path.contains('tts_')` 可能误删无关临时文件。
- **`fetchModels` 静默吞错** (`llm_service.dart:167-195`): 任何异常都 `return []`,无法区分"无模型" / "鉴权失败" / "网络错误",用户只看到 "No models returned"。
- **Profile 数量无上限**: 用户可创建任意多 Profile,无封顶提示。
- **BaseUrl 缺乏 URL 格式校验** (`profile_form_screen.dart:549-571`): 只校验非空,不校验是否合法 URL,运行时 `Uri.parse` 可能崩溃。
- **ElevenLabs voice_settings 硬编码** (`tts_service.dart:131`): `stability: 0.5, similarity_boost: 0.75` 不可配,高级用户无法调音。
- **Onboarding STT/TTS 默认对国内用户不够友好** (`onboarding_screen.dart:32, 36`): STT 默认 `deepgram` (global,国内延迟高),TTS 默认 `fish_audio` (CN,合理)。建议根据 locale 或让用户选区域后给默认值。

### 1.3 严重度

| 问题 | 严重度 | 位置 |
|---|---|---|
| DeepSeek/Kimi 默认模型名错误 | **P0** (首次使用即失败) | `provider_catalog.dart:70, 89` |
| Onboarding 不校验连通性 | P1 | `onboarding_screen.dart:451` |
| region 用正则解析 JSON | P2 | `profile_models.dart:139-150` |
| TTS 缓存 hashCode 碰撞 | P2 | `tts_playback_service.dart:14` |
| clearCache 不递归 | P2 | `tts_playback_service.dart:113` |
| fetchModels 静默吞错 | P2 | `llm_service.dart:192` |

---

## 二、AI 配置使用习惯 (temperature / max_tokens / timeout / streaming / retry)

### 2.1 现状

- **Temperature**: `0.7` 硬编码 (`llm_service.dart:30`),不可配。
- **max_tokens**: `1000` 硬编码 (`llm_service.dart:31`),不可配。
- **Timeout**: LLM 请求 60s (`llm_service.dart:34`),STT/TTS 各 60s (`stt_service.dart:57, 86, 139, 170`, `tts_service.dart:64, 97, 134, 173, 209, 255, 279`),`testConnection`/`fetchModels` 15s。
- **Streaming**: **无**。`sendMessage` 单次阻塞 POST,未设 `stream: true`。
- **Retry**: **无**。任何非 200 直接抛异常,无指数退避,无 429/5xx 重试。`_checkAuth` (`stt_service.dart:243-245`, `tts_service.dart:477-479`) 在 `>=500` 时直接 throw。
- **错误处理**: `LlmException` 消息含原始 response body (`llm_service.dart:38`),Chat 屏幕 `_safeError` 截断到 160 字符 (`chat_screen.dart:616-620`),但仍是原始 API 文本。
- **Usage 追踪**: `LlmUsage` (promptTokens/completionTokens) 已解析 (`llm_service.dart:61-66`),但**未持久化、未展示、未做成本统计**。

### 2.2 评估

- **`temperature: 0.7`**: 对口语会话尚可(多样性),但本 App 核心功能是纠错,0.5-0.6 更利于纠错一致性。且**不可配**是主要问题——不同 tutor (严格 vs 随性) 应有不同温度。
- **`max_tokens: 1000`**: **与系统提示自相矛盾**。Spine 明确要求 "Keep each turn SHORT (1–4 sentences)" (`tutor_prompts.dart:100-101`),4 句约 80-120 tokens,1000 是 8-10 倍超配,会诱导模型冗长,违反 Spine 规则。建议 300-400,或可配。
- **无 Streaming**: 对 voice-first App 是**重大体验缺陷**。用户链路: 录音 → STT → 等 LLM 全量返回 → TTS 合成 → 播放。每步串行,LLM 60s 全量等待期间用户面对静默。Streaming 可让首句 TTS 提前启动,感知延迟降一半以上。
- **无 Retry**: 瞬时 429/5xx 直接失败,用户需重发。对国内访问 global 端点(OpenAI/Deepgram)尤其脆弱。
- **无请求取消**: 用户离开 ChatScreen 时,在途请求继续跑完(浪费 token + 费用)。`_isLoading` 仅 UI 层防护,Service 无 cancel token。
- **无 Usage 持久化**: 解析了却不用,无法做用量提醒 / 成本估算 / 多 Profile 对比。

### 2.3 严重度

| 问题 | 严重度 | 位置 |
|---|---|---|
| 无 Streaming | **P0** (voice-first App 核心体验) | `llm_service.dart:20-34` |
| max_tokens 1000 与 Spine 矛盾 | **P1** | `llm_service.dart:31` vs `tutor_prompts.dart:100` |
| 无 Retry | **P1** | `llm_service.dart:36-40` |
| temperature/max_tokens 不可配 | P1 | `llm_service.dart:30-31` |
| Usage 未持久化 | P2 | `llm_service.dart:61-66` |
| 错误消息含原始 body | P2 | `llm_service.dart:38` |

---

## 三、提示词科学性合理性

### 3.1 结构 (TutorPromptBuilder, `tutor_prompts.dart`)

结构分层清晰,顺序为: Spine (角色/规则/纠错/等级) → Persona → Scenario → Review focus。`tutor_prompts_test.dart` 验证了顺序与条件包含逻辑 (`:135-167`)。

**优点:**
- Spine 强调 voice-first 优化 ("optimize for the ear, not the eye", `:97`),适合 TTS 朗读。
- Spine 要求短回合 (1-4 句) + 结尾抛问题驱动对话 (`:100-103`)。
- 等级自适应 (beginner/intermediate/advanced) 用词、句长、话题差异明确 (`:123-139`)。
- Scenario 鼓励 "introduce small realistic twists" (`:48-51`),避免单调。
- Review focus 明确禁止直接 quiz ("Do NOT list the corrections or quiz them directly — engineer the dialogue", `:68-70`),教学理念正确。
- Tutor 人设差异化 (Emma 暖心 / James 专业 / Alex 随性 / Chen 严格 / Sarah 考试 / Miller 发音, `tutor.dart:23-90`)。

### 3.2 问题

- **纠错指令双重下发且部分矛盾** (`tutor_prompts.dart:110-117` vs `llm_service.dart:81-92`):
  - Spine "How to correct": "Do NOT interrupt the flow to lecture. Model the correct form... When a mistake is subtle or high-value, give a one-line explanation **in your reply**, then move on." → 鼓励**内联**口头解释。
  - LlmService 追加: "naturally correct them... At the end of your response, add a JSON block like this: ```corrections [...]```" → 要求**JSON 块**含 explanation。
  - 矛盾点: Spine 让解释出现在口语回复中(用户能听到),LlmService 让解释进 JSON(用户在 UI 看到)。模型可能**两处都写解释**,既念出来又写 JSON,token 浪费 + 体验重复。
  - 建议: 二选一。口语回复保持自然(不内联长解释),结构化解释只进 JSON;或反之。
- **Corrections JSON 围栏非标准** (`llm_service.dart:86-90`): 用 ` ```corrections ` 而非 ` ```json `,模型不一定可靠产出。正则 `r'```corrections\s*\n([\s\S]*?)\n```'` (`:116`) 严格要求 fence 后有换行、结尾前有换行,格式微差即提取失败(静默返回空 list + debugPrint)。
- **type 字段静默降级** (`llm_service.dart:127-139`): 模型若输出 `"type": "spelling"` 或 `"style"`,默认降为 `grammar`,分类错误无提示。
- **Persona 与 Spine 冗余** (`tutor.dart:33, 44, 66`): Emma "gently correct mistakes"、Chen "correct every mistake and explain why" 与 Spine 的 "How to correct" 重复,部分(Chen "correct every mistake")甚至与 Spine "Don't over-correct" (`:115`) 冲突。
- **Placement 不调 LLM** (`placement_screen.dart:175-199`): 纯本地问卷启发式打分。这其实是**合理省 token** 的选择(避免首次即消耗),但等级仅自评,精度有限。对口语 App 可接受。
- **System prompt 每轮全量重建** (`chat_screen.dart:322-329`): 不存储,每轮从 `TutorPromptBuilder.build` 重新拼。一致性 OK,但 Spine + 纠错指令每轮重发(见第四节)。

### 3.3 严重度

| 问题 | 严重度 | 位置 |
|---|---|---|
| 纠错指令双重下发且矛盾 | **P1** | `tutor_prompts.dart:110-117` + `llm_service.dart:81-92` |
| Corrections 围栏非标准 + 正则脆弱 | P1 | `llm_service.dart:86-90, 116` |
| type 静默降级 | P2 | `llm_service.dart:127-139` |
| Persona 与 Spine 冗余/冲突 | P2 | `tutor.dart:33, 66` |

---

## 四、Token 效率性

### 4.1 每次 turn 的 token 成本估算

**System prompt (每轮重发):**
- Spine (`_spine`): ~350 tokens
- LlmService 追加的纠错指令 (`:81-92`): ~180 tokens
- Persona (`tutor.systemPrompt`): ~60-100 tokens
- Scenario (若有): ~50-100 tokens
- Review focus (若复习且有待复习项): ~100-200 tokens
- **合计: ~640-830 tokens / 轮**

**History (每轮全量重发):**
- `chat_screen.dart:291` `final history = await repo.getMessages(widget.sessionId)` — 取**全部**消息。
- `llm_service.dart:96-101` 遍历全部 history 加入 messages。
- `chat_repository.dart:75-84` `getMessages` 无 LIMIT。
- 假设每条消息平均 180 tokens(用户短句 + AI 短回复),第 N 轮发送 N-1 条历史。

**单轮总成本估算 (无复习,10 轮会话):**
- 第 1 轮: system ~640 + history 0 + user ~20 = ~660 tokens
- 第 10 轮: system ~640 + history 9×180=1620 + user ~20 = ~2280 tokens
- 累计 10 轮: ~640×10 + 180×(0+1+...+9) = 6400 + 8100 = **~14500 tokens**
- 50 轮: ~640×50 + 180×(0..49) = 32000 + 44100 = **~76100 tokens** (逼近小模型上下文窗口)

**结论: Token 成本 O(N²) 增长,无任何截断/滑动窗口/摘要。**

### 4.2 是否冗余发送

- **纠错 JSON 指令每轮重发 (~180 tokens)** (`llm_service.dart:81-92`): 即使用户只说 "Hi"、无任何错误,也照发。占 system prompt 约 25%。这是本 App 最大的单点 token 浪费。
- **Spine "How to correct" 与 LlmService 纠错指令重叠** (`tutor_prompts.dart:110-117` + `llm_service.dart:83-84`): 两处都讲"自然纠错、不打断流",约 80 tokens 重复。
- **Corrections block 不回传 LLM (正确)**: `response.content` = `_cleanResponse(content)` (`llm_service.dart:59`),存储前已剥离 corrections JSON;后续历史不含 JSON 块。✓ 这点处理正确。
- **User message 不重复发送 (正确)**: `chat_screen.dart:288-291` 注释明确,先存 DB 再取历史,不单独传 `userMessage`,避免重复。✓
- **Persona 每轮重发**: 不可避免(OpenAI API 无 system prompt 客户端缓存),但 Persona 与 Spine 冗余部分可压缩。

### 4.3 历史策略

- **全量历史,无截断** (`chat_repository.dart:75-84`): `getMessages` 无 LIMIT,无滑动窗口,无摘要压缩。
- **无消息长度上限**: 长 AI 回复或长用户输入原样保留在历史中。
- **无 token 预算检查**: 发送前不估算总 token,不防止超出模型上下文窗口 (`glm-4-flash` 128k、`deepseek-chat` 64k,长会话有超限风险)。
- **无会话轮次上限**: 无 N 轮后自动归档/摘要机制。

---

## 五、Token 节省性

### 5.1 缓存

- **TTS 双层缓存 (内存 + 磁盘)** (`tts_playback_service.dart:11, 49-67`): ✓ 重复播放同一条 AI 回复复用音频,避免重复 TTS 调用。这是本 App 唯一有效的 token/费用节省机制。
- **LLM 无 prompt 缓存**: System prompt 每轮全量重发。DeepSeek 服务端有隐式 prompt caching,但客户端未显式利用。
- **STT 无缓存**: 每次录音重新转录 (合理,录音唯一)。
- **无 Provider 响应缓存**: 相同输入不缓存 (对 tutor 不合理,因 temperature 0.7 非确定性)。

### 5.2 截断

- **无历史截断** (见 4.3)。
- **无消息截断**: 长消息原样存。
- **Review corrections 有上限** (`chat_screen.dart:318`): `getDueCorrections(limit: 10)` — ✓ 限制复习项数,防止 review block 膨胀。
- **无 system prompt 压缩**: Spine 文本偏长,可用更精简表述。

### 5.3 其它

- **`_cleanResponse` 剥离 corrections block** (`llm_service.dart:161-164`): ✓ 避免历史累积 JSON 垃圾,节省后续轮次 token。
- **Placement 不调 LLM** (`placement_screen.dart`): ✓ 节省首次 token。
- **`fetchModels` / `testConnection` 用 15s 超时**: 避免探测请求空耗。
- **未利用 LlmUsage**: 解析了 prompt_tokens/completion_tokens 却不存储、不展示,无法做用量预警或自动截断。

---

## 六、改进建议 (按优先级)

### P0 — 必须修复 (影响核心可用性 / 首次体验)

1. **修正 Catalog 默认模型名** (`provider_catalog.dart:70, 89`): `deepseek-v4-flash` → `deepseek-chat`;`kimi-k2.6` → `moonshot-v1-8k` 或 `kimi-k2`。否则新用户首次聊天即 404。
2. **接入 LLM Streaming** (`llm_service.dart:20-34`): 加 `stream: true`,SSE 解析,首句即返回。配合 TTS 边生成边合成,voice-first 体验质变。可保留非流式 fallback。
3. **降低 max_tokens 并对齐 Spine** (`llm_service.dart:31`): 1000 → 300-400,与 "1-4 句" 一致;或改为可配 (Profile 级或 Tutor 级)。

### P1 — 重要 (显著影响 token 成本 / 体验 / 纠错质量)

4. **移除每轮重发的纠错指令** (`llm_service.dart:81-92`): 将 corrections JSON 格式说明移到首次 system prompt 或单独的固定段;或仅在检测到用户消息含完整句子时才追加。预估每轮省 ~180 tokens,50 轮省 ~9000 tokens。
5. **统一纠错指令,消除 Spine vs LlmService 矛盾** (`tutor_prompts.dart:110-117` + `llm_service.dart:81-92`): 二选一——口语回复不内联解释,结构化解释只进 JSON;或反之。当前模型可能两处都写,token 浪费 + 体验重复。
6. **加历史截断 / 滑动窗口** (`chat_repository.dart:75-84`, `chat_screen.dart:291`): `getMessages` 加 `limit` 或 `offset`,保留最近 N 轮 (如 20 轮);或超阈值时摘要压缩。防止长会话 O(N²) 爆炸 + 超出上下文窗口。
7. **加 Retry (指数退避)** (`llm_service.dart:36-40`, `stt_service.dart:62-67`, `tts_service.dart:66-72`): 对 429 / 5xx 重试 2-3 次,退避 1s/2s/4s。国内访问 global 端点尤其需要。
8. **temperature / max_tokens 可配** (`llm_service.dart:30-31`): 至少在 LlmProfile 或 Tutor 级暴露 (如 Professor Chen 用 0.4, Alex 用 0.8)。
9. **Corrections 围栏改用标准 JSON** (`llm_service.dart:86-90, 116`): 改 ` ```json ` 或用 `<corrections>...</corrections>` XML tag,提升模型产出可靠性与正则鲁棒性;或用 OpenAI structured outputs / function calling。
10. **Onboarding 加连通性校验** (`onboarding_screen.dart:451-500`): 保存前可选 `testConnection`,失败给警告但不阻塞。

### P2 — 优化 (健壮性 / 可观测性 / 细节)

11. **持久化并展示 LlmUsage** (`llm_service.dart:61-66`): 存入 DB,Settings 页展示累计 token / 估算费用,支持用量预警。
12. **region 用 jsonDecode 替代正则** (`profile_models.dart:139-150, 279-283`): 避免格式微差导致解析失败。
13. **TTS 缓存 key 用 SHA-256 替代 hashCode** (`tts_playback_service.dart:14-18`): 消除碰撞风险。
14. **`clearCache` 递归清理 `tts_cache/` 子目录** (`tts_playback_service.dart:109-123`): 用 `listSync(recursive: true)` 或显式删 `tts_cache` 目录。
15. **`fetchModels` 区分错误类型** (`llm_service.dart:167-195`): 401/403 抛鉴权错,网络错抛网络错,仅在 200+空列表时返回 `[]`。
16. **请求取消** (`llm_service.dart:13`): `sendMessage` 接受 `CancelToken`,用户离开 ChatScreen 时取消在途请求,省 token + 费用。
17. **Persona 去重** (`tutor.dart:33, 44, 66`): Emma "gently correct" / Chen "correct every mistake" 与 Spine 重复或冲突,精简 persona 让 Spine 统一纠错策略。
18. **BaseUrl URL 格式校验** (`profile_form_screen.dart:549-571`): 加 `Uri.tryParse` 校验,防运行时崩溃。
19. **错误消息脱敏** (`llm_service.dart:38`): 异常消息不含原始 response body,避免泄露 provider 提示或部分 payload。
20. **type 字段未知值保留原值或标记 `other`** (`llm_service.dart:127-139`): 而非静默降为 `grammar`。

---

**总结**: 配置架构设计扎实 (3-Profile / Catalog / Secure Storage / URL 归一化),但存在两类硬伤——(1) 首次可用性: DeepSeek/Kimi 默认模型名错误将导致新用户首聊即失败;(2) Token 效率: 纠错指令每轮重发 (~180 tokens) + 全量历史无截断 (O(N²)) + 无 streaming,长会话成本与延迟双重失控。提示词层面 Spine 质量高但与 LlmService 追加块存在纠错策略矛盾,需统一。
