# SpeakFlow 统一修改点清单

> 生成日期：2026-07-25
> 来源：业务逻辑审查、UI/UX 源码审查、截图视觉分析、E2E 覆盖缺口

## 汇总统计

| 来源 | 文件 | 修改点数量 |
|------|------|-----------|
| 业务逻辑 / 交互 | [business-logic-issues.md](file:///tmp/speakflow-e2e-run/business-logic-issues.md) | 103 |
| UI/UX / 视觉设计（源码） | [ui-ux-source-issues.md](file:///tmp/speakflow-e2e-run/ui-ux-source-issues.md) | 53 |
| 视觉分析（截图） | [visual-analysis-issues.md](file:///tmp/speakflow-e2e-run/visual-analysis-issues.md) | 225 |
| E2E 覆盖缺口 | [e2e-coverage-gaps.md](file:///tmp/speakflow-e2e-run/e2e-coverage-gaps.md) | 130 |
| **合计** | - | **511** |

## 修改点分类索引

- 交互与业务逻辑：见「业务逻辑 / 交互」章节
- UI/UX 与视觉：见「UI/UX / 视觉设计（源码）」与「视觉分析（截图）」章节
- E2E 测试补强：见「E2E 覆盖缺口」章节

## 业务逻辑 / 交互（103 条）

### BL-001

## 1. 复习评分后未更新 `lastSeenAt`，技能掌握的时间衰减计算失真

- **编号**：1
- **分类**：SM2 算法 / 技能掌握
- **严重级别**：高
- **描述**：`Sm2Service.scheduleReview` 与 `ReviewScreen._rateCorrection` 在更新 correction 时均未将 `lastSeenAt` 设为当前时间。`SkillMasteryService.computeScore` 按 `lastSeenAt` 降序对最近 20 条纠错做时间衰减加权。结果是：用户复习了一条很久以前发现的纠错后，该纠错在技能掌握计算中仍按“旧发现时间”参与加权，无法反映“最近刚练习过”，导致技能掌握分数滞后、衰减权重失真。
- **文件位置**：`file:///workspace/lib/features/review/data/sm2_service.dart`（scheduleReview，未更新 lastSeenAt）、`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_rateCorrection，约第 265–327 行）
- **建议改进**：在 `scheduleReview` 返回的 `Correction` 中显式设置 `lastSeenAt: DateTime.now()`；或在 `_rateCorrection` 中更新数据库前统一刷新 `lastSeenAt`，确保技能掌握的时间衰减以“最近复习时间”为基准。

---

### BL-002

## 2. 收藏筛选下评分后卡片被移除，与“收藏永不掉出复习轮”的产品语义冲突

- **编号**：2
- **分类**：复习 UI / 交互
- **严重级别**：高
- **描述**：当用户打开“仅看收藏”筛选（`_showStarredOnly = true`）时，`ReviewScreen` 从 `getFavoriteCorrections` 加载全部收藏纠错（不限于到期项）。但 `_rateCorrection` 在评分成功后总是执行 `_corrections.removeWhere((c) => c.id == correction.id)`，导致卡片立即从收藏列表消失。收藏列表被设计为“用户主动想反复看的项目”，评分后不应直接消失，否则用户会误以为收藏被取消。
- **文件位置**：`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_toggleStarredFilter、_rateCorrection，约第 42–61、265–327 行）
- **建议改进**：评分后根据当前筛选模式决定是否移除卡片。收藏模式下保留卡片并刷新其 SM-2 状态，或重新调用 `_loadCorrections()` 按收藏逻辑重排；普通到期模式下保持移除。

---

### BL-003

## 3. “最近错误”每日任务只打开普通复习页，无法真正过滤最近错误

- **编号**：3
- **分类**：每日计划 / 复习流程
- **严重级别**：高
- **描述**：`DailyPlanService.buildForToday` 会在 `recentErrorCount > 0` 时生成 `recent_errors` 任务，badge 显示最近 3 天错误数。但该任务的 `action` 是 `DailyPlanAction.openReview`，`ReviewScreen` 没有任何按时间范围过滤的入口参数，打开后仅展示当前到期项。用户看到 badge “5 个最近错误”，点进去却可能看到完全不同的内容，造成认知不一致。
- **文件位置**：`file:///workspace/lib/features/chat/data/daily_plan_service.dart`（buildForToday，约第 66–81 行）、`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（无过滤参数）
- **建议改进**：给 `DailyPlanTask` 增加可选 payload（如 `filterDays: 3`），并在 `ReviewScreen` 支持按 `last_seen_at` 范围过滤；或改为跳转到专门的“最近错误”列表页。

---

### BL-004

## 4. 新纠错的 `next_review_at` 为 NULL，与 `review_queue.due_at` 状态不一致

- **编号**：4
- **分类**：数据一致性 / 复习队列
- **严重级别**：中
- **描述**：`Correction` 默认 `nextReviewAt` 为 null，`ChatRepository.saveCorrection` 直接将该 null 写入 `corrections.next_review_at`；随后 `syncReviewQueue` 却把 `due_at` 设为 `DateTime.now()`。同一个新纠错在 `corrections` 表中表示为“未安排”（NULL），在 `review_queue` 表中表示为“现在到期”，两个源头可能给出不同的到期判断，增加后续排查与跨表统计的复杂度。
- **文件位置**：`file:///workspace/lib/features/chat/data/chat_repository.dart`（saveCorrection，约第 258–272 行）、`file:///workspace/lib/core/database/database_helper.dart`（corrections 表结构，约第 122–145 行）
- **建议改进**：在 `saveCorrection` 插入前，如果 `correction.nextReviewAt == null`，则默认设为 `DateTime.now()`，保持与 `review_queue.due_at` 一致；或统一让 `getDueCorrections` 只依赖 `review_queue`。

---

### BL-005

## 5. `getReviewQueueItems` 未过滤仅到期项，未来到期的项目也会出现在“待复习”列表

- **编号**：5
- **分类**：复习队列
- **严重级别**：中
- **描述**：`ChatRepository.getReviewQueueItems` 的 SQL 没有 `WHERE due_at <= ?` 条件，而是按 `due_at ASC` 返回所有队列槽位。首页“待复习纠错列表”会展示几天后、甚至几周后才到期的项目，干扰用户对“今天该做什么”的判断。
- **文件位置**：`file:///workspace/lib/features/chat/data/chat_repository.dart`（getReviewQueueItems，约第 572–613 行）
- **建议改进**：增加 `bool onlyDue = true` 参数，默认只返回 `due_at <= now` 的条目；如需展示未来预告，再单独提供“即将复习”列表。

---

### BL-006

## 6. UI 显示的 mastery 等级与技能掌握计算使用的阈值不一致

- **编号**：6
- **分类**：SM2 算法 / 技能掌握
- **严重级别**：中
- **描述**：`Sm2Service.getMasteryLevel` 的分段为：reviewCount=0→New、<2→Learning、EF<2.0→Struggling、<5→Familiar、<8→Mastered、Expert。而 `SkillMasteryService._perItemScore` 的分段为：reviewCount=0→0、EF<1.5→30、reviewCount<3→50、<5→70、<8→90、100。两条路径对“Struggling/Learning”的 EF 与 reviewCount 阈值不一致，导致用户在同一界面看到的等级标签（如 Struggling）与后台用于能力雷达计算的单项分（如 70）对应不上。
- **文件位置**：`file:///workspace/lib/features/review/data/sm2_service.dart`（getMasteryLevel，约第 67–74 行）、`file:///workspace/lib/features/home/data/skill_mastery_service.dart`（_perItemScore，约第 112–119 行）
- **建议改进**：将 mastery 分段阈值统一抽象到一份配置中，`Sm2Service.getMasteryLevel` 与 `_perItemScore` 共享同一阈值表；或让 `_perItemScore` 直接复用 `getMasteryLevel` 的离散等级映射为分数。

---

### BL-007

## 7. “AI Review”按钮只是创建普通聊天会话，未真正触发基于到期纠错的 AI 复习

- **编号**：7
- **分类**：复习 UI / 交互
- **严重级别**：高
- **描述**：`ReviewScreen._startAIReview` 仅调用 `repo.createSession(topic: 'AI Review Session')`，没有传入当前到期纠错列表、技能薄弱点或任何复习上下文。用户点击“AI Review”时期望的是围绕错题本的智能复习，但进入的却是一个普通自由对话，产品语义与实际行为严重不符。
- **文件位置**：`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_startAIReview，约第 230–236 行）
- **建议改进**：将到期纠错（尤其是高重要性 / 最近失败项）拼装成 system prompt 或初始消息注入会话；或在实现该功能前暂时隐藏/禁用该按钮，避免误导。

---

### BL-008

## 8. 点击纠错卡片“练习该纠错”并未让会话聚焦该纠错

- **编号**：8
- **分类**：复习 UI / 交互
- **严重级别**：高
- **描述**：`ReviewScreen._practiceCorrection` 创建 topic 为 `"Practice: {original} → {corrected}"` 的会话，但仅把文本放在 topic 字段。聊天场景的 system prompt 与 LLM 上下文无法感知该纠错，AI 不会围绕这个具体错误进行针对性练习。界面文案“Tap the card to practice it in a conversation”与真实行为脱节。
- **文件位置**：`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_practiceCorrection，约第 238–249 行）
- **建议改进**：创建会话时把纠错信息写入会话元数据或 system prompt（例如要求 AI 在接下来的对话中专门练习该句型/词汇），确保点击练习有实际聚焦效果。

---

### BL-009

## 9. 技能掌握评分未考虑最近一次评分质量（Again/Hard/Good/Easy）

- **编号**：9
- **分类**：技能掌握 / SM2 算法
- **严重级别**：中
- **描述**：`SkillMasteryService._perItemScore` 只看 `reviewCount` 与 `easinessFactor`，不看最近一次 rating quality。例如用户连续复习 4 次后某次点了 Again（reviewCount 重置为 0，EF 下降），该条会降到 0 分；但若连续多次点 Hard（reviewCount 不变、EF 缓慢下降），其单项分可能仍与点 Good 相近。没有 quality 历史，就无法区分“勉强记住”和“轻松记住”。
- **文件位置**：`file:///workspace/lib/features/home/data/skill_mastery_service.dart`（_perItemScore、computeScore，约第 75–119 行）
- **建议改进**：新增 `review_events` 表记录每次评分 quality，在 `_perItemScore` 或 `computeScore` 中引入最近一次 quality 的衰减因子；或至少把最近一次 rating 写入 correction 并参与计算。

---

### BL-010

## 10. 每日计划未考虑场景复习队列到期数，缺少场景复习任务

- **编号**：10
- **分类**：每日计划
- **严重级别**：中
- **描述**：`DailyPlanService.buildForToday` 只接收 `dueCount`（纠错到期数）并生成一个 review 任务，完全未接收 `scenarioDueCount`。首页已有 `scenarioReviewQueueProvider` 与 `dueScenarioReviewQueueCountProvider`，说明产品支持场景复习队列，但每日计划没有为其生成高优先级复习任务，场景复习容易被遗漏。
- **文件位置**：`file:///workspace/lib/features/chat/data/daily_plan_service.dart`（buildForToday / buildFromRepository，约第 39–177 行）
- **建议改进**：在 `buildForToday` 增加 `scenarioDueCount` 参数，当 >0 时添加优先级 1 或 2 的“复习场景”任务，并跳转 `/scenario-review`（或相应路由）。

---

### BL-011

## 11. `nextReviewAt` 按当前时刻加 interval 天，未对齐到自然日

- **编号**：11
- **分类**：SM2 算法
- **严重级别**：低
- **描述**：`Sm2Service.scheduleReview` 使用 `DateTime.now().add(Duration(days: newInterval))` 作为下次复习时间。如果用户在 23:50 评分，次日 23:50 才到期；用户通常期望“明天”是指第二天早上即可复习。跨自然日的 scheduling 与其他 SR 应用习惯不一致。
- **文件位置**：`file:///workspace/lib/features/review/data/sm2_service.dart`（scheduleReview，约第 29、47 行）
- **建议改进**：将 `nextReviewAt` 对齐到次日 00:00（或用户本地设置的“一天开始时间”），保持“复习日”语义一致。

---

### BL-012

## 12. `syncReviewQueue` 的 `created_at` 每次都被覆盖，丢失队列槽位首次创建时间

- **编号**：12
- **分类**：数据一致性 / 复习队列
- **严重级别**：中
- **描述**：`ChatRepository.syncReviewQueue` 与 `_syncReviewQueueTx` 使用 `ConflictAlgorithm.replace` 并每次都写入 `created_at: DateTime.now()`。每次 SM-2 调度都会把 `review_queue.created_at` 更新为当前时间，无法追溯该队列槽位是何时首次建立的，也破坏了基于 created_at 的分析与排序能力。
- **文件位置**：`file:///workspace/lib/features/chat/data/chat_repository.dart`（syncReviewQueue、_syncReviewQueueTx，约第 505–551 行）
- **建议改进**：使用 INSERT OR REPLACE 时让 `created_at = COALESCE((SELECT created_at FROM review_queue WHERE id = ?), ?)`，或通过 UPDATE + INSERT 的 upsert 保留首次创建时间。

---

### BL-013

## 13. 每日计划对大量到期纠错仍显示固定 2 分钟，时长与 badge 不匹配

- **编号**：13
- **分类**：每日计划 / 交互
- **严重级别**：低
- **描述**：`DailyPlanService.buildForToday` 中 review 任务的 `durationMinutes` 固定为 2 分钟，`badge` 却显示真实 `dueCount`。当 `dueCount = 50` 时，卡片显示“50 个待复习”但预计只要 2 分钟，明显失真。
- **文件位置**：`file:///workspace/lib/features/chat/data/daily_plan_service.dart`（buildForToday，约第 53–64 行）
- **建议改进**：根据 `dueCount` 动态估算时长（如每条 15–20 秒），并对 badge 做上限显示（如 99+）。

---

### BL-014

## 14. `ReviewScreen` 使用 `ref.read` 加载数据，不会自动响应 repository 变化

- **编号**：14
- **分类**：复习 UI / 状态管理
- **严重级别**：中
- **描述**：`_loadCorrections` 通过 `ref.read(chatRepoProvider)` 获取 repository，`initState` 只触发一次。由于不使用 `ref.watch`，从其他页面（如首页、设置页）修改了纠错或收藏状态后返回复习页，列表不会自动刷新；页面上也没有下拉刷新逻辑。
- **文件位置**：`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_loadCorrections，约第 42–53 行）
- **建议改进**：将加载逻辑抽取为 Riverpod `FutureProvider`/`AsyncNotifier` 并使用 `ref.watch`；或添加 `RefreshIndicator` 支持下拉刷新。

---

### BL-015

## 15. 没有持久化评分历史，无法分析复习质量趋势

- **编号**：15
- **分类**：数据模型 / SM2 算法
- **严重级别**：中
- **描述**：当前只把每次评分后的 `reviewCount`、`easinessFactor`、`intervalDays`、`nextReviewAt` 写入 `corrections` 表，没有 `review_events` 表记录每次 rating 的 quality、时间、旧/新状态。后续无法做“最近 30 天复习质量趋势”“某条纠错历史成功率”等分析，也无法支撑更精准的技能掌握算法。
- **文件位置**：`file:///workspace/lib/core/database/database_helper.dart`（schema，约第 122–145 行）、`file:///workspace/lib/features/review/data/sm2_service.dart`（scheduleReview）
- **建议改进**：新增 `review_events(id, correction_id, quality, previous_review_count, new_review_count, previous_ef, new_ef, created_at)` 表，在 `_rateCorrection` 成功后插入记录。

---

### BL-016

## 16. 收藏状态切换后未失效相关 provider，首页数据可能陈旧

- **编号**：16
- **分类**：复习 UI / 状态管理
- **严重级别**：低
- **描述**：`_CorrectionCard._toggleFavorite` 在本地做乐观更新，成功后仅更新 `_isFavorite`，没有 `invalidate` `reviewQueueProvider`、`dueReviewQueueCountProvider`、`dailyPlanProvider` 等。用户返回首页后，收藏优先级、due count badge、每日计划可能仍是旧状态。
- **文件位置**：`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_toggleFavorite，约第 461–477 行）
- **建议改进**：toggle 成功后 `ref.invalidate(reviewQueueProvider)`、`ref.invalidate(dueReviewQueueCountProvider)`、`ref.invalidate(dailyPlanProvider)`，确保首页立即刷新。

---

### BL-017

## 17. `skillMasteryListProvider` 仅按 score 升序，同分技能顺序不稳定

- **编号**：17
- **分类**：技能掌握 / 每日计划
- **严重级别**：低
- **描述**：`home_providers.dart` 中 `skillMasteryListProvider` 调用 `repo.getAllSkillMastery()`，该查询 `ORDER BY score ASC`。多个技能同分时，SQLite 返回顺序不确定，dashboard 的“技能掌握列表”每次刷新可能重排，给用户造成不稳定感。
- **文件位置**：`file:///workspace/lib/features/home/presentation/home_providers.dart`（skillMasteryListProvider，约第 199–203 行）、`file:///workspace/lib/features/chat/data/chat_repository.dart`（getAllSkillMastery，约第 730–734 行）
- **建议改进**：查询改为 `ORDER BY score ASC, updated_at DESC, skill_id ASC`，让同分技能按最近更新/稳定 ID 排序。

---

### BL-018

## 18. `getDueReviewQueueCount` 与 `getDueCorrectionCount` 数据源不同，可能导致首页 badge 与复习页数字不一致

- **编号**：18
- **分类**：复习队列 / 数据一致性
- **严重级别**：中
- **描述**：首页 due badge 使用 `getDueReviewQueueCount()`（查 `review_queue.due_at`），复习页与每日计划使用 `getDueCorrectionCount()`（查 `corrections.next_review_at`）。虽然正常情况下两表同步，但一旦发生同步失败、迁移异常或代码 bug，两个口径会给出不同数字，用户会看到 badge 与页面标题数量不一致。
- **文件位置**：`file:///workspace/lib/features/chat/data/chat_repository.dart`（getDueReviewQueueCount，约第 617–625 行；getDueCorrectionCount，约第 374–382 行）
- **建议改进**：统一以 `review_queue` 为唯一到期数据源（`corrections` 只保存 SM-2 状态），或每日计划/复习页也使用 `getDueReviewQueueCount()`；同时增加启动时的一致性校验/修复任务。

---

### BL-019

## 19. 收藏筛选为空时仍显示“全部完成”文案，与筛选语义不符

- **编号**：19
- **分类**：复习 UI / 交互
- **严重级别**：低
- **描述**：当 `_showStarredOnly = true` 且用户没有任何收藏时，`_buildEmptyState` 仍然显示 `"All caught up!"` 与 `l.t('review.nothing_due')`。这些文案暗示“没有到期项”，但实际情况是“没有收藏项”，用户可能误以为收藏筛选不起作用。
- **文件位置**：`file:///workspace/lib/features/chat/presentation/screens/review_screen.dart`（_buildEmptyState，约第 90–131 行）
- **建议改进**：根据 `_showStarredOnly` 显示差异化空状态文案，例如“暂无收藏纠错”或“点击星标收藏想重点复习的纠错”。

---

### BL-020

## 20. `Sm2Service.scheduleReview` 中 `DateTime.now()` 多次调用，极端情况下可能跨天

- **编号**：20
- **分类**：SM2 算法
- **严重级别**：低
- **描述**：`scheduleReview` 在第 29 行与第 47 行分别调用 `DateTime.now()`。虽然通常只相差微秒，但在 23:59:59.999 附近的极端情况下，两次调用可能跨到第二天，导致失败分支与通过分支的 `nextReviewAt` 基于不同基准，测试也不可复现。
- **文件位置**：`file:///workspace/lib/features/review/data/sm2_service.dart`（scheduleReview，约第 7–50 行）
- **建议改进**：在函数开头缓存 `final now = DateTime.now()`，所有时间计算均使用同一 `now` 实例，并便于单元测试注入。

---

*共记录 20 条问题。*

---

## 新增：首页仪表盘 / 每日计划 / 连续学习 / 进度 / 技能掌握 / 学习统计 / 会话连续性

---

### BL-021

## 25. 首页快速入口在练习尚未发生时就记录完成

- **分类**: 连续学习 / 业务逻辑
- **严重级别**: 高
- **描述**: `_startConversation`、`_openPronunciation`、`_startScenario` 在创建/打开页面前立即调用 `recordPractice(durationSeconds: 0, completed: true)`。用户只要点击按钮即可获得今日打卡，无需真正完成对话、复习或发音练习，极易被刷分。
- **文件位置**: [home_page.dart:265-283](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L265-L283)、[home_page.dart:294-308](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L294-L308)、[home_page.dart:313-333](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L313-L333)
- **建议改进**: 把 `recordPractice` 移到真正完成行为之后：聊天在发送/收到消息后、复习在评分后、发音在练习结束后记录；`durationSeconds` 使用实际耗时。

---

### BL-022

## 26. 下拉刷新仅固定等待 100ms，未等待数据实际刷新

- **分类**: 首页仪表盘 / 交互
- **严重级别**: 中
- **描述**: `_refreshAll` 在 invalidate 大量 Provider 后只 `await Future.delayed(const Duration(milliseconds: 100))`。异步请求可能仍在进行，`RefreshIndicator` 会提前收起，用户可能看到旧数据。
- **文件位置**: [home_page.dart:256-258](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L256-L258)
- **建议改进**: 通过 `ref.read(provider.future)` 或 `Future.wait` 等待关键 Provider 重新加载完成后再返回。

---

### BL-023

## 27. “继续练习”会话恢复卡片定义后未在首页使用

- **分类**: 首页仪表盘 / 会话连续性
- **严重级别**: 中
- **描述**: `activeSessionProvider` 在 `home_providers.dart` 中被定义为“有可恢复会话时在仪表盘展示继续练习卡片”，但 `HomePage` 完全没有监听或使用该 Provider，导致会话连续性入口缺失。
- **文件位置**: [home_providers.dart:89-92](file:///workspace/lib/features/home/presentation/home_providers.dart#L89-L92)、[home_page.dart:31-226](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L31-L226)
- **建议改进**: 在 `HomePage` 顶部监听 `activeSessionProvider`，非空时展示“继续上次练习”卡片并跳转到对应 `/chat/{id}`。

---

### BL-024

## 28. 场景复习队列把 icon 字段当文本渲染

- **分类**: 首页仪表盘 / UI 交互
- **严重级别**: 中
- **描述**: `_ScenarioReviewTile` 直接使用 `Text(item.scenario.icon, ...)` 显示场景图标，结果会把 `'work'`、`'airport'` 等字符串直接显示出来，而不是渲染成对应图标。
- **文件位置**: [home_page.dart:1561](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1561)
- **建议改进**: 复用 `_ScenarioChip._iconFor` 的映射逻辑，把字符串转换为 `IconData` 后使用 `Icon` 组件。

---

### BL-025

## 29. 目标设置对话框未校验目标文本

- **分类**: 首页仪表盘 / 数据质量
- **严重级别**: 低
- **描述**: `_SetGoalDialog` 的 `TextField` 只限制了 80 字符，未对空值、纯空格或特殊字符做校验，用户可保存无意义目标。
- **文件位置**: [home_page.dart:1662-1671](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1662-L1671)
- **建议改进**: 保存前 `trim()`，空值时禁用保存按钮或提示“请输入具体目标”。

---

### BL-026

## 30. 连续打卡服务允许 0 秒练习即算完成

- **分类**: 连续学习 / 业务逻辑
- **严重级别**: 高
- **描述**: `StreakService.recordPractice` 的 `completed` 默认 `true`，且对 `durationSeconds` 没有任何下限校验。任何调用方传 0 秒都可让今日变成“已完成”。
- **文件位置**: [streak_service.dart:29-55](file:///workspace/lib/features/home/data/streak_service.dart#L29-L55)
- **建议改进**: 增加最小有效练习时长（如 30 秒），并在 `completed` 为 true 时校验 `durationSeconds` 或实际行为证据。

---

### BL-027

## 31. 打卡逻辑完全依赖设备本地时间，可修改系统时间作弊

- **分类**: 连续学习 / 业务逻辑
- **严重级别**: 中
- **描述**: `recordPractice` 与 `getCurrentStreak` 均使用 `DateTime.now()` 生成日期 key。用户调整设备日期即可补签、续签或跳过断签。
- **文件位置**: [streak_service.dart:34](file:///workspace/lib/features/home/data/streak_service.dart#L34)、[streak_service.dart:84](file:///workspace/lib/features/home/data/streak_service.dart#L84)
- **建议改进**: 引入服务端时间、不可篡改本地时间锚点，或至少检测系统时间大幅回拨并给出提示。

---

### BL-028

## 32. 每日计划“近期错误复习”仅跳转到通用复习页

- **分类**: 每日计划 / 业务逻辑
- **严重级别**: 中
- **描述**: `buildForToday` 在 `recentErrorCount > 0` 时生成“复习近期错误”任务，但 `action` 仍是 `DailyPlanAction.openReview`，没有任何过滤参数。用户点击进入的是普通复习队列，而非最近 3 天的错误。
- **文件位置**: [daily_plan_service.dart:70-81](file:///workspace/lib/features/chat/data/daily_plan_service.dart#L70-L81)
- **建议改进**: 增加 `openRecentErrors` action 或在 Review 页支持 `since` 参数，真正只展示近期错误。

---

### BL-029

## 33. 任意未归档会话都会跳过语音热身任务

- **分类**: 每日计划 / 业务逻辑
- **严重级别**: 中
- **描述**: `buildFromRepository` 把 `repo.getActiveSession() != null` 作为 `hasActiveSession`。如果会话是几天前遗留未归档的，今日计划仍会跳过“语音健康预检”。
- **文件位置**: [daily_plan_service.dart:155-177](file:///workspace/lib/features/chat/data/daily_plan_service.dart#L155-L177)
- **建议改进**: 判断 `active.updatedAt` 或 `createdAt` 是否在当天或最近 N 小时内，否则视为无活跃会话。

---

### BL-030

## 34. 每日计划构建无降级，单点失败导致整个计划为空

- **分类**: 每日计划 / 容错
- **严重级别**: 中
- **描述**: `buildFromRepository` 顺序调用多个仓库方法，只要任一抛异常，整个 `dailyPlanProvider` 进入 error 状态，首页今日任务显示 `plan.empty`，用户完全看不到推荐任务。
- **文件位置**: [daily_plan_service.dart:155-177](file:///workspace/lib/features/chat/data/daily_plan_service.dart#L155-L177)
- **建议改进**: 对每个查询加 `try/catch` 并给出默认值（如 dueCount=0、scenarioCount=0），保证至少返回基础任务列表。

---

### BL-031

## 35. 技能掌握分数按列表索引衰减，而非真实时间差

- **分类**: 技能掌握 / 业务逻辑
- **严重级别**: 中
- **描述**: `SkillMasteryService.computeScore` 使用 `math.pow(decay, i)`，其中 `i` 是排序后列表位置。两次练习相隔一年和相隔一分钟在权重上被同等对待，无法反映真实遗忘曲线。
- **文件位置**: [skill_mastery_service.dart:74-103](file:///workspace/lib/features/home/data/skill_mastery_service.dart#L74-L103)
- **建议改进**: 以 `referenceTime` 与每条纠错 `lastSeenAt` 之间的天数差计算真实时间衰减权重。

---

### BL-032

## 36. 重新计算全部技能掌握时无事务保护

- **分类**: 技能掌握 / 数据一致性
- **严重级别**: 中
- **描述**: `recomputeAll` 循环每个 skillId 单独 `recompute` 并 `upsertSkillMastery`。若中途异常退出，部分技能分数已更新、部分未更新，数据处于不一致状态。
- **文件位置**: [skill_mastery_service.dart:53-63](file:///workspace/lib/features/home/data/skill_mastery_service.dart#L53-L63)
- **建议改进**: 使用仓库层事务批量 upsert，或在应用层先把结果收集到内存，全部计算成功后再统一写入。

---

### BL-033

## 37. 能力雷达图用全部历史纠错类型比例惩罚分数

- **分类**: 首页仪表盘 / 业务逻辑
- **严重级别**: 中
- **描述**: `abilityScoresProvider` 在混合 placement 与 skill_mastery 后，再使用所有历史纠错的类型占比对各项能力进行扣分。很久以前已修正的错误仍会持续拉低分数。
- **文件位置**: [home_providers.dart:169-187](file:///workspace/lib/features/home/presentation/home_providers.dart#L169-L187)
- **建议改进**: 只取最近 N 天或按时间衰减加权后的纠错分布，避免旧错误长期影响能力评估。

---

### BL-034

## 38. 周统计中“本周纠错数”使用 last_seen_at，重复复习会重复计数

- **分类**: 进度 / 业务逻辑
- **严重级别**: 中
- **描述**: `getWeeklyStats` 统计 corrections 数量时基于 `DATE(last_seen_at)`。同一纠错本周被复习多次会被多次计入，导致“本周纠错数”与用户实际犯错次数不一致。
- **文件位置**: [progress_service.dart:58-63](file:///workspace/lib/features/home/data/progress_service.dart#L58-L63)
- **建议改进**: 使用纠错创建时间 `created_at` 统计本周新增纠错；如需统计复习次数，应单独增加指标。

---

### BL-035

## 39. 弱项分析不清除历史数据，旧弱项长期残留

- **分类**: 进度 / 数据质量
- **严重级别**: 中
- **描述**: `analyzeWeakAreas` 只调用 `upsertWeakArea`，从未删除已过期或不再出现的弱项。随着时间推移，`weak_areas` 表会积累大量不再相关的条目。
- **文件位置**: [progress_service.dart:158-180](file:///workspace/lib/features/home/data/progress_service.dart#L158-L180)
- **建议改进**: 重新分析前清空旧记录，或只分析最近一段时间内的纠错并 soft-delete 旧条目。

---

### BL-036

## 40. 会话时长用首尾消息时间差，包含长时间闲置

- **分类**: 会话连续性 / 业务逻辑
- **严重级别**: 中
- **描述**: `updateSessionMeta` 用 `messages.last.createdAt.difference(messages.first.createdAt)` 计算时长。用户中途离开、锁屏或暂停都会计入会话时长，数据失真。
- **文件位置**: [session_continuity_service.dart:58-78](file:///workspace/lib/features/chat/data/session_continuity_service.dart#L58-L78)
- **建议改进**: 记录实际录音/交互累计时长，或在每次更新时只累加相邻消息间小于阈值的时间差。

---

### BL-037

## 41. 会话摘要使用未本地化的纠错类型原始名称

- **分类**: 会话连续性 / 国际化
- **严重级别**: 低
- **描述**: `generateSessionSummary` 直接拼接 `c.type.name`（如 `grammar`、`vocabulary`），生成英文摘要。非英语用户看到的是未翻译的技术名称。
- **文件位置**: [session_continuity_service.dart:84-114](file:///workspace/lib/features/chat/data/session_continuity_service.dart#L84-L114)
- **建议改进**: 使用 `AppLocalizations` 中对应的 i18n key 翻译类型名称。

---

### BL-038

## 42. 学习统计最近 7 天活动只包含有消息的日期

- **分类**: 学习统计 / 数据质量
- **严重级别**: 中
- **描述**: `LearningStatsService.getStats` 的 `dailyActivity` 遍历 `dailyMsgResults`，只包含发过消息的日期。若某天只有纠错没有发消息，该天不会出现在图表中，造成时间断层。
- **文件位置**: [learning_stats_service.dart:96-126](file:///workspace/lib/features/chat/data/learning_stats_service.dart#L96-L126)
- **建议改进**: 对消息日期与纠错日期取并集，缺失日期补 0，确保 7 天连续。

---

### BL-039

## 43. “已掌握”判定阈值在多处不一致

- **分类**: 学习统计 / 技能掌握 / 业务逻辑
- **严重级别**: 中
- **描述**: `LearningStatsService` 以 `review_count >= 5` 视为已掌握，而 `SkillMasteryService._perItemScore` 以 `review_count >= 8` 才给出满分贡献。两处标准不同，导致仪表盘与统计口径冲突。
- **文件位置**: [learning_stats_service.dart:62-65](file:///workspace/lib/features/chat/data/learning_stats_service.dart#L62-L65)、[skill_mastery_service.dart:112-119](file:///workspace/lib/features/home/data/skill_mastery_service.dart#L112-L119)
- **建议改进**: 统一“已掌握”阈值并抽取为共享常量，或按 SM-2 的 easinessFactor 综合判断。

---

### BL-040

## 44. 搜索会话时未转义 SQL 通配符

- **分类**: 会话连续性 / 数据查询
- **严重级别**: 低
- **描述**: `searchSessions` 将用户输入直接拼成 `%$query%`。若用户输入包含 `%` 或 `_`，会被当作 LIKE 通配符，返回非预期结果。
- **文件位置**: [session_continuity_service.dart:171-185](file:///workspace/lib/features/chat/data/session_continuity_service.dart#L171-L185)
- **建议改进**: 对 `%` 和 `_` 进行转义（如 `\%`、`\_`），并在 SQL 中声明 `ESCAPE '\'`。

---

### BL-041

## 45. 连续打卡徽章出错时直接隐藏

- **分类**: 首页仪表盘 / 错误处理
- **严重级别**: 低
- **描述**: `_StreakBadge` 的 `error` 分支返回 `SizedBox.shrink()`，当 streak 加载失败时用户看不到任何提示，可能误以为 streak 为 0。
- **文件位置**: [home_page.dart:416](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L416)
- **建议改进**: 出错时显示占位或“?”图标，并提供点击重试。

---

### BL-042

## 46. 目标推荐场景出错时直接隐藏，无空态/重试

- **分类**: 首页仪表盘 / 错误处理
- **严重级别**: 低
- **描述**: `_GoalSection` 中 `scenariosAsync` 的 `error` 分支返回 `SizedBox.shrink()`，推荐场景加载失败时既不显示空态也不提示用户。
- **文件位置**: [home_page.dart:1267](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1267)
- **建议改进**: 错误时展示“加载失败，点击重试”或至少显示 `common.empty` 文案。

---

### BL-043

## 47. 每日计划服务非单例，与 streak/progress 服务不一致

- **分类**: 每日计划 / 可维护性
- **严重级别**: 低
- **描述**: `dailyPlanProvider` 每次构建都 `DailyPlanService()` 新实例，而 `streakServiceProvider`、`progressServiceProvider` 均使用 Riverpod Provider 提供单例。若后续 `DailyPlanService` 持有状态或缓存，会导致行为不一致。
- **文件位置**: [home_providers.dart:82-85](file:///workspace/lib/features/home/presentation/home_providers.dart#L82-L85)
- **建议改进**: 增加 `dailyPlanServiceProvider` 单例，并让 `dailyPlanProvider` 通过 `ref.watch` 引用。

---

### BL-044

## 48. 会话历史 SQL 查询混用别名，可能映射到 ChatSession 多余字段

- **分类**: 会话连续性 / 数据映射
- **严重级别**: 低
- **描述**: `getEnrichedSessionHistory` 使用 `SELECT cs.*, sm.id AS sm_id, ...`，随后把整行 `row` 传给 `ChatSession.fromMap`。如果 `ChatSession.fromMap` 对未知键不忽略，混入的 `sm_*` 字段可能引发解析异常。
- **文件位置**: [session_continuity_service.dart:134-168](file:///workspace/lib/features/chat/data/session_continuity_service.dart#L134-L168)
- **建议改进**: `ChatSession.fromMap` 只接收显式 `cs` 列，metadata 单独构建，避免整行混传。

---

### BL-045

## 49. 能力分无数据时默认 50，未体现“未评估”状态

- **分类**: 首页仪表盘 / 业务逻辑
- **严重级别**: 低
- **描述**: `abilityScoresProvider` 在未做 placement、无 skill_mastery、无纠错时返回四项均为 50 的能力分，新手用户会误以为自己已有中等水平。
- **文件位置**: [home_providers.dart:111-115](file:///workspace/lib/features/home/presentation/home_providers.dart#L111-L115)、[home_providers.dart:189-195](file:///workspace/lib/features/home/presentation/home_providers.dart#L189-L195)
- **建议改进**: 无数据时返回 `null` 或 0，并在雷达图区域提示“完成定级测试后查看能力评估”。

---

### BL-046

## 50. 连续打卡 30 天图表错误状态与空数据表现相同

- **分类**: 首页仪表盘 / 错误处理
- **严重级别**: 低
- **描述**: `_StreakProgressBar` 中 `history` 的 `error` 分支使用 `_StreakDots(logs: const [])`，与“最近 30 天均无练习”视觉上无法区分，用户无法感知加载失败。
- **文件位置**: [home_page.dart:459-464](file:///workspace/lib/features/home/presentation/screens/home_page.dart#L459-L464)
- **建议改进**: error 状态显示简短错误提示或重试按钮，不要直接渲染空数据。

---

*本次新增记录 26 条问题。*

---

---

### BL-047

## 48. 场景练习启动时未携带场景元数据

- **分类**: 场景练习 / 业务逻辑
- **严重级别**: 高
- **描述**: `ScenariosScreen._startScenario` 仅将 `scenario.name` 与 `scenario.id` 传入 `createSession`，未携带难度、分类、学习目标等场景元数据。聊天层无法识别当前为“场景练习”，导致 AI 难以按场景设定推进对话、纠正表达或给出场景化反馈。
- **文件位置**: [scenarios_screen.dart:46-55](file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L46-L55)
- **建议改进**: 在 Session/Chat 模型中增加 scenario 上下文字段，或在 topic 中附加结构化标记，确保场景元数据随会话下发。

---

### BL-048

## 49. 场景关联项目使用隐藏长按手势

- **分类**: 场景练习 / 交互
- **严重级别**: 中
- **描述**: 将场景关联到项目采用“长按卡片”这一隐藏手势，没有任何入口提示或图标暗示。新用户无法发现该功能，导致项目-场景关联使用率极低。
- **文件位置**: [scenarios_screen.dart:135-148](file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L135-L148)
- **建议改进**: 在卡片上增加“更多”按钮或溢出菜单，或在场景详情页提供显式的“加入项目”操作。

---

### BL-049

## 50. 练习统计相对时间硬编码英文

- **分类**: 场景练习 / 国际化
- **严重级别**: 低
- **描述**: `_ScenarioCard._relativeTime` 返回硬编码英文（`today` / `yesterday` / `X days ago`），未使用 `AppLocalizations`。非英语用户会在统计卡片上看到英文时间文案。
- **文件位置**: [scenarios_screen.dart:199-205](file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L199-L205)
- **建议改进**: 将相对时间文案抽取到 ARB，按 locale 输出“今天 / 昨天 / N 天前”。

---

### BL-050

## 51. 场景分类标题首字母大写逻辑脆弱且无本地化

- **分类**: 场景练习 / 数据质量
- **严重级别**: 低
- **描述**: 分类标题使用 `category[0].toUpperCase() + category.substring(1)` 简单首字母大写，未处理空字符串，也无法按语言规则本地化（如德语名词大小写、中文无需大写）。
- **文件位置**: [scenarios_screen.dart:111-115](file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L111-L115)
- **建议改进**: 服务端/数据层返回已本地化的分类名，或在前端通过 i18n key 映射。

---

### BL-051

## 52. 场景统计加载失败无提示

- **分类**: 场景练习 / 容错
- **严重级别**: 中
- **描述**: `_loadStats` 异常未捕获，若 `getScenarioStats` 失败，`setState` 不会被调用，统计行直接消失且无任何错误提示。
- **文件位置**: [scenarios_screen.dart:37-44](file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L37-L44)
- **建议改进**: 增加 `try/catch`，失败时通过 SnackBar 提示并保留旧数据或显示占位。

---

### BL-052

## 53. 启动场景练习未处理创建会话异常

- **分类**: 场景练习 / 交互
- **严重级别**: 高
- **描述**: `_startScenario` 中 `createSession` 未处理异常；一旦仓库调用失败，后续 `context.push` 仍可能执行并导航到不存在的会话 ID，导致空白或错误页面。
- **文件位置**: [scenarios_screen.dart:46-55](file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L46-L55)
- **建议改进**: 对 `createSession` 添加 `try/catch`，失败时显示 SnackBar 并不做路由跳转。

---

### BL-053

## 54. 项目列表无刷新与重试机制

- **分类**: 项目管理 / 交互
- **严重级别**: 低
- **描述**: `ProjectsScreen` 项目列表无下拉刷新、无错误重试按钮。用户遇到网络/数据库异常后只能重启页面。
- **文件位置**: [projects_screen.dart:35-43](file:///workspace/lib/features/project_space/presentation/screens/projects_screen.dart#L35-L43)
- **建议改进**: 使用 `RefreshIndicator` 包裹列表；`error` 状态提供“重试”按钮。

---

### BL-054

## 55. 新建项目后未同步刷新关联内容

- **分类**: 项目管理 / 数据一致性
- **严重级别**: 中
- **描述**: 新建项目弹窗返回 `Project` 后仅 `invalidate(projectsProvider)`。若该新建流程用于“同时关联某内容”的场景，链接与活动数据不会同步刷新。
- **文件位置**: [projects_screen.dart:54-62](file:///workspace/lib/features/project_space/presentation/screens/projects_screen.dart#L54-L62)
- **建议改进**: 在需要关联内容的调用处一并刷新相关 `links`/`activities` Provider；或 `ProjectsScreen` 监听项目变化时主动刷新。

---

### BL-055

## 56. 取消项目关联无二次确认

- **分类**: 项目详情 / 交互
- **严重级别**: 高
- **描述**: `_LinksTab` 中点击“取消关联”图标直接执行 `removeLink`，没有二次确认。用户误触会立即丢失场景/会话与项目的关联。
- **文件位置**: [project_detail_screen.dart:223-231](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L223-L231)
- **建议改进**: 增加 `AlertDialog` 二次确认，确认后再删除。

---

### BL-056

## 57. 关联列表显示原始 contentId 而非可读标题

- **分类**: 项目详情 / 可读性
- **严重级别**: 中
- **描述**: 关联列表的 `ListTile.title` 直接显示 `contentId`（UUID 或原始 ID），用户无法识别这是哪个场景或会话。
- **文件位置**: [project_detail_screen.dart:219-222](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L219-L222)
- **建议改进**: 根据 `contentType` 查询对应场景/会话的标题并显示；无法解析时显示“未知内容”占位。

---

### BL-057

## 58. 取消关联后未更新项目活动时间戳

- **分类**: 项目详情 / 数据一致性
- **严重级别**: 中
- **描述**: 取消关联后仅刷新 `_linksProvider` 与 `_activitiesProvider`，未更新项目的 `updated_at` 与 `last_activity_at`。项目概览中的“最近活动”时间可能 stale。
- **文件位置**: [project_detail_screen.dart:226-231](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L226-L231)
- **建议改进**: 在 `ProjectRepository.removeLink` 中同步更新 `projects.updated_at` 与 `last_activity_at`；UI 端也刷新 `_projectProvider`。

---

### BL-058

## 59. 活动列表缺少时间戳与日期分组

- **分类**: 项目详情 / 可追溯性
- **严重级别**: 中
- **描述**: `_ActivityTab` 仅通过 `ActivityTile` 渲染活动，未显示精确时间戳或按日期分组。用户难以判断事件发生顺序与频率。
- **文件位置**: [project_detail_screen.dart:260-270](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L260-L270)
- **建议改进**: 在列表项中展示相对/绝对时间，并按天分组或增加分隔线。

---

### BL-059

## 60. 项目状态修改无加载与失败反馈

- **分类**: 项目详情 / 交互
- **严重级别**: 中
- **描述**: `_SettingsTab` 的状态修改 `DropdownButtonFormField.onChanged` 直接调用 `updateProject`，无加载态、无失败反馈。若写入失败，UI 下拉框已变但实际数据未更新。
- **文件位置**: [project_detail_screen.dart:291-307](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L291-L307)
- **建议改进**: 设置临时 loading 状态，失败时回滚下拉框并提示错误。

---

### BL-060

## 61. 设置页与 AppBar 编辑后刷新逻辑不一致

- **分类**: 项目详情 / 数据一致性
- **严重级别**: 低
- **描述**: `SettingsTab` 中的“编辑项目”按钮在保存后仅 `invalidate(_projectProvider)`，而 AppBar 的编辑按钮会同时刷新 `_linksProvider` 与 `_activitiesProvider`。两处行为不一致。
- **文件位置**: [project_detail_screen.dart:309-318](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L309-L318)
- **建议改进**: 统一编辑后的刷新逻辑；仅项目元数据变更时只刷新 `_projectProvider` 即可，避免过度刷新。

---

### BL-061

## 62. 删除项目后未清理 Provider 缓存

- **分类**: 项目详情 / 状态管理
- **严重级别**: 中
- **描述**: 删除项目后只调用 `context.pop()`，未显式 invalidate 各 Provider 缓存。返回项目列表时可能仍短暂显示已删除项目，或在其他页面引用已失效数据。
- **文件位置**: [project_detail_screen.dart:327-348](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L327-L348)
- **建议改进**: 删除成功后 `invalidate(projectsProvider)` 及相关 `links`/`activities` providers。

---

### BL-062

## 63. 项目概览未展示最近活动时间

- **分类**: 项目详情 / 信息展示
- **严重级别**: 低
- **描述**: `_OverviewTab` 未展示 `project.lastActivityAt`，项目卡片/列表强调“最近活跃”但详情页却不可见。
- **文件位置**: [project_detail_screen.dart:121-153](file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L121-L153)
- **建议改进**: 在概览头部增加“最近活动于 XXX”的辅助文本。

---

### BL-063

## 64. 删除项目非事务执行可能导致脏数据

- **分类**: 项目仓库 / 数据一致性
- **严重级别**: 高
- **描述**: `ProjectRepository.deleteProject` 分三次独立执行 `DELETE`，未使用事务。若中途抛异常，`projects` 表可能已删除但 `project_links`/`project_activities` 残留；反之亦然。
- **文件位置**: [project_repository.dart:131-138](file:///workspace/lib/features/project_space/data/project_repository.dart#L131-L138)
- **建议改进**: 使用 `db.transaction` 包裹三次删除，或启用外键级联删除。

---

### BL-064

## 65. 取消关联未同步更新项目排序时间

- **分类**: 项目仓库 / 数据一致性
- **严重级别**: 中
- **描述**: `removeLink` 仅删除 link 并记录活动，未同步更新 `projects.updated_at` 与 `last_activity_at`，导致项目列表按 `updated_at` 排序时无法反映“取消关联”这一变更。
- **文件位置**: [project_repository.dart:179-195](file:///workspace/lib/features/project_space/data/project_repository.dart#L179-L195)
- **建议改进**: 删除 link 后同步更新对应项目的 `updated_at` 与 `last_activity_at`。

---

### BL-065

## 66. 无字段变更也会记录 projectEdited 活动

- **分类**: 项目仓库 / 活动日志
- **严重级别**: 低
- **描述**: `updateProject` 每次调用都会记录 `projectEdited` 活动，即使没有任何字段实际变更。活动流会被无意义的重复记录污染。
- **文件位置**: [project_repository.dart:115-129](file:///workspace/lib/features/project_space/data/project_repository.dart#L115-L129)
- **建议改进**: 在调用前比较旧对象与新对象，仅当存在差异时才记录 `projectEdited`。

---

### BL-066

## 67. resetForTesting destructive 方法编译进生产代码

- **分类**: 项目仓库 / 安全
- **严重级别**: 中
- **描述**: `resetForTesting` 提供 `DROP TABLE` 能力并编译到生产代码中，虽注释说明仅测试使用，但仍存在被误调用导致用户数据全部丢失的风险。
- **文件位置**: [project_repository.dart:13-53](file:///workspace/lib/features/project_space/data/project_repository.dart#L13-L53)
- **建议改进**: 将该方法迁移至测试夹具或 `#if DEBUG` 条件编译；生产代码中移除。

---

### BL-067

## 68. 新建项目并关联内容非原子操作

- **分类**: 加入项目 / 事务与容错
- **严重级别**: 高
- **描述**: `JoinProjectSheet._onNewProject` 先创建项目再调用 `addLink`，两步之间无事务。若 `addLink` 失败，项目已孤立创建但内容未关联，用户以为已完成。
- **文件位置**: [join_project_sheet.dart:140-152](file:///workspace/lib/features/project_space/presentation/widgets/join_project_sheet.dart#L140-L152)
- **建议改进**: 在仓库层提供 `createProjectAndLink` 原子操作；或失败后提示用户并允许重试关联。

---

### BL-068

## 69. 加入项目时 addLink 异常未处理

- **分类**: 加入项目 / 交互
- **严重级别**: 中
- **描述**: `JoinProjectSheet` 中点击未关联项目执行 `addLink` 时未捕获异常。若数据库写入失败，底部弹窗保持打开但无任何提示，用户无法判断操作是否成功。
- **文件位置**: [join_project_sheet.dart:123-130](file:///workspace/lib/features/project_space/presentation/widgets/join_project_sheet.dart#L123-L130)
- **建议改进**: 增加 `try/catch`，失败时通过 SnackBar 提示；成功后再关闭弹窗并返回 `true`。

---

### BL-069

## 70. 已关联项目无法在弹窗内解绑

- **分类**: 加入项目 / 交互
- **严重级别**: 低
- **描述**: 已关联项目仅显示勾选图标且 `onTap` 为 `null`，用户无法在当前弹窗内取消关联。若误关联，必须前往项目详情才能解除。
- **文件位置**: [join_project_sheet.dart:111-131](file:///workspace/lib/features/project_space/presentation/widgets/join_project_sheet.dart#L111-L131)
- **建议改进**: 提供“取消关联”切换，或至少显示“已加入 X 个项目”并允许跳转管理。

---

*本次新增 23 条问题，累计 47 条。*

## 新增分析范围：设置、Profile CRUD、服务配置、API Key 管理、活动 Profile 切换、Provider 选择

### BL-070

## 71. 设置页加载设置时未处理异常，失败会永久显示 loading

- **分类**: 设置 / 容错
- **严重级别**: 高
- **描述**: `SettingsScreen._loadSettings` 顺序 await `profileRepo` 与 `chatRepo` 的多个读取方法，没有任何 try/catch。一旦任意一次读取抛出异常（如 DB 损坏、secure storage 失败），`_isLoading` 不会置为 false，用户只能看到无限转圈，无法进入设置页。
- **文件位置**: [settings_screen.dart:38-59](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L38-L59)
- **建议改进**: 用 try/catch 包裹加载流程，出错时显示 SnackBar/错误页并提供“重试”按钮；确保 `finally` 中 `_isLoading = false`。

---

### BL-071

## 72. 设置页状态只在 initState 加载一次，无法感知外部修改

- **分类**: 设置 / 状态同步
- **严重级别**: 中
- **描述**: 纠错强度、TTS 速度、主题、内容开关、每日推荐数、教师 persona 等全部放在 StatefulWidget 本地变量，仅在 `initState` 拉取一次。其他页面或后台任务修改同一设置后返回，UI 仍显示旧值。
- **文件位置**: [settings_screen.dart:22-59](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L22-L59)
- **建议改进**: 将常用设置提升为 Riverpod Provider（或监听已有 shared providers），页面通过 `ref.watch` 自动刷新。

---

### BL-072

## 73. 开关类设置持久化失败时 UI 已提前翻转，造成状态不一致

- **分类**: 设置 / 状态一致性
- **严重级别**: 中
- **描述**: `_toggleLowBandwidth`、`_toggleContentEnabled` 先调用 `setState` 更新本地/全局状态，再 await 持久化。持久化失败时 UI 已显示新值，但下次启动会恢复旧值。
- **文件位置**: [settings_screen.dart:64-78](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L64-L78)
- **建议改进**: 先执行持久化，成功后再更新状态；或在失败时回滚并提示用户。

---

### BL-073

## 74. 当前 profile 连接测试文案未国际化且 `Navigator.pop` 不在安全位置

- **分类**: 设置 / 国际化 / 容错
- **严重级别**: 中
- **描述**: `_testCurrentProfile` 中测试结果前缀 `'LLM:'`、`'STT:'`、`'TTS:'` 与加载中 `'Testing…'` 均为硬编码英文；`rootNav.pop()` 位于 try/catch 外部，若 Navigator 栈异常会抛出未捕获异常。
- **文件位置**: [settings_screen.dart:432-516](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L432-L516)
- **建议改进**: 所有面向用户的文案使用 `AppLocalizations` key；将 `rootNav.pop()` 移入 `try/finally`，并判断 `canPop`。

---

### BL-074

## 75. 教师 persona 标签硬编码只识别三种 ID

- **分类**: 设置 / 可扩展性
- **严重级别**: 低
- **描述**: `_activePersonaLabel` 只把 `persona_strict`、`persona_humor` 映射到对应风格，其它 ID 全部回退到 encourage。新增 persona 时设置页副标题展示不正确。
- **文件位置**: [settings_screen.dart:82-90](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L82-L90)
- **建议改进**: 在 `TeacherPersonaStyle` 中提供 `fromId` 通用映射，或在数据库中保存 persona 显示名称。

---

### BL-075

## 76. 服务配置页只在 initState 加载，返回后列表不刷新

- **分类**: 服务配置 / 状态同步
- **严重级别**: 高
- **描述**: `ServiceConfigScreen._loadProfiles` 仅在 `initState` 调用。从 `ProfileFormScreen` 保存返回后，新增/编辑/删除的 profile 不会立即反映，用户可能误以为保存失败。
- **文件位置**: [service_config_screen.dart:32-51](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L32-L51)
- **建议改进**: 使用 `didChangeDependencies` / `onResume` 回调重新加载，或将列表数据改为 Riverpod Future/StateProvider。

---

### BL-076

## 77. 点击整卡切换 active profile 无确认，易误触

- **分类**: 服务配置 / 交互
- **严重级别**: 中
- **描述**: `_buildProfileCard` 将整个卡片设为可点击，点击任何位置都会立即调用 `_activateProfile`。在配置较多或滚动时容易误触，影响当前正在使用的服务配置。
- **文件位置**: [service_config_screen.dart:202-215](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L202-L215)、[service_config_screen.dart:396-410](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L396-L410)
- **建议改进**: 将激活操作改为单独的 radio/activate 按钮，或在点击后增加确认弹窗。

---

### BL-077

## 78. 激活 profile 后未刷新依赖 active profile 的全局 Provider/Service

- **分类**: 活动 profile 切换 / 状态同步
- **严重级别**: 高
- **描述**: `_activateProfile` 只修改 DB 并重新加载本页列表，没有 invalidate 或通知使用 active profile 的 Service/Provider。聊天页、TTS 服务等可能继续使用旧的 active profile，直到下次冷启动。
- **文件位置**: [service_config_screen.dart:396-410](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L396-L410)
- **建议改进**: 激活后调用 `ref.invalidate(activeProfileProvider)` 或广播通知；服务层在下次请求前重新读取 active profile。

---

### BL-078

## 79. 删除 profile 时先删 key 再删 DB，DB 失败会导致 key 丢失

- **分类**: Profile CRUD / API Key 管理
- **严重级别**: 中
- **描述**: `ProfileRepository.delete*Profile` 在删除 DB 行之前先调用 `SecureStorageService.deleteApiKey`。若后续 DB 删除失败，profile 仍存在但 key 已不可恢复。
- **文件位置**: [profile_repository.dart:135-147](file:///workspace/lib/features/profile/data/profile_repository.dart#L135-L147)、[profile_repository.dart:201-212](file:///workspace/lib/features/profile/data/profile_repository.dart#L201-L212)、[profile_repository.dart:266-277](file:///workspace/lib/features/profile/data/profile_repository.dart#L266-L277)
- **建议改进**: 先删除 DB 行，成功后再删除 secure storage；或把两者放入事务/补偿机制。

---

### BL-079

## 80. `getAll*Profiles` 逐个读取 secure storage，存在 N+1 性能问题

- **分类**: Profile CRUD / API Key 管理
- **严重级别**: 中
- **描述**: 每加载一个 profile 都单独读一次 secure storage。profile 数量较多时，服务配置页和设置页测试功能会明显卡顿。
- **文件位置**: [profile_repository.dart:83-94](file:///workspace/lib/features/profile/data/profile_repository.dart#L83-L94)、[profile_repository.dart:151-161](file:///workspace/lib/features/profile/data/profile_repository.dart#L151-L161)、[profile_repository.dart:216-226](file:///workspace/lib/features/profile/data/profile_repository.dart#L216-L226)
- **建议改进**: 批量读取所有 key（如 secure storage 支持前缀查询）或缓存 keys map。

---

### BL-080

## 81. `setActive*Profile` 不校验目标 ID 是否存在

- **分类**: 活动 profile 切换 / Profile CRUD
- **严重级别**: 中
- **描述**: `setActive*Profile` 先把该类型所有 profile 置为非 active，再更新目标 ID。如果 ID 无效或已被删除，会导致该类型没有任何 active profile，且调用方无法感知。
- **文件位置**: [profile_repository.dart:122-133](file:///workspace/lib/features/profile/data/profile_repository.dart#L122-L133)、[profile_repository.dart:188-199](file:///workspace/lib/features/profile/data/profile_repository.dart#L188-L199)、[profile_repository.dart:253-264](file:///workspace/lib/features/profile/data/profile_repository.dart#L253-L264)
- **建议改进**: 更新前查询目标记录，不存在时抛出明确异常；或返回更新行数供调用方判断。

---

### BL-081

## 82. `delete*Profile` 检查 active 状态不是原子操作

- **分类**: Profile CRUD / 并发
- **严重级别**: 中
- **描述**: `delete*Profile` 先查询是否 active，再执行删除。两个操作之间若用户或另一流程切换 active，可能误删 active profile。
- **文件位置**: [profile_repository.dart:135-147](file:///workspace/lib/features/profile/data/profile_repository.dart#L135-L147)、[profile_repository.dart:201-212](file:///workspace/lib/features/profile/data/profile_repository.dart#L201-L212)、[profile_repository.dart:266-277](file:///workspace/lib/features/profile/data/profile_repository.dart#L266-L277)
- **建议改进**: 在 transaction 内合并为带条件的 delete，如 `DELETE FROM ... WHERE id=? AND is_active=0`。

---

### BL-082

## 83. `save*Profile` API key 与 DB 写入分离，无事务一致性

- **分类**: Profile CRUD / API Key 管理
- **严重级别**: 中
- **描述**: `save*Profile` 先写 secure storage，再写 SQLite。任意一步失败都会导致 key 与 DB 不同步（如 DB 写入失败则 profile 存了占位符，后续读取 key 为空）。
- **文件位置**: [profile_repository.dart:109-120](file:///workspace/lib/features/profile/data/profile_repository.dart#L109-L120)、[profile_repository.dart:176-186](file:///workspace/lib/features/profile/data/profile_repository.dart#L176-L186)、[profile_repository.dart:241-251](file:///workspace/lib/features/profile/data/profile_repository.dart#L241-L251)
- **建议改进**: 捕获写入异常并回滚前一步操作；或在读取时校验 key 是否为空并给出提示。

---

### BL-083

## 84. Profile 表单加载现有档案时静默吞掉所有异常

- **分类**: Profile CRUD / 容错
- **严重级别**: 中
- **描述**: `ProfileFormScreen._loadExistingProfile` 的 catch 块为空。DB 或 secure storage 异常时用户看到空表单，还以为这是一个新建页面。
- **文件位置**: [profile_form_screen.dart:131-183](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L131-L183)
- **建议改进**: 区分“未找到”与“读取失败”，后者显示错误提示并提供重试/返回入口。

---

### BL-084

## 85. 保存 profile 时 API Key 与名称未 trim

- **分类**: Profile CRUD / API Key 管理
- **严重级别**: 高
- **描述**: `_saveProfile` 直接保存 `_keyController.text` 与 `_nameController.text`，未去除首尾空格。用户从其他 App 复制密钥时极易带入前后空格或换行，导致后续所有请求 401。
- **文件位置**: [profile_form_screen.dart:945-1015](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L945-L1015)
- **建议改进**: 保存前对 key、name、baseUrl、model 统一 `trim()`；对 key 过滤常见换行/空格。

---

### BL-085

## 86. 新建 profile 保存后不会自动激活

- **分类**: Profile CRUD / 活动 profile 切换
- **严重级别**: 高
- **描述**: 当用户创建第一个 profile 或当前该类型无任何 active profile 时，保存后返回服务配置页，新 profile 仍是非 active 状态，聊天、语音识别、语音合成等功能无法使用。
- **文件位置**: [profile_form_screen.dart:945-1015](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L945-L1015)
- **建议改进**: 保存成功后检测该类型 active profile；若为空则自动激活新 profile，并提示用户。

---

### BL-086

## 87. 连接测试/获取模型时模型为空使用硬编码 `gpt-3.5-turbo` 回退

- **分类**: Profile CRUD / Provider 选择
- **严重级别**: 中
- **描述**: `_testConnection` 与 `_fetchModels` 在模型输入为空时硬编码回退到 `'gpt-3.5-turbo'`，而保存时回退到 `_providerDef.defaultModel`。可能出现“测试通过、保存后模型为空”的情况，导致正式请求失败。
- **文件位置**: [profile_form_screen.dart:733-741](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L733-L741)、[profile_form_screen.dart:880-888](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L880-L888)
- **建议改进**: 统一回退到 `_providerDef.defaultModel`；若该 provider 无默认值则禁止测试/保存并提示。

---

### BL-087

## 88. 连接测试无超时控制，可能长时间卡住 UI

- **分类**: Profile CRUD / 交互
- **严重级别**: 中
- **描述**: `ProfileFormScreen._testConnection` 未包裹 `.timeout()`。网络异常或厂商响应缓慢时按钮长时间处于 loading，用户无法取消。
- **文件位置**: [profile_form_screen.dart:860-923](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L860-L923)
- **建议改进**: 添加 15s 超时并支持取消；超时后给出明确提示。

---

### BL-088

## 89. 获取模型/音色列表无超时，且 Azure TTS 未校验 region

- **分类**: Profile CRUD / Provider 选择
- **严重级别**: 中
- **描述**: `_fetchModels` / `_fetchVoices` 同样无超时；`_fetchVoices` 在 Azure TTS 等需要 region 的 provider 时未校验 region 字段，请求必然失败。
- **文件位置**: [profile_form_screen.dart:724-761](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L724-L761)、[profile_form_screen.dart:763-797](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L763-L797)
- **建议改进**: 统一加超时；对需要 region 的 provider 在 fetch 前校验 region 非空。

---

### BL-089

## 90. `_saveProfile` 手动拼接 region JSON 未转义

- **分类**: Profile CRUD / 数据解析
- **严重级别**: 中
- **描述**: `_saveProfile` 通过字符串插值生成 `{"region":"..."}`，如果 region 包含 `"` 会生成非法 JSON，后续 `region` getter 解析时可能崩溃。
- **文件位置**: [profile_form_screen.dart:955-957](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L955-L957)
- **建议改进**: 使用 `jsonEncode({'region': _regionController.text.trim()})` 生成 extraConfig。

---

### BL-090

## 91. STT 语言字段默认值硬编码为 en-US

- **分类**: Profile CRUD / 国际化
- **严重级别**: 中
- **描述**: `_languageController` 初始化为 `'en-US'`，保存时若为空仍回退到 `'en-US'`。中文用户创建 STT profile 后默认语音识别期望英文输入。
- **文件位置**: [profile_form_screen.dart:36](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L36)、[profile_form_screen.dart:981-983](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L981-L983)
- **建议改进**: 根据应用 locale 或 provider 默认语言初始化；UI 提供语言选择。

---

### BL-091

## 92. API Key 输入框只隐藏无显示切换

- **分类**: Profile CRUD / API Key 管理
- **严重级别**: 低
- **描述**: `_buildApiKeyField` 使用 `obscureText: true` 始终隐藏 key，用户无法自查是否多复制了空格、换行或字符。
- **文件位置**: [profile_form_screen.dart:631-659](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L631-L659)
- **建议改进**: 添加眼睛图标切换 `obscureText`。

---

### BL-092

## 93. 切换 provider 直接覆盖已填写字段，无撤销/确认

- **分类**: Profile CRUD / Provider 选择 / 交互
- **严重级别**: 中
- **描述**: 用户选择不同 provider 时，`_applyProviderDefaults(overwriteAll: true)` 会立即覆盖 URL、model、voice 等字段。若用户已手动输入大量自定义内容，误选 provider 后无法恢复。
- **文件位置**: [profile_form_screen.dart:115-129](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L115-L129)、[profile_form_screen.dart:284-290](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L284-L290)
- **建议改进**: 切换 provider 前提示是否覆盖；或仅对空字段填充默认值。

---

### BL-093

## 94. 复用 STT 配置按钮文案未国际化且未同步 model/voice/region

- **分类**: Profile CRUD / Provider 选择 / 国际化
- **严重级别**: 中
- **描述**: `_reuseSttConfig` 的提示文字为硬编码中文/英文；复制后只设置 baseUrl 与 key，model/voice/region 保持旧值，可能与目标 TTS provider 不匹配。
- **文件位置**: [profile_form_screen.dart:540-581](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L540-L581)
- **建议改进**: 文案走 `AppLocalizations`；复制 provider 后根据映射的 TTS provider 重新应用默认值。

---

### BL-094

## 95. Profile 表单存在大量硬编码英文文案

- **分类**: Profile CRUD / 国际化
- **严重级别**: 高
- **描述**: 页面标题、字段标签（Profile Name / Provider / API Base URL 等）、按钮（Save / Cancel / Test Connection）、提示（Profile saved!）全部为硬编码英文，非英语用户无法使用。
- **文件位置**: [profile_form_screen.dart:97-108](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L97-L108)、[profile_form_screen.dart:250](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L250)、[profile_form_screen.dart:270](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L270)、[profile_form_screen.dart:414](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L414)、[profile_form_screen.dart:489](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L489)、[profile_form_screen.dart:636](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L636)、[profile_form_screen.dart:674](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L674)、[profile_form_screen.dart:698](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L698) 等
- **建议改进**: 全部替换为 `AppLocalizations` key，补全 ARB。

---

### BL-095

## 96. 导入 profile 只接受粘贴 JSON，且对任何错误只显示 "Invalid JSON"

- **分类**: 服务配置 / 导入导出
- **严重级别**: 中
- **描述**: `_importProfiles` 没有文件选择器，要求用户手动粘贴 JSON；catch 所有异常统一提示 "Invalid JSON"，DB 异常、schema 错误等被掩盖。
- **文件位置**: [service_config_screen.dart:458-519](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L458-L519)
- **建议改进**: 提供文件选择器；根据异常类型给出具体提示（JSON 格式错误、schema 不兼容、DB 失败）。

---

### BL-096

## 97. 导入会把导出时掩码的 API Key 当作真实 key 保存

- **分类**: 服务配置 / 导入导出 / API Key 管理
- **严重级别**: 高
- **描述**: 导出时 key 被 mask 成 `sk-ab****cdef`，导入后该字符串被写入 secure storage。用户若未重新编辑，后续请求会 401。
- **文件位置**: [service_config_screen.dart:500-511](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L500-L511)、[profile_repository.dart:343-365](file:///workspace/lib/features/profile/data/profile_repository.dart#L343-L365)、[profile_repository.dart:368-430](file:///workspace/lib/features/profile/data/profile_repository.dart#L368-L430)
- **建议改进**: 导入时检测掩码/占位符模式，将 key 置空并在 UI 强制用户重新输入。

---

### BL-097

## 98. 导入/导出未校验 schema 版本，未来字段变更会崩溃

- **分类**: 服务配置 / 导入导出
- **严重级别**: 中
- **描述**: 导出写入 `version:1` 但导入不检查 version，也不校验必填字段类型。旧版本或损坏数据导入后可能在运行时触发空指针/类型转换异常。
- **文件位置**: [profile_repository.dart:352](file:///workspace/lib/features/profile/data/profile_repository.dart#L352)、[profile_repository.dart:368-430](file:///workspace/lib/features/profile/data/profile_repository.dart#L368-L430)
- **建议改进**: 导入时校验 `version` 范围与字段类型，不兼容时给出明确报错。

---

### BL-098

## 99. Provider 目录包含当前服务层未实现的厂商

- **分类**: Provider 选择 / 业务逻辑
- **严重级别**: 高
- **描述**: `volcengine_stt`/`xfyun_stt`/`tencent_stt`/`volcengine_tts`/`xfyun_tts`/`tencent_tts` 的 note 已写明“需自建中转适配”，说明服务层大概率没有适配；用户选择后无法直接使用。
- **文件位置**: [provider_catalog.dart:283-308](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L283-L308)、[provider_catalog.dart:461-494](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L461-L494)
- **建议改进**: 移除未实现的 provider，或标记为“实验性/需中转”并给出配置向导。

---

### BL-099

## 100. Azure / 部分厂商 defaultBaseUrl 含 `{region}` 占位符且未替换

- **分类**: Provider 选择 / Profile CRUD
- **严重级别**: 中
- **描述**: Azure STT/TTS 的 `defaultBaseUrl` 为 `https://{region}.stt.speech.microsoft.com`，但 `_buildTempTtsProfile` 直接将其传给 `TtsService`。若服务层未替换占位符，会请求到非法 URL。
- **文件位置**: [provider_catalog.dart:256](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L256)、[provider_catalog.dart:407](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L407)、[profile_form_screen.dart:799-814](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L799-L814)
- **建议改进**: 在创建临时 profile 或 UI 展示前用 `region` 替换占位符；或在 catalog 提供 `buildBaseUrl(region)` 方法。

---

### BL-100

## 101. 硬编码 voices 列表无法随供应商更新

- **分类**: Provider 选择 / 可维护性
- **严重级别**: 低
- **描述**: OpenAI/Google/Aliyun 等音色写死在代码中。供应商新增 voice 后，用户无法选择，只能手动输入 voice id。
- **文件位置**: [provider_catalog.dart:336-366](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L336-L366)、[provider_catalog.dart:377](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L377)、[provider_catalog.dart:422-423](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L422-L423)、[provider_catalog.dart:433](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L433)、[provider_catalog.dart:467-471](file:///workspace/lib/features/profile/domain/provider_catalog.dart#L467-L471)
- **建议改进**: 对支持 list endpoint 的 provider 优先动态获取；对静态列表提供“自定义输入”兜底。

---

### BL-101

## 102. Profile 模型缺少业务级校验，可保存空名称/空 URL

- **分类**: Profile CRUD / 数据模型
- **严重级别**: 中
- **描述**: `LlmProfile`/`SttProfile`/`TtsProfile` 构造函数只要求 `name`，未校验非空；`baseUrl`/`model` 等可传入空字符串。即使 UI 校验，模型层仍可能创建无效对象。
- **文件位置**: [profile_models.dart:24-36](file:///workspace/lib/features/profile/domain/profile_models.dart#L24-L36)、[profile_models.dart:116-130](file:///workspace/lib/features/profile/domain/profile_models.dart#L116-L130)、[profile_models.dart:255-271](file:///workspace/lib/features/profile/domain/profile_models.dart#L255-L271)
- **建议改进**: 在模型层或仓库层增加断言/校验，如 `name.trim().isNotEmpty`、对 openaiCompatible 校验 URL scheme。

---

### BL-102

## 103. `region` 解析使用正则而非 JSON 解析，鲁棒性差

- **分类**: Profile CRUD / 数据解析
- **严重级别**: 中
- **描述**: `SttProfile.region` 与 `TtsProfile.region` 使用 RegExp 从 `extraConfig` 中提取 region，格式稍有变化（如单引号、空格、嵌套对象）即失败。
- **文件位置**: [profile_models.dart:139-150](file:///workspace/lib/features/profile/domain/profile_models.dart#L139-L150)、[profile_models.dart:279-283](file:///workspace/lib/features/profile/domain/profile_models.dart#L279-L283)
- **建议改进**: 使用 `jsonDecode` 解析 `extraConfig` 并缓存结果。

---

### BL-103

## 104. `fromMap` 直接 `DateTime.parse` 无异常处理

- **分类**: Profile CRUD / 数据模型
- **严重级别**: 中
- **描述**: 如果 DB 中 `created_at`/`updated_at` 损坏或为空，`DateTime.parse` 抛出异常，会导致整个 profile 列表加载失败。
- **文件位置**: [profile_models.dart:87-89](file:///workspace/lib/features/profile/domain/profile_models.dart#L87-L89)、[profile_models.dart:224-226](file:///workspace/lib/features/profile/domain/profile_models.dart#L224-L226)、[profile_models.dart:364-366](file:///workspace/lib/features/profile/domain/profile_models.dart#L364-L366)
- **建议改进**: 使用 `DateTime.tryParse` 并给出默认值，或过滤损坏记录。

---

*本次新增 34 条问题，累计 104 条问题。*

## UI/UX / 视觉设计（源码）（53 条）

### UX-001

## 1
- **编号**: 1
- **分类**: 颜色体系
- **严重级别**: 中
- **描述**: 暗色/亮色主题颜色成对独立命名（如 `accentPrimary` / `lightAccentPrimary`），切换主题时需要大量条件判断，无法通过 `Theme.of(context).colorScheme` 自动派生，维护成本高。
- **文件位置**: [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L27-L29) / [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L87-L88)
- **建议改进**: 采用语义化 ColorScheme 单一调色板，通过 `ThemeData` 的 `brightness` 在不同主题间复用同一套 token。

### UX-002

## 2
- **编号**: 2
- **分类**: 颜色体系
- **严重级别**: 低
- **描述**: `bgSurface` 与 `glassBg` 使用完全相同的色值 `Color(0x0FFFFFFF)`，语义不同却颜色一致，容易造成误用。
- **文件位置**: [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L10) / [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L13)
- **建议改进**: 合并为同一个 surface token，或根据实际用途区分透明度/色值。

### UX-003

## 3
- **编号**: 3
- **分类**: 无障碍 / 对比度
- **严重级别**: 中
- **描述**: `textMuted` 注释称“improved contrast ~4.5:1”，但未提供验证逻辑；且 `textSecondary` 与 `textMuted` 色值接近，在 `bgTertiary` 等背景上可能不满足 WCAG AA。
- **文件位置**: [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L40-L41)
- **建议改进**: 在主题单元测试中增加对比度断言；若不足则提亮 `textMuted` 或仅用于装饰性文本。

### UX-004

## 4
- **编号**: 4
- **分类**: 颜色体系
- **严重级别**: 中
- **描述**: 聊天泡泡仅定义了背景色（半透明强调色），未定义前景文字颜色，直接放置文字可能对比度不足。
- **文件位置**: [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L121-L126)
- **建议改进**: 为每种泡泡定义 `onBubbleAi` / `onBubbleUser` 等文本色，并确保对比度 ≥ 4.5:1。

### UX-005

## 5
- **编号**: 5
- **分类**: Material 主题配置
- **严重级别**: 高
- **描述**: `ColorScheme` 仅声明 `primary/secondary/surface/error` 等基础槽位，缺少 `inversePrimary`、`surfaceTint`、`outline`、`shadow`、`surfaceVariant/Container`、`tertiary` 等 Material 3 槽位。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L12-L21) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L129-L138)
- **建议改进**: 补齐 M3 ColorScheme 全量槽位，或改用 `ColorScheme.fromSeed` / `ColorScheme.fromImageProvider` 生成一致调色板。

### UX-006

## 6
- **编号**: 6
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: 大量 Material 组件未配置主题（Dialog、BottomSheet、Chip、Switch、Checkbox、Radio、Slider、FAB、NavigationBar、TabBar 等），会回退到默认样式，可能与暗色/玻璃拟态视觉冲突。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart)
- **建议改进**: 至少补充 `dialogTheme`、`bottomSheetTheme`、`chipTheme`、`switchTheme`、`navigationBarTheme` 等，并统一色调。

### UX-007

## 7
- **编号**: 7
- **分类**: 排版
- **严重级别**: 高
- **描述**: `TextStyle` 硬编码 `fontFamily = 'Inter'`，未声明 fallback 字体；若资源缺失将回退到系统默认字体，导致界面跳变。
- **文件位置**: [app_text_styles.dart](file:///workspace/lib/core/theme/app_text_styles.dart#L4)
- **建议改进**: 增加 `fontFamilyFallback: ['Inter', 'Roboto', 'sans-serif']` 并按平台做适配。

### UX-008

## 8
- **编号**: 8
- **分类**: 排版
- **严重级别**: 中
- **描述**: `TextTheme` 仅映射了 6 个槽位（`displayLarge/headlineLarge/titleLarge/bodyLarge/bodyMedium/labelSmall`），缺少 `headlineMedium`、`headlineSmall`、`titleMedium`、`titleSmall`、`bodySmall`、`labelLarge` 等，其他组件会回退到默认 Roboto 字号。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L22-L29) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L139-L158)
- **建议改进**: 建立完整的 Material TextTheme 映射表，确保所有文本槽位使用同一字体家族。

### UX-009

## 9
- **编号**: 9
- **分类**: 排版
- **严重级别**: 中
- **描述**: `displayLarge` 字号仅 32，远低于 Material 3 `displayLarge` 规范（57 dp），命名与实际尺寸不匹配。
- **文件位置**: [app_text_styles.dart](file:///workspace/lib/core/theme/app_text_styles.dart#L6-L12) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L23)
- **建议改进**: 按 M3 类型比例重新命名或调整字号，补充 `displaySmall / displayMedium / displayLarge` 梯度。

### UX-010

## 10
- **编号**: 10
- **分类**: 排版
- **严重级别**: 低
- **描述**: 按钮文字 `lineHeight = 1.0`，可能导致下伸部被截断，且视觉上中心偏上。
- **文件位置**: [app_text_styles.dart](file:///workspace/lib/core/theme/app_text_styles.dart#L65-L79)
- **建议改进**: 将按钮 `height` 调整为 1.2–1.4，并验证不同语言/字号下的垂直居中。

### UX-011

## 11
- **编号**: 11
- **分类**: 排版
- **严重级别**: 中
- **描述**: `AppTextStyles.bodyMedium`（16/w500）与 `ThemeData.textTheme.bodyMedium` 映射的 `AppTextStyles.caption`（14/w400）语义不一致，命名与映射会造成使用困惑。
- **文件位置**: [app_text_styles.dart](file:///workspace/lib/core/theme/app_text_styles.dart#L36-L41) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L27)
- **建议改进**: 统一命名规范，使 `bodyMedium` 常量与 TextTheme 的 `bodyMedium` 语义一致。

### UX-012

## 12
- **编号**: 12
- **分类**: 排版
- **严重级别**: 中
- **描述**: 所有字号与行高均为固定 dp，未考虑系统字体缩放或响应式布局，辅助功能开启大字体时可能溢出。
- **文件位置**: [app_text_styles.dart](file:///workspace/lib/core/theme/app_text_styles.dart)
- **建议改进**: 在 TextStyle 中结合 `MediaQuery.textScaler` 或采用 `ThemeData.textTheme` 的响应式比例。

### UX-013

## 13
- **编号**: 13
- **分类**: 间距常量
- **严重级别**: 中
- **描述**: `AppSpacing` 仅提供 4/8/12/16/24/32/48，缺少 20/28/36/40/56/64 等中间值，开发者容易写 `+4` / `+8` 魔法数。
- **文件位置**: [app_constants.dart](file:///workspace/lib/core/constants/app_constants.dart#L1-L9)
- **建议改进**: 扩展 4dp/8dp 网格阶梯，或引入 `screenPadding`、`cardPadding`、`sectionGap` 等语义 token。

### UX-014

## 14
- **编号**: 14
- **分类**: 间距常量
- **严重级别**: 中
- **描述**: 按钮内边距直接使用 `AppSpacing.sm + 4` 这种混合计算，未定义语义化的按钮垂直内边距 token。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L73-L76) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L204-L207)
- **建议改进**: 新增 `AppSpacing.buttonVertical` / `buttonHorizontal` 等语义常量，避免在主题中做算数拼接。

### UX-015

## 15
- **编号**: 15
- **分类**: 间距常量
- **严重级别**: 低
- **描述**: `AppRadius.full = 999` 用于全圆角，但对超大组件不够语义化，且极端宽高比时可能呈现不完美的圆角。
- **文件位置**: [app_constants.dart](file:///workspace/lib/core/constants/app_constants.dart#L18)
- **建议改进**: 使用 `StadiumBorder` 或引入 `pill`、`rounded`、`full` 等语义 token；超大圆角可用 `double.infinity` 配合 Stadium。

### UX-016

## 16
- **编号**: 16
- **分类**: 间距常量
- **严重级别**: 低
- **描述**: `AppDurations` 中 `normal`（250 ms）与 `medium`（300 ms）语义重叠，没有明确使用场景，容易混用。
- **文件位置**: [app_constants.dart](file:///workspace/lib/core/constants/app_constants.dart#L22-L25)
- **建议改进**: 统一命名（如 fast/normal/slow）或补充用途注释；同时补充常用动画曲线常量。

### UX-017

## 17
- **编号**: 17
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: `DividerThemeData` 的 `space` 设为 1，等于厚度，导致分隔线紧贴内容，缺少默认 16 dp 的上下留白。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L106-L110) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L239-L243)
- **建议改进**: 将 `space` 设为至少 16，或在需要紧凑分隔的地方局部覆盖。

### UX-018

## 18
- **编号**: 18
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: 暗色 `SnackBar` 背景使用 `bgTertiary`，未显式配置 `actionTextColor`，默认 action 颜色可能与内容文字区分度不足。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L111-L120)
- **建议改进**: 配置 `actionTextColor` 或 `contentTextStyle`，并使用 `inverseSurface / onInverseSurface` 表达 SnackBar 作为浮层面板的层级。

### UX-019

## 19
- **编号**: 19
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: 亮色 `SnackBar` 背景使用 `lightGlassBg`（80% 白），在浅色 scaffold 上可能因半透明而对比度不足。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L244-L254)
- **建议改进**: 使用不透明的 surface 色作为背景，或提高不透明度，并配置 elevation/shadow 以区分层级。

### UX-020

## 20
- **编号**: 20
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: `TextButton` 仅配置 `foregroundColor`，未设置 `overlayColor` / `splashFactory`，默认 Ripple 颜色可能与深色玻璃风格不协调。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L97-L102) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L228-L233)
- **建议改进**: 配置低透明度 `overlayColor`（如 white 8%）并统一 `splashFactory` 为 `InkRipple` 或 `InkHighlight`。

### UX-021

## 21
- **编号**: 21
- **分类**: Material 主题配置
- **严重级别**: 低
- **描述**: `IconButtonTheme` 只设置 `foregroundColor`，缺少 `disabledColor`、`selectedColor`、`hoverColor` 等状态色。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L103-L105) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L234-L238)
- **建议改进**: 补充各状态颜色，或依赖 `ColorScheme.onSurfaceVariant` 与 `ColorScheme.primary` 表达选中和禁用态。

### UX-022

## 22
- **编号**: 22
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: 暗色输入框 `fillColor` 使用 `bgTertiary`，边界色使用 `glassBorder`（white 8%），低对比度边界在部分屏幕上几乎不可见。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L44-L67)
- **建议改进**: 将 `enabledBorder` 颜色提高到 white 16–20%，或提供 `outline` 语义 token，确保输入框边界可识别。

### UX-023

## 23
- **编号**: 23
- **分类**: 颜色体系
- **严重级别**: 中
- **描述**: 亮色模式下 `bubbleAi` / `bubbleUser` 使用 25% 透明度强调色，在浅色背景上饱和度/对比度可能过强或不足，影响可读性。
- **文件位置**: [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart#L124-L126)
- **建议改进**: 在浅色模式下使用更柔和的容器色（如 `surfaceContainer` 变体），并针对文本颜色做对比度测试。

### UX-024

## 24
- **编号**: 24
- **分类**: Material 主题配置
- **严重级别**: 中
- **描述**: 主题未配置 `visualDensity` 与 `pageTransitionsTheme`，在手机/平板/桌面端布局密度与页面转场行为不一致。
- **文件位置**: [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart)
- **建议改进**: 设置 `visualDensity: VisualDensity.adaptivePlatformDensity`，并配置统一的 `pageTransitionsTheme`。

### UX-025

## 25
- **编号**: 25
- **分类**: 颜色体系
- **严重级别**: 中
- **描述**: 缺少 disabled、占位、加载状态颜色；`ColorScheme` 中无 `onSurfaceVariant`、`outlineVariant`、`disabled` 等，禁用组件会回退到默认灰色。
- **文件位置**: [app_colors.dart](file:///workspace/lib/core/theme/app_colors.dart) / [app_theme.dart](file:///workspace/lib/core/theme/app_theme.dart#L12-L21)
- **建议改进**: 在 `ColorScheme` 中补充 `onSurfaceVariant`、`outline`、`outlineVariant`、`shadow` 等槽位，并定义语义化的 disabled 颜色常量。

## 新增：响应式布局、断点、方向、Shell 导航与玻璃拟态问题

| 编号 | 分类 | 严重级别 | 描述 | 文件位置 | 建议改进 |
|------|------|----------|------|----------|----------|
| 31 | 响应式断点/适配 | 中 | Responsive 中 600/768/900/1240/1400 等断点阈值全部硬编码，未提取为命名常量，维护困难且易出现口径不一致。 | file:///workspace/lib/core/util/responsive.dart#L36-L60 | 在 AppDimens/BreakpointTokens 中定义常量并统一引用。 |
| 32 | 响应式断点/适配 | 中 | `isMobile`（<600）与 `isWide`（>=900）使用两套宽度口径，且 `isWide` 被标记为 legacy 仍在 `shouldUseSideBySide` 等路径混用。 | file:///workspace/lib/core/util/responsive.dart#L53-L60 | 废弃 legacy 口径，统一使用 Breakpoint/formFactor 决策。 |
| 33 | 响应式断点/适配 | 中 | `useBottomNav` 在 width < 600 时强制使用底部导航，即使设备 longEdge 已达 tablet/desktop（如桌面窄分屏），导致大屏出现手机式导航。 | file:///workspace/lib/core/util/responsive.dart#L267-L272 | 结合可用宽度与最小功能宽度，窄窗口使用 collapsed rail。 |
| 34 | 响应式断点/适配 | 高 | `formFactorOf` 用 `longestSide >= 768` 判定 tablet，大屏手机（如 iPhone 14 Pro Max 430×932，longEdge 932）会被误判为 tablet，从而启用侧边 rail。 | file:///workspace/lib/core/util/responsive.dart#L71-L77 | 改用 `shortestSide` 或结合宽高比，并参考 Flutter WindowSizeClass。 |
| 35 | 方向与视口 | 低 | `isPortrait` 通过 `height >= width` 判断，正方形视口被归为竖屏，且未使用 `MediaQuery.orientationOf`。 | file:///workspace/lib/core/util/responsive.dart#L90-L93 | 使用 `orientationOf` 并单独处理 square 状态。 |
| 36 | 方向与视口 | 中 | `isShortViewport` 以固定 480dp 为阈值，未扣除安全区、键盘高度等内边距，导致判断不准确。 | file:///workspace/lib/core/util/responsive.dart#L98-L99 | 基于 `MediaQuery.viewInsets/padding` 计算可用内容高度。 |
| 37 | 响应式布局 | 低 | `characterPanelHeight` 在 expanded 断点返回 `double.infinity`，若调用方未提供约束直接使用会触发布局异常。 | file:///workspace/lib/core/util/responsive.dart#L203-L214 | side-by-side 场景返回 null 或明确高度，并在文档说明约束要求。 |
| 38 | 响应式布局 | 低 | `sidePanelWidth` 以整个屏幕宽度 *0.36 计算，未扣除导航 rail 宽度（72/200），可能让聊天区域过窄。 | file:///workspace/lib/core/util/responsive.dart#L162-L167 | 传入 body 可用宽度或使用 `LayoutBuilder` 在消费侧计算。 |
| 39 | 响应式布局 | 低 | `gridColumnCount` / `statCardColumnCount` 基于全屏宽度计算列数，未扣除 rail/安全区，桌面左侧有 rail 时列数可能过多。 | file:///workspace/lib/core/util/responsive.dart#L231-L251 | 基于 body constraints 或可用宽度计算列数。 |
| 40 | 响应式布局 | 低 | `statCardColumnCount` 在手机上固定返回 2 列，iPhone SE 等窄屏中统计卡片可能过于拥挤。 | file:///workspace/lib/core/util/responsive.dart#L243-L251 | 极窄手机回退 1 列，或使用 `LayoutBuilder` 自适应。 |
| 41 | 响应式布局 | 低 | 多个工具方法重复调用 `MediaQuery.sizeOf`，breakpoints/formFactor 在多处重复计算，存在性能开销。 | file:///workspace/lib/core/util/responsive.dart#L36-L86 | 提供 `ResponsiveData` Provider/Notifier 一次查询并缓存。 |
| 42 | 桌面/移动端适配 | 中 | `MaterialApp` 未配置 `scrollBehavior`，桌面与网页端无法使用鼠标拖拽滚动，滚轮/触控板体验受限。 | file:///workspace/lib/main.dart#L130-L148 | 设置 `MaterialScrollBehavior.dragDevices` 包含 mouse、trackpad。 |
| 43 | 桌面/移动端适配 | 低 | 根应用没有统一监听窗口尺寸变化并缓存响应式状态的入口，各页面可能各自重复计算。 | file:///workspace/lib/main.dart#L112-L149 | 在顶层注入响应式数据对象，避免重复 MediaQuery 查询。 |
| 44 | Shell 导航 | 中 | `MainShell` 桌面布局用 `Center + ConstrainedBox` 统一限制 `contentMaxWidth`，所有页面共用，列表/表格页面两侧可能大量留白。 | file:///workspace/lib/core/router/app_router.dart#L261-L269 | 允许页面通过路由参数覆盖最大宽度或按页面类型区分。 |
| 45 | Shell 导航 | 中 | 侧边 rail 宽度 72/200 硬编码，切换断点时无动画，瞬间跳变。 | file:///workspace/lib/core/router/app_router.dart#L395 | 使用 `AnimatedContainer` 平滑过渡宽度与标签透明度。 |
| 46 | Shell 导航 | 中 | `_SideNavItem` 的触控高度约 42dp（icon 22 + 上下 padding 各 10），可能低于推荐的 44dp 最小触控目标。 | file:///workspace/lib/core/router/app_router.dart#L482-L485 | 增加垂直 padding 或使用 `Constraints(minHeight: 44)` 保证 44×44 目标。 |
| 47 | Shell 导航 | 中 | `_SideNavRail` 标签为硬编码英文，底部 `NavigationBar` 却使用 `AppLocalizations`，两者不一致且未国际化。 | file:///workspace/lib/core/router/app_router.dart#L355-L381 | 侧边栏标签接入 `AppLocalizations.t(...)`。 |
| 48 | Shell 导航 | 中 | `_SideNavRail` 使用纯色背景，与产品 Liquid Glass / glassmorphism 设计语言不一致。 | file:///workspace/lib/core/router/app_router.dart#L391-L393 | 使用半透明毛玻璃背景或 `GlassCard` 包裹，统一设计语言。 |
| 49 | Shell 导航 | 中 | `_SideNavRail` 内部为普通 `Column`，未包裹滚动视图，屏幕高度不足时会溢出。 | file:///workspace/lib/core/router/app_router.dart#L396-L436 | 添加 `SingleChildScrollView` 或根据高度启用滚动。 |
| 50 | Shell 导航 | 低 | 手机底部导航固定 5 个入口，超窄屏或横屏手机上图标/标签拥挤，且未切换为 rail。 | file:///workspace/lib/core/router/app_router.dart#L276-L309 | 宽屏手机横屏或折叠屏展开时切换为 rail 或折叠菜单。 |
| 51 | Shell 导航 | 中 | 桌面/平板布局的 body child 未在 shell 层自动加 `SafeArea(top)`，页面需自行处理状态栏/刘海。 | file:///workspace/lib/core/router/app_router.dart#L251-L272 | 在 body 外层加 `SafeArea(top: true)` 或统一页面 padding。 |
| 52 | Shell 导航 | 低 | `_calculateSelectedIndex` 只匹配 5 个 shell 路由，`/chat`、`/project` 等全屏页无法保持导航上下文。 | file:///workspace/lib/core/router/app_router.dart#L312-L320 | 记录最近 shell 索引或在返回时恢复高亮。 |
| 53 | Shell 导航 | 低 | 转场辅助函数使用 `MediaQuery.of(context)`，会监听所有 MediaQuery 变化，文字缩放、键盘弹出等均触发重建。 | file:///workspace/lib/core/router/app_router.dart#L203-L218 | 改用 `MediaQuery.accessibleNavigationOf` / `disableAnimationsOf` 精确订阅。 |
| 54 | Shell 导航 | 低 | 转场回退以 `accessibleNavigation` 作为减少动画条件，其语义是“无障碍导航”，不能准确代表减少动画。 | file:///workspace/lib/core/router/app_router.dart#L204 和 #L221 | 优先判断 `MediaQuery.disableAnimationsOf(context)`。 |
| 55 | 玻璃拟态样式 | 中 | `GlassCard` 使用 `MediaQuery.of(context)` 订阅全部 MediaQuery，系统栏变化即重绘；且 `reduceTransparency` 使用 `accessibleNavigation` 代理。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L44-L49 | 使用 `disableAnimationsOf` / `highContrastOf` 精确取值。 |
| 56 | 玻璃拟态样式 | 低 | `GlassCard` 的阴影、模糊半径、渐变 stops 全部硬编码，未适配屏幕像素密度或尺寸。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L85-L89 | 按 pixel ratio 或断点提供分档 Token。 |
| 57 | 玻璃拟态样式 | 中 | `GlassCard` 的镜面高光渐变覆盖整个 `Stack`，若子内容透明会与高光混合，降低可读性。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L124-L142 | 将高光限定在边框区域或使用 BlendMode 隔离。 |
| 58 | 玻璃拟态样式 | 低 | `GlassCard` 通过 `GestureDetector` 手动处理按下状态，缺少 Material 水波纹/焦点/悬停反馈，桌面端无鼠标手型。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L67-L78 | 使用 `InkWell` 或设置 `MouseCursor.click`，并完善焦点状态。 |
| 59 | 玻璃拟态样式 | 低 | 当 `onTap` 为 null 时 `GlassCard` 仍构建 `GestureDetector`，可能让屏幕阅读器误判为可点击。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L67-L78 | `onTap` 为 null 时直接返回不含 `GestureDetector` 的容器。 |
| 60 | 玻璃拟态样式 | 中 | `GlassDialog` 未限制最大宽度，在大屏桌面端会因 stretch 被拉得过宽，阅读体验差。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L271-L318 | 加 `ConstrainedBox(maxWidth: 560/640)` 或按断点限制。 |
| 61 | 玻璃拟态样式 | 低 | `GlassBottomSheet` 未提供内置滚动，内容超长时可能溢出或被键盘遮挡。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L329-L356 | 内部用 `SingleChildScrollView` 或 `DraggableScrollableSheet` 并处理键盘内边距。 |
| 62 | 玻璃拟态样式 | 低 | `GlassBackground` 极光色块尺寸 260/280/300 固定，未随屏幕尺寸缩放。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L390-L392 | 基于屏幕短边百分比或断点动态计算尺寸与位置。 |
| 63 | 玻璃拟态样式 | 低 | `StatusPill` 的字体 13、指示点 8 硬编码，未响应系统文字缩放。 | file:///workspace/lib/shared/widgets/glass_widgets.dart#L188-L201 | 使用 Theme 文本样式并设置最小/最大尺寸。 |
| 64 | 响应式布局 | 低 | `contentMaxWidth` 的 medium 值 880 大于 medium 断点下限 600，命名与上限语义容易混淆。 | file:///workspace/lib/core/util/responsive.dart#L150-L159 | 重命名或注释说明其为上限，并在实现中取 min(可用宽度, 上限)。 |
| 65 | 响应式断点/适配 | 中 | `shouldUseSideBySide` 包含多个硬编码数字与嵌套条件，缺少真值表与测试，新增设备易回归。 | file:///workspace/lib/core/util/responsive.dart#L115-L133 | 拆分为命名布尔变量并补充单元测试。 |
| 66 | Shell 导航 | 低 | `_SideNavRail` 品牌区 `Row` 使用 `mainAxisSize.min`，extended 模式文本可能超出 200dp 容器宽度。 | file:///workspace/lib/core/router/app_router.dart#L401-L421 | 对 `Text` 加 overflow/flexible 并让 rail 宽度自适应最长标签。 |

## 新增：场景、项目、历史与进度页面 UI/UX 问题

| 编号 | 分类 | 严重级别 | 描述 | 文件位置 | 建议改进 |
|---|---|---|---|---|---|
| 67 | 本地化 | 中 | 场景分类标题通过 `category[0].toUpperCase() + category.substring(1)` 手动大写，只适合英文且无法翻译，多语言场景下可能大小写或语义错误。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L112 | 将分类 key 放入 ARB，使用 `l.t('scenarios.category.$category')` 显示。 |
| 68 | 本地化 | 中 | 场景卡片难度标签直接拼接首字母大写（`scenario.difficulty[0].toUpperCase()`），未走 `AppLocalizations`。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L243-L245 | 在 ARB 中定义 `scenarios.difficulty.beginner` 等键并调用 `l.t(...)`。 |
| 69 | 本地化 | 中 | 练习统计文案 "Practiced X times" 与 "Last: X days ago" 直接硬编码英文，未国际化也未处理复数。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L264-L281 | 使用 `AppLocalizations` 复数语法或 `intl` 格式化相对时间。 |
| 70 | 本地化 | 中 | `_relativeTime` 返回 `today`/`yesterday`/`X days ago`，无法翻译且日期格式美式。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L199-L205 | 使用 `intl` 的 `DateFormat` 或 `AppLocalizations` 相对时间 key。 |
| 71 | 交互/可发现性 | 高 | 场景卡片通过 `onLongPress` 触发“加入项目”，但卡片外观与普通可点击卡片无异，用户难以发现该功能。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L135-L148 | 增加更多操作菜单按钮（⋮）或在卡片上显示“加入项目”图标，提供明确入口。 |
| 72 | 布局/响应式 | 中 | 横向列表高度按设备类型固定为 188/210，未适配系统字体放大或长文本换行，大字号下内容可能被截断。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L121-L122 | 使用 `IntrinsicHeight` 或动态计算卡片高度，并在最大字体下测试。 |
| 73 | 空态/错误态 | 中 | 加载与错误状态仅显示 `CircularProgressIndicator` 或 `Error: $e`，无重试按钮与友好提示。 | file:///workspace/lib/features/chat/presentation/screens/scenarios_screen.dart#L164-L165 | 封装统一的 `AsyncValueWidget`，提供骨架屏、本地化文案与重试按钮。 |
| 74 | 布局/响应式 | 中 | 项目网格 `childAspectRatio` 固定为 0.85，在小屏可能溢出，大屏留白过多。 | file:///workspace/lib/features/project_space/presentation/screens/projects_screen.dart#L105-L109 | 使用 `LayoutBuilder` 结合内容动态计算，或为不同断点配置不同比例。 |
| 75 | 空态/错误态 | 中 | 项目列表加载与错误状态均为简单 `Center` 组件，错误时无重试入口。 | file:///workspace/lib/features/project_space/presentation/screens/projects_screen.dart#L41-L42 | 统一使用带重试的异步状态组件。 |
| 76 | 视觉一致性 | 低 | 空状态图标与标题颜色对比不足，CTA 使用 `ElevatedButton` 而非项目页其他地方可能使用的 `FilledButton`。 | file:///workspace/lib/features/project_space/presentation/screens/projects_screen.dart#L132-L155 | 标题使用 `bodyLarge` + `textSecondary`，CTA 统一为 `FilledButton.icon`。 |
| 77 | 交互/反馈 | 中 | 项目详情 AppBar 标题在数据加载完成前为空，加载完成后标题突然出现，造成布局跳动。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L50-L53 | 加载时显示骨架占位文字或项目名称 shimmer，避免空白。 |
| 78 | 空态/错误态 | 中 | 项目详情错误状态直接显示原始异常 `Text('$e')`，既不友好也可能暴露内部信息。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L108 | 使用本地化错误页面，包含重试按钮。 |
| 79 | 信息架构 | 高 | 项目链接列表项标题直接展示 `contentId`，用户无法识别具体场景或会话内容。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L221 | 根据 `contentType` 查询内容名称/标题与图标并显示。 |
| 80 | 本地化 | 中 | 项目链接时间文案使用硬编码 `today`/`yesterday`/`X days ago`，未国际化。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L243-L249 | 统一使用 `intl` 或 `AppLocalizations` 的相对时间 key。 |
| 81 | 视觉一致性 | 低 | 项目状态仅为单色普通文本，缺乏视觉权重，难以快速识别。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L146-L148 | 使用 `Chip` / `Badge` / `StatusPill` 组件，并配合对应颜色。 |
| 82 | 交互/安全 | 高 | 删除确认弹窗的删除按钮使用默认 `FilledButton`，未使用错误色，用户可能误点执行删除。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L338-L341 | 将删除按钮设为 `AppColors.error` 前景/背景色，以标识危险操作。 |
| 83 | 视觉一致性 | 中 | Settings 标签页中“编辑项目”与“删除项目”均使用 `FilledButton.tonalIcon`，破坏性操作不够突出。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L309-L352 | 删除按钮改用 `OutlinedButton` 或 `TextButton` 配错误色，并保留二次确认。 |
| 84 | 间距/留白 | 低 | 活动列表 `Divider` 高度设为 `AppSpacing.lg`，导致活动项之间留白过大、列表松散。 | file:///workspace/lib/features/project_space/presentation/screens/project_detail_screen.dart#L268 | 将 `Divider` 高度减小或改用间距/卡片分组。 |
| 85 | 交互/效率 | 中 | JoinProjectSheet 项目数量多时缺少搜索框，用户只能滚动查找。 | file:///workspace/lib/features/project_space/presentation/widgets/join_project_sheet.dart#L94-L134 | 在 Sheet 顶部加入 `TextField` 实时过滤项目列表。 |
| 86 | 交互/反馈 | 中 | 已关联项目 `onTap` 为 `null`，但整行无禁用视觉样式，用户不明白为何不可点击。 | file:///workspace/lib/features/project_space/presentation/widgets/join_project_sheet.dart#L112-L130 | 对已关联行使用 `Opacity` 或 `disabledColor` 进行禁用样式处理。 |
| 87 | 信息架构 | 中 | JoinProjectSheet 标题仅显示“加入项目”，未展示正在关联的内容名称，用户缺少上下文。 | file:///workspace/lib/features/project_space/presentation/widgets/join_project_sheet.dart#L83-L84 | 在标题下方增加内容摘要（图标 + 名称）。 |
| 88 | 本地化 | 中 | HistoryScreen 时间格式化使用硬编码 `Today`/`Yesterday`/`X days ago`，日期格式为美式 `mm/dd/yyyy`。 | file:///workspace/lib/features/chat/presentation/screens/history_screen.dart#L88-L98 | 使用 `intl.DateFormat` 或 `AppLocalizations` 本地化。 |
| 89 | 本地化 | 中 | 会话主题为空时显示硬兜底文案 `'Free Talk'`，未国际化。 | file:///workspace/lib/features/chat/presentation/screens/history_screen.dart#L302 | 改为 `l.t('history.free_talk')` 等本地化 key。 |
| 90 | 本地化 | 高 | 删除会话确认弹窗正文直接拼接英文，且删除按钮未使用错误色。 | file:///workspace/lib/features/chat/presentation/screens/history_screen.dart#L113-L116 | 使用 `l.t(...)` 键值，并将确认删除按钮设为 `AppColors.error`。 |
| 91 | 本地化/无障碍 | 中 | 发音评分按钮文案为硬编码 `"Score"`，且 `fontSize` 仅 11，触控目标与字号均偏小。 | file:///workspace/lib/features/chat/presentation/screens/history_screen.dart#L319-L324 | 接入本地化并使用 `labelMedium`，增大最小触控目标。 |
| 92 | 空态/错误态 | 中 | 历史页面仅在 `_enrichedSessions` 为空时显示空状态，搜索无匹配结果时没有提示。 | file:///workspace/lib/features/chat/presentation/screens/history_screen.dart#L185-L186 | 当 `_filtered.isEmpty && _searchQuery.isNotEmpty` 时显示“无匹配结果”与清除搜索按钮。 |
| 93 | 交互/安全 | 中 | 每条历史会话卡片右侧直接放置删除 `IconButton`，与“Score”按钮相邻，容易误触删除。 | file:///workspace/lib/features/chat/presentation/screens/history_screen.dart#L332-L340 | 将删除移入长按菜单或详情页，或增加二次确认。 |
| 94 | 本地化 | 高 | ProgressScreen 存在多处硬编码英文标题与标签：`Your Progress`、`Mastery Breakdown`、`Error Types`、`New`、`Messages`、`Corrections`、`Start Review Session` 等。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L103-L296 | 全部接入 `AppLocalizations.t(...)`。 |
| 95 | 本地化 | 中 | 错误类型直接显示 `grammar`/`vocabulary`/`pronunciation` 并手动首字母大写，未翻译。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L167-L212 | 在 ARB 中定义 `progress.error_type.grammar` 等键。 |
| 96 | 本地化 | 中 | 7 日趋势图下方日期显示为 `day/month`，星期为硬编码 `Mon`/`Tue` 等英文。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L540 和 #L558-L562 | 使用 `intl.DateFormat` 根据 locale 显示。 |
| 97 | 布局/响应式 | 低 | 统计卡片网格使用 `Wrap` 强制固定 cell 宽度，最后一行可能出现单个左对齐卡片，视觉不平衡。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L342-L353 | 使用 `GridView` 或设置 `Wrap.alignment` 让最后一行居中。 |
| 98 | 布局/本地化 | 中 | `_MasteryRow` 标签区固定宽度 80dp，其他语言下长文本会被截断。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L425-L427 | 使用 `IntrinsicWidth` 或 `Flexible` 让标签自适应。 |
| 99 | 空态/错误态 | 中 | 进度页错误状态仅显示红色 `Error loading stats`，无重试按钮。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L76-L81 | 提供重试按钮并调用 `ref.invalidate(statsProvider)`。 |
| 100 | 视觉一致性 | 低 | “Start Review Session” 使用 `ElevatedButton.icon` 默认样式，未与主题主色/玻璃风格对齐。 | file:///workspace/lib/features/chat/presentation/screens/progress_screen.dart#L293-L300 | 改用 `FilledButton.icon` 并统一高度、圆角与颜色。 |
## 新增：首页仪表盘、Onboarding、Placement、雷达图与进度组件 UI/UX 问题

| 编号 | 分类 | 严重级别 | 描述 | 文件位置 | 建议改进 |
|------|------|----------|------|----------|----------|

## 新增：按钮、输入框、表单、开关、Banner、指示器、触控目标、焦点与组件一致性问题

### UX-026

## 67
- **编号**: 67
- **分类**: 输入框/表单
- **严重级别**: 中
- **描述**: API Key 输入框使用 `obscureText: true` 但没有后缀“显示/隐藏”切换按钮，用户无法核对已粘贴的密钥是否正确。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L643-L657)
- **建议改进**: 在 `InputDecoration.suffixIcon` 中添加 `IconButton`，通过状态切换 `obscureText`。

### UX-027

## 68
- **编号**: 68
- **分类**: 焦点管理
- **严重级别**: 中
- **描述**: 表单所有 `TextFormField` 均未设置 `textInputAction` 与 `FocusNode`，用户无法通过键盘“下一步/完成”在字段间顺序跳转。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L256-L260)
- **建议改进**: 为字段配置 `textInputAction: TextInputAction.next`，最后一个字段使用 `TextInputAction.done`，并在 `onFieldSubmitted` 中切换焦点。

### UX-028

## 69
- **编号**: 69
- **分类**: 输入框/表单
- **严重级别**: 低
- **描述**: API Base URL 字段未指定 `keyboardType: TextInputType.url`，无法调出 `/`、`.` 快捷键，也缺少 URL 自动补全。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L414-L419)
- **建议改进**: 为 URL 字段设置 `keyboardType: TextInputType.url` 与 `autocorrect: false`。

### UX-029

## 70
- **编号**: 70
- **分类**: 输入框/表单
- **严重级别**: 中
- **描述**: 字段校验仅返回简单的 `"Required"`，没有说明具体字段或格式要求，且只在保存时触发，实时反馈不足。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L260)
- **建议改进**: 使用本地化、描述性错误文案（如“请输入配置文件名称”），并考虑 `onChanged` 配合 `debounce` 做即时校验。

### UX-030

## 71
- **编号**: 71
- **分类**: 组件一致性
- **严重级别**: 低
- **描述**: 字段标题（如“Profile Name”）使用独立的 `Text` 组件放在输入框上方，而非 `InputDecoration.labelText`，与 Material 输入框规范不一致，聚焦时标题也不会浮动/高亮。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L254-L255)
- **建议改进**: 将标题移入 `InputDecoration(labelText: ...)`，统一使用主题输入框样式。

### UX-031

## 72
- **编号**: 72
- **分类**: 组件一致性
- **严重级别**: 低
- **描述**: Provider 下拉菜单用 `enabled: false` 的 `DropdownMenuItem` 作为地区分组标题，视觉上与可选项难以区分，容易误点。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L334-L347)
- **建议改进**: 在分组处使用 `Divider` 或自定义 `DropdownButton` header 样式，明确区分标题与选项。

### UX-032

## 73
- **编号**: 73
- **分类**: 按钮/触控目标
- **严重级别**: 低
- **描述**: “Fetch available models / Fetch voice list” 使用 `TextButton.icon`，图标仅 16pt 且依赖默认内边距，整体触控目标可能低于 44×44pt。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L709-L720)
- **建议改进**: 给按钮外套 `ConstrainedBox(minHeight: 44)`，或改用 `OutlinedButton` 并确保最小高度。

### UX-033

## 74
- **编号**: 74
- **分类**: 按钮/触控目标
- **严重级别**: 低
- **描述**: “Save / Cancel” 按钮使用默认 `ElevatedButton`/`OutlinedButton`，未设置 `minimumSize`，在紧凑主题或系统字体放大时高度可能不足 44pt。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L679-L703)
- **建议改进**: 配置 `style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48))`。

### UX-034

## 75
- **编号**: 75
- **分类**: 指示器
- **严重级别**: 低
- **描述**: “Test Connection” 按钮在加载状态下使用 16×16 的 `CircularProgressIndicator`，stroke 仅 2pt，可视性较差。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L668-L672)
- **建议改进**: 将加载指示器增大到 20–24，或与按钮文字同色。

### UX-035

## 76
- **编号**: 76
- **分类**: 输入框/表单
- **严重级别**: 中
- **描述**: 导入配置弹窗仅提供多行文本粘贴框，没有文件选择按钮，移动端用户难以从文件管理器导入。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L823-L858)
- **建议改进**: 在弹窗底部增加“选择文件”按钮，支持 `file_picker` 读取本地 JSON。

### UX-036

## 77
- **编号**: 77
- **分类**: 按钮
- **严重级别**: 低
- **描述**: 删除确认弹窗的“Delete”按钮使用普通 `TextButton`，破坏操作缺乏视觉权重，且与“Cancel”样式区分度不足。
- **文件位置**: [profile_form_screen.dart](file:///workspace/lib/features/profile/presentation/screens/profile_form_screen.dart#L851-L855)
- **建议改进**: 使用 `TextButton.styleFrom(foregroundColor: error)` 并加大水平内边距，或改用 `FilledButton` 配错误色背景。

### UX-037

## 78
- **编号**: 78
- **分类**: 组件一致性
- **严重级别**: 中
- **描述**: ServiceConfig 列表卡片整体可点击以激活配置，但没有复选框、单选按钮或明确提示，用户难以发现“点击切换激活”这一交互。
- **文件位置**: [service_config_screen.dart](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L212-L215)
- **建议改进**: 在卡片左侧使用 `Radio`/`Checkbox` 或添加 trailing 提示文字，并确保 `InkWell` 水波纹可见。

### UX-038

## 79
- **编号**: 79
- **分类**: 触控目标
- **严重级别**: 低
- **描述**: 资料卡片右侧的 `PopupMenuButton` 图标仅 20pt，默认 padding 为 8，整体点击区域约 36×36，低于 iOS/Android 推荐的 44/48dp。
- **文件位置**: [service_config_screen.dart](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L287-L295)
- **建议改进**: 增加 padding 至 12 或使用 `IconButton` 并设置 `style: IconButton.styleFrom(minimumSize: Size(44, 44))`。

### UX-039

## 80
- **编号**: 80
- **分类**: 组件一致性
- **严重级别**: 低
- **描述**: 分区标题使用 emoji（🧠/🎤/🔊）作为图标，缺少 `Semantics` 标签，读屏软件会跳过或读作“脑/麦克风/扬声器”，且不同平台渲染差异大。
- **文件位置**: [service_config_screen.dart](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L82-L83)
- **建议改进**: 使用 `Icon(Icons.xxx)` 并包裹 `Semantics(label: ...)`，或给 emoji 加 `ExcludeSemantics` 与语义标签。

### UX-040

## 81
- **编号**: 81
- **分类**: 组件一致性
- **严重级别**: 低
- **描述**: 资料卡片的副标题（URL/Provider 名称）未设置 `maxLines` 与 `overflow`，长 URL 可能导致卡片高度异常或溢出。
- **文件位置**: [service_config_screen.dart](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L270-L276)
- **建议改进**: 设置 `maxLines: 1` 与 `TextOverflow.ellipsis`。

### UX-041

## 82
- **编号**: 82
- **分类**: 按钮/触控目标
- **严重级别**: 低
- **描述**: “Add Profile” 使用 `TextButton.icon`，图标 18pt 且无最小高度限制，触控面积可能不足。
- **文件位置**: [service_config_screen.dart](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L385-L394)
- **建议改进**: 外套 `SizedBox(height: 44)` 或改用 `TextButton.styleFrom(minimumSize: Size.fromHeight(44))`。

### UX-042

## 83
- **编号**: 83
- **分类**: 按钮
- **严重级别**: 中
- **描述**: 删除确认弹窗的“Delete”按钮为纯文本按钮，未突出显示为破坏性操作，用户容易误触确认。
- **文件位置**: [service_config_screen.dart](file:///workspace/lib/features/profile/presentation/screens/service_config_screen.dart#L577-L583)
- **建议改进**: 使用 `TextButton` 加粗/错误色，或改用 `FilledButton(backgroundColor: error)` 以符合 Material 破坏性操作规范。

### UX-043

## 84
- **编号**: 84
- **分类**: 开关/Toggle
- **严重级别**: 中
- **描述**: `_SettingsToggleTile` 使用 `ListTile` 内嵌 `Switch`，导致行和开关是两个可聚焦/可点击元素，读屏软件可能重复播报，且焦点管理复杂。
- **文件位置**: [settings_screen.dart](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L976-L990)
- **建议改进**: 改用 `SwitchListTile.adaptive` 或 `MergeSemantics` 统一语义。

### UX-044

## 85
- **编号**: 85
- **分类**: 开关/Toggle
- **严重级别**: 低
- **描述**: `Switch` 未配置 `activeColor`、`activeTrackColor`、`thumbColor` 与焦点视觉，可能不符合品牌色且高对比度模式下状态不明显。
- **文件位置**: [settings_screen.dart](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L986-L989)
- **建议改进**: 通过 `SwitchThemeData` 统一配置，或显式传入 `activeColor`、`focusColor`。

### UX-045

## 86
- **编号**: 86
- **分类**: 组件一致性
- **严重级别**: 低
- **描述**: 低带宽模式开关的图标使用 `Icons.data_saver_off`，当开关开启（启用低带宽）时，图标语义却是“关闭”，与状态相反。
- **文件位置**: [settings_screen.dart](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L340)
- **建议改进**: 使用 `Icons.data_saver_on`，或根据 `value` 动态切换图标。

### UX-046

## 87
- **编号**: 87
- **分类**: 按钮
- **严重级别**: 中
- **描述**: “Clear Cache” 为破坏性操作，但 `_clearCache` 直接执行，没有二次确认弹窗，存在误操作风险。
- **文件位置**: [settings_screen.dart](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L412-L430)
- **建议改进**: 在执行前弹出 `AlertDialog` 提示用户确认清除。

### UX-047

## 88
- **编号**: 88
- **分类**: 组件一致性
- **严重级别**: 低
- **描述**: 设置页多个对话框（主题、语速、语言等）都根据当前亮度硬编码 `backgroundColor`，未统一使用 `DialogTheme`，导致维护困难和潜在不一致。
- **文件位置**: [settings_screen.dart](file:///workspace/lib/features/settings/presentation/screens/settings_screen.dart#L573-L575)
- **建议改进**: 在 `app_theme.dart` 配置 `dialogTheme` 并在各弹窗中移除硬编码背景色。

### UX-048

## 89
- **编号**: 89
- **分类**: 按钮
- **严重级别**: 低
- **描述**: Banner 关闭按钮使用 `InkWell` 直接包在 `SizedBox` 内，缺少 `Material` 祖先，水波纹效果被裁剪/缺失，且没有 `Tooltip`。
- **文件位置**: [app_banners.dart](file:///workspace/lib/shared/widgets/app_banners.dart#L486-L500)
- **建议改进**: 外层包 `Material`，并给 `InkWell` 添加 `Tooltip(message: 'Dismiss')`。

### UX-049

## 90
- **编号**: 90
- **分类**: 按钮
- **严重级别**: 低
- **描述**: Banner 的“Update / Install / Show steps”按钮文字字号固定 12，小于 Material 推荐的最小 14sp，影响可读性。
- **文件位置**: [app_banners.dart](file:///workspace/lib/shared/widgets/app_banners.dart#L460)
- **建议改进**: 将字号提升至 14，并使用 `Theme.of(context).textTheme.labelLarge` 保持一致。

### UX-050

## 91
- **编号**: 91
- **分类**: 按钮/触控目标
- **严重级别**: 低
- **描述**: iOS “Add to Home Screen”底部弹窗中的 “Not now / Got it” 按钮使用默认 `TextButton`/`FilledButton`，未设置最小高度，可能不足 44pt。
- **文件位置**: [app_banners.dart](file:///workspace/lib/shared/widgets/app_banners.dart#L278-L292)
- **建议改进**: 给两个按钮都设置 `minimumSize: Size.fromHeight(44)`。

### UX-051

## 92
- **编号**: 92
- **分类**: 指示器
- **严重级别**: 中
- **描述**: `VoiceStatusIndicator` 的进度条仅在 `expanded: true` 时显示，紧凑模式下用户无法感知 thinking/speaking 的进度。
- **文件位置**: [voice_status_indicator.dart](file:///workspace/lib/shared/widgets/voice_status_indicator.dart#L167-L179)
- **建议改进**: 在紧凑模式下也展示一条细进度指示（如 2px 的 `LinearProgressIndicator` 或脉冲动画）。

### UX-052

## 93
- **编号**: 93
- **分类**: 指示器
- **严重级别**: 低
- **描述**: 脉冲状态点外层容器尺寸为 `dotSize + 4`，但动画 scale 最大到 1.6，脉冲光环可能被裁剪。
- **文件位置**: [voice_status_indicator.dart](file:///workspace/lib/shared/widgets/voice_status_indicator.dart#L118-L148)
- **建议改进**: 将外层容器增大到 `dotSize * 2` 左右，或降低最大 scale 至 1.3。

### UX-053

## 94
- **编号**: 94
- **分类**: 指示器
- **严重级别**: 中
- **描述**: 语音阶段标签使用 phase-specific 颜色直接绘制在玻璃卡片上，毛玻璃背景会削弱对比度，可能不满足无障碍对比度要求。
- **文件位置**: [voice_status_indicator.dart](file:///workspace/lib/shared/widgets/voice_status_indicator.dart#L161-L166)
- **建议改进**: 在文本后加半透明背景容器，或使用主题 `textTheme.titleMedium` 配固定高对比度文本色。
| 67 | 首页仪表盘 / 品牌识别 | 中 | 顶部品牌区仅使用固定 48×48 渐变容器 + 白色 mic 图标，无用户头像或首字母 fallback，品牌识别度弱。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L66-L76 | 提供用户头像或首字母占位；将 Logo 与问候语分行或增大间距。 |
| 68 | 首页仪表盘 / 情感化设计 | 低 | `_greeting` 仅按设备时间返回早/午/晚，未使用用户昵称，情感化不足。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L228-L233 | 从 Profile 读取用户名称并拼接个性化问候。 |
| 69 | 首页仪表盘 / 数据可视化 | 中 | `_StreakDots` 30 个格子仅展示是否完成，缺少练习时长/强度的视觉层次，信息密度低。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L487-L554 | 使用热力图强度色阶区分练习时长，并增加悬停/长按提示具体数据。 |
| 70 | 首页仪表盘 / 可读性 | 低 | `_MilestoneBadge` 字号 11、内边距极小，在小屏上难点击且难阅读。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L556-L595 | 增大最小高度至 32dp，字号不低于 12，并增强已达成与未达成状态的对比。 |
| 71 | 首页仪表盘 / 布局适配 | 中 | `_BigActionButton` 标签 `maxLines=2`，在窄屏或长翻译文本下会出现双行不齐，破坏三列等宽对齐。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L655-L731 | 限制标签为单行并溢出省略，或改用垂直堆叠 + 自适应字体。 |
| 72 | 首页仪表盘 / 视觉语义 | 中 | `_BigActionButton` 的待复习 badge 使用 `AppColors.error` 红色并覆盖在图标右上角，颜色过于警示，易让用户误以为出错。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L692-L715 | 改用 accent 或 muted 背景，并增加“待复习”语义标签。 |
| 73 | 首页仪表盘 / 任务状态 | 高 | `_TaskCard` 不展示任务是否已完成，用户无法区分已做与待做。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L808-L910 | 增加 Checkbox 或完成图标，并对已完成任务使用更低对比度的视觉样式。 |
| 74 | 首页仪表盘 / 信息层级 | 中 | `_TaskCard` 使用 “P1/P2” 文本作为优先级，对普通用户不够直观，且颜色与任务图标无直接关联。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L824-L840 | 用“高/中/低”文字或色点替代 P 编号，并确保颜色符合色彩语义。 |
| 75 | 首页仪表盘 / 图表可解释性 | 中 | `_AbilityOverviewSection` 中的雷达图没有维度说明、分数刻度与图例，新用户难以理解。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L916-L974 | 在图表旁增加维度说明与 0-100 刻度图例，并为低分维度提供改进建议入口。 |
| 76 | 首页仪表盘 / 颜色语义 | 中 | `_ReviewQueueTile` 将“正确句子”显示为绿色 success，而“原句”用删除线灰色，用户可能误以为绿色是可点击的正面反馈。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1050-L1131 | 使用更中性的文本颜色，突出原句与纠正句的对比，并增加“复习”动作按钮。 |
| 77 | 首页仪表盘 / 信息重复 | 中 | `_GoalSection` 与 `_StructuredContentSection` 都展示“推荐场景”，造成信息重复、页面冗长。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1137-L1180 与 #L1359-L1418 | 合并推荐场景卡片，或根据用户是否开启内容设置二选一显示。 |
| 78 | 首页仪表盘 / 文本截断 | 中 | `_ScenarioChip` 固定宽度 140，描述 `maxLines=2`，在中文字符较多时极易截断，信息丢失。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1283-L1351 | 使用自适应宽度或垂直滚动卡片，并增加描述 tooltip。 |
| 79 | 首页仪表盘 / 对话框适配 | 中 | `_SetGoalDialog` 使用 `AlertDialog + Column`，在小屏手机上选择目标类型后可能溢出。 | file:///workspace/lib/features/home/presentation/screens/home_page.dart#L1621-L1690 | 将内容包裹在 `SingleChildScrollView` 中，并限制对话框最大宽度。 |
| 80 | Onboarding / 操作层级 | 中 | `_buildWelcomePage` 将“开始”、“跳过”、“访客试用”三个主要操作以相似视觉重量堆叠，用户难以识别主操作。 | file:///workspace/lib/features/onboarding/presentation/screens/onboarding_screen.dart#L179-L215 | 突出主按钮，将跳过与访客试用降为次级链接/文字按钮。 |
| 81 | Onboarding / 导航可理解性 | 低 | 服务配置页顶部 3 段进度条没有步骤名称，用户不确定当前配置哪一项。 | file:///workspace/lib/features/onboarding/presentation/screens/onboarding_screen.dart#L577-L597 | 增加步骤标签或图标（LLM / STT / TTS）。 |
| 82 | Onboarding / 输入体验 | 中 | 三个服务页的 API Key 输入框均 `obscureText=true`，用户无法确认粘贴/输入是否正确。 | file:///workspace/lib/features/onboarding/presentation/screens/onboarding_screen.dart#L684-L692 | 增加“显示/隐藏”切换图标按钮。 |
| 83 | Onboarding / 反馈可见性 | 中 | `_buildTestButton` 使用 `TextButton`，视觉上与“跳过”等次级操作同级，不易发现。 | file:///workspace/lib/features/onboarding/presentation/screens/onboarding_screen.dart#L507-L523 | 改为 `OutlinedButton` 或带状态色的按钮，并显示成功/失败图标反馈。 |
| 84 | Onboarding / 视觉噪音 | 低 | 服务页直接显示完整 `docsUrl`，文本过长且下划线链接与表单风格不统一。 | file:///workspace/lib/features/onboarding/presentation/screens/onboarding_screen.dart#L652-L669 | 使用“获取 API Key →”简洁链接文案，并放在输入框右侧辅助区。 |
| 85 | Onboarding / 动线一致性 | 低 | TTS 页的“复用 STT”按钮左对齐，而主要操作按钮在右下角，视觉动线断裂。 | file:///workspace/lib/features/onboarding/presentation/screens/onboarding_screen.dart#L442-L449 | 将复用按钮与测试按钮统一放在输入区下方，或在主按钮旁作为辅助链接。 |
| 86 | Placement / 操作层级 | 中 | `_buildIntro` 将“跳过”右对齐放在顶部，与底部主要操作距离过远，用户可能忽略。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L450-L455 | 将跳过操作与主按钮并列放在底部，或提供“稍后评估”次级按钮。 |
| 87 | Placement / 状态反馈 | 低 | `_buildChat` 进度条已完成与当前回合颜色差异仅透明度，对比度不足。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L527-L548 | 使用不同形状（圆角/实心）或颜色区分已完成、当前、未开始。 |
| 88 | Placement / 颜色语义 | 中 | 输入栏的录音按钮使用 `AppColors.error` 红色，会让用户误以为点击会报错/删除。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L599-L609 | 使用主品牌色或录音专用强调色表示正在录音，停止状态再变红。 |
| 89 | Placement / 视觉重心 | 低 | `_buildResult` 中成功图标容器 80×80，在结果页占据过多视觉重心。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L692-L704 | 缩小至 56-64dp，或改为与等级徽章结合的设计。 |
| 90 | Placement / 无障碍 | 中 | `_LearningPathCard` 使用 `'• '` 字符作为项目符号，屏幕阅读器会读作“bullet”，不利于无障碍。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L872-L940 | 使用 `ListTile` / `Row + Icon(Icons.check_circle_outline)` 或语义列表。 |
| 91 | Placement / 交互反馈 | 高 | `_LegacyQuiz` 选项点击后立即切换下一题，没有视觉选中反馈，用户可能误触且无法撤销。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L1060-L1102 | 增加选中高亮 + 确认按钮，允许用户复核后再进入下一题。 |
| 92 | Placement / 进度误导 | 中 | `_LegacyQuiz` 进度条用 `i <= _currentQuestion` 标记当前题为已完成，实际尚未回答当前题。 | file:///workspace/lib/features/onboarding/presentation/screens/placement_screen.dart#L1019-L1033 | 进度条应仅标记已回答的题目，当前题使用不同状态（如高亮边框）。 |
| 93 | 雷达图 / 数据可读性 | 中 | `PlacementRadarChart` 仅在顶点多点画点，没有显示具体分数，用户需对照下方表格。 | file:///workspace/lib/features/onboarding/presentation/widgets/placement_radar_chart.dart#L136-L158 | 在每个顶点旁显示分数标签，并提供 tooltip。 |
| 94 | 雷达图 / 排版 | 低 | 雷达图维度标签 `fontSize=11`，在小屏或高密度屏上难以辨认。 | file:///workspace/lib/features/onboarding/presentation/widgets/placement_radar_chart.dart#L138-L142 | 按文字缩放比例调整，最小不低于 12sp，并在拥挤时自动省略。 |
| 95 | 进度组件 / 本地化 | 中 | `WeeklyTrendChart` 的星期标签与统计标签均硬编码英文，未使用 `AppLocalizations`。 | file:///workspace/lib/features/home/presentation/widgets/weekly_trend_chart.dart#L28 与 #L37-L47 | 接入本地化字符串并支持周起始日设置。 |
| 96 | 进度组件 / 交互反馈 | 中 | `_BarChartPainter` 绘制的柱状图没有 tooltip 或点击反馈，用户无法查看具体数值。 | file:///workspace/lib/features/home/presentation/widgets/weekly_trend_chart.dart#L144-L207 | 添加 tap 区域与 tooltip/overlay，显示当天消息数与纠错数。 |
| 97 | 进度组件 / 本地化 | 中 | `WeakAreaCard` 的类型标签直接写死英文（Pronunciation/Grammar…），未本地化。 | file:///workspace/lib/features/home/presentation/widgets/weak_area_card.dart#L91-L104 | 使用 `AppLocalizations` 键值映射，并按类型使用一致颜色。 |
| 98 | 进度组件 / 触控目标 | 低 | `WeakAreaCard` 左侧色点仅 10×10，右侧“×N”徽章也很小，整体触控区域不足。 | file:///workspace/lib/features/home/presentation/widgets/weak_area_card.dart#L27-L71 | 将整行包裹为 `ListTile` 或 `InkWell`，保证最小 48dp 触控高度。 |
| 99 | 进度组件 / 信息架构 | 中 | `CalendarHeatmap` 按水平方向从左到右、从上到下排列日期，不符合常见的 GitHub 式垂直星期视图。 | file:///workspace/lib/features/home/presentation/widgets/calendar_heatmap.dart#L99-L104 | 采用垂直列（每周一列）布局，并增加月份分隔标签。 |
| 100 | 进度组件 / 本地化 | 低 | `CalendarHeatmap` 的 Less/More 图例标签硬编码英文。 | file:///workspace/lib/features/home/presentation/widgets/calendar_heatmap.dart#L80 与 #L94 | 接入本地化字符串。 |

## 视觉分析（截图）（225 条）

### VA-001

1. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 空状态
   - **严重级别**: 中
   - **描述**: 右侧大面积留白仅显示一个对话气泡图标和两行提示文字，信息密度极低，没有引导用户开始交互的视觉焦点。
   - **建议修改**: 在右侧空白区增加一个居中的“开始对话”主按钮或浮层提示，提升首屏转化率。

### VA-002

2. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 布局
   - **严重级别**: 低
   - **描述**: 头像卡片与右侧聊天区之间的白色分隔带宽度不统一，顶部与底部存在可察觉的间隙差异。
   - **建议修改**: 使用统一的 12–16px 间隔，并确保上下边缘对齐。

### VA-003

3. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 颜色
   - **严重级别**: 低
   - **描述**: 整体色调过于单一，背景为浅灰，头像背景为蓝白，缺少品牌强调色贯穿。
   - **建议修改**: 在顶部导航栏或底部输入区引入品牌主色（如淡紫/青绿）作为视觉锚点。

### VA-004

4. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 头像
   - **严重级别**: 中
   - **描述**: 左侧 AI 头像显示为静态图片，边缘有轻微锯齿，且被截断到胸口位置，缺少肩部过渡，显得“断头”。
   - **建议修改**: 使用更高分辨率的全身或半身素材，或在头像卡片底部添加渐变遮罩以自然过渡。

### VA-005

5. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 组件
   - **严重级别**: 低
   - **描述**: 左下角“AI Tutor · Ready”状态胶囊与头像底部距离过近，几乎贴边。
   - **建议修改**: 增加 8–12px 下边距，确保状态标签呼吸感。

### VA-006

6. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 布局
   - **严重级别**: 中
   - **描述**: 底部输入栏高度偏低，文本框、麦克风按钮和发送按钮排布拥挤，视觉重心偏向右侧。
   - **建议修改**: 增加输入栏高度至 56–64px，并等分各元素间距。

### VA-007

7. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 交互
   - **严重级别**: 中
   - **描述**: 底部麦克风按钮（青色圆形）与输入框右侧的麦克风图标同时存在，功能重复且容易引起困惑。
   - **建议修改**: 在文本输入模式下隐藏右侧小麦克风图标，仅保留左侧主麦克风按钮。

### VA-008

8. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 按钮
   - **严重级别**: 高
   - **描述**: 发送按钮在未输入内容时呈现浅蓝色并禁用，但其禁用状态与可用状态对比度不足，用户难以判断当前是否可点击。
   - **建议修改**: 禁用状态使用灰阶或更低透明度（如 38%），并添加 disabled 光标。

### VA-009

9. **截图**: `m03-hp1-chat-route--chromium.png`
   - **分类**: 无障碍
   - **严重级别**: 中
   - **描述**: 提示文字“Tap the mic to start speaking”使用灰色小字，与浅灰背景对比度可能不足，视力不佳用户难以阅读。
   - **建议修改**: 将提示文字颜色加深至 WCAG 4.5:1 以上对比度。

### VA-010

10. **截图**: `m03-hp1-chat-route--chromium.png`
    - **分类**: 视觉层次
    - **严重级别**: 低
    - **描述**: 右侧空状态图标尺寸过小，无法起到视觉锚点作用。
    - **建议修改**: 将空状态图标放大至 64–80px，并添加轻微投影或品牌色描边。

### VA-011

11. **截图**: `m03-hp2-chat-shell--chromium.png`
    - **分类**: 品牌
    - **严重级别**: 低
    - **描述**: 顶部导航栏仅有返回箭头、头像缩略图和“AI Tutor”文字，缺少 SpeakFlow 品牌 Logo 或标识。
    - **建议修改**: 在标题左侧或右侧加入 SpeakFlow 品牌图标，强化品牌认知。

### VA-012

12. **截图**: `m03-hp2-chat-shell--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 顶部小头像（🧑‍🏫 风格）与左侧大头像风格不一致，一个是插画 emoji，一个是写实 AI 生成图。
    - **建议修改**: 统一头像风格，例如将顶部小头像也替换为与左侧一致的真人化缩略图。

### VA-013

13. **截图**: `m03-hp2-chat-shell--chromium.png`
    - **分类**: 布局
    - **严重级别**: 低
    - **描述**: 标题“AI Tutor”与顶部小头像垂直对齐略显偏高，与返回箭头不在同一视觉中心线。
    - **建议修改**: 使用 flex 居中对齐，确保标题、头像、返回箭头三者中心线一致。

### VA-014

14. **截图**: `m03-hp3-typing-toggle--chromium.png`
    - **分类**: 输入框
    - **严重级别**: 中
    - **描述**: 输入框获得焦点后仅有蓝色边框变化，缺少焦点阴影或背景色变化，焦点感知较弱。
    - **建议修改**: 增加 2px 品牌色描边 + 轻微外发光，提升焦点可见性。

### VA-015

15. **截图**: `m03-hp3-typing-toggle--chromium.png`
    - **分类**: 排版
    - **严重级别**: 低
    - **描述**: 输入框内文字“Hello there”与左侧麦克风图标间距较小，视觉上显得拥挤。
    - **建议修改**: 增加输入文字与图标之间的 padding-left 至 16px。

### VA-016

16. **截图**: `m03-hp3-typing-toggle--chromium.png`
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 输入内容后发送按钮仍为浅蓝色，未变为更醒目的品牌色，反馈不明显。
    - **建议修改**: 有内容时发送按钮切换为饱和品牌色（如 #6366F1），并添加 hover/active 状态。

### VA-017

17. **截图**: `m03-hp3-typing-toggle--chromium.png`
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 同时出现两个麦克风入口（左侧大按钮与输入框右侧小图标），当用户正在打字时右侧小图标无实际用途。
    - **建议修改**: 当输入框有焦点时，右侧小麦克风图标应淡出或隐藏。

### VA-018

18. **截图**: `m03-hp4-send--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 高
    - **描述**: 用户发送消息后，右侧仅出现一个极小的“ I ”气泡，且气泡右上角圆角与右下角圆角看起来不一致。
    - **建议修改**: 统一聊天气泡圆角，典型方案是用户消息右上/右下均为 16px，左下为 4px。

### VA-019

19. **截图**: `m03-hp4-send--chromium.png`
    - **分类**: 颜色
    - **严重级别**: 中
    - **描述**: 用户消息气泡使用非常淡的蓝色，与浅灰背景区分度不足，看起来像未发送成功的草稿。
    - **建议修改**: 用户消息使用更饱和的品牌色背景（如 #DBEAFE 或 #BFDBFE）。

### VA-020

20. **截图**: `m03-hp4-send--chromium.png`
    - **分类**: 状态
    - **严重级别**: 高
    - **描述**: 发送消息后输入框立即清空且没有“发送中”状态，用户无法确认消息是否已提交。
    - **建议修改**: 添加发送中 spinner 或临时消息项，待服务端确认后再移除。

### VA-021

21. **截图**: `m03-hp4-send--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: AI 正在思考时左侧头像保持微笑静态图，缺少“思考中”的微表情或动效反馈。
    - **建议修改**: 在思考时给头像叠加柔和脉冲环或表情变化（如闭眼/歪头）。

### VA-022

22. **截图**: `m03-hp4-send--chromium.png`
    - **分类**: 状态
    - **严重级别**: 高
    - **描述**: 左下角状态从“Ready”变为“Thinking”后，状态胶囊颜色几乎无变化，状态切换不醒目。
    - **建议修改**: “Thinking”状态使用不同颜色（如琥珀色）并加入加载点动画。

### VA-023

23. **截图**: `m03-hp5-streaming--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 高
    - **描述**: AI 流式回复尚未显示任何文字，但状态已是“Thinking”，用户等待期间右侧完全空白。
    - **建议修改**: 在等待 AI 首字时显示“AI 正在输入…”占位文案或骨架屏。

### VA-024

24. **截图**: `m03-hp5-streaming--chromium.png`
    - **分类**: 加载
    - **严重级别**: 中
    - **描述**: 没有可见的加载指示器（spinner、骨架屏、跳动点），仅靠状态文字反馈，感知延迟明显。
    - **建议修改**: 在 AI 回复区域顶部显示三点跳动动画或渐变骨架条。

### VA-025

25. **截图**: `m03-hp6-corrections-saved--chromium.png`
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: “corrections saved”语义上应出现 toast/snackbar，但截图中无可见反馈。
    - **建议修改**: 添加居底 toast，文案如“已保存发音纠正”，显示 2–3 秒后自动消失。

### VA-026

26. **截图**: `m03-hp6-corrections-saved--chromium.png`
    - **分类**: 状态
    - **严重级别**: 中
    - **描述**: 保存纠正后界面与“streaming”阶段几乎完全相同，缺少成功状态差异。
    - **建议修改**: 在状态胶囊或 toast 中使用绿色勾选图标表示保存成功。

### VA-027

27. **截图**: `m03-hp7-tts-autoplay--chromium.png`
    - **分类**: 音频
    - **严重级别**: 中
    - **描述**: TTS 自动播放状态下没有音频波形或播放进度指示，用户无法判断当前是否在朗读。
    - **建议修改**: 在 AI 消息气泡旁加入小型音波动画或播放进度条。

### VA-028

28. **截图**: `m03-hp7-tts-autoplay--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: AI 朗读时头像仍为静态，嘴部未张开，与“说话”状态割裂。
    - **建议修改**: 引入 Live2D 或序列帧口型动画，至少叠加嘴唇微张效果。

### VA-029

29. **截图**: `m03-hp8-loading-cleared--chromium.png`
    - **分类**: 加载
    - **严重级别**: 高
    - **描述**: “loading cleared”阶段界面与等待回复阶段完全一致，没有“已清空/可重新输入”的视觉提示。
    - **建议修改**: 清空加载后短暂显示“准备就绪”动画或输入框焦点恢复效果。

### VA-030

30. **截图**: `m03-hp8-loading-cleared--chromium.png`
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 连续多个阶段的截图（hp5–hp8）几乎没有可见差异，说明状态变化反馈不足。
    - **建议修改**: 为每个阶段设计不同的过渡帧或微交互动画。

### m10 Live2D/头像动画模块

### VA-031

31. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 布局
    - **严重级别**: 中
    - **描述**: 切换到语音模式后，底部出现“Hold to talk”大胶囊按钮，但按钮左右留白极不均衡，左侧“Continuous”标签占用空间后右侧几乎贴边。
    - **建议修改**: 使用底部居中布局，左右边距统一为 24px。

### VA-032

32. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: “Hold to talk”按钮使用青到紫的渐变，但渐变方向看起来是垂直而非水平，且与整体浅色调不兼容。
    - **建议修改**: 将渐变改为柔和的横向品牌渐变，或改用单色 + 投影。

### VA-033

33. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 按钮
    - **严重级别**: 高
    - **描述**: “Hold to talk”按钮文字颜色为白色，在青紫渐变背景下对比度不足，尤其在渐变交界处。
    - **建议修改**: 在按钮文字下方添加半透明深色遮罩，或改用深色文字 + 浅色背景。

### VA-034

34. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 排版
    - **严重级别**: 低
    - **描述**: “Release to transcribe”提示文字字号过小，且与按钮距离偏远，关联性弱。
    - **建议修改**: 将提示文字移至按钮上方或下方 8px 处，并增大字号。

### VA-035

35. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 组件
    - **严重级别**: 中
    - **描述**: “Continuous”标签仅有文字和一个小图标，缺少开关状态（on/off）的视觉表达。
    - **建议修改**: 将其改为标准 Switch 开关组件，明确当前连续对话是否开启。

### VA-036

36. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 布局
    - **严重级别**: 低
    - **描述**: 右侧键盘图标位于底部最右角，尺寸偏小，触达困难。
    - **建议修改**: 将键盘图标放大至 24–28px，并增加点击热区至 44×44dp。

### VA-037

37. **截图**: `m10-hp2-head-microturn--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头部微转动效果在静态截图中无法体现，导致该测试点视觉验证价值有限。
    - **建议修改**: 在 E2E 截图中捕获关键帧，或提供 GIF/视频对比。

### VA-038

38. **截图**: `m10-hp2-head-microturn--chromium.png`
    - **分类**: 动画
    - **严重级别**: 低
    - **描述**: 头像动画幅度可能过小，截图上看不出与 hp1 的区别。
    - **建议修改**: 增加头部微转的角度或叠加动态提示，使状态可感知。

### VA-039

39. **截图**: `m10-hp3-body-sway--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 身体摇摆效果在截图中不可见，无法验证该功能是否生效。
    - **建议修改**: 在截图时选择摇摆幅度最大帧，或单独输出视频帧序列。

### VA-040

40. **截图**: `m10-hp4-fallback-renderer--chromium.png`
    - **分类**: 视觉
    - **严重级别**: 高
    - **描述**: fallback renderer 阶段界面与正常 Live2D 阶段完全相同，无法区分是否已降级。
    - **建议修改**: fallback 时在头像区域添加 subtle 水印或状态提示“静态模式”。

### VA-041

41. **截图**: `m10-hp4-fallback-renderer--chromium.png`
    - **分类**: 错误状态
    - **严重级别**: 高
    - **描述**: 降级到 fallback renderer 没有错误提示或重试入口，用户不知道 Live2D 加载失败。
    - **建议修改**: 显示非阻塞提示“Live2D 暂不可用，已切换为静态模式”，并提供重试按钮。

### VA-042

42. **截图**: `m10-hp5-live2d-branch--chromium.png`
    - **分类**: 分支
    - **严重级别**: 中
    - **描述**: Live2D 分支与静态分支在视觉上无法区分，不利于回归测试。
    - **建议修改**: 为不同渲染分支增加可识别的视觉标记或调试信息（测试环境下）。

### VA-043

43. **截图**: `m10-hp5-live2d-branch--chromium.png`
    - **分类**: 性能
    - **严重级别**: 中
    - **描述**: 静态截图无法判断 Live2D 帧率或 GPU 占用，但界面缺少性能指示。
    - **建议修改**: 在开发/测试构建中增加 FPS 或渲染模式调试浮层。

### VA-044

44. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 颜色
    - **严重级别**: 低
    - **描述**: 底部“Hold to talk”渐变按钮与顶部导航栏颜色没有任何呼应，视觉断层明显。
    - **建议修改**: 在顶部状态栏或返回按钮上使用同色渐变或品牌强调色。

### VA-045

45. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: “Hold to talk”按钮缺少按压状态预览，用户无法预知长按效果。
    - **建议修改**: 增加按下时的缩放/发光/文字变化反馈。

### VA-046

46. **截图**: `m10-hp2-head-microturn--chromium.png`
    - **分类**: 头像
    - **严重级别**: 低
    - **描述**: 头像卡片圆角（约 16–20px）与底部输入区完全直角形成强烈风格对比。
    - **建议修改**: 统一界面圆角体系，例如底部输入区也使用 16px 圆角。

### VA-047

47. **截图**: `m10-hp3-body-sway--chromium.png`
    - **分类**: 布局
    - **严重级别**: 低
    - **描述**: 头像卡片左侧与屏幕左边缘的距离在截图中看起来小于右侧聊天区留白。
    - **建议修改**: 检查并统一左右安全边距，建议均为 16–24px。

### VA-048

48. **截图**: `m10-hp4-fallback-renderer--chromium.png`
    - **分类**: 可访问性
    - **严重级别**: 中
    - **描述**: 纯图标按钮（键盘、更多、返回）没有文字标签，屏幕阅读器用户难以理解。
    - **建议修改**: 为所有图标按钮添加 `aria-label` 或 tooltip。

### VA-049

49. **截图**: `m10-hp5-live2d-branch--chromium.png`
    - **分类**: 品牌
    - **严重级别**: 低
    - **描述**: 语音模式下没有任何品牌元素或吉祥物标识，品牌感弱。
    - **建议修改**: 在“Hold to talk”按钮或状态胶囊中加入 SpeakFlow logo。

### VA-050

50. **截图**: `m10-hp1-idle-breathing--chromium.png`
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: “Hold to talk”按钮在桌面端尺寸过大，但在宽屏下仍居中且未拉伸，显得有些孤立。
    - **建议修改**: 在桌面端限制按钮最大宽度为 320px，并增加左右辅助操作。

### m11 情绪/状态反馈模块

### VA-051

51. **截图**: `m11-hp1-happy-marker--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: AI 回复气泡“That's great!”下方出现“Listen”按钮，但按钮图标（青色小圆）与文字对齐不自然。
    - **建议修改**: 将 Listen 图标与文字设为同一行基线，并增加 6px 间距。

### VA-052

52. **截图**: `m11-hp1-happy-marker--chromium.png`
    - **分类**: 颜色
    - **严重级别**: 中
    - **描述**: AI 消息气泡为浅紫色，Listen 按钮又为青色，两种颜色冲突且没有统一调色板。
    - **建议修改**: Listen 按钮使用与气泡同色系但更深的紫色，保持单色层次。

### VA-053

53. **截图**: `m11-hp1-happy-marker--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 高
    - **描述**: 用户消息“hello”与 AI 消息“That's great!”之间缺少时间戳或分隔，用户无法判断对话顺序。
    - **建议修改**: 在每条消息下方添加发送时间或“刚刚”标签。

### VA-054

54. **截图**: `m11-hp1-happy-marker--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 情绪标记为“happy”，但头像表情仍是固定微笑，没有更明显的喜悦表现。
    - **建议修改**: 根据情绪状态切换头像表情素材（如大笑、眨眼）。

### VA-055

55. **截图**: `m11-hp1-happy-marker--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 低
    - **描述**: 用户消息气泡与屏幕右边缘距离偏小，贴边感明显。
    - **建议修改**: 增加用户消息右侧外边距至 16px。

### VA-056

56. **截图**: `m11-hp2-transition--chromium.png`
    - **分类**: 过渡
    - **严重级别**: 高
    - **描述**: transition 阶段截图与初始空状态几乎完全相同，无法验证过渡动画是否正确执行。
    - **建议修改**: 在测试脚本中截取过渡中间帧，或对比前后像素差异。

### VA-057

57. **截图**: `m11-hp2-transition--chromium.png`
    - **分类**: 状态
    - **严重级别**: 中
    - **描述**: 状态胶囊显示“Ready”，但界面正处于 transition，状态信息没有帮助。
    - **建议修改**: transition 期间显示“切换中…”或进度条。

### VA-058

58. **截图**: `m11-hp3-neutral-cycle--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 多轮对话中消息间距不均匀，第一条与第二条 AI 消息之间的空隙明显大于用户消息之间。
    - **建议修改**: 统一消息组间距，同一说话者连续消息间距 4–8px，不同说话者间距 16–20px。

### VA-059

59. **截图**: `m11-hp3-neutral-cycle--chromium.png`
    - **分类**: 排版
    - **严重级别**: 低
    - **描述**: “first / second”用户消息与“Wonderful! / Okay.” AI 消息字体大小看起来一致，缺少 sender 区分。
    - **建议修改**: 用户消息可使用略粗字重，AI 消息保持常规，形成层次。

### VA-060

60. **截图**: `m11-hp3-neutral-cycle--chromium.png`
    - **分类**: 状态
    - **严重级别**: 中
    - **描述**: “neutral cycle”阶段头像没有中性/平静的视觉表达，仍是标准微笑。
    - **建议修改**: 为 neutral 状态设计默认平静表情，并循环播放微妙呼吸动画。

### VA-061

61. **截图**: `m11-hp4-waiting-idle--chromium.png`
    - **分类**: 空状态
    - **严重级别**: 中
    - **描述**: waiting idle 阶段回到空状态，但“Start a conversation!”文案没有变化，缺少等待中的引导。
    - **建议修改**: 等待 idle 时文案可变为“我在听，随时可以说”或显示脉冲麦克风。

### VA-062

62. **截图**: `m11-hp5-thinking--chromium.png`
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: AI 思考回复“Hmm, let me consider.”气泡颜色与中性回复相同，思考状态没有高亮。
    - **建议修改**: 思考中消息可带有轻微脉冲边框或不同的背景色。

### VA-063

63. **截图**: `m11-hp5-thinking--chromium.png`
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 思考时头像表情未变化，未能传达“正在思考”的情绪。
    - **建议修改**: 思考时叠加手托下巴、眨眼或头顶“…”动画。

### VA-064

64. **截图**: `m11-hp3-neutral-cycle--chromium.png`
    - **分类**: 组件
    - **严重级别**: 低
    - **描述**: 每条 AI 消息都带“Listen”按钮，但当多条消息同时存在时，重复按钮显得冗余。
    - **建议修改**: 仅在最近一条 AI 消息显示 Listen，或提供全局朗读控制。

### VA-065

65. **截图**: `m11-hp3-neutral-cycle--chromium.png`
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 用户消息不可朗读（缺少 Listen 按钮），但用户可能希望回听自己的输入。
    - **建议修改**: 长按用户消息显示“朗读”选项，或为用户消息也提供小喇叭图标。

### 跨模块通用发现

### VA-066

66. **截图**: 全部
    - **分类**: 响应式
    - **严重级别**: 高
    - **描述**: 所有截图均为桌面宽屏，左侧头像卡片固定宽度，右侧聊天区留有大面积空白，未展示移动端或平板适配。
    - **建议修改**: 提供 375px、768px、1440px 等多断点截图，验证响应式布局。

### VA-067

67. **截图**: 全部
    - **分类**: 响应式
    - **严重级别**: 高
    - **描述**: 桌面端右侧聊天区宽度超过 700px，单气泡消息显得孤立且远离头像，沉浸感不足。
    - **建议修改**: 在宽屏下限制聊天内容最大宽度为 600px 或采用左右分栏比例调整。

### VA-068

68. **截图**: 全部
    - **分类**: 视觉层次
    - **严重级别**: 中
    - **描述**: 左侧头像卡片在整个界面中占比过大（约 40%），挤压了聊天内容区域。
    - **建议修改**: 桌面端头像区占比降至 30–35%，或支持用户拖拽调整宽度。

### VA-069

69. **截图**: 全部
    - **分类**: 颜色
    - **严重级别**: 中
    - **描述**: 界面缺少深色模式支持，所有截图均为浅色主题。
    - **建议修改**: 提供深色模式截图并验证对比度。

### VA-070

70. **截图**: 全部
    - **分类**: 阴影
    - **严重级别**: 低
    - **描述**: 头像卡片、输入栏、按钮均缺少阴影或 elevation，界面显得扁平、层次弱。
    - **建议修改**: 为头像卡片和底部输入栏添加 0 2 8 rgba 投影，提升层次。

### VA-071

71. **截图**: 全部
    - **分类**: 字体
    - **严重级别**: 中
    - **描述**: 界面字体看起来使用系统默认 sans-serif，缺乏品牌字体特征。
    - **建议修改**: 引入品牌字体（如 Inter / Noto Sans SC）并统一字重。

### VA-072

72. **截图**: 全部
    - **分类**: 排版
    - **严重级别**: 低
    - **描述**: 标题“AI Tutor”字重偏轻，在浅色背景下不够醒目。
    - **建议修改**: 标题使用 semibold（600）字重。

### VA-073

73. **截图**: 全部
    - **分类**: 图标
    - **严重级别**: 低
    - **描述**: 返回箭头、更多菜单、分享图标风格不统一（线性与填充混用）。
    - **建议修改**: 统一使用同一套图标库，并保持线宽一致。

### VA-074

74. **截图**: 全部
    - **分类**: 布局
    - **严重级别**: 中
    - **描述**: 顶部导航栏高度看起来较低，导致图标与标题显得拥挤。
    - **建议修改**: 顶部栏高度增加至 56–64px，并增加垂直内边距。

### VA-075

75. **截图**: 全部
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 右上角“更多”菜单（⋮）点击后未展示菜单截图，无法验证菜单项。
    - **建议修改**: 补充更多菜单展开的截图。

### VA-076

76. **截图**: 全部
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 分享/扩展开关（右上角）图标含义不明确，用户可能误以为是全屏或设置。
    - **建议修改**: 使用更通用的分享箭头图标，并添加 tooltip。

### VA-077

77. **截图**: 全部
    - **分类**: 可访问性
    - **严重级别**: 高
    - **描述**: 所有按钮和状态仅依赖颜色/图标传达，缺少文字说明或 aria-label。
    - **建议修改**: 为关键操作添加文字标签或无障碍描述。

### VA-078

78. **截图**: 全部
    - **分类**: 动画
    - **严重级别**: 中
    - **描述**: 截图无法验证动画曲线与时长，可能存在生硬切换。
    - **建议修改**: 提供录屏或 Lottie 文件，确保动画使用 ease-in-out 200–300ms。

### VA-079

79. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 高
    - **描述**: AI 头像整体呈现“完美但无生命”的塑料感，皮肤高光过强，眼睛过于明亮，恐怖谷效应明显。
    - **建议修改**: 降低皮肤平滑度，增加细微纹理和更自然的瞳孔高光。

### VA-080

80. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头像头发边缘在蓝色背景上有轻微蓝边溢出（chromatic aberration）。
    - **建议修改**: 对头像素材进行去边处理，使用更干净的抠图。

### VA-081

81. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头像衣领区域过于平整，缺少布料褶皱和阴影，显得不自然。
    - **建议修改**: 使用更高质量的生成/摄影素材，增加服装纹理细节。

### VA-082

82. **截图**: 全部
    - **分类**: 背景
    - **严重级别**: 低
    - **描述**: 头像背景为简单的蓝天白云，与“AI Tutor”学习场景关联性弱。
    - **建议修改**: 使用书房、课堂、科技感渐变等更贴合教育场景的背景。

### VA-083

83. **截图**: 全部
    - **分类**: 品牌
    - **严重级别**: 中
    - **描述**: 未见 SpeakFlow 应用名称、Logo 或品牌色系统，品牌辨识度低。
    - **建议修改**: 在空状态、加载页或顶部栏中突出 SpeakFlow 品牌。

### VA-084

84. **截图**: 全部
    - **分类**: 一致性
    - **严重级别**: 中
    - **描述**: 不同模块间底部输入区形态差异巨大（文本模式 vs 语音模式），切换时可能造成认知跳跃。
    - **建议修改**: 保持底部栏高度一致，仅切换内部控件形态。

### VA-085

85. **截图**: 全部
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 未展示错误状态截图（网络失败、TTS 失败、ASR 失败等），无法评估错误体验。
    - **建议修改**: 补充错误状态截图，并设计统一错误提示组件。

### VA-086

86. **截图**: 全部
    - **分类**: 状态
    - **严重级别**: 中
    - **描述**: “Ready / Thinking”状态仅通过胶囊展示，缺少更明显的全局状态指示。
    - **建议修改**: 在头像周围添加状态光环（绿色 Ready、琥珀色 Thinking）。

### VA-087

87. **截图**: 全部
    - **分类**: 输入框
    - **严重级别**: 中
    - **描述**: 文本输入框 placeholder “Type a message...”颜色过浅，与背景融合。
    - **建议修改**: placeholder 颜色加深至 #6B7280，并增加占位符动画。

### VA-088

88. **截图**: 全部
    - **分类**: 输入框
    - **严重级别**: 中
    - **描述**: 输入框不支持多行显示，长文本时体验可能受限。
    - **建议修改**: 实现最多 3–5 行的自适应高度输入框。

### VA-089

89. **截图**: 全部
    - **分类**: 按钮
    - **严重级别**: 低
    - **描述**: 发送按钮为纯图标，缺少“发送”文字，新用户可能不确定功能。
    - **建议修改**: 在桌面端按钮可显示“Send”文字，移动端保持图标。

### VA-090

90. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 聊天气泡缺少已读/未读状态或发送失败重试图标。
    - **建议修改**: 为消息添加发送状态小图标（✓ / ! / ⏳）。

### VA-091

91. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 用户消息与 AI 消息都没有头像标识，长对话中难以快速识别说话者。
    - **建议修改**: 在 AI 消息旁显示小头像缩略图，用户消息显示用户头像或首字母。

### VA-092

92. **截图**: 全部
    - **分类**: 滚动
    - **严重级别**: 中
    - **描述**: 截图未展示消息较多时的滚动场景，无法判断滚动条样式和自动滚动行为。
    - **建议修改**: 补充长对话滚动截图，并自定义滚动条样式。

### VA-093

93. **截图**: 全部
    - **分类**: 性能
    - **严重级别**: 中
    - **描述**: 未展示加载大图片/模型时的占位或骨架屏，首屏可能出现空白。
    - **建议修改**: 头像加载前显示骨架屏或低分辨率占位图。

### VA-094

94. **截图**: 全部
    - **分类**: 可访问性
    - **严重级别**: 高
    - **描述**: 语音模式下“Hold to talk”操作对运动障碍用户不友好，缺少替代输入方式。
    - **建议修改**: 提供单击锁定录音模式或键盘快捷键（如空格键）。

### VA-095

95. **截图**: 全部
    - **分类**: 语言
    - **严重级别**: 中
    - **描述**: 界面文案全为英文，但产品面向中文用户时应提供中文本地化。
    - **建议修改**: 根据用户语言设置切换中英文文案。

### VA-096

96. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 屏幕四角为直角，与头像卡片的圆角风格冲突。
    - **建议修改**: 为应用窗口添加统一圆角，或使用无边框沉浸式布局。

### VA-097

97. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 用户点击麦克风后没有语音波形或音量反馈，无法判断是否在录音。
    - **建议修改**: 录音时显示实时音量波形或脉冲环。

### VA-098

98. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 语音识别结果未在界面上实时转写，用户无法即时纠正。
    - **建议修改**: 录音时显示实时转写文本流。

### VA-099

99. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 低
    - **描述**: 消息气泡内边距看起来不一致，AI 消息上下内边距大于用户消息。
    - **建议修改**: 统一消息气泡内边距为 12px 16px。

### VA-100

100. **截图**: 全部
    - **分类**: 一致性
    - **严重级别**: 中
    - **描述**: 不同模块的 AI 消息气泡颜色不同（m03 无回复、m11 为紫色），但用户消息颜色一致，缺少统一调色板。
    - **建议修改**: 制定完整 Design Token，统一 sender/AI/user 颜色。

---

## 详细逐图发现

### m03-hp1-chat-route / m03-hp2-chat-shell

### VA-101

101. **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 顶部导航栏背景与页面背景色相同，缺少底部分隔线，导航栏漂浮感弱。
    - **建议修改**: 添加 1px 底部分割线或轻微背景色差异。

### VA-102

102. **分类**: 头像
    - **严重级别**: 中
    - **描述**: 左上角应用图标与左侧头像风格完全不一致（emoji vs 写实）。
    - **建议修改**: 将应用图标统一为写实风格或品牌 Logo。

### VA-103

103. **分类**: 布局
    - **严重级别**: 低
    - **描述**: “AI Tutor”标题左侧小头像与文字基线不一致，头像偏下。
    - **建议修改**: 使用 align-items: center 垂直居中对齐。

### VA-104

104. **分类**: 空状态
    - **严重级别**: 中
    - **描述**: 空状态提示“Start a conversation!”未说明可以文字输入，用户可能误以为只能语音。
    - **建议修改**: 文案改为“Type or tap the mic to start speaking”。

### VA-105

105. **分类**: 输入框
    - **严重级别**: 中
    - **描述**: 输入框左侧麦克风按钮与输入框边框距离过近，视觉拥挤。
    - **建议修改**: 增加 8px 间距。

### VA-106

106. **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 右侧麦克风按钮与发送按钮之间距离过近，容易误触。
    - **建议修改**: 两个图标按钮间距至少 12px，热区不重叠。

### VA-107

107. **分类**: 颜色
    - **严重级别**: 低
    - **描述**: 麦克风按钮青色与发送按钮浅蓝色同时出现，两种蓝色无关联。
    - **建议修改**: 统一麦克风相关操作使用青色，发送使用品牌蓝紫色。

### VA-108

108. **分类**: 状态
    - **严重级别**: 中
    - **描述**: “AI Tutor · Ready”状态文字颜色过浅，不够醒目。
    - **建议修改**: 使用深灰色文字 + 绿色状态点。

### VA-109

109. **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头像眼部高光过强，看起来像玻璃眼球，缺少真实感。
    - **建议修改**: 降低高光强度，增加虹膜细节。

### VA-110

110. **分类**: 视觉层次
    - **严重级别**: 低
    - **描述**: 左侧头像区域缺乏焦点引导，用户视线容易直接落在输入框。
    - **建议修改**: 在头像周围添加柔和光晕，吸引视线。

### m03-hp3-typing-toggle

### VA-111

111. **分类**: 输入框
    - **严重级别**: 中
    - **描述**: 输入框聚焦后光标不明显，截图中难以判断是否已聚焦。
    - **建议修改**: 使用 2px 品牌色 caret，并提高闪烁对比。

### VA-112

112. **分类**: 按钮
    - **严重级别**: 低
    - **描述**: “Hello there”输入后发送按钮仍未变为激活态，视觉反馈延迟。
    - **建议修改**: 输入非空时立即切换为激活态颜色。

### VA-113

113. **分类**: 键盘
    - **严重级别**: 中
    - **描述**: 桌面端截图未展示移动端键盘弹出后的布局变化。
    - **建议修改**: 补充移动端键盘弹出截图，验证输入框不被遮挡。

### VA-114

114. **分类**: 排版
    - **严重级别**: 低
    - **描述**: 输入文字字号偏小，长文本可读性一般。
    - **建议修改**: 输入文字字号至少 16px。

### VA-115

115. **分类**: 交互
    - **严重级别**: 中
    - **描述**: 左侧麦克风按钮在文本输入过程中仍然存在，可能打断打字流程。
    - **建议修改**: 打字时左侧麦克风按钮可缩小或变为表情按钮。

### m03-hp4-send / m03-hp5-streaming / m03-hp6-corrections-saved / m03-hp7-tts-autoplay / m03-hp8-loading-cleared

### VA-116

116. **分类**: 聊天 UI
    - **严重级别**: 高
    - **描述**: 用户发送“ I ”后，右侧消息气泡过小，几乎没有内边距，看起来像未渲染完整。
    - **建议修改**: 保证消息气泡最小宽度 60px 或最小内边距。

### VA-117

117. **分类**: 状态
    - **严重级别**: 高
    - **描述**: hp4–hp8 五个阶段截图几乎一致，无法通过视觉区分发送、流式、保存纠正、TTS、加载清空等状态。
    - **建议修改**: 每个阶段必须有独特的视觉标识（不同状态文案、加载动画、toast）。

### VA-118

118. **分类**: 聊天 UI
    - **严重级别**: 高
    - **描述**: AI 回复迟迟未出现，但界面没有“AI 正在输入”指示，用户可能认为应用卡死。
    - **建议修改**: 在 AI 侧显示跳动点动画占位。

### VA-119

119. **分类**: 头像
    - **严重级别**: 中
    - **描述**: AI 思考期间头像保持完全静止，缺少动态反馈。
    - **建议修改**: 思考时添加 subtle 头部微点或眼神移动。

### VA-120

120. **分类**: 反馈
    - **严重级别**: 中
    - **描述**: “corrections saved”应出现成功提示，但截图中无可见反馈。
    - **建议修改**: 在屏幕底部显示“发音纠正已保存”snackbar。

### VA-121

121. **分类**: 音频
    - **严重级别**: 中
    - **描述**: TTS 自动播放时没有音量控制或静音按钮。
    - **建议修改**: 在 AI 消息旁添加音量/静音小图标。

### VA-122

122. **分类**: 反馈
    - **严重级别**: 中
    - **描述**: “loading cleared”没有清除动画或过渡，状态切换生硬。
    - **建议修改**: 加载清除时显示一个快速淡出动画。

### VA-123

123. **分类**: 性能
    - **严重级别**: 中
    - **描述**: 头像在长时间等待过程中没有降级占位，若模型加载慢会导致长时间空白。
    - **建议修改**: 加载期间显示低分辨率头像或骨架屏。

### VA-124

124. **分类**: 状态
    - **严重级别**: 中
    - **描述**: “AI Tutor · Thinking”胶囊没有动画，用户不知道是否真的在处理。
    - **建议修改**: 胶囊内文字后添加三点动画“Thinking…”。

### VA-125

125. **分类**: 颜色
    - **严重级别**: 低
    - **描述**: Thinking 状态未使用品牌警示色，仍是灰色胶囊。
    - **建议修改**: Thinking 状态使用琥珀色或品牌紫色边框。

### m10 语音模式各阶段

### VA-126

126. **分类**: 布局
    - **严重级别**: 中
    - **描述**: 语音模式下右侧聊天区完全空白，浪费大量空间。
    - **建议修改**: 在语音模式下右侧可显示转写文本、建议问题或最近对话。

### VA-127

127. **分类**: 按钮
    - **严重级别**: 高
    - **描述**: “Hold to talk”按钮是唯一视觉焦点，但其在宽屏下显得过小且孤立。
    - **建议修改**: 增大按钮尺寸或添加环绕式声波装饰。

### VA-128

128. **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 渐变按钮在浅色背景下边缘模糊，看起来有光晕溢出。
    - **建议修改**: 使用更清晰的边框或降低渐变饱和度。

### VA-129

129. **分类**: 排版
    - **严重级别**: 低
    - **描述**: “Release to transcribe”文字使用灰色，且字号过小，阅读困难。
    - **建议修改**: 字号加大至 14px，颜色加深。

### VA-130

130. **分类**: 组件
    - **严重级别**: 中
    - **描述**: “Continuous”标签图标含义不明，用户难以理解连续对话模式。
    - **建议修改**: 使用标准 Switch 组件 + 文字说明 tooltip。

### VA-131

131. **分类**: 交互
    - **严重级别**: 高
    - **描述**: 长按说话对老年人和儿童不友好，缺少一键切换。
    - **建议修改**: 提供单击开始/结束录音的切换模式。

### VA-132

132. **分类**: 反馈
    - **严重级别**: 高
    - **描述**: 按住说话时没有任何音量/波形反馈，用户不确定麦克风是否工作。
    - **建议修改**: 按住时显示环绕按钮的音量波形。

### VA-133

133. **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 录音时间没有显示，用户不知道已录多久。
    - **建议修改**: 在按钮上方显示录音时长“00:23”。

### VA-134

134. **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 右下角键盘图标过小，难以作为返回文字输入的入口。
    - **建议修改**: 放大图标并增加文字标签“键盘”。

### VA-135

135. **分类**: 头像
    - **严重级别**: 中
    - **描述**: 语音模式下头像仍是静态，没有“倾听”的表情变化。
    - **建议修改**: 录音时头像微微前倾、眼神聚焦，模拟倾听姿态。

### VA-136

136. **分类**: 动画
    - **严重级别**: 中
    - **描述**: m10 各阶段（idle breathing / head microturn / body sway / fallback / live2d branch）在静态截图中无法区分。
    - **建议修改**: 为每个阶段截取关键帧并叠加状态水印。

### VA-137

137. **分类**: 错误状态
    - **严重级别**: 高
    - **描述**: fallback renderer 阶段没有任何降级提示，用户会以为 Live2D 正常工作。
    - **建议修改**: 添加“Live2D 不可用，已切换静态模式”的非阻塞提示。

### VA-138

138. **分类**: 测试
    - **严重级别**: 低
    - **描述**: Live2D 分支与静态分支截图无法区分，回归测试容易漏检。
    - **建议修改**: 在测试构建中加入渲染模式水印。

### VA-139

139. **分类**: 颜色
    - **严重级别**: 低
    - **描述**: 语音模式底部栏颜色与页面背景完全一致，缺少分隔。
    - **建议修改**: 添加顶部 1px 分隔线或微背景色差异。

### VA-140

140. **分类**: 布局
    - **严重级别**: 中
    - **描述**: 桌面端“Hold to talk”按钮位于底部居中，但左右空间利用率低。
    - **建议修改**: 在桌面端将按钮与常用快捷问题并排放置。

### m11 情绪/多轮对话

### VA-141

141. **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: m11-hp1 中用户消息“hello”与 AI 消息“That's great!”上下间距过大，对话感松散。
    - **建议修改**: 同一轮对话间距控制在 16–20px。

### VA-142

142. **分类**: 颜色
    - **严重级别**: 中
    - **描述**: AI 消息气泡使用淡紫色，与用户消息的淡蓝色区分度不足。
    - **建议修改**: AI 消息使用更饱和的紫色或带轻微渐变。

### VA-143

143. **分类**: 按钮
    - **严重级别**: 中
    - **描述**: “Listen”按钮青色播放图标与紫色气泡背景不协调。
    - **建议修改**: Listen 按钮使用气泡同色系深色。

### VA-144

144. **分类**: 排版
    - **严重级别**: 低
    - **描述**: “Listen”文字字号小于消息文字，看起来像次要不重要的操作。
    - **建议修改**: 增大 Listen 字号或改为图标 + 文字并排按钮。

### VA-145

145. **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 消息缺少头像，无法建立人格化对话感。
    - **建议修改**: AI 消息左侧显示小圆形头像，用户消息右侧显示用户头像。

### VA-146

146. **分类**: 情绪
    - **严重级别**: 中
    - **描述**: “happy”情绪标记未在界面中可视化（无表情变化、无颜色变化）。
    - **建议修改**: happy 状态时头像微笑更明显，消息气泡可增加暖色调。

### VA-147

147. **分类**: 过渡
    - **严重级别**: 高
    - **描述**: m11-hp2 transition 截图与空状态完全相同，无法验证过渡效果。
    - **建议修改**: 捕获过渡中间帧或提供视频/GIF。

### VA-148

148. **分类**: 多轮对话
    - **严重级别**: 中
    - **描述**: m11-hp3 中“first/second”用户消息连续出现时，气泡之间没有连接感。
    - **建议修改**: 同一用户连续消息可共享头像并减少间距。

### VA-149

149. **分类**: 多轮对话
    - **严重级别**: 中
    - **描述**: m11-hp3 中 AI 连续回复“Wonderful!”和“Okay.”，但缺少时间或顺序提示。
    - **建议修改**: 在连续消息间显示“刚刚”或具体时间。

### VA-150

150. **分类**: 状态
    - **严重级别**: 中
    - **描述**: m11-hp4 waiting idle 回到空状态，但提示文案与初始空状态相同，缺少等待中的语义。
    - **建议修改**: waiting idle 时显示“我在听，随时开始说吧”并展示脉冲麦克风。

### VA-151

151. **分类**: 状态
    - **严重级别**: 中
    - **描述**: m11-hp5 thinking 回复“Hmm, let me consider.”，但头像和思考提示没有同步变化。
    - **建议修改**: 思考时头像显示思考手势，消息气泡带脉冲边框。

### VA-152

152. **分类**: 聊天 UI
    - **严重级别**: 低
    - **描述**: 用户消息气泡圆角在所有截图中不完全一致，部分看起来右上圆角偏小。
    - **建议修改**: 严格统一用户消息圆角为 16px。

### VA-153

153. **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: AI 消息气泡的“Listen”按钮重复出现，界面显得杂乱。
    - **建议修改**: 仅在最新 AI 消息显示 Listen，历史消息 hover 时才显示。

### VA-154

154. **分类**: 情绪
    - **严重级别**: 中
    - **描述**: “neutral cycle”阶段没有中性视觉表达，头像仍是微笑。
    - **建议修改**: 为 neutral 状态设计平静/默认表情。

### VA-155

155. **分类**: 响应式
    - **严重级别**: 中
    - **描述**: 多轮对话在宽屏下消息靠左对齐，远离用户操作区域。
    - **建议修改**: 聊天内容区限制最大宽度并居中，或采用左右分栏对话流。

---

## 进一步深度发现

### VA-156

156. **截图**: 全部
    - **分类**: 无障碍
    - **严重级别**: 高
    - **描述**: 界面未展示焦点轮廓（focus ring），键盘导航用户无法判断焦点位置。
    - **建议修改**: 为所有可聚焦元素添加 2px 品牌色 focus ring。

### VA-157

157. **截图**: 全部
    - **分类**: 无障碍
    - **严重级别**: 高
    - **描述**: 缺少高对比度模式或色盲友好配色。
    - **建议修改**: 提供高对比度主题，并避免仅依赖颜色传达状态。

### VA-158

158. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 页面背景为纯浅灰，缺少 subtle 纹理或渐变，显得单调。
    - **建议修改**: 添加极淡的品牌渐变或点阵纹理。

### VA-159

159. **截图**: 全部
    - **分类**: 布局
    - **严重级别**: 中
    - **描述**: 左侧头像卡片与右侧内容区之间没有明确分隔线，边界感弱。
    - **建议修改**: 在两区之间添加 1px 垂直分隔线。

### VA-160

160. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头像整体光线方向不明确，服装高光与背景光源不一致。
    - **建议修改**: 统一光照方向，确保人物与背景光影一致。

### VA-161

161. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头发质感像塑料丝，缺少发丝细节和自然飘逸感。
    - **建议修改**: 使用更高质量的素材或降低 AI 生成平滑度。

### VA-162

162. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 低
    - **描述**: 头像下方被截断位置正好在胸口，给人“被裁剪”的不适感。
    - **建议修改**: 截断位置调整至胸部以下，或添加渐变淡出。

### VA-163

163. **截图**: 全部
    - **分类**: 组件
    - **严重级别**: 中
    - **描述**: 顶部状态胶囊“AI Tutor · Ready/Thinking”左侧小圆点颜色不明显。
    - **建议修改**: 使用饱和度更高的状态点（绿色 Ready / 琥珀色 Thinking）。

### VA-164

164. **截图**: 全部
    - **分类**: 输入框
    - **严重级别**: 中
    - **描述**: 输入框边框颜色过浅，未聚焦时几乎不可见。
    - **建议修改**: 未聚焦边框颜色加深至 #D1D5DB。

### VA-165

165. **截图**: 全部
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 麦克风按钮与发送按钮尺寸不一致，视觉节奏混乱。
    - **建议修改**: 统一底部操作按钮尺寸（44×44dp）。

### VA-166

166. **截图**: 全部
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 没有展示长按麦克风后的取消/滑动取消功能。
    - **建议修改**: 补充取消录音的交互截图并设计滑动取消 UI。

### VA-167

167. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 未展示消息上下文菜单（长按/右键菜单）。
    - **建议修改**: 为消息补充复制、朗读、删除等上下文操作截图。

### VA-168

168. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 未展示网络断开、API 错误等异常状态。
    - **建议修改**: 设计并截图展示错误提示、重试按钮。

### VA-169

169. **截图**: 全部
    - **分类**: 品牌
    - **严重级别**: 中
    - **描述**: 应用 favicon 或标题栏未在截图中体现。
    - **建议修改**: 确保浏览器标签页显示 SpeakFlow 品牌 favicon 和标题。

### VA-170

170. **截图**: 全部
    - **分类**: 视觉层次
    - **严重级别**: 低
    - **描述**: 空状态图标使用浅灰色，与背景融合，缺少视觉焦点。
    - **建议修改**: 空状态图标使用品牌色并添加轻微动画。

### VA-171

171. **截图**: 全部
    - **分类**: 响应式
    - **严重级别**: 高
    - **描述**: 没有窄屏截图，无法验证头像卡片在移动端是否隐藏或缩小。
    - **建议修改**: 补充 375px 宽度移动端截图。

### VA-172

172. **截图**: 全部
    - **分类**: 响应式
    - **严重级别**: 高
    - **描述**: 没有超宽屏截图，无法验证 4K/ultrawide 下的布局表现。
    - **建议修改**: 补充 1920px+ 宽度截图，限制内容最大宽度。

### VA-173

173. **截图**: 全部
    - **分类**: 性能
    - **严重级别**: 中
    - **描述**: 截图中未体现图片懒加载或骨架屏，首屏可能出现空白。
    - **建议修改**: 头像和头像背景使用渐进式加载。

### VA-174

174. **截图**: 全部
    - **分类**: 安全
    - **严重级别**: 中
    - **描述**: 未展示麦克风/摄像头权限请求的 UI，可能缺少权限解释文案。
    - **建议修改**: 设计权限请求弹窗，说明为何需要麦克风权限。

### VA-175

175. **截图**: 全部
    - **分类**: 本地化
    - **严重级别**: 中
    - **描述**: 所有文案均为英文，缺少中文、日文等多语言截图。
    - **建议修改**: 补充主要目标语言截图，检查文本截断。

### VA-176

176. **截图**: 全部
    - **分类**: 字体
    - **严重级别**: 低
    - **描述**: 标题与正文字体家族相同，缺少字号/字重层次。
    - **建议修改**: 标题使用更大字号和 semibold 字重。

### VA-177

177. **截图**: 全部
    - **分类**: 组件
    - **严重级别**: 中
    - **描述**: 右上角“更多”菜单图标为竖三点，但不确定是否包含设置、关于、退出等必要项。
    - **建议修改**: 补充更多菜单展开截图。

### VA-178

178. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 消息气泡缺少悬停/点击反馈，交互感弱。
    - **建议修改**: 为消息气泡添加 hover 背景变化或按压效果。

### VA-179

179. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: AI 头像没有眨眼、呼吸等自然微动作，显得僵硬。
    - **建议修改**: 即使静态截图无法展示，也应通过设计规范保证 idle 动画存在。

### VA-180

180. **截图**: 全部
    - **分类**: 情绪
    - **严重级别**: 中
    - **描述**: 情绪状态（happy / neutral / thinking / waiting）没有对应的系统级视觉主题变化。
    - **建议修改**: 不同情绪下可微调头像光晕、状态胶囊颜色、气泡色调。

### VA-181

181. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 未展示录音音量过小、网络延迟等中间状态提示。
    - **建议修改**: 设计“听不清，请靠近麦克风”等提示。

### VA-182

182. **截图**: 全部
    - **分类**: 输入框
    - **严重级别**: 低
    - **描述**: 输入框右侧麦克风图标在文本模式下重复了左侧功能，界面冗余。
    - **建议修改**: 删除右侧小麦克风图标，或将其改为语音输入切换开关。

### VA-183

183. **截图**: 全部
    - **分类**: 按钮
    - **严重级别**: 中
    - **描述**: 发送按钮为圆形，但内部纸飞机图标偏小，没有填满按钮。
    - **建议修改**: 放大发送图标，确保视觉中心居中。

### VA-184

184. **截图**: 全部
    - **分类**: 颜色
    - **严重级别**: 中
    - **描述**: 界面整体冷暖色调混用（头像偏冷蓝、按钮偏青、消息偏紫），缺乏统一色彩方向。
    - **建议修改**: 建立以蓝紫色为主、青色为强调的统一调色板。

### VA-185

185. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 头像卡片背景天空与左侧屏幕边缘之间有轻微白边，像未完全填充。
    - **建议修改**: 检查图片 object-fit 和容器 overflow，确保背景铺满。

### VA-186

186. **截图**: 全部
    - **分类**: 布局
    - **严重级别**: 中
    - **描述**: 右侧聊天区内容在空状态时垂直居中，但在有消息后未保持从底部向上堆叠的常规聊天体验。
    - **建议修改**: 有消息时聊天内容从底部开始堆叠，空状态时居中。

### VA-187

187. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 未展示富文本、链接、代码块、图片等多媒体消息渲染。
    - **建议修改**: 补充富文本消息截图并设计对应气泡样式。

### VA-188

188. **截图**: 全部
    - **分类**: 性能
    - **严重级别**: 中
    - **描述**: 未展示大量消息滚动时的渲染性能，可能存在卡顿。
    - **建议修改**: 长对话截图并监控帧率。

### VA-189

189. **截图**: 全部
    - **分类**: 可访问性
    - **严重级别**: 高
    - **描述**: 自动播放 TTS 没有暂停/停止控制，对听力辅助技术用户不友好。
    - **建议修改**: 添加全局 TTS 播放/暂停控制条。

### VA-190

190. **截图**: 全部
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 没有展示语音输入的“正在识别…”过渡状态。
    - **建议修改**: 识别中在按钮附近显示转写文字和旋转指示器。

### VA-191

191. **截图**: 全部
    - **分类**: 品牌
    - **严重级别**: 中
    - **描述**: 加载/启动画面未在截图中体现，可能缺少品牌启动页。
    - **建议修改**: 设计带有 SpeakFlow Logo 和加载动画的启动页。

### VA-192

192. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 头像卡片的圆角与屏幕圆角（如果有）不匹配，窗口边缘显得生硬。
    - **建议修改**: 统一应用窗口和组件圆角规范。

### VA-193

193. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 消息气泡内的文字行高偏小，长文本可读性一般。
    - **建议修改**: 行高设置为 1.5 倍字号。

### VA-194

194. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: AI 头像表情过于单一，无法体现个性化和情感连接。
    - **建议修改**: 建立多套表情资产，根据对话情绪动态切换。

### VA-195

195. **截图**: 全部
    - **分类**: 组件
    - **严重级别**: 中
    - **描述**: 状态胶囊“AI Tutor · Ready”没有点击/展开能力，用户无法查看更详细状态。
    - **建议修改**: 点击状态胶囊可展开连接状态、模型版本、TTS 状态等信息。

### VA-196

196. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 未展示语音识别失败的反馈 UI。
    - **建议修改**: 识别失败时显示“未能听清，请重试”并自动保持录音状态。

### VA-197

197. **截图**: 全部
    - **分类**: 安全/隐私
    - **严重级别**: 中
    - **描述**: 未展示录音指示器（如红点录音中），用户无法明确知晓何时在录音。
    - **建议修改**: 录音时在屏幕某处显示红色录音指示器。

### VA-198

198. **截图**: 全部
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 没有展示语音模式与文本模式之间的切换动画。
    - **建议修改**: 设计并截图展示模式切换的过渡动画。

### VA-199

199. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 页面整体缺少微交互（hover、pressed、ripple），静态感强。
    - **建议修改**: 为按钮、消息气泡、输入框添加 ripple 或 scale 反馈。

### VA-200

200. **截图**: 全部
    - **分类**: 测试覆盖
    - **严重级别**: 中
    - **描述**: 截图集缺少断网、弱网、慢速 TTS、ASR 错误、权限拒绝等边界场景。
    - **建议修改**: 扩展 E2E 截图用例，覆盖异常和边界状态。

### VA-201

201. **截图**: 全部
    - **分类**: 视觉层次
    - **严重级别**: 低
    - **描述**: 右侧聊天区顶部缺少标题或日期栏，空状态时区域边界模糊。
    - **建议修改**: 在聊天区顶部添加轻量级标题栏或日期显示。

### VA-202

202. **截图**: 全部
    - **分类**: 一致性
    - **严重级别**: 中
    - **描述**: 文本输入模式与语音模式的底部栏高度不一致，切换时产生布局跳动。
    - **建议修改**: 统一底部栏高度为 72px，仅切换内部控件。

### VA-203

203. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头像的肤色经过过度磨皮，缺少毛孔和皮肤纹理，降低真实感。
    - **建议修改**: 降低磨皮强度，保留自然皮肤细节。

### VA-204

204. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 头像背景云朵过于平滑，看起来像 AI 生成痕迹，缺少自然噪点。
    - **建议修改**: 添加 subtle 纹理或更换为摄影背景。

### VA-205

205. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 用户开始打字后，空状态提示没有即时消失，可能与新消息重叠。
    - **建议修改**: 一旦有用户输入或消息，空状态提示应立即淡出。

### VA-206

206. **截图**: 全部
    - **分类**: 组件
    - **严重级别**: 中
    - **描述**: “Continuous”标签缺少关闭/开启的明确视觉反馈。
    - **建议修改**: 使用 Material Switch 组件并带 on/off 标签。

### VA-207

207. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 用户消息气泡内的文字未设置最大宽度，长句可能撑满整个右侧。
    - **建议修改**: 设置用户消息最大宽度为聊天区宽度的 70–75%。

### VA-208

208. **截图**: 全部
    - **分类**: 可访问性
    - **严重级别**: 高
    - **描述**: 渐变按钮上的白色文字在青紫交界处对比度不足，可能不符合 WCAG AA。
    - **建议修改**: 在文字层下方添加半透明遮罩或改用深色文字。

### VA-209

209. **截图**: 全部
    - **分类**: 品牌
    - **严重级别**: 中
    - **描述**: 所有截图中未出现 SpeakFlow 的产品标语或价值主张。
    - **建议修改**: 在空状态或启动页加入品牌标语。

### VA-210

210. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 页面四角与头像圆角风格不一致，整体像临时窗口而非完整应用。
    - **建议修改**: 为 Web 应用容器添加统一圆角和窗口阴影。

### VA-211

211. **截图**: 全部
    - **分类**: 交互
    - **严重级别**: 中
    - **描述**: 缺少快捷问题/建议提示，空状态时用户可能不知道该说什么。
    - **建议修改**: 在空状态或语音模式下展示“你可以问我…”快捷提示。

### VA-212

212. **截图**: 全部
    - **分类**: 头像
    - **严重级别**: 中
    - **描述**: 头像的眼睛注视方向始终正对镜头，缺少与用户交流时的自然眼神接触变化。
    - **建议修改**: 根据对话状态微调眼球注视方向。

### VA-213

213. **截图**: 全部
    - **分类**: 视觉
    - **严重级别**: 低
    - **描述**: 页面背景缺乏深度，缺少分层阴影或渐变层次。
    - **建议修改**: 为背景添加极淡的径向渐变或分层卡片阴影。

### VA-214

214. **截图**: 全部
    - **分类**: 聊天 UI
    - **严重级别**: 中
    - **描述**: 没有展示消息撤回、编辑功能，长对话管理体验未知。
    - **建议修改**: 设计消息编辑/撤回交互并补充截图。

### VA-215

215. **截图**: 全部
    - **分类**: 反馈
    - **严重级别**: 中
    - **描述**: 没有展示 TTS 播放完成后的视觉反馈。
    - **建议修改**: TTS 播放完成时在 Listen 按钮上短暂显示勾选动画。

### VA-216

216. **截图**: 全部
    - **分类**: 可访问性
    - **严重级别**: 高
    - **描述**: 缺少字幕/转写显示，听力障碍用户无法使用语音功能。
    - **建议修改**: 在语音模式下实时显示 ASR 转写文本。

### VA-217

217. **截图**: 全部
    - **分类**: 性能
    - **严重级别**: 中
    - **描述**: 未展示头像模型加载失败时的占位 UI。
    - **建议修改**: 头像加载失败时显示默认占位图和重试按钮。

### VA-218

218. **截图**: 全部
    - **分类**: 组件
    - **严重级别**: 中
    - **描述**: 顶部导航栏右侧图标过多（分享、更多），缺少文字说明。
    - **建议修改**: 为图标添加 tooltip 或展开菜单说明。

### VA-219

219. **截图**: 全部
    - **分类**: 视觉层次
    - **严重级别**: 低
    - **描述**: 底部输入栏与页面背景无分隔，漂浮感不足。
    - **建议修改**: 为输入栏添加上方投影或背景色差异。

### VA-220

220. **截图**: 全部
    - **分类**: 品牌
    - **严重级别**: 中
    - **描述**: 缺少用户头像或用户身份标识，用户感觉不到“自己”在对话。
    - **建议修改**: 在设置中允许上传头像，并在用户消息旁显示。

---

## 总结

本次视觉审计共识别 **220 条** 发现，涵盖布局、视觉、响应式、头像、聊天 UI、颜色、排版、交互、无障碍、品牌、状态反馈等多个维度。高优先级问题主要集中在：

### VA-221

1. **状态反馈不足**：m03 多个阶段（发送、流式、TTS、加载清空）视觉差异极小，用户难以感知应用状态。

### VA-222

2. **响应式覆盖缺失**：所有截图均为单一桌面宽度，未验证移动端和超宽屏。

### VA-223

3. **头像真实感与动态表现**：AI 头像静态、表情单一、恐怖谷效应明显，且缺少情绪/思考动画。

### VA-224

4. **语音模式交互反馈**：录音/识别过程缺少音量波形、时长、转写等关键反馈。

### VA-225

5. **无障碍与品牌**：缺少焦点轮廓、高对比度、文字标签和品牌一致性。

建议优先修复高严重级别问题，并扩展 E2E 截图用例以覆盖更多断点、异常状态和情绪动画关键帧。

## E2E 覆盖缺口（130 条）

### E2E-001

## 1. 执行摘要

本次审计基于对 Playwright 配置、`setup.ts`、`screenshots.ts` 及全部 28 个 spec 文件的逐行阅读，围绕 **移动端视口覆盖、截图留存、双端对比、Happy-Path 旅程、错误态、Avatar/Chat 移动端** 六大维度进行结构化梳理，共识别出 **120 条可执行的覆盖缺口**。其中高优先级 22 条、中优先级 73 条、低优先级 25 条。

核心发现：
- **移动端覆盖严重不足**：除 `home/dashboard.spec.ts`、`voice-health.spec.ts`、`system/banners-version.spec.ts` 等少量文件外，绝大多数 spec 默认使用 1280×800 桌面视口，未在 375×812 或更小视口下验证布局与交互。
- **双端对比机制闲置**：`screenshots.ts` 已提供 `captureDesktopAndMobile`，但没有任何 spec 调用该函数；多数测试仅依赖 Playwright 项目级别的视口差异，而非在单条用例内主动验证两端。
- **截图捕获流于形式**：大量异常分支仅做 `expectNoException`，未在关键错误态、加载态、空态、弹窗等节点截图。
- **Happy-Path 旅程碎片化**：测试按模块孤立编写，缺少跨屏幕的端到端用户旅程（如 onboarding → placement → home → chat → review → progress）。
- **错误态断言偏弱**：大量异常用例使用 `expectNoException` 或 `|| true` 形式的弱断言，未验证错误提示文案、恢复按钮、重试行为。
- **Avatar/Chat 移动端存在明显空白**：avatar 的 canvas 渲染、呼吸/眨眼/唇同步/情绪切换在移动端完全未验证；chat 的输入框、mic 按钮、消息气泡、correction card 在小屏下的布局也未覆盖。

---

### E2E-002

## 2. 覆盖缺口清单（共 120 条）

### 维度 1：移动端视口覆盖缺失（1–30）

### E2E-003

**1. Chat 文字消息 — 移动端视口未验证**
- **模块/feature**: `chat/text-messaging.spec.ts`（M03）
- **Gap description**: 全部 27 个测试均使用默认桌面视口（1280×800），未在 375×812 下验证消息气泡、输入框、发送按钮的排版与可点击性。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1（Home Start Conversation → /chat/:id）等核心用例中增加 `await page.setViewportSize(MOBILE_VIEWPORT)`，并断言发送按钮、输入框、`MessageBubble` 可见且不重叠。
- **Priority**: high

### E2E-004

**2. Chat 语音输入 — 移动端 mic 按钮未验证**
- **模块/feature**: `chat/voice-input.spec.ts`（M04）
- **Gap description**: 27 个测试均在桌面运行，未验证移动端 mic 按钮的显示、按住录音手势、录音中波纹动画及权限提示。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 专用用例：设置 MOBILE_VIEWPORT 后进入 chat，断言 mic 按钮在底部居中显示，模拟按住/释放事件触发录音状态切换。
- **Priority**: high

### E2E-005

**3. Chat TTS 播放 — 移动端播放控制未验证**
- **模块/feature**: `chat/tts-playback.spec.ts`（M06）
- **Gap description**: 31 个测试无移动端视口，未验证 TTS 自动播放后移动端扬声器图标、暂停/重播按钮的可触达性。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1 基础上复制一条 mobile 用例，断言 TTS 播放指示器在 375pt 宽度下不被截断，且点击重播按钮有效。
- **Priority**: medium

### E2E-006

**4. Chat 连续模式 — 移动端 auto-rearm 未验证**
- **模块/feature**: `chat/continuous-mode.spec.ts`（M07）
- **Gap description**: 23 个测试均在桌面验证 continuous 模式，未在移动端验证 TTS 结束后 mic 自动重新武装及 barge-in（打断）行为。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：375×812 下启用 continuous，发送消息后验证 mic 按钮在 500ms 后重新出现，并可在播放过程中再次点击打断。
- **Priority**: high

### E2E-007

**5. Chat 纠错卡片 — 移动端布局未验证**
- **模块/feature**: `chat/corrections.spec.ts`（M05）
- **Gap description**: 25 个测试未切换移动端视口，未验证 correction card 在窄屏下的换行、severity chip 不被截断、解释文本可读。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1 增加 mobile 变体，使用 `captureAtViewport(MOBILE_VIEWPORT)` 并断言 correction card 宽度小于屏幕宽度。
- **Priority**: medium

### E2E-008

**6. Chat 会话管理 — 移动端选项菜单未验证**
- **模块/feature**: `chat/session-management.spec.ts`（M08）
- **Gap description**: 25 个测试未在移动端验证会话列表、归档/删除/重命名选项的底部 sheet 或弹窗布局。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：MOBILE_VIEWPORT 下打开 session options，断言操作按钮纵向排列，且删除确认弹窗覆盖安全区域。
- **Priority**: medium

### E2E-009

**7. Chat 导师摘要 — 移动端 tutor cards 未验证**
- **模块/feature**: `chat/tutor-summary.spec.ts`（M28）
- **Gap description**: 47 个测试全部桌面运行，未验证 6 张 tutor card 在移动端的网格/列表切换、名称截断、头像显示。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-2 增加 mobile 变体，断言 tutor cards 在 375pt 宽度下以单列或双列显示，无横向溢出。
- **Priority**: medium

### E2E-010

**8. Chat 错误态 — 移动端错误提示未验证**
- **模块/feature**: `chat/error-states.spec.ts`（M09）
- **Gap description**: 25 个测试未在移动端验证 LLM 500、STT 失败、TTS 失败时的 snackbar 位置、文案换行、重试按钮可点击。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 为 LLM 500、STT 失败、TTS 失败各新增一条 mobile 用例，断言 snackbar 出现在底部且不与输入框重叠。
- **Priority**: high

### E2E-011

**9. Avatar idle 动画 — 移动端 canvas 渲染未验证**
- **模块/feature**: `avatar/idle.spec.ts`（M10）
- **Gap description**: 23 个测试均在桌面验证呼吸/眨眼动画，未在移动端验证 avatar canvas 尺寸适配、不被底部输入栏遮挡。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：进入 chat 后设置 MOBILE_VIEWPORT，断言 avatar canvas 仍渲染且可见区域占比合理。
- **Priority**: high

### E2E-012

**10. Avatar 情绪标记 — 移动端情绪过渡未验证**
- **模块/feature**: `avatar/emotion.spec.ts`（M11）
- **Gap description**: 23 个测试未在移动端验证 `[emotion:happy]` 等标记触发后的表情过渡、UI 不被截断。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1 增加 mobile 变体，验证情绪切换后 bubble 文本与 avatar 表情同时更新，且无布局错位。
- **Priority**: medium

### E2E-013

**11. Avatar 唇同步 — 移动端 viseme 渲染未验证**
- **模块/feature**: `avatar/lip-sync.spec.ts`（M12）
- **Gap description**: 23 个测试未在移动端验证 TTS 播放时的 viseme 时间轴与嘴型动画在小屏上的性能与渲染。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：MOBILE_VIEWPORT 下触发 TTS，断言 avatar 仍处于渲染状态，无 WebGL/Canvas 崩溃。
- **Priority**: medium

### E2E-014

**12. Onboarding — 移动端欢迎页未验证**
- **模块/feature**: `onboarding/onboarding.spec.ts`（M01）
- **Gap description**: 42 个测试均在桌面运行，未验证欢迎页、目标选择、水平选择等步骤在移动端的纵向滚动与按钮位置。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-2（welcome page）增加 mobile 变体，断言 Get Started CTA 位于可视区域内，无需滚动即可点击。
- **Priority**: high

### E2E-015

**13. Placement 测试 — 移动端答题界面未验证**
- **模块/feature**: `onboarding/placement.spec.ts`（M02）
- **Gap description**: 48 个测试未在移动端验证 placement 题目、选项、结果页的排版与交互。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：MOBILE_VIEWPORT 下完成 placement，断言每道题选项可点击，结果页等级卡片完整显示。
- **Priority**: high

### E2E-016

**14. Home 每日计划 — 移动端任务卡片未验证**
- **模块/feature**: `home/daily-plan.spec.ts`（M20）
- **Gap description**: 37 个测试未在移动端验证 today tasks 卡片的优先级布局、标题截断、按钮可点击。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1 增加 mobile 变体，断言 1–5 张任务卡片在 375pt 宽度下纵向堆叠，无横向滚动。
- **Priority**: medium

### E2E-017

**15. Home 能力雷达 — 移动端雷达图未验证**
- **模块/feature**: `home/ability-goals.spec.ts`（M21）
- **Gap description**: 42 个测试未在移动端验证能力雷达图 4 轴的渲染、标签不被截断。
- **Affected viewport**: mobile
- **Suggested test modification**: 新增 mobile 用例：设置 MOBILE_VIEWPORT 后断言雷达图 canvas 渲染且 4 个轴标签可见。
- **Priority**: medium

### E2E-018

**16. Home 连续打卡 — 移动端 30 天点阵未验证**
- **模块/feature**: `home/streak.spec.ts`（M19）
- **Gap description**: 41 个测试未在移动端验证 30 天点阵网格的换行、火标、连续天数文本。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1 增加 mobile 变体，断言 30 个点在窄屏下以 7 列换行显示，无重叠。
- **Priority**: low

### E2E-019

**17. Progress Dashboard — 移动端图表与卡片未验证**
- **模块/feature**: `progress/dashboard.spec.ts`（M25）
- **Gap description**: 23 个测试均在桌面运行，未验证 mastery breakdown、error distribution、7-day activity、heatmap、weekly trend、weak-area card 在移动端的纵向排版。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 为 HP-1–HP-6 各增加 mobile 变体，或使用 `captureAtViewport(MOBILE_VIEWPORT)` 对关键图表截图。
- **Priority**: medium

### E2E-020

**18. Pronunciation History — 移动端会话列表未验证**
- **模块/feature**: `progress/pronunciation-history.spec.ts`（M26）
- **Gap description**: 19 个测试未在移动端验证历史列表、搜索栏、发音详情页的排版。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-6（history list）增加 mobile 变体，断言搜索框在顶部可见，会话卡片不溢出屏幕。
- **Priority**: medium

### E2E-021

**19. Review SM-2 — 移动端复习卡片未验证**
- **模块/feature**: `review/sm2-review.spec.ts`（M24）
- **Gap description**: 25 个测试未在移动端验证 due corrections 列表、Again/Hard/Good/Easy 评分栏的触控面积与布局。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：设置 MOBILE_VIEWPORT 后断言评分按钮在底部横向排布，且可点击。
- **Priority**: medium

### E2E-022

**20. Scenarios — 移动端场景卡片与练习未验证**
- **模块/feature**: `scenarios/scenarios.spec.ts`（M27）
- **Gap description**: 23 个测试未在移动端验证场景卡片网格、分类/难度筛选、句子练习录音界面。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1、HP-4、HP-5 增加 mobile 变体，断言筛选 chips 可横向滚动，练习页 mic 按钮位于拇指热区。
- **Priority**: medium

### E2E-023

**21. Projects — 移动端项目卡片与表单未验证**
- **模块/feature**: `projects/projects.spec.ts`（M29）
- **Gap description**: 24 个测试未在移动端验证项目卡片列表、新建表单对话框、详情页活动流。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1、HP-2、HP-3 增加 mobile 变体，断言 FAB 不遮挡卡片，表单对话框在 375pt 下完整显示。
- **Priority**: medium

### E2E-024

**22. LLM Profile CRUD — 移动端表单与列表未验证**
- **模块/feature**: `profile/llm-crud.spec.ts`（M13）
- **Gap description**: 37 个测试未在移动端验证 LLM 列表、provider picker、表单输入、删除确认。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1、HP-2、HP-4 增加 mobile 变体，断言 provider picker 在窄屏下可滚动，保存按钮不被键盘遮挡。
- **Priority**: medium

### E2E-025

**23. STT Profile CRUD — 移动端语言选择器未验证**
- **模块/feature**: `profile/stt-crud.spec.ts`（M14）
- **Gap description**: 30 个测试未在移动端验证 STT 列表、language picker、Azure region 字段。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-6 增加 mobile 变体，断言 language picker 弹窗在 375pt 宽度下选项可点击。
- **Priority**: medium

### E2E-026

**24. TTS Profile CRUD — 移动端 speed slider 未验证**
- **模块/feature**: `profile/tts-crud.spec.ts`（M15）
- **Gap description**: 58 个测试未在移动端验证 TTS 表单、speed slider 0.75×–1.5× 的触控交互。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-7 增加 mobile 变体，断言 slider 在窄屏下可拖动且当前值清晰可读。
- **Priority**: low

### E2E-027

**25. Service Config — 移动端三栏布局未验证**
- **模块/feature**: `profile/service-config.spec.ts`（M16）
- **Gap description**: 50 个测试除 active profile 切换外，未在移动端验证 LLM/STT/TTS 三栏的 tab/accordion 切换。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1 增加 mobile 变体，断言三栏在移动端以 tab 或折叠形式展示，切换后内容可见。
- **Priority**: medium

### E2E-028

**26. Voice Health — 移动端 touch 交互覆盖不足**
- **模块/feature**: `profile/voice-health.spec.ts`（M17）
- **Gap description**: 虽有 BR-12 设置 MOBILE_VIEWPORT，但仅做截图，未验证 Run Check 按钮的 touch target、状态行纵向布局、失败项的折叠/展开。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 BR-12 基础上新增 mobile 用例：断言 Run Check 按钮高度 ≥ 44pt，四个检查行纵向排列且状态 chip 不重叠。
- **Priority**: medium

### E2E-029

**27. Settings 主题/语言 — 移动端设置页未验证**
- **模块/feature**: `settings/theme-language.spec.ts`（M22）
- **Gap description**: 23 个测试未在移动端验证主题/语言 picker 弹窗、RadioListTile 列表、保存按钮位置。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-5、BR-1、BR-2 增加 mobile 变体，断言 language picker 弹窗在 375pt 下完整显示且选项可点。
- **Priority**: medium

### E2E-030

**28. Settings App Section — 移动端 About/Updates 未验证**
- **模块/feature**: `settings/app-section.spec.ts`（M23）
- **Gap description**: 23 个测试未在移动端验证 About dialog、Check for updates、Re-run onboarding 等 tiles 的触控与弹窗布局。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 HP-1–HP-5 增加 mobile 变体，断言 About dialog 在窄屏下居中且关闭按钮可见。
- **Priority**: low

### E2E-031

**29. System Banners — 仅验证 iPhone SE，未覆盖标准移动端视口**
- **模块/feature**: `system/banners-version.spec.ts`（M30）
- **Gap description**: BR-4 仅验证 320×568 的 iPhone SE，未在 375×812（Pixel 5 / iPhone X-class）标准移动端视口验证 banner 不截断。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增用例：设置 MOBILE_VIEWPORT（375×812）并 mock 新版本，断言 banner 文本在两行内显示，关闭按钮可见。
- **Priority**: medium

### E2E-032

**30. Home Dashboard — 移动端用例仅截图，缺少交互断言**
- **模块/feature**: `home/dashboard.spec.ts`（M18）
- **Gap description**: BR-9、BR-10 使用 `captureAtViewport` 对 iPad/iPhone SE 截图，但未在 375×812 下验证 quick-action 按钮可点击、各 section 不重叠。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 在 MOBILE_VIEWPORT 下新增交互用例：点击 Start Conversation 按钮应跳转 `/chat/:id`，并断言 dashboard 六个 section 纵向排列无重叠。
- **Priority**: high

---

### 维度 2：截图捕获缺失（31–50）

### E2E-033

**31. Chat 文字消息 — 流式输出与加载态未截图**
- **模块/feature**: `chat/text-messaging.spec.ts`（M03）
- **Gap description**: HP-1 仅在进入 /chat/:id 后截图，未在消息发送中、AI 流式输出、打字指示器显示时截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在发送消息后、流式输出过程中分别调用 `capture(page, 'm03-streaming')` 与 `capture(page, 'm03-typing')`。
- **Priority**: medium

### E2E-034

**32. Chat 语音输入 — 录音中状态未截图**
- **模块/feature**: `chat/voice-input.spec.ts`（M04）
- **Gap description**: 未在按住 mic 录音、STT 转写中、转写完成等关键状态截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在触发录音后调用 `capture(page, 'm04-recording')`，在转写结果出现后调用 `capture(page, 'm04-transcribed')`。
- **Priority**: medium

### E2E-035

**33. Chat TTS 播放 — 播放/暂停状态未截图**
- **模块/feature**: `chat/tts-playback.spec.ts`（M06）
- **Gap description**: HP-1 在 TTS 自动播放后截图，但未捕获播放中指示器、暂停状态、播放完成状态。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 TTS 播放期间、播放结束后分别截图，并断言扬声器图标状态变化。
- **Priority**: medium

### E2E-036

**34. Chat 连续模式 — 状态切换未截图**
- **模块/feature**: `chat/continuous-mode.spec.ts`（M07）
- **Gap description**: 未在 continuous 模式启用、mic auto-rearm、barge-in 触发瞬间截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 toggle continuous chip、auto-rearm 完成后分别调用 `capture()`。
- **Priority**: medium

### E2E-037

**35. Chat 纠错卡片 — 卡片展开/收起未截图**
- **模块/feature**: `chat/corrections.spec.ts`（M05）
- **Gap description**: HP-1 仅在 correction card 渲染后截图，未捕获卡片展开、severity chip、explanation 展开状态。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增用例：点击 correction card 展开 explanation 并截图 `m05-correction-expanded`。
- **Priority**: low

### E2E-038

**36. Chat 会话管理 — 选项菜单与确认弹窗未截图**
- **模块/feature**: `chat/session-management.spec.ts`（M08）
- **Gap description**: `openSessionOptions` 弹出的菜单未截图，archive/delete 确认弹窗也未截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 `openSessionOptions` 后、确认弹窗出现后分别调用 `capture()`。
- **Priority**: medium

### E2E-039

**37. Chat 导师摘要 — tutor 详情与选择态未截图**
- **模块/feature**: `chat/tutor-summary.spec.ts`（M28）
- **Gap description**: 6 张 tutor cards 渲染后仅一张截图，未捕获选中态、hover/press 反馈、详情展开。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在选择某 tutor 后截图 `m28-tutor-selected`，并 capture 详情面板。
- **Priority**: low

### E2E-040

**38. Avatar idle — 呼吸/眨眼中间帧未截图**
- **模块/feature**: `avatar/idle.spec.ts`（M10）
- **Gap description**: HP-1 在 settle 1200ms 后截图，但未在 0ms、600ms 等中间时刻捕获呼吸与眨眼动画帧。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 0ms、600ms、1200ms 分别调用 `captureElement(page, 'canvas', 'm10-idle-frame-{n}')`。
- **Priority**: low

### E2E-041

**39. Avatar 情绪 — 情绪过渡帧未截图**
- **模块/feature**: `avatar/emotion.spec.ts`（M11）
- **Gap description**: 未在 `[emotion:happy]` 等标记触发后的过渡动画中截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在发送带情绪标记的消息后，于 0ms/500ms/1000ms 分别截图以验证过渡平滑。
- **Priority**: low

### E2E-042

**40. Avatar 唇同步 — viseme 关键帧未截图**
- **模块/feature**: `avatar/lip-sync.spec.ts`（M12）
- **Gap description**: 未在 TTS 播放过程中的 viseme 关键帧截图，无法验证嘴型变化。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 TTS 播放 0ms/500ms/1000ms 分别调用 `captureElement(page, 'canvas', 'm12-viseme-frame-{n}')`。
- **Priority**: low

### E2E-043

**41. Onboarding — 中间步骤未截图**
- **模块/feature**: `onboarding/onboarding.spec.ts`（M01）
- **Gap description**: 仅对 welcome、目标选择等少数节点截图，profile setup、水平选择、完成页未逐一截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 为每个 onboarding 步骤增加 `capture()`，命名遵循 `m01-step-{n}`。
- **Priority**: medium

### E2E-044

**42. Placement — 题目与结果页未截图**
- **模块/feature**: `onboarding/placement.spec.ts`（M02）
- **Gap description**: 48 个测试中大量题目切换、结果页等级展示未截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在答题过程中、结果页渲染后分别截图，并捕获最终等级卡片。
- **Priority**: medium

### E2E-045

**43. Profile CRUD — 保存成功/失败提示未截图**
- **模块/feature**: `profile/llm-crud.spec.ts`、`profile/stt-crud.spec.ts`、`profile/tts-crud.spec.ts`（M13–M15）
- **Gap description**: 异常用例 EX-20–EX-25 多使用弱断言，未在保存成功/失败的 snackbar 出现时截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在点击 Save 后、snackbar 可见时调用 `capture()` 并断言文案包含 “saved”/“failed”。
- **Priority**: medium

### E2E-046

**44. Service Config — active switch 动画与 popup 菜单未截图**
- **模块/feature**: `profile/service-config.spec.ts`（M16）
- **Gap description**: HP-3 切换 active profile 后截图，但未捕获切换瞬间的 badge 动画；popup 菜单打开后也未截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在点击 inactive profile 前、后，以及打开 popup 菜单后分别截图。
- **Priority**: low

### E2E-047

**45. Voice Health — 检查前/中/后三态未截图**
- **模块/feature**: `profile/voice-health.spec.ts`（M17）
- **Gap description**: HP-4/HP-5 在 Run Check 后截图，但未捕获 pending、running、completed 三种状态的对比截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在点击 Run Check 前、按钮显示 “Checking...” 时、四个检查项全部完成后分别截图。
- **Priority**: medium

### E2E-048

**46. Progress Dashboard — 加载态 shimmer 与错误态未截图**
- **模块/feature**: `progress/dashboard.spec.ts`（M25）
- **Gap description**: BR-12 捕获 loading，但其他异常用例未截图；per-section error 状态未捕获。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 EX-2（DB failure）中截图 `m25-ex2-error-state`，并断言错误提示可见。
- **Priority**: medium

### E2E-049

**47. Pronunciation History — 单词详情 overlay 未截图**
- **模块/feature**: `progress/pronunciation-history.spec.ts`（M26）
- **Gap description**: BR-12 点击单词打开 overlay，但未对 overlay 内容（per-phoneme scores + A/B replay）截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 overlay 打开后调用 `capture(page, 'm26-br12-overlay')` 并断言 IPA/分数/A/B 按钮可见。
- **Priority**: medium

### E2E-050

**48. Review SM-2 — 评分后 snackbar 与空态未截图**
- **模块/feature**: `review/sm2-review.spec.ts`（M24）
- **Gap description**: HP-6 提及 SnackBar 显示 next review time，但未在 snackbar 可见时截图；EX-1 空态截图了，但 filtered empty 未截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在点击 Good/Easy 后、SnackBar 可见时截图；在 EX-4（favorites filter empty）中截图。
- **Priority**: low

### E2E-051

**49. Scenarios — 筛选展开与空态未截图**
- **模块/feature**: `scenarios/scenarios.spec.ts`（M27）
- **Gap description**: BR-5/BR-6 验证分类/难度筛选，但未在筛选展开状态下截图；EX-1 空态截图但缺少无匹配筛选结果截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在筛选 chip 选中后、无匹配结果时分别截图。
- **Priority**: low

### E2E-052

**50. Projects — 表单验证错误提示未截图**
- **模块/feature**: `projects/projects.spec.ts`（M29）
- **Gap description**: EX-2/EX-3 验证表单校验，但未在出现 “name required”/“max length” 错误提示时截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在触发校验错误后调用 `capture(page, 'm29-ex2-validation-error')` 并断言错误文案可见。
- **Priority**: medium

---

### 维度 3：双端视口对比验证缺失（51–70）

### E2E-053

**51. Chat 文字消息 — 未在同一条用例内对比 desktop/mobile**
- **模块/feature**: `chat/text-messaging.spec.ts`（M03）
- **Gap description**: 仅依赖 Playwright 项目级别的视口差异，未使用 `captureDesktopAndMobile` 同时生成两端截图。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 结尾调用 `const { desktop, mobile } = await captureDesktopAndMobile(page, 'm03-hp1-chat-route')`，并断言两端截图均生成。
- **Priority**: medium

### E2E-054

**52. Chat 语音输入 — 未验证 mic 按钮在两端的一致性**
- **模块/feature**: `chat/voice-input.spec.ts`（M04）
- **Gap description**: 未对比桌面与移动端的 mic 按钮位置、大小、默认可见性。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增用例：进入 chat 后调用 `captureDesktopAndMobile(page, 'm04-hp1-mic-default')`。
- **Priority**: medium

### E2E-055

**53. Chat TTS 播放 — 未双端对比播放指示器**
- **模块/feature**: `chat/tts-playback.spec.ts`（M06）
- **Gap description**: 未验证 TTS 自动播放后在桌面与移动端的 UI 一致性。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 结尾调用 `captureDesktopAndMobile(page, 'm06-hp1-tts-autoplay')`。
- **Priority**: medium

### E2E-056

**54. Chat 纠错卡片 — 未双端对比卡片布局**
- **模块/feature**: `chat/corrections.spec.ts`（M05）
- **Gap description**: 未对比 correction card 在桌面与移动端的宽度、内边距、按钮位置。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 使用 `captureDesktopAndMobile(page, 'm05-hp1-correction-card')`。
- **Priority**: medium

### E2E-057

**55. Avatar idle — 未双端对比 avatar 渲染尺寸**
- **模块/feature**: `avatar/idle.spec.ts`（M10）
- **Gap description**: 未对比桌面与移动端 avatar canvas 的相对大小及是否被其他 UI 遮挡。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 结尾调用 `captureDesktopAndMobile(page, 'm10-hp1-idle-breathing')`。
- **Priority**: medium

### E2E-058

**56. Avatar 情绪 — 未双端对比情绪 bubble 与 avatar 的相对位置**
- **模块/feature**: `avatar/emotion.spec.ts`（M11）
- **Gap description**: 未验证情绪触发后两端的消息气泡与 avatar 表情相对位置是否一致。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 使用 `captureDesktopAndMobile(page, 'm11-hp1-happy-marker')`。
- **Priority**: low

### E2E-059

**57. Onboarding — 未双端对比欢迎页**
- **模块/feature**: `onboarding/onboarding.spec.ts`（M01）
- **Gap description**: 未对比欢迎页在桌面与移动端的品牌图、CTA 按钮位置。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-2 使用 `captureDesktopAndMobile(page, 'm01-hp2-welcome')`。
- **Priority**: medium

### E2E-060

**58. Placement — 未双端对比题目与结果页**
- **模块/feature**: `onboarding/placement.spec.ts`（M02）
- **Gap description**: 未对比 placement 题目选项、结果页等级卡片在两端的一致性。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-2 与最终 result 用例中调用 `captureDesktopAndMobile`。
- **Priority**: medium

### E2E-061

**59. Home Dashboard — 未系统对比六个 section 的两端布局**
- **模块/feature**: `home/dashboard.spec.ts`（M18）
- **Gap description**: 虽有 iPad/iPhone SE 截图，但未在标准 desktop + mobile 两端同时对比六个 section 的排列。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 调用 `captureDesktopAndMobile(page, 'm18-hp1-home-render')` 并断言两端布局差异符合预期（桌面多列、移动端单列）。
- **Priority**: medium

### E2E-062

**60. Home 每日计划 — 未双端对比任务卡片**
- **模块/feature**: `home/daily-plan.spec.ts`（M20）
- **Gap description**: 未验证 today tasks 卡片在桌面与移动端的差异。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 使用 `captureDesktopAndMobile(page, 'm20-hp1-task-cards')`。
- **Priority**: low

### E2E-063

**61. Progress Dashboard — 未双端对比图表排版**
- **模块/feature**: `progress/dashboard.spec.ts`（M25）
- **Gap description**: 未对比 mastery/error/heatmap/trend/weak-area 在两端的不同布局策略。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 使用 `captureDesktopAndMobile(page, 'm25-hp1-mastery-breakdown')`，并对关键图表重复。
- **Priority**: medium

### E2E-064

**62. Review SM-2 — 未双端对比复习卡片与评分栏**
- **模块/feature**: `review/sm2-review.spec.ts`（M24）
- **Gap description**: 未对比桌面与移动端的 due card 与 Again/Hard/Good/Easy 评分栏布局。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 与 HP-3 使用 `captureDesktopAndMobile`。
- **Priority**: medium

### E2E-065

**63. Scenarios — 未双端对比场景卡片网格**
- **模块/feature**: `scenarios/scenarios.spec.ts`（M27）
- **Gap description**: 未对比 10 个 scenario cards 在桌面（多列）与移动端（可能单列）的网格策略。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 使用 `captureDesktopAndMobile(page, 'm27-hp1-scenario-cards')`。
- **Priority**: low

### E2E-066

**64. Projects — 未双端对比项目卡片与表单**
- **模块/feature**: `projects/projects.spec.ts`（M29）
- **Gap description**: 未对比项目卡片网格、新建表单对话框在桌面与移动端的差异。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 与 HP-2 使用 `captureDesktopAndMobile`。
- **Priority**: medium

### E2E-067

**65. Profile CRUD — 未双端对比 provider picker 与表单**
- **模块/feature**: `profile/llm-crud.spec.ts`、`profile/stt-crud.spec.ts`、`profile/tts-crud.spec.ts`（M13–M15）
- **Gap description**: 未对比 provider picker、表单字段、保存按钮在桌面与移动端的布局。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-2（Add Profile 表单）使用 `captureDesktopAndMobile`。
- **Priority**: medium

### E2E-068

**66. Service Config — 未双端对比三栏/Tab 切换**
- **模块/feature**: `profile/service-config.spec.ts`（M16）
- **Gap description**: 未验证 LLM/STT/TTS 三栏在桌面（并列/侧边栏）与移动端（tab/accordion）的切换策略。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-1 调用 `captureDesktopAndMobile(page, 'm16-hp1-three-sections')`。
- **Priority**: medium

### E2E-069

**67. Settings 主题/语言 — 未双端对比 picker 弹窗**
- **模块/feature**: `settings/theme-language.spec.ts`（M22）
- **Gap description**: 未对比 theme/language picker 弹窗在桌面（居中 dialog）与移动端（底部 sheet / 全屏）的形态差异。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-5 使用 `captureDesktopAndMobile(page, 'm22-hp5-language-list')`。
- **Priority**: low

### E2E-070

**68. System Banners — 未双端对比 update/install banner**
- **模块/feature**: `system/banners-version.spec.ts`（M30）
- **Gap description**: 未对比 banner 在桌面（顶部非遮挡）与移动端（顶部 narrow）的高度、文字换行、关闭按钮位置。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-2 与 HP-5 使用 `captureDesktopAndMobile`。
- **Priority**: medium

### E2E-071

**69. Voice Health — 未双端对比检查行布局**
- **模块/feature**: `profile/voice-health.spec.ts`（M17）
- **Gap description**: 仅有 BR-12 的 mobile 单张截图，未在同一用例内生成 desktop/mobile 对比。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-2（four check rows）使用 `captureDesktopAndMobile(page, 'm17-hp2-four-rows')`。
- **Priority**: low

### E2E-072

**70. Pronunciation History — 未双端对比历史列表与详情页**
- **模块/feature**: `progress/pronunciation-history.spec.ts`（M26）
- **Gap description**: 未对比 `/history` 列表与 `/pronunciation/:id` 详情页在桌面与移动端的布局。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在 HP-6 与 HP-1 使用 `captureDesktopAndMobile`。
- **Priority**: low

---

### 维度 4：Happy-Path 端到端旅程缺失（71–95）

### E2E-073

**71. Onboarding → Placement → Home 核心激活旅程缺失**
- **模块/feature**: 跨 `onboarding/onboarding.spec.ts` + `onboarding/placement.spec.ts` + `home/dashboard.spec.ts`
- **Gap description**: 现有测试按模块隔离，未验证新用户从 welcome → 目标选择 → placement → 首页的完整激活流程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增跨模块 spec `activation-journey.spec.ts`，使用 `setupEmptyApp` 模拟新用户，依次完成 onboarding、placement，断言最终路由为 `/` 且 dashboard 六个 section 渲染。
- **Priority**: high

### E2E-074

**72. Home → Chat → Review → Progress 学习闭环旅程缺失**
- **模块/feature**: 跨 `home/dashboard.spec.ts` + `chat/text-messaging.spec.ts` + `review/sm2-review.spec.ts` + `progress/dashboard.spec.ts`
- **Gap description**: 未验证用户从首页开始对话、产生纠错、进入 review 评分、查看 progress dashboard 的完整闭环。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 spec `learning-loop-journey.spec.ts`：首页点击 Start Conversation → 发送消息触发 correction → 完成 review → 进入 /progress 验证 weak area 更新。
- **Priority**: high

### E2E-075

**73. Scenario → Chat → Pronunciation → History 场景练习旅程缺失**
- **模块/feature**: 跨 `scenarios/scenarios.spec.ts` + `chat/text-messaging.spec.ts` + `progress/pronunciation-history.spec.ts`
- **Gap description**: 未验证用户选择 scenario 开始对话、练习句子、查看发音报告与历史记录的完整旅程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 spec `scenario-practice-journey.spec.ts`：选择 Job Interview scenario → 进入 chat → 跳转 /practice 录音 → 查看 /history 与 /pronunciation/:id。
- **Priority**: high

### E2E-076

**74. Settings → Service Config → Chat 配置生效旅程缺失**
- **模块/feature**: 跨 `settings/app-section.spec.ts` + `profile/service-config.spec.ts` + `chat/text-messaging.spec.ts`
- **Gap description**: 未验证切换 LLM/STT/TTS active profile 后，新 chat 会话实际使用新配置的端到端旅程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：在 service-config 切换 active LLM profile → 进入 chat 发送消息 → 断言（通过 bridge 或 mock 拦截）请求使用了新的 provider/model。
- **Priority**: high

### E2E-077

**75. Tutor Selection → Chat → Tutor Summary 导师旅程缺失**
- **模块/feature**: 跨 `chat/tutor-summary.spec.ts` + `chat/text-messaging.spec.ts`
- **Gap description**: 现有 tutor-summary 测试孤立，未验证选择 tutor 后进入 chat 对话，再返回 summary 的完整流程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：选择 Emma → 进入 /chat/:id 发送消息 → 结束会话 → 查看 tutor summary。
- **Priority**: medium

### E2E-078

**76. Continuous Voice Conversation 多轮语音对话旅程缺失**
- **模块/feature**: `chat/continuous-mode.spec.ts` + `chat/voice-input.spec.ts`
- **Gap description**: 未验证用户连续多轮使用语音输入、AI 回复、TTS 播放、mic 自动重新武装的完整语音对话。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile journey：启用 continuous → 语音输入第 1 轮 → 等待 AI 回复与 TTS → mic 自动重新出现 → 语音输入第 2 轮。
- **Priority**: high

### E2E-079

**77. Multi-turn Correction Loop 多轮纠错闭环旅程缺失**
- **模块/feature**: `chat/corrections.spec.ts` + `chat/text-messaging.spec.ts`
- **Gap description**: 未验证用户重复犯同一语法错误时，correction card 出现、occurrence count 增加、进入 review 后再次出现的过程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：连续发送 “I goes” 两次 → 断言 occurrence_count = 2 → 进入 /review 完成评级 → 返回 chat 再次发送同一错误，验证卡片展示 mastered/familiar 状态。
- **Priority**: medium

### E2E-080

**78. Daily Plan Task Completion 每日计划完成旅程缺失**
- **模块/feature**: `home/daily-plan.spec.ts` + `scenarios/scenarios.spec.ts` + `review/sm2-review.spec.ts`
- **Gap description**: 未验证用户完成 today tasks 中推荐 scenario、review、practice 任务后，daily plan 状态更新的完整流程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：首页查看 today tasks → 完成一个 scenario 任务 → 完成一次 review → 返回首页断言任务状态为已完成。
- **Priority**: medium

### E2E-081

**79. Streak Maintenance Across Sessions 跨会话打卡旅程缺失**
- **模块/feature**: `home/streak.spec.ts` + `home/dashboard.spec.ts`
- **Gap description**: 未验证用户在多个 chat/practice 会话后，streak 天数与 practice log 正确累计。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：模拟 3 天分别进行 chat/practice → 断言 30-day dot grid 显示对应日期为点亮状态，且 streak count 增加。
- **Priority**: medium

### E2E-082

**80. Review Queue Completion 复习队列清空旅程缺失**
- **模块/feature**: `review/sm2-review.spec.ts` + `home/dashboard.spec.ts`
- **Gap description**: 未验证用户清空所有 due corrections 后，首页 review queue section 与 dashboard due count 同步更新。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：seed 3 条 due correction → 进入 /review 全部评级 → 返回 / 断言 review queue section 显示 “nothing due”。
- **Priority**: medium

### E2E-083

**81. Pronunciation Practice → Score → History 发音练习旅程缺失**
- **模块/feature**: `scenarios/scenarios.spec.ts` + `progress/pronunciation-history.spec.ts`
- **Gap description**: 未验证用户在 /practice 完成句子录音、获得分数、在 /history 查看 enriched session 的完整流程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：/practice 录音并 mock STT → 断言分数显示 → 进入 /history 断言会话元数据 chip 包含分数与纠正数。
- **Priority**: medium

### E2E-084

**82. Project Creation → Add Link → Add Activity 项目空间旅程缺失**
- **模块/feature**: `projects/projects.spec.ts`
- **Gap description**: 现有测试孤立验证 CRUD，未验证新建 project → 添加 link → 添加 activity → 查看 activity feed 的完整流程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：点击 New Project → 填写表单保存 → 进入 detail → 添加 link → 添加 activity → 断言 activity feed 按时间排序。
- **Priority**: medium

### E2E-085

**83. Theme/Language Change Across Screens 主题/语言跨屏生效旅程缺失**
- **模块/feature**: `settings/theme-language.spec.ts` + `chat/text-messaging.spec.ts` + `home/dashboard.spec.ts`
- **Gap description**: BR-10/BR-11 仅验证 chat 主题/语言切换不崩溃，未系统验证设置变更后所有核心屏幕文案/颜色同步。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：设置中文 → 断言 / 页面文案为中文 → 进入 chat 断言发送按钮文案为中文 → 切换 dark theme 断言 chat 背景色变暗。
- **Priority**: medium

### E2E-086

**84. Archive Session → History 归档后历史旅程缺失**
- **模块/feature**: `chat/session-management.spec.ts` + `progress/pronunciation-history.spec.ts`
- **Gap description**: 未验证归档会话后，/history 列表中该会话状态变为 archived，且可取消归档。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：创建 session → archive → 进入 /history 断言 session 显示 archived 标签 → 取消归档 → 断言标签消失。
- **Priority**: medium

### E2E-087

**85. Guest Trial → Onboarding Completion 游客试用转正旅程缺失**
- **模块/feature**: `onboarding/onboarding.spec.ts` + `progress/pronunciation-history.spec.ts`
- **Gap description**: 未验证游客试用会话在登录/完成 onboarding 后正确迁移到用户名下。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：以 guest 身份产生 chat session → 完成 onboarding → 断言 /history 中保留该 session 且 is_guest 变为 0。
- **Priority**: low

### E2E-088

**86. Mobile Gesture Navigation 移动端手势返回旅程缺失**
- **模块/feature**: 跨所有含返回场景的 spec
- **Gap description**: 未验证移动端的系统返回手势（Android back / iOS swipe-back）是否能正确返回上一页。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile journey：/chat/:id → 触发系统返回 → 断言回到 /；/project/:id → 返回 → 回到 /projects。
- **Priority**: medium

### E2E-089

**87. Offline → Online Recovery 离线恢复旅程缺失**
- **模块/feature**: `system/banners-version.spec.ts` + `chat/text-messaging.spec.ts`
- **Gap description**: M30 BR-12 仅验证 connectivity service 不崩溃，未验证 chat 中离线后恢复在线的消息重发或提示消失。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：进入 chat 发送消息 → `page.context().setOffline(true)` → 断言离线提示 → 恢复在线 → 断言提示消失并可继续发送。
- **Priority**: high

### E2E-090

**88. Voice Health Check → Chat Mic 语音健康到对话旅程缺失**
- **模块/feature**: `profile/voice-health.spec.ts` + `chat/voice-input.spec.ts`
- **Gap description**: 未验证用户在 voice health 全部通过后，进入 chat 使用 mic 录音无权限/服务错误。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：/voice-health 运行检查并全部通过 → 进入 /chat/:id → 点击 mic 录音 → 断言转写成功。
- **Priority**: medium

### E2E-091

**89. Re-run Onboarding → Preserve Data 重新 onboarding 数据保留旅程缺失**
- **模块/feature**: `settings/app-section.spec.ts` + `onboarding/onboarding.spec.ts` + `home/dashboard.spec.ts`
- **Gap description**: BR-6 验证重新 onboarding 跳转，但未验证重新 onboarding 后历史会话、复习队列、项目等数据是否保留。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：创建 chat session 与 project → 触发 Re-run onboarding → 完成 onboarding → 断言 /history 与 /projects 数据仍然存在。
- **Priority**: low

### E2E-092

**90. Retake Placement → Level Update 重新定级后等级更新旅程缺失**
- **模块/feature**: `settings/app-section.spec.ts` + `onboarding/placement.spec.ts` + `home/dashboard.spec.ts`
- **Gap description**: BR-7 验证 Retake placement 跳转，未验证重新定级后用户等级与首页推荐内容更新。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：完成 placement 获得 B1 → 进入 /settings 触发 Retake → 完成 placement 获得 B2 → 断言首页 level tag 与推荐 scenario 难度更新。
- **Priority**: medium

### E2E-093

**91. Check for Updates → Apply Update 更新安装旅程缺失**
- **模块/feature**: `system/banners-version.spec.ts`
- **Gap description**: HP-2–HP-4 验证 update banner 与点击不崩溃，但未在端到端中验证 applyUpdate 后版本号更新、banner 消失。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：mock version.json 返回更高版本 → 点击 Update → mock SW waiting → 断言 `dismissed_version` 写入且 banner 不再显示。
- **Priority**: medium

### E2E-094

**92. Install Banner Dismiss → Reset 安装横幅重置旅程缺失**
- **模块/feature**: `system/banners-version.spec.ts` + `settings/app-section.spec.ts`
- **Gap description**: EX-4 验证 dismissed 设置后 settings 出现 reset tile，但未验证点击 reset tile 后 install banner 重新显示。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：设置 install_prompt_dismissed=true → 进入 /settings 点击 “Show install banner again” → 返回 / 断言 banner 可再次显示。
- **Priority**: low

### E2E-095

**93. Service Config Delete Guard → Switch Active → Delete 删除保护旅程缺失**
- **模块/feature**: `profile/service-config.spec.ts` + `profile/llm-crud.spec.ts`
- **Gap description**: 未验证删除 active profile 被阻止后，用户切换 active 到另一 profile 再成功删除原 active profile 的完整流程。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：seed 两个 LLM profiles → 尝试删除 active 被阻止 → 点击 inactive 切换 active → 再次删除原 active → 断言 DB 只剩一个 profile。
- **Priority**: medium

### E2E-096

**94. LLM Profile Test Connection → Chat 连接测试到对话旅程缺失**
- **模块/feature**: `profile/llm-crud.spec.ts` + `chat/text-messaging.spec.ts`
- **Gap description**: BR-17/BR-18 验证 Test Connection 按钮存在与成功 snackbar，未验证测试通过后在 chat 中实际能发起 LLM 请求。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：新增 LLM profile → Test Connection 成功 → 切换 active → 进入 chat 发送消息 → 断言响应来自新 profile 的 model。
- **Priority**: medium

### E2E-097

**95. Correction Favorite → Filter → Review 收藏纠错筛选旅程缺失**
- **模块/feature**: `review/sm2-review.spec.ts` + `chat/corrections.spec.ts`
- **Gap description**: BR-6 验证 favorite-only filter，但未验证在 chat 中将 correction 标记 favorite 后，/review 的 favorite filter 能正确过滤。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 journey：chat 中产生 correction → 标记 favorite → 进入 /review 打开 favorite-only → 断言该 correction 出现，取消 favorite 后 filter 为空。
- **Priority**: low

---

### 维度 5：错误态覆盖不足（96–115）

### E2E-098

**96. Chat LLM — 仅覆盖 500，缺少 401/403/429/503 错误码**
- **模块/feature**: `chat/error-states.spec.ts`（M09）
- **Gap description**: HP-1 仅 mock 500，未验证 401（key 无效）、403（rate limit）、429（throttle）、503（overloaded）等错误提示与恢复行为差异。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：分别 mock `**/v1/chat/completions*` 返回 401/403/429/503，断言 snackbar 文案区分且 Retry 按钮行为正确。
- **Priority**: high

### E2E-099

**97. Chat LLM — 请求超时场景缺失**
- **模块/feature**: `chat/error-states.spec.ts`（M09）
- **Gap description**: 未验证 LLM 请求长时间无响应后的超时提示与自动重试。
- **Affected viewport**: both
- **Suggested test addition/modification**: 使用 `mockNetworkTimeout(page, '**/v1/chat/completions*')`，断言超时后显示 “Request timed out” 并提供重试。
- **Priority**: high

### E2E-100

**98. Chat STT — 仅覆盖空转录，缺少具体 STT 服务错误码**
- **模块/feature**: `chat/voice-input.spec.ts`（M04）
- **Gap description**: 未验证 STT 服务返回 401/500、网络断开、麦克风权限拒绝时的 UI 提示。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile EX 用例：mock STT endpoint 401，断言提示 “Microphone access denied” 或 “STT service error”。
- **Priority**: high

### E2E-101

**99. Chat TTS — 音频流失败/空音频恢复缺失**
- **模块/feature**: `chat/tts-playback.spec.ts`（M06）
- **Gap description**: 未验证 TTS 返回空音频、音频解码失败、网络中断后的恢复与提示。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：mock TTS 返回 500 或空 bytes，断言播放按钮仍可点击且显示错误提示。
- **Priority**: medium

### E2E-102

**100. Chat 会话管理 — DB 写入失败未验证**
- **模块/feature**: `chat/session-management.spec.ts`（M08）
- **Gap description**: archive/delete/rename 操作未在 DB 写入失败时验证错误提示与会话状态一致性。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：mock 相关 DB/HTTP 500，断言 archive/delete 失败时 snackbar 显示且列表状态不变。
- **Priority**: medium

### E2E-103

**101. Profile CRUD — 保存网络错误断言偏弱**
- **模块/feature**: `profile/llm-crud.spec.ts`、`profile/stt-crud.spec.ts`、`profile/tts-crud.spec.ts`（M13–M15）
- **Gap description**: EX-25 等异常用例仅验证不崩溃，未验证错误提示文案、Save 按钮 loading 态、重试按钮。
- **Affected viewport**: both
- **Suggested test addition/modification**: mock 对应 endpoint 500，断言按钮恢复可点、snackbar 文案包含 “retry”/“failed to save”。
- **Priority**: medium

### E2E-104

**102. Profile CRUD — 表单校验错误文案未验证**
- **模块/feature**: `profile/llm-crud.spec.ts`、`profile/stt-crud.spec.ts`、`profile/tts-crud.spec.ts`（M13–M15）
- **Gap description**: EX-20/EX-21/EX-22 仅验证未写入 DB，未断言 “Name is required”、“Invalid base URL” 等文案是否显示。
- **Affected viewport**: both
- **Suggested test addition/modification**: 在触发校验后断言页面文本包含对应错误提示，并截图。
- **Priority**: medium

### E2E-105

**103. Review SM-2 — 评分 DB 失败仅弱断言**
- **模块/feature**: `review/sm2-review.spec.ts`（M24）
- **Gap description**: EX-2 仅 mock chat endpoint 500 并验证不崩溃，未验证评分失败时 card 不被移除、显示错误提示。
- **Affected viewport**: both
- **Suggested test addition/modification**: mock updateCorrection endpoint 500，断言 card 仍可见、snackbar 显示 “Failed to save review” 并提供重试。
- **Priority**: medium

### E2E-106

**104. Progress Dashboard — 错误态使用虚假错误**
- **模块/feature**: `progress/dashboard.spec.ts`（M25）
- **Gap description**: BR-13/EX-2 未真正注入 provider 错误，仅断言 canvas 渲染；未验证 per-section error widget 文案与重试按钮。
- **Affected viewport**: both
- **Suggested test addition/modification**: mock 对应 provider endpoint 500，断言错误区域显示 “Retry” 按钮，点击后重新加载成功。
- **Priority**: high

### E2E-107

**105. Scenarios — 场景特定错误处理缺失**
- **模块/feature**: `scenarios/scenarios.spec.ts`（M27）
- **Gap description**: EX-2 仅 mock chat endpoint 500 验证不崩溃，未验证 scenario 加载失败、scenario_items 缺失、TTS 失败时的具体提示。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：mock scenarios endpoint 500，断言列表显示 “Unable to load scenarios” 与重试；mock TTS 失败断言练习页显示 “Try again”。
- **Priority**: medium

### E2E-108

**106. Projects — 创建失败仅弱断言**
- **模块/feature**: `projects/projects.spec.ts`（M29）
- **Gap description**: EX-5 仅验证不崩溃，未验证 DB 失败时表单仍打开、显示错误提示。
- **Affected viewport**: both
- **Suggested test addition/modification**: mock project save endpoint 500，断言 dialog 未关闭、snackbar 显示 “Failed to create project”、Save 按钮停止 loading。
- **Priority**: medium

### E2E-109

**107. Onboarding — 表单校验与提交错误缺失**
- **模块/feature**: `onboarding/onboarding.spec.ts`（M01）
- **Gap description**: 未验证 onboarding 各步骤中非法输入、网络失败、提交失败时的提示与恢复。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：在 profile setup 提交空昵称、选择目标时 mock 保存 500，断言错误提示与停留在当前步骤。
- **Priority**: medium

### E2E-110

**108. Placement — 测试失败/中断恢复缺失**
- **模块/feature**: `onboarding/placement.spec.ts`（M02）
- **Gap description**: 未验证 placement 过程中网络中断、提交失败、用户返回后进度保留与恢复。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：答题到第 3 题后 mock 提交 500 → 断言可重试；切换页面后返回 → 断言进度保留。
- **Priority**: medium

### E2E-111

**109. Voice Health — 部分检查失败后的恢复缺失**
- **模块/feature**: `profile/voice-health.spec.ts`（M17）
- **Gap description**: BR-13/EX-4 验证 STT 失败，但未验证失败后重新点击 Recheck 仅重跑失败项、并通过后 banner 变绿。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：mock STT 500 → banner 显示失败 → 恢复 STT → 点击 Recheck → 断言 banner 更新为全部通过。
- **Priority**: medium

### E2E-112

**110. Settings Updates — 404 错误提示未验证文案**
- **模块/feature**: `settings/app-section.spec.ts`（M23）
- **Gap description**: EX-4 仅验证不崩溃，未验证 “Up to date” 或 “Server unavailable” 文案显示。
- **Affected viewport**: both
- **Suggested test addition/modification**: mock version.json 404，断言页面文本包含 “Server unavailable” 或 “Up to date”。
- **Priority**: low

### E2E-113

**111. System Banners — 404 仅验证 banner 不可见，未验证状态清理**
- **模块/feature**: `system/banners-version.spec.ts`（M30）
- **Gap description**: BR-9 验证 404 后无 phantom banner，但未验证 `serverVersion` 状态被清空、后续新版本能重新触发 banner。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：mock 404 → 断言 settings 中无新版本标记 → 再 mock 高版本 → 断言 banner 出现。
- **Priority**: low

### E2E-114

**112. Pronunciation History — 搜索无结果与 DB 失败缺失**
- **模块/feature**: `progress/pronunciation-history.spec.ts`（M26）
- **Gap description**: EX-3 验证搜索无匹配隐藏会话，但未验证空搜索结果的文案；未验证 history metadata 加载失败的降级展示。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：搜索无匹配断言显示 “No results”；mock metadata endpoint 500 断言会话列表仍显示基础信息。
- **Priority**: low

### E2E-115

**113. Avatar — WebGL/渲染错误未覆盖**
- **模块/feature**: `avatar/idle.spec.ts`、`avatar/emotion.spec.ts`、`avatar/lip-sync.spec.ts`（M10–M12）
- **Gap description**: 未验证 canvas/WebGL 初始化失败、资源加载失败时的降级 UI（如占位图或错误提示）。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：通过 bridge 模拟 avatar 渲染失败，断言页面显示 fallback 占位或错误提示，而非白屏。
- **Priority**: medium

### E2E-116

**114. Theme/Language — 非法值 fallback UI 未验证**
- **模块/feature**: `settings/theme-language.spec.ts`（M22）
- **Gap description**: EX-1/EX-2 仅验证不崩溃，未验证非法 theme/language 值是否在 UI 上回退为 “system”/“browser default”。
- **Affected viewport**: both
- **Suggested test addition/modification**: 设置非法 theme/language → 断言 settings 页当前选项显示为 “System” 或浏览器检测语言。
- **Priority**: low

### E2E-117

**115. Connectivity — 离线状态提示未验证**
- **模块/feature**: `system/banners-version.spec.ts`（M30）
- **Gap description**: BR-12 验证 setOffline 不崩溃，但未验证全局离线 banner 或 chat 中离线提示是否显示。
- **Affected viewport**: both
- **Suggested test addition/modification**: 新增 EX 用例：`setOffline(true)` 后断言全局或 chat 页面显示 “You are offline” 提示；恢复在线后提示消失。
- **Priority**: high

---

### 维度 6：Avatar / Chat 移动端专项缺口（116–120）

### E2E-118

**116. Avatar — 移动端 canvas 尺寸与定位未验证**
- **模块/feature**: `avatar/idle.spec.ts`（M10）
- **Gap description**: 未验证 375×812 下 avatar canvas 是否被底部输入栏遮挡、是否保持居中、尺寸是否按设计比例缩放。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：进入 chat → 设置 MOBILE_VIEWPORT → 获取 canvas bounding box，断言其底部高于输入框顶部、水平居中。
- **Priority**: high

### E2E-119

**117. Chat — 移动端输入框聚焦与键盘弹出未验证**
- **模块/feature**: `chat/text-messaging.spec.ts`（M03）
- **Gap description**: 未验证点击输入框后键盘弹出、页面滚动、发送按钮不被键盘遮挡。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：设置 MOBILE_VIEWPORT → 点击 textbox → 断言输入框在可视区域、发送按钮可点击。
- **Priority**: high

### E2E-120

**118. Chat — 移动端 mic 按钮触控区域未验证**
- **模块/feature**: `chat/voice-input.spec.ts`（M04）
- **Gap description**: 未验证 375pt 宽度下 mic 按钮的触控区域 ≥ 44×44pt，且与输入框切换按钮不重叠。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：获取 mic 按钮 bounding box，断言 width/height ≥ 44，并截图验证与相邻按钮间距。
- **Priority**: high

### E2E-121

**119. Chat — 移动端消息气泡换行与长文本未验证**
- **模块/feature**: `chat/text-messaging.spec.ts`（M03）
- **Gap description**: 未验证长文本消息、长链接、长单词在移动端气泡内的换行与截断行为。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：发送一段长文本（>200 字符），断言 bubble 宽度 ≤ 屏幕宽度 80%，文本无横向溢出。
- **Priority**: medium

### E2E-122

**120. Chat — 移动端 correction card 触控与展开未验证**
- **模块/feature**: `chat/corrections.spec.ts`（M05）
- **Gap description**: 未验证 correction card 在移动端的点击展开、收起、severity chip 触控面积及 explanation 文本可读性。
- **Affected viewport**: mobile
- **Suggested test addition/modification**: 新增 mobile 用例：设置 MOBILE_VIEWPORT → 触发 correction → 点击 card 展开 explanation → 断言 explanation 完整可见且关闭按钮可点。
- **Priority**: medium

---

### E2E-123

## 3. 优先级分布

| 优先级 | 数量 | 占比 |
|--------|------|------|
| high   | 22   | 18.3%|
| medium | 73   | 60.9%|
| low    | 25   | 20.8%|
| **合计** | **120** | **100%** |

---

### E2E-124

## 4. 建议的短期行动计划（按 ROI 排序）

### E2E-125

1. **补齐核心移动端覆盖**：优先为 `chat/text-messaging`、`chat/voice-input`、`chat/error-states`、`avatar/idle`、`onboarding/onboarding`、`home/dashboard` 增加 MOBILE_VIEWPORT 用例。

### E2E-126

2. **引入双端对比**：在关键 Happy-Path 用例中统一使用 `captureDesktopAndMobile`，建立 baseline 截图目录。

### E2E-127

3. **强化错误态断言**：将现有 `expectNoException` 或 `|| true` 弱断言替换为对 snackbar 文案、重试按钮、状态一致性的强断言，并补充截图。

### E2E-128

4. **构建端到端旅程 spec**：新增 `activation-journey.spec.ts`、`learning-loop-journey.spec.ts`、`scenario-practice-journey.spec.ts` 等跨模块旅程。

### E2E-129

5. **完善 Avatar/Chat 移动端专项**：针对 canvas 尺寸、mic 触控区、输入框键盘适配、消息气泡换行等增加自动化验证。

---

### E2E-130

## 5. 附录：审计文件清单

- `/workspace/e2e/playwright.config.ts`
- `/workspace/e2e/lib/setup.ts`
- `/workspace/e2e/lib/screenshots.ts`
- `/workspace/e2e/specs/onboarding/onboarding.spec.ts`
- `/workspace/e2e/specs/onboarding/placement.spec.ts`
- `/workspace/e2e/specs/home/dashboard.spec.ts`
- `/workspace/e2e/specs/home/daily-plan.spec.ts`
- `/workspace/e2e/specs/home/ability-goals.spec.ts`
- `/workspace/e2e/specs/home/streak.spec.ts`
- `/workspace/e2e/specs/chat/text-messaging.spec.ts`
- `/workspace/e2e/specs/chat/voice-input.spec.ts`
- `/workspace/e2e/specs/chat/tts-playback.spec.ts`
- `/workspace/e2e/specs/chat/continuous-mode.spec.ts`
- `/workspace/e2e/specs/chat/corrections.spec.ts`
- `/workspace/e2e/specs/chat/session-management.spec.ts`
- `/workspace/e2e/specs/chat/tutor-summary.spec.ts`
- `/workspace/e2e/specs/chat/error-states.spec.ts`
- `/workspace/e2e/specs/avatar/idle.spec.ts`
- `/workspace/e2e/specs/avatar/emotion.spec.ts`
- `/workspace/e2e/specs/avatar/lip-sync.spec.ts`
- `/workspace/e2e/specs/review/sm2-review.spec.ts`
- `/workspace/e2e/specs/scenarios/scenarios.spec.ts`
- `/workspace/e2e/specs/projects/projects.spec.ts`
- `/workspace/e2e/specs/progress/dashboard.spec.ts`
- `/workspace/e2e/specs/progress/pronunciation-history.spec.ts`
- `/workspace/e2e/specs/profile/llm-crud.spec.ts`
- `/workspace/e2e/specs/profile/stt-crud.spec.ts`
- `/workspace/e2e/specs/profile/tts-crud.spec.ts`
- `/workspace/e2e/specs/profile/service-config.spec.ts`
- `/workspace/e2e/specs/profile/voice-health.spec.ts`
- `/workspace/e2e/specs/settings/theme-language.spec.ts`
- `/workspace/e2e/specs/settings/app-section.spec.ts`
- `/workspace/e2e/specs/system/banners-version.spec.ts`
