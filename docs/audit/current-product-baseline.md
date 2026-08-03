# 当前产品基线

核查日期：2026-08-04
代码基线：`main` / `9cb74e2`（与 `origin/main` 一致；本轮中断与生命周期修复尚未提交）

## 结论摘要

- 远端同步后代码基线为 `9cb74e2`；`flutter analyze` 0 errors，剩余问题均为既有兼容性/弃用提示。
- 基线的 2 个 `SkillMasteryService` 评分失败已修复：reviewCount 5–7 使用 90 分，reviewCount ≥8 才是 100 分，时间衰减测试也恢复通过。
- 当前默认路径是 `/` → `PracticeHomePage`：直接展示 AI 老师、当前人物、自由对话主题和开始按钮；原 `HomePage` 仪表盘保留在 `/dashboard`。
- 当前主导航收敛为 3 项：练习、复习、设置（“我的”由设置及其二级入口承载）；场景/历史/项目保留为二级入口。
- 当前真实 Avatar 主流程是 `PracticeHomePage/ChatScreen → AvatarStage → VirtualCharacter3D → painter fallback`。`assets/3d/avatar.html` 是 Three.js + GLB iframe/WebView 管线，低带宽或加载失败时不阻塞练习。
- API Key 的 SQLite 字段只写入 `***stored***`，真实值由 `flutter_secure_storage` 保存；Web 端仍属于浏览器端密钥，不能等同于原生 Keychain。
- 本轮补强了处理态取消、turn token 的持久化边界、filler TTS 生命周期、permission/completed
  语义和 Three.js Avatar 姿态复位；最终提交以测试报告中的 commit 为准。

## 路由与页面地图

### 一级入口（当前）

| 入口 | 路径 | 当前用途 | 处理决定 |
|---|---|---|---|
| 练习 | `/`、`/chat/:sessionId` | 仪表盘与对话 | Keep；`/` 改成 AI 老师对话准备页 |
| 场景 | `/scenarios` | 场景选择 | Merge；从对话准备页或会话选项进入 |
| 复习 | `/review` | SM-2 纠错复习 | Keep；主入口 |
| 项目 | `/projects` | 项目空间 | Hide；保留数据与二级路由 |
| 设置 | `/settings` | 配置、外观、内容、数据 | Merge 为“我的”；仍保留二级配置页 |

### 二级入口

`/onboarding`、`/placement`、`/chat/:sessionId`、`/summary/:sessionId`、`/practice`、`/history`、`/pronunciation/:sessionId`、`/tutor-selection`、`/service-config`、`/profile-form/:type`、`/voice-health`、`/projects`、`/project/:projectId`、`/progress`。

### 主要跳转

```text
冷启动
  ├─ 未完成 onboarding → /onboarding → /placement（可跳过）
  └─ 已完成 → /（AI 老师准备页；完整仪表盘保留在 /dashboard）

准备页 → 创建 ChatSession → /chat/:sessionId
场景选择 → 创建带 scenarioId 的 ChatSession → /chat/:sessionId
会话结束 → /summary/:sessionId → /review
纠错保存 → review_queue → /review → SM-2 评分更新
设置 → /service-config / /tutor-selection / /voice-health / /history / /projects
```

新用户当前至少需要：完成 onboarding（可跳过部分 Provider）→ placement（可跳过）→ 打开准备页→点击开始对话。老用户打开后即可看到老师与主题，并在一次主操作后进入会话。

## 功能清单

| 功能 | 决定 | 理由与兼容要求 |
|---|---|---|
| Chat / 语音 / TTS | Keep | 核心闭环；必须优先保证中断、失败重试、资源释放 |
| Avatar | Keep | 是产品差异化；3D 失败仍需 painter/字幕降级 |
| 纠错气泡与保存 | Keep | 真实错误进入复习队列，不能只做展示 |
| Session summary | Keep | 对话结束后的集中总结入口 |
| Review / SM-2 | Keep | 学习闭环的第二阶段 |
| Scenarios | Merge | 场景是对话准备的一部分，不占一级导航 |
| Tutor selection | Merge | 进入会话前或“我的”里选择 |
| History | Merge | “我的”/会话历史二级入口，数据保留 |
| Pronunciation | Merge | 从会话纠错或“我的”进入 |
| Dashboard / 今日任务 | Hide | 统计与任务保留数据和服务，但不阻挡冷启动 |
| Ability radar | Hide | 降为进度详情，不作为默认主视觉 |
| Projects | Hide | 项目数据和 Repository 保留，暂不占一级导航 |
| Provider / Service config | Merge | 归入“我的”；保持自带 API 配置 |
| PWA install/update | Keep | 只缓存应用壳，不缓存 Key、Authorization 或动态 AI 请求 |

## 技术地图

- Flutter + Riverpod + GoRouter；应用启动逻辑在 `lib/main.dart`，路由在 `lib/core/router/app_router.dart`。
- 对话 UI 在 `ChatScreen`，消息通过 `messagesProvider` 读取 `ChatRepository`；LLM 支持 SSE 流式读取，STT/TTS 走用户配置的 Provider Profile。
- 音频：`RecordingService` 负责录音；`TtsPlaybackService` 负责缓存、播放、振幅流、停止；`ChatScreen` 监听播放器完成事件并更新 Avatar。
- Avatar：`AvatarStage` 维护 idle/emotion/viseme 时间线；`VirtualCharacter` 是 Flutter painter fallback；`VirtualCharacter3D` 负责 Web `HtmlElementView` 与移动/桌面 WebView；`assets/3d/avatar.html` 使用 Three.js `GLTFLoader` 加载 Ready Player Me GLB。
- 数据：`DatabaseHelper` v10 创建/迁移 SQLite 表；Repository 分布在 chat、profile、home、project_space 等 feature。
- API Key：profile metadata 在 SQLite；真实 Key 通过 `SecureStorageService` 写入 `flutter_secure_storage`。
- PWA：`web/manifest.json`、`web/index.html`、`version_check.js`、Flutter 生产构建生成的 `flutter_service_worker.js`。版本检查与 SW waiting 通过 JS bridge 暴露给 Dart。
- 测试：Dart unit/widget tests；`e2e/` 为 Playwright + Flutter E2E bridge，支持 Chromium/mobile-chrome 和 HTTP/Dart mock。

## 数据兼容表

| 数据 | 当前存储 | 本次策略 |
|---|---|---|
| Provider metadata | `llm_profiles` / `stt_profiles` / `tts_profiles` | 必须兼容；保留 provider_id/base_url/model/voice 等字段 |
| API Key | secure storage；SQLite 仅 placeholder | 必须兼容；任何导出都只允许 mask，永不写入构建物、URL、日志或 SW cache |
| 对话历史 | `chat_sessions` / `chat_messages` | 必须兼容；路由和导航调整不得删除 |
| 纠错记录 | `corrections` | 必须兼容；继续保存 session/message 关联 |
| 复习数据 | `review_queue`、SM-2 字段、`practice_log` | 必须兼容；修正评分实现与旧测试一致 |
| 学习进度 | `skill_mastery`、`user_goal`、placement JSON | 保留；从默认首页移到进度/我的二级入口 |
| 人物设置 | `selected_tutor_id`、teacher persona | 必须兼容；准备页读取当前人物 |
| 场景数据 | `scenarios`、`scenario_items`、session.scenario_id | 必须兼容；场景页降为二级 |
| 项目空间 | `projects`、links、activities | 必须兼容；隐藏一级入口但不删数据 |

## 基线阶段门结论

已找到完整路由、对话、音频、Avatar、Provider、SQLite、PWA 和测试入口；首页与主导航已完成收敛，所有旧路由和数据表仍保留兼容入口。
