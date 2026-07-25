# SpeakFlow 业务逻辑与交互问题审查计划

## 1. 目标摘要

对 `/workspace/lib/` 下的 Flutter 源码以及 `/workspace/e2e/specs/` 下的端到端测试规范进行系统性审查，聚焦以下业务领域：

- Chat / 会话流与状态管理
- Avatar 动画、情绪、唇同步行为
- Onboarding 与 Placement 流程
- Scenario / Practice 逻辑
- Settings、Profile、TTS/STT/LLM 配置
- Daily Plan、Streak、Progress 仪表盘
- Review / SM-2 间隔重复逻辑
- 语音输入/输出处理
- 错误状态与恢复

最终交付物：中文 markdown 文件 `/tmp/speakflow-e2e-run/business-logic-issues.md`，至少包含 200 条编号问题，每条包含 Category、Severity、Description、File reference（markdown file:// 链接）、Suggested improvement。

## 2. 当前已探索的关键文件

已读取并理解以下核心文件：

- `lib/features/chat/presentation/screens/chat_screen.dart` — 聊天主界面、消息发送、TTS 自动播放、语音输入、重试、情绪与 avatar 状态驱动。
- `lib/features/chat/data/llm_service.dart` / `llm_streaming.dart` — LLM 请求、流式响应、corrections JSON 提取。
- `lib/features/chat/data/tts_service.dart` / `stt_service.dart` — 多厂商 TTS/STT 适配。
- `lib/features/chat/data/tts_playback_service.dart` / `recording_service.dart` — 音频播放、缓存、录音。
- `lib/features/chat/data/chat_repository.dart` — SQLite 会话、消息、纠错、复习队列、练习日志、技能掌握等 CRUD。
- `lib/features/chat/data/daily_plan_service.dart` / `learning_stats_service.dart` — 每日计划生成、学习统计。
- `lib/features/home/presentation/screens/home_page.dart` / `home_providers.dart` — 仪表盘、streak、能力雷达、今日任务、推荐场景。
- `lib/features/home/data/streak_service.dart` / `progress_service.dart` / `skill_mastery_service.dart` / `user_goal_service.dart` — streak、进度、技能掌握、目标。
- `lib/features/review/data/sm2_service.dart` — SM-2 间隔重复算法。
- `lib/features/avatar/presentation/widgets/avatar_stage.dart` — avatar 阶段、唇同步、情绪。
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` / `placement_screen.dart` — 首次配置、访客试用、placement 评估。
- `lib/features/settings/presentation/screens/settings_screen.dart` — 设置页。
- `lib/features/profile/presentation/screens/service_config_screen.dart` — LLM/STT/TTS 配置页。

## 3. 待深入审查文件

为确保 200+ 条不重复且高质量的问题，还需系统阅读：

- `lib/features/chat/presentation/screens/review_screen.dart`
- `lib/features/chat/presentation/screens/scenarios_screen.dart`
- `lib/features/chat/presentation/screens/sentence_practice_screen.dart`
- `lib/features/chat/presentation/screens/session_summary_screen.dart`
- `lib/features/chat/presentation/screens/tutor_selection_screen.dart`
- `lib/features/chat/presentation/screens/history_screen.dart`
- `lib/widgets/chat/chat_input_bar.dart`
- `lib/widgets/chat/chat_message_list.dart`
- `lib/widgets/chat/chat_bubble.dart`
- `lib/widgets/chat/chat_providers.dart`
- `lib/features/chat/domain/tutor_prompts.dart`
- `lib/features/chat/domain/tutor_emotion.dart`
- `lib/features/chat/domain/phoneme_score.dart`
- `lib/features/avatar/data/rhubarb_service.dart`
- `lib/features/avatar/data/viseme_timeline_player.dart`
- `lib/features/avatar/domain/emotion_controller.dart`
- `lib/features/profile/data/profile_repository.dart`
- `lib/features/profile/domain/profile_models.dart`
- `lib/features/profile/domain/provider_catalog.dart`
- `lib/features/profile/domain/guest_profiles.dart`
- `lib/features/project_space/` 相关文件
- `lib/core/router/app_router.dart`
- `lib/core/database/database_helper.dart`
- `e2e/specs/chat/*.spec.ts`
- `e2e/specs/home/*.spec.ts`
- `e2e/specs/review/*.spec.ts`
- `e2e/specs/onboarding/*.spec.ts`
- `e2e/specs/profile/*.spec.ts`
- `e2e/specs/scenarios/*.spec.ts`

## 4. Issue 分类与严重级别定义

每条 issue 归入以下 Category 之一：

- Chat / Conversation Flow
- State Management
- Avatar / Emotion / Lip-sync
- Onboarding / Placement
- Scenario / Practice
- Settings / Profile / Service Config
- TTS / STT / LLM
- Daily Plan / Streak / Progress
- Review / SM-2
- Voice I/O
- Error Handling / Recovery

Severity 采用四级：

- **Critical**：导致崩溃、数据丢失、安全泄漏、核心流程完全不可用。
- **High**：明显业务逻辑错误、状态不一致、重要功能失效或反复失败。
- **Medium**：体验受损、边界情况处理不当、可维护性或性能隐患。
- **Low**：文案/提示、可访问性、代码异味、低风险优化点。

## 5. 输出格式

写入 `/tmp/speakflow-e2e-run/business-logic-issues.md`，内容全部使用中文。

每条 issue 格式：

```markdown
### 1. [Category] 简要标题
- **Category**: Chat / Conversation Flow
- **Severity**: High
- **Description**: 具体问题描述，包含触发条件与影响。
- **File reference**: [chat_screen.dart](file:///workspace/lib/features/chat/presentation/screens/chat_screen.dart)
- **Suggested improvement**: 可执行的修复或改进建议。
```

编号从 1 开始连续递增，最终 ≥ 200。

## 6. 执行步骤

1. 继续阅读第 3 节列出的剩余文件，必要时结合 e2e spec 核对期望行为。
2. 使用 Grep / SearchCodebase 交叉定位问题代码片段（如 `catch (_) {}`、未释放资源、竞态条件、不一致状态）。
3. 按 Category 逐条记录问题，确保 Description 具体、可复现，Suggested improvement 可操作。
4. 汇总并去重，检查编号连续性与分类分布。
5. 写入 `/tmp/speakflow-e2e-run/business-logic-issues.md`。
6. 统计 issue 数量与分类占比，确认 ≥ 200 条。

## 7. 验证标准

- [ ] 文件路径存在且可访问：`/tmp/speakflow-e2e-run/business-logic-issues.md`。
- [ ] 文件中至少 200 条编号 issue。
- [ ] 每条 issue 包含 Category、Severity、Description、File reference、Suggested improvement 五个字段。
- [ ] File reference 使用 markdown file:// 链接格式。
- [ ] 文档内容为中文。
- [ ] 覆盖用户指定的 10 个以上业务领域。

## 8. 假设与决策

- 假设 e2e specs 中描述的行为是“期望行为”；源码与 specs 不一致的地方视为业务逻辑问题。
- 不修改源码，仅输出审查报告。
- 问题尽可能独立，避免同一段代码反复拆分导致低价值重复；若同一根因在不同文件表现不同，仍视为独立 issue。
- 严重级别以用户体验和业务正确性为主要判断依据，而非代码风格。
