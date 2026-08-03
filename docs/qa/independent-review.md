# 第二遍独立验收记录

核查日期：2026-08-04
范围：原任务清单、当前 main、路由/数据/状态/音频/Avatar/PWA/Provider/安全/响应式/测试/构建。

## 结论

当前实现已形成可用的“练习 → 对话 → 纠错 → 复习”主闭环，根路由收敛为练习准备页，
语义会话状态与异步 turn token 已覆盖录音、STT、LLM、TTS、打断和页面销毁。以下本轮复核
发现的问题已修复并纳入待提交 diff：

| 发现 | 修复 |
|---|---|
| LLM/STT 处理时语音主按钮不可取消 | 处理态显示 Cancel，取消会使 token 失效并停止播放 |
| pointer up 可能在取消后重新开启录音 | 区分按下前 loading 状态，取消过程不自动 re-arm |
| 迟到的 correction/phoneme 保存可能污染新 turn | 每个持久化边界再次检查 turn token |
| filler TTS 在页面状态改变后可能迟到播放 | 增加 filler generation token 和 thinking/loading 守卫 |
| Avatar gesture/viseme 可能粘住 | 每帧重置受控骨骼，语义状态映射到 idle/listening/thinking/speaking |
| 播放完成未标记 completed | 播放完成使用显式 `ConversationState.completed` |

## 清单结果

- 产品：主入口只有一个主要 CTA；场景、人物、历史、项目仍可达；review 保留。
- 状态：包含 `idle`、`permissionRequired`、`recording`、`transcribing`、`generating`、
  `synthesizing`、`speaking`、`interrupted`、`completed`、`recoverableError`、`fatalError`。
- Provider：LLM/STT/TTS/Profile/Repository 分层；错误、retry、timeout 和 CORS/relay 风险
  由文档与配置页暴露。
- 数据：schema v10 的 additive migrations；API key 只以 placeholder 进入 SQLite。
- PWA：manifest、install/update、shell cache 和敏感 cache 排除项已有实现。
- Avatar：Three.js + GLB 作为主 Spike；painter + amplitude/Rhubarb 为 fallback。
- 测试：Dart 与 Playwright 使用 deterministic mock；不能等同于真实 Provider/设备验收。

## 未关闭风险

真实 GLB 资产的分发许可、外部 CDN/CORS、WebKit standalone、真实麦克风权限、低端设备
FPS/内存和真实 Provider relay 尚未在当前环境形成硬件证据；详见
`docs/qa/known-limitations-and-backlog.md` 和最终测试报告。
