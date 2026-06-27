# AI Talk Teacher

> 🗣️ 跨平台 AI 英语口语练习应用

一款支持 macOS、Web、iOS、Android 的 AI 口语练习应用。与 AI 虚拟外教进行自然英语对话，实时纠正语法和用词，跟踪学习弱点并通过复习模式巩固提升。

## 特性

- 🌍 **跨平台** — Flutter 构建，一套代码运行在 macOS / Web / iOS / Android
- 🤖 **多 AI 提供商** — 兼容所有 OpenAI 协议的 LLM 服务（DeepSeek、GLM、Kimi、Ollama 等）
- 🎙️ **语音对话** — 语音输入 + TTS 语音输出，自然对话体验
- 💬 **智能纠正** — AI 在对话中自然纠正错误，不打断交流节奏
- 📝 **错误跟踪** — 自动记录所有错误，支持间隔重复复习
- 🎭 **虚拟外教** — Live2D 角色 + 唇形同步动画
- 🔒 **隐私优先** — 用户自带 API Key，数据全部本地存储

## 技术栈

| 层面 | 方案 |
|------|------|
| 框架 | Flutter 3.x + Dart |
| AI 对话 | OpenAI 兼容协议（用户自选提供商） |
| STT | SenseVoice / faster-whisper（本地）/ Deepgram（云端） |
| TTS | Kokoro TTS（本地）/ Fish Audio（云端） |
| 虚拟人物 | Live2D + Rhubarb Lip Sync |
| 数据库 | SQLite |
| 状态管理 | Riverpod |

## 项目文档

- [projects.md](projects.md) — 项目式样、功能规格、开发计划
- [agent.md](agent.md) — Agent 协作工作流和开发约定

## 开发阶段

| 阶段 | 内容 | 周期 |
|------|------|------|
| 一 | MVP：基本对话 + Profile 管理 + 聊天 UI | 4-6 周 |
| 二 | 学习循环：错误记录 + 复习模式 + 场景选择 | 4-6 周 |
| 三 | 虚拟人物：Live2D + 唇形同步 | 4-8 周 |
| 四 | 发布：四端打磨 + 应用商店提交 | 4-6 周 |

## License

MIT
