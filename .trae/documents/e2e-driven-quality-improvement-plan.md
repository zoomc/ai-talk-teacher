# E2E 驱动全量品质提升计划

## 摘要

本计划通过“运行 E2E → 双端截图 → 交互/视觉分析 → 集中修改 → 回归测试 → 合并发布”的闭环，对 SpeakFlow 进行一轮全流程品质提升。重点覆盖：

- **双端适配**：桌面端（chromium 1280×800）+ 移动端（mobile-chrome Pixel 5 375×812）。
- **AI 虚拟人物**：渲染、动画、口型、表情、动作自然度与美观度。
- **聊天界面**：对话流程、交互细节、业务逻辑自洽性。
- **产物**：修改后的 Flutter 源码、补全后的 E2E 用例、更新的 `project.md` 与 `CHANGELOG.md`。

范围确认：修改应用源码 + E2E 测试 + 文档；使用 subagent 并行处理截图视觉分析与部分修改任务。

---

## 当前状态分析

### 代码库

- **分支**：已位于 `main`，且与 `origin/main` 同步（`git status` 显示 working tree clean）。
- **项目类型**：Flutter 多端应用（Web/iOS/Android/macOS），主要验证 Web E2E。
- **E2E 位置**：`/workspace/e2e/`，基于 Playwright + TypeScript。
- **E2E 规模**：30 个 spec 文件，717 条独立用例，配置 4 个浏览器项目（chromium/firefox/webkit/mobile-chrome），全量共 2868 次执行。
- **构建要求**：必须先执行 `flutter build web --dart-define=E2E=true` 生成 `build/web/`，`start-server.mjs` 会托管该目录。
- **截图基础设施**：已存在 `e2e/lib/screenshots.ts`（`capture` / `captureFullPage` / `captureElement` / `captureAtViewport`），默认保存到 `e2e/screenshots/`。
- **关键文件**：
  - `e2e/playwright.config.ts`：配置浏览器项目、webServer、trace/video/screenshot 策略。
  - `e2e/lib/setup.ts`：`setupE2EApp` / `setupEmptyApp` 统一重置 DB、seed fixture、启用 mock。
  - `e2e/helpers.ts`：Flutter hash 路由导航、等待、点击等基础 helper。
  - `project.md`：项目说明文档。
  - `CHANGELOG.md`：大写的变更日志（用户原需求中的 `changelog.md` 实际对应 `CHANGELOG.md`）。

### 环境缺口

- 当前 sandbox 没有 Flutter/Dart 工具链，无法直接构建。计划第一步需安装 Flutter 3.44.4 + Dart 3.12.2（与 `pubspec.yaml` 中 `sdk: ^3.12.2` 及 CHANGELOG 历史一致）。
- Playwright 浏览器可能也未安装，需执行 `npx playwright install chromium`（若跑双端则同时装 chromium 所需依赖）。

### E2E 双端覆盖现状

- `playwright.config.ts` 已同时定义 `chromium`（桌面）和 `mobile-chrome`（Pixel 5），但现有 spec 中显式使用 `captureAtViewport` 做响应式截图的较少。
- 多数测试直接调用 `capture(page, name)`，只记录当前项目默认视口下的截图；因此同一条用例在 chromium 和 mobile-chrome 下会分别产生同名文件覆盖（因为 `screenshots.ts` 用固定文件名）。
- 需要增强截图命名，使其带上项目名，保证双端截图共存。

---

## 实施计划

### Phase 0 — 环境与基线准备

**目标**：让 E2E 可构建、可运行、可截图，且双端截图不互相覆盖。

1. **安装 Flutter 工具链**
   - 安装 Flutter 3.44.4 + Dart 3.12.2（使用 `git clone` 官方 stable 分支或下载 tar）。
   - 运行 `flutter doctor --android-licenses`（如需要）并配置 PATH。
   - 验证：`flutter --version` 与 `dart --version`。

2. **安装 Playwright 依赖**
   - 进入 `e2e/` 目录，执行 `npm install`。
   - 执行 `npx playwright install chromium`（mobile-chrome 复用 chromium 二进制）。

3. **构建 E2E 版本 Flutter Web**
   - 在项目根目录执行：
     ```bash
     flutter build web --dart-define=E2E=true
     ```
   - 确认产物目录 `build/web/` 存在且包含 `index.html`、`main.dart.js`、`flutter_bootstrap.js`。

4. **增强截图命名以支持双端**
   - 修改文件：`e2e/lib/screenshots.ts`
   - 在 `capture` / `captureFullPage` / `captureElement` 中读取 Playwright 项目名（通过传入 `project.name` 或在 test 上下文中拼接），让文件名形如 `m18-hp1-home-render--chromium.png` 与 `m18-hp1-home-render--mobile-chrome.png`。
   - 或者新增 `captureForProject(page, name)` 包装，默认根据 `testInfo.project.name` 拼接。
   - 新增 `captureMobile` / `captureDesktop` 便捷函数，确保同一个功能的双端截图都能在 `e2e/screenshots/` 下共存。

5. **确认 webServer 与 baseURL**
   - 保持 `e2e/playwright.config.ts` 中的 `webServer` 配置不变；运行 `cd e2e && npx playwright test --list --project=chromium --project=mobile-chrome` 枚举用例，确认双端都能列出约 1434 条测试。

### Phase 1 — 全量 E2E 执行与双端截图

**目标**：运行所有 E2E，产生完整的双端截图和测试日志。

1. **运行全量 E2E**
   - 命令：
     ```bash
     cd e2e && npx playwright test --project=chromium --project=mobile-chrome --reporter=list
     ```
   - 预期耗时：30–120 分钟（取决于 sandbox 性能与测试稳定性）。
   - 启用 trace/video on failure（已配置），失败用例保留在 `e2e/test-results/`。

2. **运行中截图保存到临时目录**
   - 测试内部调用 `capture` / `captureFullPage` 产生的截图统一保存到 `e2e/screenshots/`。
   - 在整个运行结束后，将 `e2e/screenshots/` 与 `e2e/test-results/` 复制到 `/tmp/speakflow-e2e-run-<timestamp>/`，作为后续视觉分析的输入。

3. **记录运行日志**
   - 保存 stdout/stderr 到 `/tmp/speakflow-e2e-run-<timestamp>/e2e-run.log`。
   - 保存 `playwright-report/`（HTML 报告）到同目录。

4. **失败用例处理**
   - 对失败的用例先不立即修复，先记录失败场景；后续 Phase 8 回归时统一处理。
   - 若失败率过高（>10%），先暂停并分析是否为环境/构建问题。

### Phase 2 — 交互与业务逻辑分析（≥200 条）

**目标**：基于 E2E 运行过程、截图、trace、console 日志，找出交互/动画/业务逻辑不合理、体验差、可改善的点。

1. **主 agent 负责主导分析**
   - 逐模块阅读 E2E spec 与对应源码，结合截图与 trace：
     - `lib/features/chat/presentation/screens/chat_screen.dart`
     - `lib/widgets/chat/chat_bubble.dart`、`chat_input_bar.dart`、`chat_message_list.dart`
     - `lib/features/avatar/presentation/widgets/avatar_stage.dart`
     - `lib/features/home/presentation/screens/home_page.dart`
     - `lib/features/onboarding/presentation/screens/onboarding_screen.dart`
     - `lib/features/profile/presentation/screens/*.dart`
     - `lib/features/progress/presentation/screens/*.dart`
     - `lib/features/review/presentation/screens/review_screen.dart`
     - `lib/features/scenarios/presentation/screens/*.dart`
     - `lib/features/settings/presentation/screens/settings_screen.dart`
     - `lib/shared/widgets/virtual_character.dart`、`virtual_character_3d*.dart`、`app_banners.dart`
   - 关注维度：
     - 动画是否突兀、循环不自然、缺少过渡。
     - 交互反馈是否缺失（hover、press、loading、empty、error、success）。
     - 业务流程是否自洽（onboarding → placement → home → chat → review → progress）。
     - 按钮/输入/弹窗是否符合双端触控与鼠标操作习惯。
     - 错误状态是否友好、是否有重试路径。
     - AI 虚拟人物：表情与语音/文本状态是否匹配、口型同步、动作是否符合语境。

2. **结构化记录**
   - 输出文件：`/tmp/speakflow-e2e-run-<timestamp>/interaction-issues.md`
   - 每条记录包含：模块、位置、问题描述、影响、建议修改、优先级（P0/P1/P2）。
   - 目标数量：≥200 条。若自然发现不足，则扩大检查范围到所有辅助流程、边界状态、空状态、加载状态。

### Phase 3 — 视觉分析 subagent（≥200 条）

**目标**：对所有 E2E 截图进行全量视觉审查，找出 UI 细节、美观度、交互提示、适配问题。

1. **派发 visual-review subagent**
   - subagent 类型：`general_purpose_task`
   - 输入：
     - 截图目录 `/tmp/speakflow-e2e-run-<timestamp>/screenshots/`
     - `project.md` 与 `docs/design-reference.md` 中关于设计语言与品牌的描述
     - 重点关注：AI 虚拟人物、聊天界面、home dashboard、onboarding、settings、双端适配
   - 任务：
     - 遍历所有 `.png` 截图，分别审查 PC 端与移动端。
     - 记录 UI/视觉/交互可改善点，每条包含：截图文件名、页面/组件、问题、建议、优先级。
     - 目标数量：≥200 条。
   - 输出：`/tmp/speakflow-e2e-run-<timestamp>/visual-issues.md`

2. **subagent 工作方式**
   - 使用 `Read` 读取图片文件，通过视觉模型分析。
   - 若截图过多，可按模块分批处理；必要时压缩/采样，但优先保证关键流程全覆盖。

### Phase 4 — 整合修改点清单（≥400 条）

**目标**：将 Phase 2 与 Phase 3 的发现合并为统一的待修改清单。

1. **去重与归类**
   - 主 agent 读取 `interaction-issues.md` 与 `visual-issues.md`。
   - 去重：同一位置的交互问题与视觉问题合并为一条完整修改项。
   - 归类：
     - A. AI 虚拟人物 / Avatar（渲染、动画、表情、口型）
     - B. 聊天界面 / Chat（输入、气泡、状态、TTS、纠错、连续模式）
     - C. Home / Dashboard（布局、卡片、数据可视化、快速入口）
     - D. Onboarding / Placement（流程、表单、提示、跳过逻辑）
     - E. Profile / Settings（表单、验证、空状态、主题/语言）
     - F. Review / Progress / Scenarios（列表、空状态、图表、导航）
     - G. System / Banner / PWA（更新提示、离线提示、安装提示）
     - H. E2E 测试本身（断言、截图、覆盖度）

2. **输出清单**
   - 文件：`/tmp/speakflow-e2e-run-<timestamp>/modification-plan.md`
   - 格式：序号 | 类别 | 文件位置 | 问题简述 | 修改方案 | 优先级 | 验证方式
   - 目标：≥400 条。

3. **用户确认（可选）**
   - 若修改清单规模过大或涉及架构调整，先输出清单摘要请用户确认优先级；否则直接进入 Phase 5。

### Phase 5 — 派发 subagent 执行修改

**目标**：根据清单对应用源码、E2E 测试、文档进行集中修改。

1. **任务拆分**
   - 按类别拆分为多个 subagent 任务，每个 subagent 负责一个或几个类别：
     - subagent A：AI 虚拟人物 / Avatar（`lib/features/avatar/`、`lib/shared/widgets/virtual_character*.dart`、`lib/widgets/chat/` 中相关部分）
     - subagent B：聊天界面 / Chat（`lib/features/chat/presentation/screens/chat_screen.dart`、`lib/widgets/chat/`）
     - subagent C：Home / Dashboard / Review / Progress / Scenarios（`lib/features/home/`、`lib/features/review/`、`lib/features/progress/`、`lib/features/scenarios/`）
     - subagent D：Onboarding / Profile / Settings / System（`lib/features/onboarding/`、`lib/features/profile/`、`lib/features/settings/`、`lib/core/services/`、`lib/shared/widgets/app_banners.dart`）
     - subagent E：E2E 测试补全与截图增强（`e2e/specs/`、`e2e/lib/`）

2. **subagent 输入**
   - `modification-plan.md` 中对应类别的条目。
   - 相关源码文件路径与当前实现（subagent 自行读取）。
   - 必须遵循的约束：
     - 不要引入新的未请求功能。
     - 保持 Riverpod provider 依赖正确。
     - 不要破坏现有单元测试（`test/`）。
     - 所有用户可见字符串使用 `t()` / `tArg()`（必要时补充 i18n key）。
     - 双端适配优先使用 `lib/core/util/responsive.dart` 中已有的 `FormFactor` 辅助函数。

3. **主 agent 协调**
   - 并行启动 subagent。
   - 收集每个 subagent 的修改摘要与遇到的 blocker。
   - 对冲突文件（如 `chat_screen.dart` 被多个 subagent 修改）进行串行化或合并。

### Phase 6 — 汇总与 Review

**目标**：确认所有修改一致、可编译、符合设计方向。

1. **收集修改**
   - 汇总所有 subagent 的改动文件列表。
   - 检查是否有重复修改、逻辑冲突、格式问题。

2. **静态检查**
   - 在项目根目录执行：
     ```bash
     flutter analyze
     dart fix --apply
     ```
   - 在 `e2e/` 目录执行：
     ```bash
     npm run typecheck
     ```
   - 修复所有 analyze/typecheck 错误。

3. **单元测试回归**
   - 执行 `flutter test`。
   - 修复失败的单元测试；若测试假设已过期，则同步更新测试。

4. **Review 产出**
   - 文件：`/tmp/speakflow-e2e-run-<timestamp>/modification-review.md`
   - 内容：修改统计、关键改动说明、已知限制、待后续跟进项。

### Phase 7 — 更新 E2E、project.md、CHANGELOG.md

**目标**：让测试与文档与本次修改保持一致。

1. **更新 E2E 测试**
   - 对本次修改涉及的新交互、新状态、新错误提示补充断言与截图。
   - 对双端适配缺失的用例，使用 `captureAtViewport` 或分别在 chromium/mobile-chrome 项目中运行并生成双端截图。
   - 确保所有新截图命名带项目名，不互相覆盖。

2. **更新 project.md**
   - 在 `/workspace/project.md` 中补充：
     - 本次品质提升的范围与关键改进（AI 虚拟人物、聊天交互、双端适配）。
     - 若新增/调整了业务流程，更新“当前架构”与“E2E 测试”章节。

3. **更新 CHANGELOG.md**
   - 在 `[Unreleased]` 下新增一节，日期 2026-07-25：
     - 按类别列出主要改进（Added / Changed / Fixed / Improved / UI/UX）。
     - 引用 E2E 双端覆盖数量、截图数量、修改项数量。
     - 注明已知限制（如有）。

### Phase 8 — 重新 E2E 回归测试

**目标**：确认修改没有引入回归，且所有关键路径在双端正常。

1. **重新构建 Flutter Web E2E 版本**
   - 因为源码已修改，必须重新执行 `flutter build web --dart-define=E2E=true`。

2. **运行 E2E**
   - 命令：
     ```bash
     cd e2e && npx playwright test --project=chromium --project=mobile-chrome --reporter=list
     ```
   - 保存日志与截图到 `/tmp/speakflow-e2e-run-<timestamp>-regression/`。

3. **修复失败项**
   - 若测试失败由应用代码导致 → 修改应用代码。
   - 若测试失败由 E2E 断言/选择器过时导致 → 修改 E2E 测试。
   - 循环执行“修复 → 重新跑失败用例”直到通过率达到可接受水平（目标：所有 P0/P1 用例通过，整体失败率 <2%）。

4. **Typecheck / Analyze 再次验证**
   - `flutter analyze` 0 errors。
   - `cd e2e && npm run typecheck` 0 errors。
   - `flutter test` 全绿。

### Phase 9 — Git 合并与推送

**目标**：将修改合并到 main 并推送到远程。

1. **Git 状态检查**
   - `git status`、`git diff --stat`。

2. **提交修改**
   - 只提交与本次任务相关的文件（不包含 `.env`、凭据、临时文件）。
   - 若修改量大，可按类别拆分为多个 commit（如 `fix(ui): avatar animation polish`、`test(e2e): add mobile viewport coverage`、`docs: update project.md and CHANGELOG`）。
   - 提交信息遵循仓库已有风格（类型前缀 + 简明描述）。

3. **合并到 main / 推送**
   - 当前已在 `main` 分支，可直接 commit。
   - 执行 `git push origin main`。
   - 若远程有更新导致冲突，先 `git pull --rebase origin main` 再 push；绝不使用 `--force`。

---

## 关键决策与假设

1. **Flutter 环境**：假设可以在 sandbox 中成功安装 Flutter 3.44.4 + Dart 3.12.2。若安装失败或网络受限，将立即上报并寻求替代方案（如使用预构建镜像）。
2. **E2E 执行范围**：仅跑 `chromium` 和 `mobile-chrome` 两个项目，不跑 firefox/webkit。这样既能覆盖桌面与移动端，又控制耗时。
3. **数量目标**：200/400 条是目标下限，实际以真实发现为准；若自然发现超过则全部记录，若不足则扩大检查面至 loading/empty/error/accessibility 等边界状态。
4. **修改边界**：只修改已存在的问题和明显可改善点，不主动新增大型功能模块；若发现缺少关键流程，记录为“建议后续迭代”而不是强行在本轮实现。
5. **双端截图命名**：通过增强 `screenshots.ts` 让文件名自动带项目名，避免同名覆盖，同时保持旧测试调用方式兼容。
6. **文档**：用户提到的 `changelog.md` 实际对应仓库中的 `CHANGELOG.md`；计划更新 `CHANGELOG.md`，不新建小写文件。

---

## 验证清单

- [ ] `flutter --version` 与 `dart --version` 正常。
- [ ] `flutter build web --dart-define=E2E=true` 成功生成 `build/web/`。
- [ ] `cd e2e && npm run typecheck` 0 错误。
- [ ] `npx playwright test --list --project=chromium --project=mobile-chrome` 列出约 1434 条用例。
- [ ] 全量 E2E 运行完成，截图保存到临时目录。
- [ ] `interaction-issues.md` ≥200 条记录。
- [ ] `visual-issues.md` ≥200 条记录。
- [ ] `modification-plan.md` ≥400 条记录。
- [ ] subagent 完成源码与 E2E 修改。
- [ ] `flutter analyze` 0 errors / `flutter test` 全绿 / `npm run typecheck` 0 errors。
- [ ] 回归 E2E 通过率达到目标（P0/P1 100%，整体 <2% 失败）。
- [ ] `project.md` 与 `CHANGELOG.md` 已更新。
- [ ] `git push origin main` 成功。

---

## 风险与应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| Flutter 工具链安装失败或下载过慢 | 无法构建 E2E 版本 | 先检查环境；若无法安装则使用 CI/远端构建机或请求用户提供预构建镜像。 |
| E2E 全量运行时间过长 | 影响后续分析与修改 | 可先在 chromium 跑一轮快速基线，再跑 mobile-chrome；必要时拆分模块运行。 |
| 截图数量过大导致视觉分析 subagent 超时 | 视觉分析不完整 | 按模块分批派发多个 subagent；对相似页面采样。 |
| subagent 并行修改同一文件冲突 | 代码损坏 | 主 agent 负责串行化冲突文件，或按文件维度拆分任务。 |
| 修改范围过大导致回归测试大量失败 | 无法按时合并 | 优先修复 P0/P1 用例；低优先级问题可延后到后续迭代。 |
| 远程 main 在本轮工作期间有新提交 | push 冲突 | 执行 `git pull --rebase origin main` 后再 push。 |
