# SpeakFlow Phase 5 业务逻辑/交互修改执行计划

## 1. 任务摘要

继续实施 `/tmp/speakflow-e2e-run/unified-modifications.md` 中「业务逻辑 / 交互」章节的 **BL-001 ~ BL-103** 共 103 条修改项。实施顺序按严重级别 **高 → 中 → 低** 逐条推进；每条改动保持小而聚焦；对需要大重构或当前结构无法低成本实现的条目记录为「暂缓」并说明原因。最终通过 `/opt/flutter/bin/dart analyze` 修复本次改动引入的静态错误，并输出变更报告到 `/tmp/speakflow-e2e-run/business-logic-implementation-report.md`。

**约束**：不改动 e2e 测试代码。

---

## 2. 当前状态分析

### 2.1 已完成的修改（根据上一轮上下文与源码核对）

| 编号 | 简述 | 主要修改文件 | 状态 |
|------|------|-------------|------|
| BL-001 | 复习评分后更新 `lastSeenAt` | `lib/features/review/data/sm2_service.dart` | ✅ 已完成，`scheduleReview` 统一 `now = DateTime.now()` 并写入 `lastSeenAt: now` |
| BL-002 | 收藏筛选下评分后不移除卡片 | `lib/features/chat/presentation/screens/review_screen.dart` | ✅ 已完成，`_rateCorrection` 中 `_showStarredOnly` 时更新卡片而非移除 |
| BL-007 | AI Review 注入到期纠错上下文 | `lib/features/chat/presentation/screens/review_screen.dart` | ✅ 已完成，`_startAIReview` 构建 system prompt 并写入当前到期纠错 |
| BL-008 | 练习纠错时注入场景元数据 | `lib/features/chat/presentation/screens/review_screen.dart` | ✅ 已完成，`_practiceCorrection` 写入针对性 system prompt |
| BL-019 | 收藏筛选空状态文案差异化 | `lib/features/chat/presentation/screens/review_screen.dart` | ✅ 已完成，`_buildEmptyState` 区分 starred/due 状态 |
| BL-020 | 统一 `DateTime.now()` 调用 | `lib/features/review/data/sm2_service.dart` | ✅ 已完成 |
| BL-021 | 首页快速入口需实际练习才打卡 | `lib/features/home/presentation/screens/home_page.dart` | ✅ 已完成，移除 `_startConversation`/`_openPronunciation`/`_startScenario` 中的 `recordPractice` 调用 |
| BL-026 | 连续打卡增加最小练习时长校验 | `lib/features/home/data/streak_service.dart` | ✅ 已完成，新增 `kMinPracticeSeconds = 30` |
| BL-055 | 取消项目关联增加二次确认 | `lib/features/project_space/presentation/screens/project_detail_screen.dart` | ✅ 已完成，`removeLink` 前弹出确认对话框 |
| BL-061 | 删除项目后清理 Provider 缓存 | `lib/features/project_space/presentation/screens/project_detail_screen.dart` | ✅ 已完成，`deleteProject` 后 `invalidate(projectsProvider/_linksProvider/_activitiesProvider)` |
| BL-063 | 删除项目使用事务 | `lib/features/project_space/data/project_repository.dart` | ✅ 已完成，`deleteProject` 使用 `db.transaction` |
| BL-084 | API Key 与名称 trim | `lib/features/profile/presentation/screens/profile_form_screen.dart` | ✅ 已完成，`_saveProfile` 中对输入 trim |
| BL-085 | 新建 profile 自动激活 | `lib/features/profile/presentation/screens/profile_form_screen.dart` | ✅ 已完成，新增 `_maybeActivateOnFirstSave` |
| BL-089 | JSON 转义（region extraConfig） | `lib/features/profile/presentation/screens/profile_form_screen.dart` | ✅ 已完成，使用 `jsonEncode({'region': region})` |
| 设置加载失败处理 / 开关持久化失败回滚 | 设置容错 | `lib/features/settings/presentation/screens/settings_screen.dart` | ✅ 已完成，`_loadSettings` / `_toggleLowBandwidth` / `_toggleContentEnabled` 添加 try/catch + 回滚 |

### 2.2 已发现的需要注意的实现问题

- `profile_form_screen.dart` 中使用了 `jsonEncode` 但未导入 `dart:convert`，执行阶段运行 `dart analyze` 时必须修复。
- `service_config_screen.dart` 中原本尝试 invalidate `activeLlmProfileProvider` 等 Provider，但 `shared/providers.dart` 未定义这些 Provider；执行阶段若涉及该文件，需使用现有 Provider 或暂缓 Provider 刷新相关条目。

---

## 3. 待实施项分组计划

### 3.1 第一阶段：高优先级核心修复（高严重级别 + 依赖少）

重点关注 SRS 算法一致性、复习队列数据一致性、每日计划与场景复习队列缺口。

| 编号 | 修改目标 | 文件 | 实施方式 |
|------|---------|------|---------|
| **BL-004** | 新纠错 `next_review_at` 为 NULL 导致与 `review_queue.due_at` 不一致 | `lib/features/chat/data/chat_repository.dart`（`saveCorrection`） | 插入前若 `correction.nextReviewAt == null`，默认设为 `DateTime.now()` |
| **BL-005** | `getReviewQueueItems` 未过滤仅到期项 | `lib/features/chat/data/chat_repository.dart` | 增加 `bool onlyDue = true` 参数，默认只返回 `due_at <= now` 的条目 |
| **BL-006** | UI 显示的 mastery 等级与技能掌握计算阈值不一致 | `lib/features/review/data/sm2_service.dart`、`lib/features/home/data/skill_mastery_service.dart` | 统一阈值映射，可让 `_perItemScore` 复用 `getMasteryLevel` 的离散等级 |
| **BL-009** | 技能掌握评分未考虑最近一次评分质量 | `lib/features/home/data/skill_mastery_service.dart` | 在 `_perItemScore` 中纳入最近一次 rating quality 的衰减因子；若 correction 未记录 quality，则先写入 quality 字段再参与计算 |
| **BL-010** | 每日计划未考虑场景复习队列到期数 | `lib/features/chat/data/daily_plan_service.dart` | 在 `buildForToday` 增加 `scenarioDueCount` 参数，>0 时添加优先级 2 的「复习场景」任务 |
| **BL-014** | `ReviewScreen` 使用 `ref.read` 加载数据，不响应 repository 变化 | `lib/features/chat/presentation/screens/review_screen.dart` | 增加 `Pull-to-refresh`（`RefreshIndicator`）或在 `didChangeDependencies`/`onResume` 中重新加载 |

### 3.2 第二阶段：中优先级数据一致性与交互改进

| 编号 | 修改目标 | 文件 | 实施方式 |
|------|---------|------|---------|
| **BL-003** | 「最近错误」每日任务只打开普通复习页，无法真正过滤最近错误 | `lib/features/chat/data/daily_plan_service.dart`、`lib/features/chat/presentation/screens/review_screen.dart` | 给 `DailyPlanTask` 增加 `filterDays` payload；`ReviewScreen` 支持按 `last_seen_at` 范围过滤或创建「最近错误」列表 |
| **BL-011** | `nextReviewAt` 未对齐自然日 | `lib/features/review/data/sm2_service.dart` | 将 `nextReviewAt` 对齐到次日 00:00（本地时间） |
| **BL-012** | `syncReviewQueue` 的 `created_at` 每次被覆盖 | `lib/features/chat/data/chat_repository.dart` | 使用 `INSERT OR REPLACE` + `COALESCE((SELECT created_at FROM review_queue WHERE id = ?), ?)` 保留首次创建时间 |
| **BL-013** | 每日计划 review 任务固定 2 分钟，与 badge 不匹配 | `lib/features/chat/data/daily_plan_service.dart` | 根据 `dueCount` 动态估算时长（每条 15–20 秒），badge 上限 99+ |

### 3.3 第三阶段：低优先级优化项

低严重级别条目（如 BL-011、BL-013 等已在第二阶段的部分）以及其余未列出的中低优先级条目，将按 unified-modifications.md 顺序处理。处理原则：

- 若改动 ≤ 5 行且逻辑清晰 → 直接实施。
- 若需要新增表/字段/路由/复杂 UI → 记录为「暂缓」并说明原因。
- 若与 e2e 测试代码相关 → 跳过（不改动 e2e）。

---

## 4. 执行流程

1. **读取统一修改清单**：使用 `Read` 工具读取 `/tmp/speakflow-e2e-run/unified-modifications.md` 的 BL 章节，逐条核对当前实现状态。
2. **按优先级实施**：高 → 中 → 低；每条改动前先 `Read` 相关源码文件，确保理解上下文。
3. **小而聚焦**：单次编辑只解决一个 BL 项；相关 BL 项可合并到同一次提交级编辑中。
4. **静态分析**：每完成一批（约 5–10 个 BL 项）后运行 `/opt/flutter/bin/dart analyze`，修复本次引入的错误。
5. **记录结果**：维护一个内部清单，区分「已完成」「暂缓」。
6. **生成报告**：全部完成后输出 `/tmp/speakflow-e2e-run/business-logic-implementation-report.md`，包含：
   - 完成的编号/简述/修改文件/关键代码片段
   - 暂缓项清单及原因
   - 最终 `dart analyze` 结果摘要

---

## 5. 假设与决策

- **假设**：当前代码库可以正常编译，e2e 测试不在 `lib/` 目录下而在独立目录（如 `e2e/`、`test_e2e/`），因此业务逻辑改动不会触碰 e2e。
- **决策**：BL-003（最近错误过滤）优先采用「在 `ReviewScreen` 增加按 `last_seen_at` 范围过滤」而非新建页面，因为成本更低且能满足每日计划入口。
- **决策**：BL-009（最近一次评分质量）先尝试扩展 `Correction` 模型记录 `lastReviewQuality`；若模型冻结或影响过大，则暂缓。
- **决策**：BL-011（自然日对齐）仅对齐到次日 00:00，不引入用户自定义「一天开始时间」配置，避免新增设置项。

---

## 6. 验证步骤

1. 每批改动后运行 `/opt/flutter/bin/dart analyze`，确保无新增 error（warning/info 尽量处理，但不阻塞）。
2. 对涉及 SRS 算法的改动（BL-001/004/006/011/012），检查 `Sm2Service` 单元测试是否仍通过（如有）。
3. 对涉及数据库操作的改动（BL-004/005/012/063），确认 `review_queue` 与 `corrections` 表状态一致。
4. 报告生成后，再次运行 `dart analyze` 并将结果写入报告。
