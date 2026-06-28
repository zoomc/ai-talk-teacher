# SpeakFlow — 临时 Review 与改进计划

> 生成日期：2026-06-28
> 依据：源码全量阅读 + projects.md / agent.md / docs/design-reference.md 式样比对
> 用途：开发执行清单（开发完成后删除本文件）

---

## Review #1 — UI 与交互逻辑

### P0 阻断性问题（功能不可用）

1. **录音服务返回空字节** — [lib/features/chat/data/recording_service.dart#L33-L45](lib/features/chat/data/recording_service.dart)
   - `stopRecording()` 直接 `return Uint8List(0)`，注释写 "placeholder"
   - 结果：所有"按住说话 → STT → 文字"流程 100% 失败，永远弹 "No audio recorded"
   - 同时录音路径 `path: 'audio_recording.wav'` 是相对路径，多数平台无写入权限

2. **聊天消息发送后不刷新** — [lib/features/chat/presentation/screens/chat_screen.dart#L176](lib/features/chat/presentation/screens/chat_screen.dart)
   - `_handleSend` 调用 `setState(() {})` 试图刷新，但消息列表用 `ref.watch(_messagesProvider(...))`（FutureProvider，结果被缓存）
   - 没有 `ref.invalidate(_messagesProvider(sessionId))`，新消息不会出现在 UI 上
   - 结果：用户发送的消息和 AI 回复都"消失"了，聊天界面看起来没有任何反应

3. **用户消息被发送两次给 LLM** — [lib/features/chat/presentation/screens/chat_screen.dart#L120-L157](lib/features/chat/presentation/screens/chat_screen.dart)
   - 顺序：`saveMessage(userMsg)` → `getMessages(sessionId)`（已包含刚保存的用户消息）→ `sendMessage(history, userMessage: text)`
   - `_buildMessages` 又把 `userMessage` 追加到末尾，用户消息在 API 调用里出现 2 次
   - 影响：浪费 token、可能让 LLM 重复回答、上下文混乱

4. **TTS 监听器内存泄漏** — [lib/features/chat/presentation/screens/chat_screen.dart#L272-L278](lib/features/chat/presentation/screens/chat_screen.dart)
   - 每次 `_playTts` 都 `_ttsPlaybackService.player.playerStateStream.listen(...)`，从没 `cancel()`
   - 多次点击播放后，监听器堆叠，回调多次触发，setState 多次

5. **AI 回复不自动播放 TTS，无 speaking 状态** — [lib/features/chat/presentation/screens/chat_screen.dart#L82-L88](lib/features/chat/presentation/screens/chat_screen.dart)
   - VirtualCharacter 状态只有 `listening`/`thinking`/`idle`，从来不进入 `speaking`
   - 式样 §3.1 / §4.3 要求 AI 回复自动 TTS + 嘴型同步，目前完全缺失

### P1 严重 UX 问题

6. **聊天气泡不渲染 corrections** — [lib/features/chat/presentation/screens/chat_screen.dart#L388-L462](lib/features/chat/presentation/screens/chat_screen.dart)
   - `_ChatBubble` 只接收 `message` 字符串和 `isUser` 布尔，不接收 `corrections` 列表
   - 式样要求"错误词红色高亮 + 绿色纠正气泡"，目前用户看不到任何纠正信息
   - 数据库里的 corrections 完全没在聊天 UI 中体现

7. **播放图标永远不切换** — [lib/features/chat/presentation/screens/chat_screen.dart#L372](lib/features/chat/presentation/screens/chat_screen.dart)
   - `_ChatBubble` 的 `isPlaying` 参数被硬编码为 `false`
   - `chat_screen` 里 `_playingMessageId` 状态根本没传给子组件

8. **滚动到底部失效** — [lib/features/chat/presentation/screens/chat_screen.dart#L45-L53](lib/features/chat/presentation/screens/chat_screen.dart)
   - `_scrollToBottom()` 定义了但从未在消息更新时调用
   - 新消息出现时用户看不到，必须手动下滑

9. **TutorSelectionScreen 是孤岛** — [lib/features/chat/presentation/screens/tutor_selection_screen.dart](lib/features/chat/presentation/screens/tutor_selection_screen.dart)
   - 路由 `/tutor-selection` 注册了，但 UI 中没有任何按钮跳到这里
   - `context.pop(tutor.id)` 返回的 tutor ID 也没人接收、不持久化、不影响 chat
   - 整个 6 个 tutor 系统形同虚设

10. **设置弹窗全部不可用** — [lib/features/settings/presentation/screens/settings_screen.dart](lib/features/settings/presentation/screens/settings_screen.dart)
    - `_showCorrectionStrengthDialog` / `_showThemeDialog` 用 `groupValue: 'moderate'` / `'system'` 硬编码，`onChanged: (_) {}` 空实现
    - "TTS Speed"、"Interface Language"、"Export Learning Data" 的 `onTap: () {}` 全空
    - 设置项完全不持久化、不生效

11. **Profile Form 编辑模式不加载已有数据** — [lib/features/profile/presentation/screens/profile_form_screen.dart#L29-L35](lib/features/profile/presentation/screens/profile_form_screen.dart)
    - `widget.profileId` 收下了，但 `initState` 不去查询已有 profile，所有输入框空白
    - 用户点"编辑"看到的是空表单，保存后会把原 profile 整个覆盖成空值

12. **"Fetch available models" 是 TODO** — [lib/features/profile/presentation/screens/profile_form_screen.dart#L219-L224](lib/features/profile/presentation/screens/profile_form_screen.dart)
    - 点击只弹 SnackBar "will be implemented"，但 `LlmService.fetchModels()` 早已实现
    - 仅仅是没有接线

13. **ServiceConfig 无删除/测试连接** — [lib/features/profile/presentation/screens/service_config_screen.dart](lib/features/profile/presentation/screens/service_config_screen.dart)
    - 式样 §3.4 明确要求：删除（带确认、不能删当前激活）、测试连接、复制、导入/导出
    - 当前只有"激活"和"编辑"两个操作；"Import All" / "Export All" 按钮 `onPressed: () {}` 空

14. **Review "AI Review" / "Practice" 创建空会话** — [lib/features/chat/presentation/screens/review_screen.dart#L160-L176](lib/features/chat/presentation/screens/review_screen.dart)
    - `_startAIReview` / `_practiceCorrection` 只是 `createSession(topic: '...')`，不把 corrections 注入 system prompt
    - 进入 chat 后 AI 完全不知道要复习什么，用户期待落空

15. **Placement 只用第 1 题** — [lib/features/onboarding/presentation/screens/placement_screen.dart#L141-L149](lib/features/onboarding/presentation/screens/placement_screen.dart)
    - 4 道题收集完，只看 `_answers[0]` 决定 level，其他 3 题纯摆设
    - 式样要求"AI 引导 2-3 分钟英语对话定级"，目前是 4 道选择题

16. **无聊天历史浏览** — projects.md §7 阶段二要求"会话管理：新建/继续/历史浏览"
    - 数据层 `getAllSessions` 实现了，但 UI 完全没有历史列表
    - Home 只显示 1 个"Continue your conversation"卡片，看不到过往会话

### P2 一致性/可用性

17. **发 送按钮不区分空态** — 文本框空时按钮仍可点，点了 `_handleSend` 才发现空文本 return
18. **Loading 中输入未禁用** — LLM 思考时仍可继续点发送/录音
19. **无 typing indicator** — AI 思考时聊天区域无任何反馈
20. **BottomNav 在 chat 页消失** — chat 在 ShellRoute 外，进 chat 后底栏不见，只有 AppBar 返回；UX 不一致
21. **Empty state 缺失** — scenarios 加载失败 / 无数据时是白屏
22. **场景卡缺式样要求的"进度标记"** — projects.md §3.2 要求"分类展示 + 进度标记 + 难度标签"，难度有，进度无
23. **Web 录音兼容性未处理** — `record` 包在 Web 上行为不同，没有平台分支
24. **录音无振幅反馈** — 式样 §4.3 要求录音时"波纹向外扩散"，目前只有按钮颜色变化
25. **无 haptic feedback** — 录音开始/停止、长按等关键交互无震动反馈
26. **无响应式适配** — 式样 §4.2 要求手机/平板/桌面/Web 适配，目前所有布局都是 mobile-first 单列
27. **Profile 切换后旧 chat 状态未清理** — `setActive*Profile` 后正在进行的 chat 会突然换 LLM，无提示
28. **PlayMusicTTS 失败时图标不重置** — `setState(() => _playingMessageId = null)` 在 catch 内 OK，但若 setFilePath 抛异常前的 setState 已经置为 messageId
29. **Onboarding 进度不可跳过/重做** — 用户填错 key 也无法回退
30. **ReviewScreen 一次拉 50 条无分页** — 错误多了会卡

---

## Review #2 — 式样完成度

### 阶段一（MVP）

| 式样条目 | 状态 | 说明 |
|---|---|---|
| Flutter 项目初始化 macOS+Web | ✅ | 还包含 iOS+Android |
| 3-Profile 系统统一管理 | 🟡 | 数据层完整，UI 缺删除/测试连接/导入导出 |
| 主界面：上半屏角色 + 振幅嘴型动画 | ❌ | 角色 placeholder 有，**振幅驱动嘴型完全没做** |
| 按住录音 → 云端 STT → 文字 | ❌ | RecordingService 返回空字节，整条链路断 |
| AI 对话（OpenAI 兼容） | ✅ | LlmService 工作正常（除重复 user message bug） |
| TTS 播放 + 嘴型动画 | 🟡 | TTS 能播，无自动播放、无嘴型同步 |
| 智能纠正 + corrections[] 入库 | 🟡 | 提取逻辑在，但 UI 不展示，且发送时 user msg 重复 |
| Profile CRUD | 🟡 | 缺 UI 删除、缺测试连接 |
| 新手引导分步教程 | ✅ | Onboarding 4 页面 OK，但无"跳过" |
| 水平定级（AI 引导对话） | ❌ | 式样要求 AI 对话定级，实际是 4 道选择题，且只用第 1 题 |
| 对话历史本地存储 | 🟡 | 数据层 OK，**无历史浏览 UI** |

### 阶段二（学习循环）

| 式样条目 | 状态 | 说明 |
|---|---|---|
| 错误记录系统 | ✅ | DB + 提取 OK |
| 复习模式（AI 聊天式） | ❌ | 按钮存在但创建空 session，不注入 corrections |
| SM-2 算法 | ✅ | 已修复 EF/interval 字段 |
| 会话管理：新建/继续/历史 | 🟡 | 新建+继续 OK，**历史浏览缺失** |
| 场景选择（游戏化卡片） | 🟡 | 卡片有，**进度标记缺失** |
| 纠正强度三档 | ❌ | 设置弹窗 UI 在，完全不生效、不持久化 |
| 消息点击重播 TTS | ✅ | 点击 Listen 触发播放 |
| iOS + Android 适配测试 | ❌ | 未执行 |
| Profile 导入/导出 | ❌ | 按钮存在，逻辑全空 |

### 阶段三（虚拟人物）

| 式样条目 | 状态 | 说明 |
|---|---|---|
| Live2D 模型集成 | ❌ | 仅 emoji placeholder |
| Rhubarb Lip Sync | ❌ | 未集成 |
| Viseme → 嘴型参数 | ❌ | 未做 |
| 待机动画（呼吸/眨眼/微笑） | 🟡 | 呼吸有，**眨眼/微笑无** |
| 情感表情切换 | ❌ | 仅状态色变化 |

### 阶段四（发布）

| 式样条目 | 状态 |
|---|---|
| Web Safari/Chrome 兼容测试 | ❌ |
| macOS App Store 打包/签名/公证 | ❌ |
| iOS App Store 提交 | ❌ |
| Google Play 提交 | ❌ |
| 性能优化 | ❌ |
| 错误处理和边界情况 | 🟡 |
| 新手引导教程 | ✅ |

### 式样要求但完全缺失的功能

1. **振幅驱动嘴型动画** — MVP 明确要求，完全没做
2. **聊天 UI 内的纠正可视化** — 红色错误词、绿色纠正气泡，全部缺失
3. **历史会话浏览页** — 阶段二明确要求
4. **场景进度标记** — §3.2 要求
5. **Profile 导入/导出 JSON** — §3.4 要求
6. **Profile 测试连接** — §3.4 要求"发送简单请求验证 Key 有效性，显示延迟和状态"
7. **AI 引导定级对话** — §3.2 要求"AI 引导 2-3 分钟英语对话评估"，目前是选择题
8. **TTS 音频本地缓存** — §5.1 要求"哈希索引，避免重复合成"，完全没做
9. **话题连续性"继续上次/开始新话题"** — §3.2 要求打开应用时选择，目前只有 home 一张卡片
10. **Tutor 选择实际生效** — 选了不用，6 个 tutor 全部死代码
11. **TTS 语速可调** — 设置项有 UI，不生效；Profile 表里 `speed` 字段也不在 form 里
12. **界面语言切换（中/英）** — 设置项有 UI，无 i18n 实现

---

## Review #3 — 项目整体

### 架构问题

1. **状态管理混乱** — FutureProvider（一次性）+ setState（本地）混用，ChatScreen 用 setState 试图刷新 FutureProvider 数据，根本不会刷新。需要 NotifierProvider 或 invalidation 策略
2. **`AppRouter._profileRepo = ProfileRepository()`** — 在 ProviderScope 之外又 new 了一个实例，绕过 DI，全局两份 ProfileRepository
3. **Service 每次重新 new** — `LlmService(llmProfile)` / `SttService(sttProfile)` / `TtsService(ttsProfile)` 每次调用就 new，无单例、无缓存
4. **DB 无版本迁移** — `dbVersion = 1` 没有 `onUpgrade`，下次改 schema 必然丢数据
5. **完全没有测试** — `dev_dependencies` 有 `flutter_test`，`test/` 目录不存在。agent.md §7 列了详细测试策略，0 行实现
6. **无全局错误处理** — `runApp` 没 `FlutterError.onError` / `PlatformDispatcher.instance.onError`
7. **无 loading skeleton** — chat 列表、corrections 列表 loading 时只有一个转圈
8. **无重试逻辑** — LLM/STT/TTS 失败直接弹 SnackBar，消息丢失
9. **无请求取消** — 用户切走后 LLM 响应仍会被处理，可能 setState on disposed widget
10. **Provider 不 invalidate** — onboarding 保存后 home 的 `activeSessionProvider` 不会刷新
11. **硬编码字符串** — 没有 i18n，但式样和设置都有"中/英"切换
12. **主题硬编码** — `main.dart` 写死 `themeMode: ThemeMode.dark`，设置里却有主题切换 UI
13. **TutorRepository 是 static const** — 无法扩展、无法持久化用户偏好

### 安全

1. **Google STT 把 API Key 放 URL** — `?key=${profile.apiKey}` 会被任何 HTTP 中间件日志看到
2. **错误信息泄露 response body** — `SttException('Deepgram error: ${response.statusCode} - ${response.body}')` 可能在 SnackBar 暴露敏感信息
3. **无 API key / URL 格式校验**
4. **无证书锁定**
5. **`CorrectionType.values.byName()`** 在 DB 数据损坏时直接抛异常，无 fallback

### 性能

1. **GlassCard BackdropFilter 滥用** — 每个聊天气泡、每个场景卡、每个 correction 卡都用 20px 模糊，低端机必卡
2. **无分页** — messages / corrections / sessions 一次全拉
3. **`DATE()` SQLite 函数** — 在 sqflite 上行为依平台而异，统计可能错
4. **TTS 音频无缓存** — 同一句 AI 回复每次点播放都重新合成
5. **`flutter_animate`** 在列表 item 上用 `fadeIn().slideX()` — 滚动时会反复触发

### 代码质量

1. **`print('Warning: Failed to parse corrections block: $e')`** — `llm_service.dart#L145` 用 print 不用 logger
2. **死代码** — `glass_widgets.dart` 的 `GlowButton` / `StatusPill` 没人用（`VirtualCharacter` 自己实现了 state pill）
3. **`_handleSend` 内 `setState(() {})`** — 空闭包无意义
4. **`onTap: () {}`** 多处空实现留着
5. **重复 `ScrollController` dispose 检查缺失**
6. **`_messagesProvider` 用 family** — 但保存后不 invalidate，UI 永远不刷新
7. **`widget.profileId == null ? 'New $_title' : 'Edit $_title'`** — Edit 模式下表单是空的，用户会以为是新建

---

## 改进计划（按优先级执行）

### 阶段 A：阻断性修复（必须）

A1. 修复 `RecordingService.stopRecording()` 真正读文件返回字节
A2. 修复 `_messagesProvider` 不刷新：保存后 `ref.invalidate(_messagesProvider(sessionId))`，或改用 `StreamProvider`
A3. 修复 user message 重复发送：`sendMessage` 不要再传 `userMessage`，history 已包含
A4. 修复 TTS 监听器泄漏：保存 subscription，dispose/cancel 时取消
A5. AI 回复后自动 TTS 播放 + VirtualCharacter 进入 speaking 状态

### 阶段 B：核心 UX 补全（必须）

B1. ChatBubble 渲染 corrections：红色错误词 + 绿色纠正小卡
B2. 播放图标根据 `_playingMessageId` 切换 stop/play
B3. 新消息自动滚动到底部
B4. TutorSelectionScreen 实际接入：Home 增加"切换外教"入口，选中后持久化到 user_settings，chat 时拼进 system prompt
B5. ProfileForm 编辑模式加载已有数据
B6. 接通 `LlmService.fetchModels()` 到 ProfileForm 的"Fetch available models"按钮
B7. ServiceConfig 增加：删除 profile（带确认，禁用 active）、测试连接（调一次 fetchModels 或最简请求显示延迟）
B8. ReviewScreen `_startAIReview` 把 due corrections 注入新 session 的 system prompt；`_practiceCorrection` 同理注入单个 correction
B9. Placement 改为综合 4 题评分，或保留选择题但加权计算
B10. 添加聊天历史浏览页（路由 `/history`），Home 增加"History"入口
B11. 设置弹窗接通：纠正强度、TTS 语速、主题，全部持久化到 user_settings 并生效

### 阶段 C：式样补全（应做）

C1. 振幅驱动嘴型动画：用 `just_audio` 振幅 API 驱动 VirtualCharacter 嘴型
C2. Profile 导入/导出 JSON（Key 脱敏）
C3. 场景卡增加进度标记（已练习次数 / 上次练习时间）
C4. TTS 音频本地缓存（hash 索引）
C5. Home 首次进入时若 active session 存在，弹"继续上次 / 开始新话题"选择
C6. TTS 语速在 ProfileForm 中可配置（speed 字段）
C7. 移除设置里"Interface Language"或保留 UI 但加 TODO 标注（i18n 工作量大，单独迭代）

### 阶段 D：质量与稳定性（应做）

D1. 全局错误处理（`FlutterError.onError` + `PlatformDispatcher.onError`）
D2. 网络请求重试 + 取消（用 `CancelToken` 或 `http.Client` + timeout）
D3. `mounted` 检查覆盖所有 await 后的 setState
D4. `print` 改 `debugPrint`
D5. 删死代码：未使用的 GlowButton / StatusPill（除非保留为公共组件）
D6. ChatInput 发送按钮 disabled when empty / loading
D7. Loading 期间禁用输入
D8. Loading 时显示 typing indicator（AI 头像 + 三点动画）
D9. Provider 间 invalidation 链：onboarding 完成 → invalidate activeSessionProvider；保存 profile → invalidate 对应 provider
D10. 主题接通：`main.dart` 用 `themeMode` from settings，不再硬编码 dark
D11. DB onUpgrade 占位（即使 v1 也要写好框架）
D12. 错误信息脱敏：不直接把 response.body 丢给 SnackBar

### 阶段 E：性能（应做）

E1. GlassCard 性能：列表 item 改用纯色 + 边框，只有大卡片保留 BackdropFilter
E2. 列表分页（messages/corrections/sessions limit+offset）
E3. `flutter_animate` 列表 item 用 `key` 或只在首次出现动画

### 阶段 F：测试（应做）

F1. 单测：SM-2 算法（scheduleReview 各 quality 分支）、LlmService `_extractCorrections` 解析、Correction copyWith/Serialization
F2. Widget 测：GlassCard 渲染、ChatBubble corrections 展示、SettingsScreen 交互
F3. 集成测试路径：onboarding → placement → chat（mock LLM）

### 阶段 G：多轮 Review（执行后回看）

G1. 修复完成后从"用户视角"再走一遍主流程
G2. 从"安全视角"再过一遍 API key 流转
G3. 从"性能视角"再过一遍列表渲染
G4. 从"式样视角"再核对一次完成度

---

## 执行顺序

1. 阶段 A（A1-A5）→ 跑 `flutter analyze` → 提交
2. 阶段 B（B1-B11）→ 跑 analyze → 提交
3. 阶段 C（C1-C7）→ 跑 analyze → 提交
4. 阶段 D（D1-D12）→ 跑 analyze → 提交
5. 阶段 E（E1-E3）→ 跑 analyze → 提交
6. 阶段 F（F1-F3）→ 跑 `flutter test` → 提交
7. 阶段 G：三轮自审 → 修补 → merge main → push

> 本文件为临时执行清单，全部任务完成后删除。
