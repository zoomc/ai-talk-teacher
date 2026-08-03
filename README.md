# AI Talk Teacher

> 🗣️ 跨平台 AI 英语口语练习应用

一款支持 macOS、Web、iOS、Android 的 AI 口语练习应用。与 AI 虚拟外教进行自然英语对话，实时纠正语法和用词，跟踪学习弱点并通过复习模式巩固提升。

## 特性

- 🌍 **跨平台** — Flutter 构建，一套代码运行在 macOS / Web / iOS / Android
- 🤖 **多 AI 提供商** — 支持常见 OpenAI-compatible LLM 服务（DeepSeek、GLM、Kimi、Ollama 等；浏览器端服务商仍需允许 CORS）
- 🎙️ **语音对话** — 语音输入 + TTS 语音输出，自然对话体验
- 💬 **智能纠正** — AI 在对话中自然纠正错误，不打断交流节奏
- 📝 **错误跟踪** — 自动记录所有错误，支持间隔重复复习
- 🎭 **虚拟外教** — Three.js + GLB 3D 角色、振幅/Rhubarb 唇形同步，失败时回退 Flutter 绘制角色
- 🔒 **隐私优先** — 用户自带 API Key，SQLite 学习数据默认本地保存；Web 端 Key 仍受浏览器存储与 XSS 风险约束

## 技术栈

| 层面 | 方案 |
|------|------|
| 框架 | Flutter 3.x + Dart |
| AI 对话 | OpenAI 兼容协议（用户自选提供商） |
| STT | SenseVoice / faster-whisper（本地）/ Deepgram（云端） |
| TTS | Kokoro TTS（本地）/ Fish Audio（云端） |
| 虚拟人物 | Three.js + GLB + Rhubarb Lip Sync（painter fallback） |
| 数据库 | SQLite |
| 状态管理 | Riverpod |

## 项目文档

- [projects.md](projects.md) — 项目式样、功能规格、开发计划
- [agent.md](agent.md) — Agent 协作工作流和开发约定
- [docs/audit/current-product-baseline.md](docs/audit/current-product-baseline.md) — 当前产品/路由/数据基线
- [docs/architecture/target-product-architecture.md](docs/architecture/target-product-architecture.md) — 状态、Provider、Avatar 与安全架构
- [docs/architecture/data-migration.md](docs/architecture/data-migration.md) — SQLite/IndexedDB schema v10 兼容与迁移
- [docs/architecture/responsive-design.md](docs/architecture/responsive-design.md) — 手机/桌面/PWA 响应式策略
- [docs/research/avatar-technology-selection.md](docs/research/avatar-technology-selection.md) — Avatar 技术研究与 Spike
- [docs/qa/test-and-performance-report.md](docs/qa/test-and-performance-report.md) — 测试证据与性能边界
- [docs/qa/independent-review.md](docs/qa/independent-review.md) — 第二遍独立验收记录
- [docs/qa/known-limitations-and-backlog.md](docs/qa/known-limitations-and-backlog.md) — 已知限制与后续工作
- [docs/qa/dependency-license-inventory.md](docs/qa/dependency-license-inventory.md) — 依赖、模型与资产许可证检查

## 开发阶段

| 阶段 | 内容 | 周期 |
|------|------|------|
| 一 | MVP：基本对话 + Profile 管理 + 聊天 UI | 4-6 周 |
| 二 | 学习循环：错误记录 + 复习模式 + 场景选择 | 4-6 周 |
| 三 | 虚拟人物：Live2D + 唇形同步 | 4-8 周 |
| 四 | 发布：四端打磨 + 应用商店提交 | 4-6 周 |

## License

MIT
