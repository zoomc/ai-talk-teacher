# SpeakFlow 项目说明

## 产品

SpeakFlow 是一个 Flutter 多端 AI 英语口语练习应用，支持 Web、iOS、Android
和 macOS。核心体验是语音转写、AI 对话、气泡内即时纠错、自动语音回复和可见的
分层 2D AI 外教；3D 角色保留为实验路径。

## 当前架构

- Flutter + Riverpod + SQLite（Web 使用 sqflite Common FFI）。
- LLM、STT、TTS 由用户配置的 Provider Profile 驱动，密钥本地安全保存。
- 3D 实验外教为 Three.js + Ready Player Me GLB：Web 使用同源 iframe，移动/桌面
  使用 `webview_flutter`，TTS 振幅驱动口型；失败时回退到 Flutter 绘制角色。
- 界面语言的优先级：用户设置 > 浏览器语言（Web）> 系统语言 > 中文。
- 默认入口 `/` 是聚焦式练习准备页：展示当前 AI 老师、自由对话主题和一次主操作；旧学习仪表盘保留在 `/dashboard`，场景、历史、项目等保留为二级路由。
- 主导航收敛为练习、复习、设置三项；设置承载“我的”下的 Provider、人物、语音健康、进度、项目和数据管理入口。

## 3D 方案与性能策略

默认采用 `LayeredTutorAvatar` 的本地 2D 分层 painter：不依赖模型下载、WebGL、
持续 GPU 或未核准素材，可在手机和离线 Demo 中稳定显示。它单独控制身体、手臂、
头发、眼睛、眉毛、脸颊和嘴部；Rhubarb/振幅没有数据时仍可用文本驱动的口型降级。
Ready Player Me GLB + Three.js 仅在隐藏 Avatar Lab 中用于对比；后续如要将其变为
生产默认，必须先完成资产商业许可、移动 FPS/内存和离线失败证据。

生产级 Live2D 仍需要定稿原画的分层 PSD、Cubism 绑定产物（`.moc3` / motions）和
发布授权，因此当前不随仓库捆绑。
现有 TTS 振幅流与 Rhubarb 时间线接口可继续复用。

浏览器端直连 Provider 仍受 CORS、HTTPS 和密钥暴露风险约束；README 与安全威胁
模型不把“OpenAI-compatible”解释为所有服务都能从浏览器直接调用。

## 发布（阿里云）

- 线上地址：`https://zoomlab.top/talk/`（实际可用性以部署工作流健康检查为准）。
- nginx：生产和受 Basic Auth 保护的 Demo 使用两个独立 location 与文档根，
  各自启用 SPA 回退。
- 标准发布入口：`.github/workflows/deploy-aliyun.yml`。它从同一 commit 构建
  Production 与 Demo，写入 commit/mode 版本元数据，原子切换 symlink，执行
  `nginx -t`、入口/深链接/version/Basic Auth 校验，失败时恢复上一版 symlink。
  Demo 路径由 GitHub repository variable `DEMO_PATH` 提供，不能用查询参数冒充
  隔离环境。

部署不需要重启 nginx，因为仅更新静态资源。发布前由 workflow stamp
`build/web/version.json`；不能把本地构建或手工 rsync 当作线上发布证据。

### 必经发布校验

CI 先使用 `--pwa-strategy=offline-first` 构建 `/talk/` 与 Demo，使用
`--pwa-strategy=none` 构建根路径 E2E，随后检查 base-href、worker、版本元数据、
运行模式隔离和敏感代码标记。部署工作流再在服务器上检查公网入口；在缺少
`DEMO_PATH` 或 Aliyun environment secrets 时必须报告阻塞，不得伪造健康。

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
