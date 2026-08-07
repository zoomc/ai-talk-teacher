# SpeakFlow 项目说明

## 产品

SpeakFlow 是一个 Flutter 多端 AI 英语口语练习应用，支持 Web、iOS、Android
和 macOS。核心体验是语音转写、AI 对话、气泡内即时纠错、自动语音回复和可见的
自托管 WebGL 3D AI 外教；分层 2D painter 仅作为明确的安全/测试降级。

## 当前架构

- Flutter + Riverpod + SQLite（Web 使用 sqflite Common FFI）。
- LLM、STT、TTS 由用户配置的 Provider Profile 驱动，密钥本地安全保存。
- 3D 外教为 Three.js + TalkingHead + 本地 CC0 MPFB GLB：Web 使用同源 iframe，
  移动/桌面使用 `webview_flutter`，HeadAudio 分析真实 TTS 字节驱动口型；失败时
  回退到 Flutter 绘制角色。
- 界面语言的优先级：用户设置 > 浏览器语言（Web）> 系统语言 > 中文。
- 默认入口 `/` 是聚焦式练习准备页：展示当前 AI 老师、自由对话主题和一次主操作；旧学习仪表盘保留在 `/dashboard`，场景、历史、项目等保留为二级路由。
- 主导航收敛为练习、复习、设置三项；设置承载“我的”下的 Provider、人物、语音健康、进度、项目和数据管理入口。

## 3D 方案与性能策略

默认采用 TalkingHead 的本地 WebGL 3D runtime：模型、Three.js、HeadAudio
worklet 与 viseme 模型都随 `assets/3d/` 自托管，Web/原生 WebView 不依赖在线角色
服务。DPR capped、动态骨骼、眼神、眨眼、呼吸、情绪、语义手势和真实音频口型都在
runtime 内完成；WebGL/模型/AudioWorklet 失败时才回退到分层 2D painter。
当前 CC0 MPFB 是高质量可运行 prototype，不是 MetaHuman/电影级资产；若要达到真正
3A/film fidelity，应替换为经过授权的高模、PBR/法线/眼睛/毛发/服装资产，桥接协议不变。

生产级 Live2D 仍需要定稿原画的分层 PSD、Cubism 绑定产物（`.moc3` / motions）和
发布授权，因此当前不随仓库捆绑。
现有 TTS 振幅流与 Rhubarb 时间线接口可继续复用。

浏览器端直连 Provider 仍受 CORS、HTTPS 和密钥暴露风险约束；README 与安全威胁
模型不把“OpenAI-compatible”解释为所有服务都能从浏览器直接调用。

## 发布（阿里云）

- 线上地址：`https://zoomlab.top/talk/`（实际可用性以部署工作流健康检查为准）。
- nginx：生产 Web 位于 `/talk/`，受 Basic Auth 保护的 Demo Web 位于
  `/talk-demo/`，两者都使用独立文档根与 SPA 回退。
- 标准发布入口：`.github/workflows/deploy-aliyun.yml`。它从同一 commit 构建
  Production Web 与 Demo Web，写入 commit/mode 版本元数据，原子切换两套
  symlink，执行 nginx、入口、深链接、版本与 Demo Basic Auth 健康校验，失败时
  恢复上一版 symlink。
- Demo/E2E 仍用于本地和 CI 验证；Demo 同时作为受保护的线上测试环境部署。

部署不需要重启 nginx，因为仅更新静态资源。发布前由 workflow stamp
`build/web/version.json`；不能把本地构建或手工 rsync 当作线上发布证据。

### 必经发布校验

CI 使用 `--pwa-strategy=offline-first` 构建生产 Web `/talk/` 与 Demo Web
`/talk-demo/`，并使用独立的 E2E 构建检查运行时隔离、base-href、worker、版本
元数据和敏感代码标记。部署工作流再在服务器上检查两个公网入口；在缺少
Aliyun environment secrets 或 Demo Basic Auth 时必须报告阻塞，不得伪造健康。

## E2E 测试（Playwright + Flutter E2E Bridge）

E2E 套件位于 `e2e/`，覆盖 30 个功能点（子功能粒度）；当前 `npx playwright test --list`
 可枚举 2972 条测试执行项，分布在 32 个 spec 文件和四个浏览器项目。每个功能点不少于 20 条用例，
分 happypath / 旁支 / 异常三类。规格见 `docs/e2e-spec.md`。

### 质量提升流程

2026-07-25 进行了全量 E2E 驱动的质量提升：
1. 运行全量 E2E（chromium + mobile-chrome），双端截图保存到临时目录。
2. 分析交互/业务逻辑问题（103 条）、UI/UX 源码问题（53 条）、截图视觉问题
   （225 条）、E2E 覆盖缺口（130 条），合计 511 条统一修改点。
3. 按类别派发 subagent 实施修改，覆盖业务逻辑、UI 组件、主题、E2E 测试。
4. 重新构建并运行 E2E 回归，修复所有失败项。
5. 详细记录见 `CHANGELOG.md` 的 "E2E-driven quality improvement" 章节。

### Mock 策略：HTTP 拦截 + Dart 端 E2E Bridge（混合方案）

- **HTTP 拦截**（`e2e/lib/mock.ts`）：用 Playwright `page.route` 拦截厂商 API
  （OpenAI 兼容的 `/v1/chat/completions`、STT、TTS），返回固定 fixture 或模拟
  401/429/500/超时。
- **Flutter E2E Bridge**（`lib/core/e2e/e2e_bridge*.dart`）：仅在
  `--dart-define=E2E=true` 时编译，向 `window.speakflowE2E` 暴露 JS 钩子：
  `resetDatabase / seedChatSessions / seedMessages / seedCorrections / setMockMode /
  setMockLlmResponse / setMockSttTranscript / setMockTtsAudio / getSnapshot /
  setSetting`。测试可重置/种子 SQLite，并让 `LlmService` / STT / TTS 直接短路返回
  预置响应，零真实网络调用。
- 非 E2E 构建（正常 release）走 `e2e_bridge_stub.dart` 与 `e2e_mock_services_stub.dart`
  的 no-op 实现，对生产代码无影响。

### 双端覆盖

- **PC 端**（chromium, 1280×800）：覆盖所有 30 个功能点。
- **移动端**（mobile-chrome, Pixel 5 / 375×812）：覆盖所有 30 个功能点，包括
  路由适配、输入框交互、长文本换行、错误状态、纠错卡片、首页导航、banner 适配、
  avatar 渲染等移动端专属用例。
- **截图**：同一功能在 PC 端和移动端分别截图，文件名包含 project 后缀
  （如 `m11-hp1-happy-marker--chromium.png` / `m11-hp1-happy-marker--mobile-chrome.png`），
  便于双端视觉对比。

### 运行方式

```bash
# 1. 构建 E2E 版本的 Flutter Web（编译期隔离；旧 E2E define 仍兼容）
flutter build web --dart-define=APP_MODE=e2e --dart-define=E2E=true

# 2. 安装 Playwright 浏览器（首次）
cd e2e && npx playwright install chromium

# 3. 跑 E2E Simulation smoke（webServer 会自动起 start-server.mjs）
npm run test:simulation
npm run test:simulation:responsive  # chromium + mobile-chrome

# 旧的 provider/onboarding UI 规格保留在 specs/，需要 production-like
# 测试构建后再运行，不能对 APP_MODE=e2e 的 profile-free 构建宣称通过。
npm test            # 历史全量规格；不作为 APP_MODE=e2e 的 CI gate
npm run test:all    # 两个浏览器全跑
npm run test:fast   # 仅 chromium + list reporter
npm run test:mobile # 仅 mobile-chrome（Pixel 5 视口）
```

### 验证项

- `npm run typecheck`（`tsc --noEmit`）必须 0 错误。
- `npx playwright test --list` 应枚举 1476 条用例 / 30 个文件。
- 失败用例自动保留 trace / screenshot / video 于 `e2e/test-results/`。
- 每个页面至少一条 screenshot + 元素断言用例，用于人工 review 渲染质量。

### 旧套件

`e2e/legacy/` 保留旧 E2E 用例，默认 `testMatch` 已排除；如需运行：
`npm run test:legacy`。
