# 目标产品架构

核查日期：2026-08-01

## 信息架构

一级区域收敛为：

1. 对话：AI 老师准备页、会话、场景选择、历史/总结的二级入口。
2. 复习：纠错队列与跟读/评分。
3. 我的：Provider、人物、语音健康、进度、项目与数据管理。

`scenarios`、`projects`、`history`、`progress` 等路由保留，避免破坏深链接和已有数据，但不再出现在一级导航。

## Avatar 边界

业务层只传有限语义：`phase`（idle/listening/thinking/speaking）、`emotion`、`speakingText`、`amplitudeStream`、`tutorName`、`prefer3d`。底层实现负责：

- 3D GLB 加载、骨骼/BlendShape 白名单和 WebView/HtmlElementView bridge；
- 文本 → viseme、普通音频 → jawOpen、Rhubarb → 时间线的降级优先级；
- 状态变化幂等；播放结束/中断/页面销毁时停止定时器、订阅和 WebView；
- WebGL/远程模型失败时回退 painter；低带宽时不加载 3D。

LLM 不得输出动画文件名、骨骼名、BlendShape 数值。LLM 的 emotion marker 只能经过解析和白名单映射。

## 对话状态机

权威状态集合：`idle`、`permissionRequired`、`recording`、`transcribing`、`generating`、`synthesizing`、`speaking`、`interrupted`、`completed`、`recoverableError`、`fatalError`。

`ConversationStateMachine` 为 turn 分配单调 token；异步 STT/LLM/TTS 回调必须验证 token 仍为当前 turn，旧请求不可覆盖新状态。UI 仍可保留 `_isLoading` 这类局部呈现字段，但不再把它当作业务状态来源。

核心事件：

```text
idle → recording → transcribing → generating → synthesizing → speaking → completed → idle
任何可播放阶段 → interrupted → idle
任何网络/Provider 问题 → recoverableError → idle 或 retry
不可恢复初始化问题 → fatalError（字幕与 painter 仍可用）
```

## Provider 边界

LLM、STT、TTS 仍由 Profile 驱动；每个请求都必须从 Profile 读取 Base URL/模型/Key，并经过 timeout、错误映射和 retry。浏览器直连只在 Provider 的 CORS、HTTPS、浏览器暴露 Key 风险可接受时使用；否则文档明确要求用户使用自托管 relay，而不把 relay 伪装成“所有 OpenAI-compatible API 都可用”。

## API Key 威胁模型

- 原生：`flutter_secure_storage` 走平台安全存储。
- Web/PWA：浏览器端存储只能提供同源隔离/插件和 XSS 风险下的有限保护，不能等价于 Keychain；用户必须信任当前设备和部署域名。
- 禁止：日志、异常详情、URL、构建产物、Service Worker Cache、动态 AI 响应缓存写入完整 Key 或 Authorization header。
- 导出：只导出 masked key；导入 masked key 强制清空，要求重新输入。
- 用户可在 Service Config 删除单个 Profile/Key；清除缓存只清理音频，不删除学习数据。

## 数据迁移

数据库 v10 与现有 Repository 保持兼容。导航减法只改变入口，不删除表、字段、session、correction、review、project 或 persona 数据。任何后续 schema 变更必须增加 migration，并覆盖旧数据 round-trip 测试。
