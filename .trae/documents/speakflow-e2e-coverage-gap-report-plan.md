# SpeakFlow E2E 覆盖缺口报告执行计划

## 1. Summary
读取 `/workspace/e2e/` 下全部 Playwright 配置与 spec，生成一份不少于 100 条编号发现的 E2E 覆盖缺口报告，写入 `/tmp/speakflow-e2e-run/e2e-coverage-gaps.md`。报告以中文撰写，每条发现包含：模块/功能、缺口描述、受影响视口（desktop/mobile/both）、建议补测/修改、优先级（high/medium/low）。重点聚焦：移动端视口覆盖缺失、截图捕获缺失、双视口验证缺失、happy-path 旅程缺失、错误态覆盖缺失、Avatar/Chat 移动端缺口。

## 2. Current State Analysis（基于 Phase 1 探索）

### 2.1 配置与基础设施
- `/workspace/e2e/playwright.config.ts` 定义了 4 个项目：chromium/firefox/webkit（均为 1280×800）和 mobile-chrome（375×812，isMobile/hasTouch）。
- `use.screenshot` 为 `only-on-failure`，`trace` 为 `on-first-retry`。
- `/workspace/e2e/lib/setup.ts` 中 `setupE2EApp`/`setupEmptyApp` 默认使用 `DESKTOP_VIEWPORT`（1280×800）；`MOBILE_VIEWPORT`（375×812）常量已导出但极少被显式调用。
- `/workspace/e2e/lib/screenshots.ts` 提供 `capture`、`captureFullPage`、`captureAtViewport`、`captureDesktopAndMobile`；但多数 spec 仅调用 `capture(page, name)`，未做移动端显式截图或双视口对比。

### 2.2 已审查 Spec 的覆盖特点
- **chat/text-messaging.spec.ts (M03)**：27 个用例，覆盖文本发送、流式回复、纠错、TTS、异常状态等，但全部默认桌面视口，未使用 `captureAtViewport`/`captureDesktopAndMobile`。
- **chat/voice-input.spec.ts (M04)**：27 个用例，覆盖按住录音、STT 纠错、权限、连续模式等；同样未针对 375×812 做 mic 按钮可见性、触摸按住、小屏布局断言。
- **chat/error-states.spec.ts (M09)**：25 个用例，覆盖 LLM/STT/TTS 错误、重试、脱敏等；未在 mobile-chrome 下验证错误 snackbar 是否被遮挡、重试按钮是否可点击。
- **avatar/idle.spec.ts (M10)**：23 个用例，验证 canvas 渲染与动画稳定性；未在移动端验证 AvatarStage 在小视口下的尺寸、是否被输入栏遮挡。
- **home/dashboard.spec.ts (M18)**：少数使用 `captureAtViewport` 测试 iPad/iPhone SE 的 spec，但缺少与 mobile-chrome 项目的系统化双视口断言。
- **profile/stt-crud.spec.ts (M14)**、**profile/llm-crud.spec.ts (M13)**：导入 `DESKTOP_VIEWPORT`/`MOBILE_VIEWPORT` 但未实际传入 `setupE2EApp` 的 `viewport` 选项。

### 2.3 已识别的高频缺口模式
1. **移动端覆盖缺口**：几乎所有 spec 的 `beforeEach` 不设置 `viewport: MOBILE_VIEWPORT`，导致 mobile-chrome 项目虽然存在，但测试逻辑并未针对小屏做断言。
2. **截图捕获缺口**：大量 `capture(page, name)` 未区分视口；失败时截图由 Playwright 自动生成，但成功路径缺少移动端基线截图。
3. **双视口验证缺口**：`captureDesktopAndMobile` 仅在极少数 spec 使用，缺少“同一功能在桌面和移动端并排截图+断言”的用例。
4. **Happy-path 旅程缺口**：缺少跨模块端到端旅程，例如：Home → Start Conversation → Voice Input → Correction → Tutor Summary → Session Archive。
5. **错误态覆盖缺口**：错误用例多在桌面验证，未覆盖移动端的错误提示布局、toast 遮挡、可恢复性。
6. **Avatar/Chat 移动端缺口**：未验证移动设备下头像 canvas 与聊天输入栏的层叠、软键盘弹出对头像的影响、触摸按住录音与头像说话的同步。

## 3. Proposed Changes
本次任务**只生成报告文件**，不修改 `/workspace/e2e/` 下任何代码。执行步骤如下：

### Step 1：完整读取剩余 Spec（Read-only）
对 Phase 1 未完整读取的 spec 进行批量读取，确保每个模块至少被审阅：
- `/workspace/e2e/specs/chat/session-management.spec.ts`
- `/workspace/e2e/specs/chat/continuous-mode.spec.ts`
- `/workspace/e2e/specs/chat/corrections.spec.ts`
- `/workspace/e2e/specs/chat/tts-playback.spec.ts`
- `/workspace/e2e/specs/chat/tutor-summary.spec.ts`
- `/workspace/e2e/specs/avatar/emotion.spec.ts`
- `/workspace/e2e/specs/avatar/lip-sync.spec.ts`
- `/workspace/e2e/specs/home/daily-plan.spec.ts`
- `/workspace/e2e/specs/home/ability-goals.spec.ts`
- `/workspace/e2e/specs/home/streak.spec.ts`
- `/workspace/e2e/specs/onboarding/onboarding.spec.ts`
- `/workspace/e2e/specs/onboarding/placement.spec.ts`
- `/workspace/e2e/specs/profile/tts-crud.spec.ts`
- `/workspace/e2e/specs/profile/service-config.spec.ts`
- `/workspace/e2e/specs/profile/voice-health.spec.ts`
- `/workspace/e2e/specs/progress/dashboard.spec.ts`
- `/workspace/e2e/specs/progress/pronunciation-history.spec.ts`
- `/workspace/e2e/specs/review/sm2-review.spec.ts`
- `/workspace/e2e/specs/scenarios/scenarios.spec.ts`
- `/workspace/e2e/specs/projects/projects.spec.ts`
- `/workspace/e2e/specs/settings/theme-language.spec.ts`
- `/workspace/e2e/specs/settings/app-section.spec.ts`
- `/workspace/e2e/specs/system/banners-version.spec.ts`

### Step 2：按维度建立缺口清单
对每个 spec，从以下 6 个维度记录具体缺口：
1. **Mobile viewport**：是否显式设置 `MOBILE_VIEWPORT` 或依赖 mobile-chrome project；小屏下的关键元素可见性、可点击性、布局断言是否存在。
2. **Screenshot capture**：成功路径是否截图；是否按视口命名（如 `--mobile-chrome`）；是否使用 `captureFullPage` 捕获滚动内容。
3. **Dual-viewport verification**：是否在同一场景下对桌面和移动端分别断言/截图。
4. **Happy-path journey**：是否覆盖从入口到核心价值的完整用户旅程，而非单点功能。
5. **Error-state coverage**：网络异常、权限异常、服务端错误、空状态、边界输入在桌面和移动端是否有独立断言。
6. **Avatar/Chat mobile**：Avatar 渲染、说话/思考/情绪状态、语音输入、纠错卡片在移动端是否被验证。

### Step 3：撰写报告（Write）
- 目标文件：`/tmp/speakflow-e2e-run/e2e-coverage-gaps.md`
- 格式：Markdown，编号列表 ≥100 条。
- 每条字段：
  - **模块/功能**：如 `M03 Chat / 文本消息发送`
  - **缺口描述**：具体缺失了什么覆盖
  - **受影响视口**：desktop / mobile / both
  - **建议测试补全/修改**：可执行的用例或断言建议
  - **优先级**：high / medium / low
- 分组：按模块（Onboarding、Chat、Avatar、Home、Profile、Progress、Review、Settings、System）组织，便于阅读。
- 数量保底：确保编号从 1 到至少 100，优先填满用户指定的 6 大焦点领域。

### Step 4：自校验
- 使用 `Read` 工具回读生成的报告文件，确认：
  - 文件路径正确；
  - 编号连续且无重复；
  - 每条包含 5 个 required 字段；
  - 总条数 ≥100；
  - 语言为中文。

## 4. Assumptions & Decisions
- **不修改代码**：任务仅为分析报告，不新增/修改 spec 或 helper。
- **不运行测试**：不需要启动 Flutter 服务或执行 Playwright，仅做静态审查。
- **输出目录**：`/tmp/speakflow-e2e-run/` 若不存在则创建；该目录在 `/tmp` 下，符合用户“不要写到 `/workspace/.trae/documents/`”的要求。
- **优先级判定原则**：
  - high：影响核心用户旅程、可能在生产环境造成回归、移动端独有缺陷难以在桌面复现。
  - medium：重要但已有部分覆盖，或可在现有用例中扩展断言。
  - low：边缘布局、文档化截图、增强型双视口基线。
- **截图缺口判定**：凡是用例中仅调用 `capture(page, name)` 且未在移动端显式截图，均视为“缺少移动端截图/双视口验证”。

## 5. Verification Steps
1. 读取 `/tmp/speakflow-e2e-run/e2e-coverage-gaps.md` 全文。
2. 统计 `^[0-9]+\.` 样式的条目数，确认 ≥100。
3. 随机抽查 10 条，确认包含“模块/功能、缺口描述、受影响视口、建议测试补全/修改、优先级”。
4. 最终向用户报告：发现总数 + 输出文件绝对路径。
