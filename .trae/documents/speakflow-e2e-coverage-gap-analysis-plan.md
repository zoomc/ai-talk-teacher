# SpeakFlow E2E 覆盖率缺口分析执行计划

## 1. Summary（任务概述）

本任务要求对 `/workspace/e2e/specs/` 下的端到端测试套件进行系统性覆盖率审查，识别桌面端与移动端视口、关键用户旅程、截图验证等方面的缺口，并将至少 100 条具体、可执行的发现写入 `/tmp/speakflow-e2e-run/e2e-coverage-gaps.md`。文档需使用中文，每条发现包含模块/功能、缺口描述、受影响视口、建议测试新增/修改、优先级。

## 2. Current State Analysis（现状分析）

### 2.1 测试套件结构
- 配置文件：`/workspace/e2e/playwright.config.ts`
  - 定义了 4 个项目：chromium（1280×800）、firefox（1280×800）、webkit（1280×800）、mobile-chrome（375×812，Pixel 5）
  - 实际 spec 中视口由 `setupE2EApp` / `setupEmptyApp` 控制，默认均为 `DESKTOP_VIEWPORT`
- 工具函数：`/workspace/e2e/lib/setup.ts` 暴露 `DESKTOP_VIEWPORT`（1280×800）与 `MOBILE_VIEWPORT`（375×812）
- 截图工具：`/workspace/e2e/lib/screenshots.ts`
  - `capture()` 仅截取当前视口
  - `captureAtViewport()` 可在指定视口截图
  - `captureDesktopAndMobile()` 可一次性截取双视口，但**整个 specs 目录未调用过**
- spec 分布：
  - avatar：emotion、idle、lip-sync（3 个）
  - chat：continuous-mode、corrections、error-states、session-management、text-messaging、tts-playback、tutor-summary、voice-input（8 个）
  - home：ability-goals、daily-plan、dashboard、streak（4 个）
  - onboarding：onboarding、placement（2 个）
  - profile：llm-crud、service-config、stt-crud、tts-crud、voice-health（5 个）
  - progress：dashboard、pronunciation-history（2 个）
  - projects：projects（1 个）
  - review：sm2-review（1 个）
  - scenarios：scenarios（1 个）
  - settings：app-section、theme-language（2 个）
  - system：banners-version（1 个）
  共 30 个 spec 文件。

### 2.2 已识别的关键模式
1. **默认桌面视口**：所有 `beforeEach` 调用 `setupE2EApp(...)` 时未传 `viewport`，导致每个 test 初始渲染为 1280×800。
2. **移动端覆盖极少**：
   - 仅 `chat/session-management.spec.ts`（BR-14）和 `profile/voice-health.spec.ts`（BR-12）显式调用 `page.setViewportSize(MOBILE_VIEWPORT)`。
   - `home/dashboard.spec.ts` 使用 `captureAtViewport` 验证 iPad 与 iPhone SE，但未使用项目标准 `MOBILE_VIEWPORT`。
   - 大量 spec 虽 import 了 `MOBILE_VIEWPORT`，但实际未使用。
3. **双视口截图工具未被使用**：`captureDesktopAndMobile` 仅定义，未在 spec 中调用。
4. **部分测试未截图**：大量分支/异常路径（如 BR-9、BR-10、EX 等）未调用 `capture()`，或仅在 happy path 截图。
5. **缺少关键旅程 E2E**：如首次安装全流程（cold launch → onboarding → placement → home → first chat）、设置变更后返回聊天、离线恢复、跨模块数据一致性等。
6. **移动端特有交互缺失**：
   - 聊天中的底部输入栏/键盘弹出
   - 头像/表情在窄屏下的裁切
   - 场景卡片列表横向滚动
   - 项目卡片/复习卡片在小屏下的布局
   - 设置页底部 sheet/picker

## 3. Proposed Changes / Execution Plan（执行计划）

### 3.1 信息补齐（执行时读取）
在生成最终报告前，完整读取以下尚未细读的文件，确保每条发现基于实际代码而非推测：
1. `/workspace/e2e/specs/avatar/idle.spec.ts`
2. `/workspace/e2e/specs/avatar/lip-sync.spec.ts`
3. `/workspace/e2e/specs/chat/corrections.spec.ts`
4. `/workspace/e2e/specs/chat/error-states.spec.ts`
5. `/workspace/e2e/specs/chat/session-management.spec.ts`
6. `/workspace/e2e/specs/chat/tts-playback.spec.ts`
7. `/workspace/e2e/specs/chat/tutor-summary.spec.ts`
8. `/workspace/e2e/specs/home/ability-goals.spec.ts`
9. `/workspace/e2e/specs/home/streak.spec.ts`
10. `/workspace/e2e/specs/profile/stt-crud.spec.ts`
11. `/workspace/e2e/specs/progress/pronunciation-history.spec.ts`
12. `/workspace/e2e/fixtures/fixtures.ts`（了解 fixture 数据，判断哪些 journey 可被 seed）

### 3.2 发现的生成策略
为确保至少 100 条、覆盖用户要求的 8 个维度，按以下维度逐模块拆解：

#### 维度 A：桌面有覆盖但移动端无覆盖的模块
对每个 spec 文件，若其 `beforeEach` 未传 `viewport: MOBILE_VIEWPORT` 且文件内无 `page.setViewportSize(MOBILE_VIEWPORT)`，则生成 1 条“模块级移动端缺失”发现。每个 spec 中关键 happy path 再单独生成 1-3 条。

#### 维度 B：单视口验证的用户流
对每个跨页面/跨模块流程（如 onboarding → placement → home → chat → review → progress），若未在双视口下验证，生成 1 条。

#### 维度 C：缺失的重要旅程 E2E
结合产品功能与现有测试，识别以下旅程缺口：
- 冷启动 → onboarding → placement → home
- 设置所有服务配置后首次聊天
- 离线 → 在线恢复后的连续对话
- 跨设备/跨标签页状态同步
- 升级 banner 触发与安装流程
- 项目与场景的关联使用
- 语音健康检查失败后的引导

#### 维度 D：Avatar 移动端缺口
- 表情切换在 375×812 下渲染
- 头像 Canvas 在 iPhone SE（320×568）不裁剪
- 等待/思考状态在小屏下的位置
- TTS 口型与表情同步在移动端的性能

#### 维度 E：Chat 移动端缺口
- 文字输入模式下键盘弹起对输入栏的影响
- 语音模式下 72px 录音按钮在窄屏可点击
- 连续模式 chip 在底部栏的换行/截断
- 纠错卡片在移动端的折叠/展开
- TTS 播放控制在小屏位置
- 会话列表/空状态在移动端

#### 维度 F：Onboarding / Placement / Scenarios / Review / Settings / Profile 移动端缺口
- 向导各步骤在移动端的表单布局
- placement 雷达图在小屏下的可读性
- 场景卡片网格 → 列表切换
- 复习评分按钮在小屏可点击
- 设置中的 dialog/sheet 在移动端不超出屏幕
- 服务配置三段式列表在移动端滚动
- 个人资料表单的底部按钮不遮挡输入

#### 维度 G：应截图但未截图的测试
扫描所有 spec，标记未调用 `capture()` / `captureFullPage()` / `captureAtViewport()` / `captureDesktopAndMobile()` 的测试用例，尤其是那些涉及 UI 状态变化（主题、语言、错误、加载、空状态）的用例。

#### 维度 H：应验证双视口但仅验证单视口的测试
- 主题/语言切换类测试
- 布局响应式测试
- 空状态/错误状态
- 关键 happy path
- 涉及 Canvas/图表渲染的测试

### 3.3 报告结构
输出文件：`/tmp/speakflow-e2e-run/e2e-coverage-gaps.md`

文件结构：
```markdown
# SpeakFlow E2E 覆盖率缺口报告

> 生成时间：2026-07-25
> 审查范围：/workspace/e2e/specs/
> 发现总数：≥100

## 摘要
（按模块与维度统计缺口数量）

## 详细发现

### 1. [模块/功能]
- **缺口描述**：...
- **受影响视口**：desktop / mobile / both
- **建议测试新增/修改**：...
- **优先级**：high / medium / low

### 2. ...
```

### 3.4 优先级定义
- **high**：核心用户旅程、移动端崩溃风险、关键功能（chat、onboarding、profile 配置）无覆盖。
- **medium**：重要分支/边界、截图缺失、非核心模块移动端覆盖。
- **low**：文案/细节验证、已有部分覆盖但可补强。

## 4. Assumptions & Decisions（假设与决策）

1. **不修改任何现有代码**：本次任务仅输出报告，不在 plan 阶段或执行阶段修改 spec 文件（除非后续接到明确指令）。
2. **以代码静态审查为主**：基于现有 spec 与配置文件判断缺口，不实际运行 Playwright。
3. **移动端视口标准**：以 `playwright.config.ts` 中 `mobile-chrome` 的 375×812 为准，同时参考 iPhone SE 320×568 作为最小屏幕。
4. **“应截图”判断标准**：凡涉及 UI 渲染、状态变化、错误/空状态、主题语言切换、布局响应式的测试，均建议补充截图。
5. **100 条为下限**：通过按模块 × 维度矩阵拆解，预计可生成 110-130 条互不重复的发现。
6. **中文输出**：报告正文使用中文，代码路径/函数名保留英文。

## 5. Verification Steps（验证步骤）

1. 报告生成后，使用 `wc -l` 与搜索 `^### \d+\.` 确认条目数 ≥ 100。
2. 检查每条发现是否包含：模块/功能、缺口描述、受影响视口、建议、优先级。
3. 检查文档语言为中文。
4. 检查报告已写入 `/tmp/speakflow-e2e-run/e2e-coverage-gaps.md`。
5. 可选：随机抽取 10 条发现与对应 spec 文件核对，确保描述与代码一致。
