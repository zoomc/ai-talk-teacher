# SpeakFlow 业务逻辑 / 交互问题报告 实施计划

## 1. 任务摘要

阅读 `/workspace/lib/` 下全部 Flutter 源码与 `/workspace/e2e/specs/` 下全部 Playwright E2E 规约，针对业务逻辑、交互流程、状态管理、错误处理、数据持久化、国际化、无障碍等维度，撰写一份综合性问题报告，输出到：

```
/tmp/speakflow-e2e-run/business-logic-issues.md
```

报告必须满足：
- 至少 **200 条** 编号发现；
- 每条包含：编号、分类、严重级别、描述、文件位置（`file://` 链接）、建议改进；
- 覆盖全部主要模块（启动 / 路由 / 数据库 / 配置 / 聊天 / LLM / STT / TTS / 头像 / 复习 / 每日计划 / 首页 / 场景 / 项目空间 / 设置 / 本地化 / E2E）。

## 2. 当前已探明的架构与关键文件

通过 Phase 1 探索，已确认项目结构如下：

- **启动与全局状态**：`lib/main.dart` 初始化 E2E Bridge、错误处理、主题、Locale、低带宽模式，并通过 `ProviderScope` 覆盖初始 Provider。
- **路由与导航**：`lib/core/router/app_router.dart` 使用 `GoRouter`，基于 `onboarding_completed` / `placement_completed` 做重定向；包含 `ShellRoute` 与响应式导航 UI。
- **数据库**：`lib/core/database/database_helper.dart` 负责 SQLite 初始化、建表、迁移；`chat_repository.dart` / `profile_repository.dart` / `project_repository.dart` 封装具体表操作。
- **服务配置（LLM/STT/TTS）**：`lib/features/profile/data/profile_repository.dart` 管理 Profile CRUD、API Key 安全存储、激活切换；`service_config_screen.dart` / `profile_form_screen.dart` 提供 UI。
- **聊天核心**：`chat_screen.dart` + `lib/widgets/chat/*` 实现消息列表、输入栏、发送、流式回复、纠错展示；`llm_service.dart` / `llm_streaming.dart` 负责 OpenAI 兼容接口与 SSE 流式解析；`tts_playback_service.dart` 管理缓存与播放；`stt_service.dart` / `recording_service.dart` / `tts_service.dart` 负责语音pipeline。
- **学习与复习**：`review_screen.dart` + `sm2_service.dart` 实现 SM-2 调度；`learning_stats_service.dart` / `daily_plan_service.dart` / `session_continuity_service.dart` 支撑首页数据。
- **首页与目标**：`home_page.dart` 展示 streak、今日任务、能力雷达、复习队列、推荐场景；`home_providers.dart` 聚合 Riverpod Provider。
- **场景与项目空间**：`scenarios_screen.dart` 展示分类场景；`project_repository.dart` / `projects_screen.dart` / `project_detail_screen.dart` / `join_project_sheet.dart` 管理项目与内容关联。
- **头像与可视化**：`avatar_stage.dart` / `viseme_timeline_player.dart` / `emotion_controller.dart` / `idle_animation.dart` / `rhubarb_service.dart` 负责 Live2D 占位、嘴型同步、情绪动画。
- **首次体验**：`onboarding_screen.dart` 提供 LLM/STT/TTS 向导、Guest 试用；`placement_screen.dart` 通过 AI 对话完成定级测试。
- **设置与国际化**：`settings_screen.dart` 管理主题、语言、低带宽、内容开关、教师人格；`app_localizations.dart` 提供多语言；`shared/providers.dart` 提供全局 Provider。
- **E2E 测试**：`e2e/specs/` 下按模块划分 spec；`e2e/lib/e2e-bridge.ts` / `mock.ts` / `setup.ts` 提供桥接与 mock。

## 3. 计划步骤（可直接执行）

### 步骤 1：补全源码阅读清单

在已读关键文件基础上，按模块补读剩余文件，确保每个模块都有足够依据支撑发现。阅读策略：
- 每个模块至少精读 1-2 个核心文件，剩余文件用 Grep / SearchCodebase 搜索风险模式（`catch (_) {}`、`timeout`、`assert`、`TODO`、`FIXME`、`UnimplementedError`、`null` 传播、硬编码字符串等）。
- 对超大文件（如 `app_localizations.dart`、`chat_screen.dart`）分多次读取，不一次性加载全文。

具体文件清单：

| 模块 | 需要阅读/扫描的文件 |
|------|---------------------|
| 启动 / 全局 | `lib/main.dart`、`lib/shared/providers.dart` |
| 路由 / 导航 | `lib/core/router/app_router.dart` |
| 数据库 / 持久化 | `lib/core/database/database_helper.dart`、`lib/core/database/database_init_*.dart` |
| 配置 / Profile | `lib/features/profile/data/profile_repository.dart`、`lib/features/profile/domain/profile_models.dart`、`lib/features/profile/domain/provider_catalog.dart`、`lib/features/profile/domain/guest_profiles.dart`、`lib/features/profile/presentation/screens/service_config_screen.dart`、`lib/features/profile/presentation/screens/profile_form_screen.dart`、`lib/features/profile/domain/services/connection_tester.dart` |
| 聊天 UI | `lib/features/chat/presentation/screens/chat_screen.dart`、`lib/widgets/chat/chat_input_bar.dart`、`lib/widgets/chat/chat_bubble.dart`、`lib/widgets/chat/chat_message_list.dart`、`lib/widgets/chat/chat_header.dart`、`lib/widgets/chat/chat_providers.dart` |
| LLM | `lib/features/chat/data/llm_service.dart`、`lib/features/chat/data/llm_streaming.dart`、`lib/features/chat/domain/tutor_prompts.dart`、`lib/features/chat/domain/teacher_persona.dart` |
| 语音 STT/TTS | `lib/features/chat/data/stt_service.dart`、`lib/features/chat/data/tts_service.dart`、`lib/features/chat/data/recording_service.dart`、`lib/features/chat/data/tts_playback_service.dart` |
| 学习与复习 | `lib/features/chat/presentation/screens/review_screen.dart`、`lib/features/review/data/sm2_service.dart`、`lib/features/chat/data/learning_stats_service.dart`、`lib/features/chat/data/daily_plan_service.dart`、`lib/features/chat/data/session_continuity_service.dart`、`lib/features/chat/domain/daily_plan.dart` |
| 首页 / 进度 | `lib/features/home/presentation/screens/home_page.dart`、`lib/features/home/presentation/home_providers.dart`、`lib/features/home/data/*.dart`、`lib/features/home/presentation/widgets/*.dart` |
| 场景 / 项目空间 | `lib/features/chat/presentation/screens/scenarios_screen.dart`、`lib/features/project_space/data/project_repository.dart`、`lib/features/project_space/presentation/screens/*.dart`、`lib/features/project_space/presentation/widgets/*.dart`、`lib/features/project_space/domain/*.dart` |
| 头像 | `lib/features/avatar/presentation/widgets/avatar_stage.dart`、`lib/features/avatar/data/*.dart`、`lib/features/avatar/domain/*.dart` |
| 首次体验 | `lib/features/onboarding/presentation/screens/onboarding_screen.dart`、`lib/features/onboarding/presentation/screens/placement_screen.dart`、`lib/features/onboarding/presentation/widgets/placement_radar_chart.dart`、`lib/features/onboarding/domain/placement_result.dart` |
| 设置 / 本地化 | `lib/features/settings/presentation/screens/settings_screen.dart`、`lib/core/i18n/app_localizations.dart`、`lib/core/theme/*.dart`、`lib/core/constants/app_constants.dart` |
| E2E 规约 | `e2e/specs/**/*.spec.ts`、`e2e/lib/*.ts`、`e2e/fixtures/fixtures.ts` |

### 步骤 2：建立问题分类与严重级别定义

每条发现统一使用以下字段：

- **分类**（按模块）：`启动与全局状态`、`路由与导航`、`数据库与持久化`、`服务配置（LLM/STT/TTS）`、`聊天会话与消息`、`LLM 集成与流式响应`、`语音输入（STT）与录音`、`语音合成（TTS）与播放`、`头像与可视化`、`复习与 SM-2 算法`、`每日计划与首页`、`场景与项目空间`、`首次体验与定级`、`设置与个性化`、`国际化与无障碍`、`E2E 测试与 Mock`。
- **严重级别**：
  - `致命`：导致崩溃、数据丢失、安全泄漏、核心流程完全不可用；
  - `高`：导致明显功能缺陷、错误状态、业务逻辑错误、影响主要用户体验；
  - `中`：导致边界场景异常、信息不一致、可恢复错误提示不足；
  - `低`：导致轻微体验问题、冗余代码、可维护性风险；
  - `建议`：改进建议、设计优化、可测试性 / 可访问性提升。

### 步骤 3：系统性提取发现

按模块顺序遍历源码与 E2E 规约，重点检查以下风险点：

1. **空值与默认值**：`null` / `??` 使用是否导致默认行为错误（如 `getContentEnabled` 默认 `true` 是否合理，`getDailyScenarioRecommendationCount` 默认 3 是否与 UI 一致）。
2. **异常 swallow**：`catch (_) {}` 是否隐藏了应当反馈用户的错误（如首页 streak 记录、缓存清理、TTS 速度设置）。
3. **并发与原子性**：Profile 激活切换使用 transaction，但 UI 层面是否可能并发触发多次；`setActiveLlmProfile` 未验证目标 ID 是否存在。
4. **数据一致性与外键**：多处代码注释“SQLite FK 默认关闭”，需检查级联删除是否完整（如 `deleteSession`、`deleteProject`）。
5. **输入校验与边界**：onboarding 中 API Key、base URL、model 是否做长度 / 格式校验；超长文本（>2000）在前端是否截断；空消息是否拦截。
6. **状态管理**：Riverpod Provider 失效时机是否正确；theme / locale 变更后 UI 是否重建；`setState` 在 `mounted` 检查是否完备。
7. **网络与超时**：LLM/STT/TTS 超时固定 30s/60s，无动态低带宽适配；重试仅指数退避，无用户取消机制。
8. **缓存与资源**：TTS 磁盘缓存无大小上限、无过期策略；`tts_play_*.mp3` 文件在播放中无法清理；Rhubarb / Live2D 资源未释放风险。
9. **业务规则**：SM-2 `scheduleReview` 对 quality 的断言在 release 模式下无效；复习队列 `due_at` 过滤是否包含 `NULL`；每日计划 `recentErrorCount` 基于 `last_seen_at` 而非 `created_at` 是否准确。
10. **无障碍与国际化**：按钮缺少语义标签；主题 / 语言切换依赖字符串匹配；部分 UI 硬编码英文（如场景卡片 “Practiced N times”）。
11. **E2E 与实现错位**：E2E 使用大量 `catch(() => {})` 与 `|| true` 弱化断言；spec 中期望的行为在源码中可能未实现（如 P5 `startScenario` 跳转、active profile 删除禁用提示）。
12. **安全**：`ProfileRepository.exportAllProfilesJson` 仅做简单 mask，导入时未校验 version；API Key 在内存中以明文持有；`app_localizations.dart` 可能包含大量敏感字符串。

### 步骤 4：撰写报告

按以下结构生成 Markdown：

```markdown
# SpeakFlow 业务逻辑 / 交互问题报告

> 生成日期：2026-07-25
> 覆盖范围：lib/ 与 e2e/specs/
> 发现总数：XXX

## 按模块汇总表
| 分类 | 致命 | 高 | 中 | 低 | 建议 | 小计 |
...

## 详细发现

### 1. 启动与全局状态
1. **编号**: B-001
   **分类**: 启动与全局状态
   **严重级别**: 高
   **描述**: ...
   **文件位置**: file:///workspace/lib/main.dart#Lxx
   **建议改进**: ...
...
```

要求：
- 所有 `文件位置` 使用绝对 `file://` 链接，精确到行号（若无法精确定位则链接到文件）。
- 描述具体、可复现，引用源码中的关键函数 / 变量名。
- 建议改进具备可操作性，优先给出最小修改方向。
- 总数不少于 200，编号连续，模块分组清晰。

### 步骤 5：校验与输出

- 使用脚本 / 正则统计 Markdown 中编号条目数量，确认 ≥ 200。
- 校验所有 `file://` 链接指向真实存在的文件（通过 `ls` 或文件读取）。
- 检查严重级别分布合理，不出现某级别过于稀疏。
- 最终仅向用户返回：**发现总数** 与 **输出文件路径**。

## 4. 假设与决策

1. **“业务逻辑 / 交互问题”** 采用广义理解：包括功能缺陷、边界处理、状态管理、数据一致性、错误提示、安全、可访问性、可维护性、E2E 覆盖可信度等。
2. 严重级别由探索者基于代码实际影响判定，而非用户需求优先级。
3. 报告语言为中文（与用户指令一致），源码中的类名 / 方法名 / 文件名保持英文原样。
4. 对于无法精确定位行号的大文件，使用 `file:///workspace/.../filename.dart` 链接；可定位时追加 `#Lxxx`。
5. 不修改任何业务代码，仅输出报告；不提交 Git。

## 5. 验证步骤

1. 报告生成后，执行命令检查文件存在与大小：
   ```bash
   wc -l /tmp/speakflow-e2e-run/business-logic-issues.md
   ls -lh /tmp/speakflow-e2e-run/business-logic-issues.md
   ```
2. 统计编号条目：
   ```bash
   grep -cE '^\s*\*\*编号\*\*:|^\d+\.\s+\*\*编号\*\*:' /tmp/speakflow-e2e-run/business-logic-issues.md
   ```
3. 抽样检查 5-10 条 `file://` 链接对应的文件是否存在。
4. 确认最终回复仅包含总数与文件路径，无内容摘要。
