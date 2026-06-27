# SpeakFlow — Agent 开发工作流

> 项目：AI 口语练习应用（Flutter）
> 更新日期：2026-06-28

---

## 工作流概述

本项目使用多 Agent 协作开发，按阶段分解任务，每个 Agent 负责单一关注点。

```
用户需求
  │
  ▼
orchestrator（总控）
  ├── 调度 investigate（调研）
  ├── 调度 spec（规格定义）
  ├── 调度 implementer / implementer-ui（实现）
  ├── 调度 testing（测试）
  └── 调度 reviewer（审查）
```

---

## Agent 角色定义

### 1. orchestrator（总控调度）

**职责：** 任务分解、Agent 协调、进度跟踪

**工作流：**
1. 接收用户需求
2. 判断是否需要调研 → 调度 investigator
3. 非简单任务 → 调度 spec 生成 mini-spec
4. 派发实现任务 → implementer（后端/逻辑）或 implementer-ui（UI/UX）
5. 实现完成 → testing 验证
6. 测试通过 → reviewer 审查
7. 审查通过 → 汇报用户

### 2. investigator（调研分析）

**职责：** 代码探索、根因分析、技术调研

**适用场景：**
- Flutter 包选型对比
- 第三方 API 接入调研
- 性能瓶颈定位
- 平台兼容性问题排查

### 3. spec（规格定义）

**职责：** 生成紧凑的 mini-spec 文档供 implementer 直接消费

**输出格式：**
```markdown
## [功能名]
- **范围：** 具体做什么
- **非目标：** 明确不做什么
- **验收标准：** 可验证的 AC 列表
- **依赖：** 涉及的文件/模块
- **风险：** 可能的坑
```

### 4. implementer（逻辑实现）

**职责：** 后端逻辑、数据层、服务层、API 集成

**典型任务：**
- Profile CRUD 服务（SQLite 存储、加密）
- LLM 对话服务（OpenAI 兼容协议封装）
- STT/TTS 服务集成
- 错误记录和间隔重复算法
- 数据导入/导出

### 5. implementer-ui（UI 实现）

**职责：** 界面布局、组件、动画、响应式适配

**典型任务：**
- 主练习界面布局（上半屏角色 + 下半屏聊天）
- 聊天气泡组件（AI/用户样式、错误标红、重播按钮）
- Live2D / Rive 角色集成和唇形动画
- Profile 管理界面（列表、编辑表单、切换）
- 设置页面
- 响应式适配（手机/平板/桌面/Web）

### 6. testing（测试验证）

**职责：** 编写测试、运行测试、报告结果

**测试策略：**
- 单元测试：服务层（Profile CRUD、LLM 客户端、错误记录）
- Widget 测试：关键 UI 组件
- 集成测试：对话完整流程（录音 → STT → LLM → TTS → 显示）
- 平台测试：macOS、Web（Chrome + Safari）、iOS 模拟器

### 7. reviewer（代码审查）

**职责：** 代码质量、架构合理性、安全审查

**审查重点：**
- API Key 是否安全存储（不明文暴露）
- Profile 切换是否即时生效且无状态残留
- 跨平台代码是否有平台特定 bug
- 是否存在过度工程或不必要的抽象
- 错误处理是否完整

---

## 按阶段的 Agent 调度计划

### 阶段一：MVP

| 序号 | 任务 | Agent | 依赖 |
|------|------|-------|------|
| 1 | Flutter 项目初始化 + 目录结构 | implementer | 无 |
| 2 | Profile 管理服务（CRUD + 加密存储） | implementer | 1 |
| 3 | Profile 管理 UI（列表/编辑/切换） | implementer-ui | 2 |
| 4 | LLM 对话服务（OpenAI 兼容，流式） | implementer | 2 |
| 5 | 主界面布局（角色区 + 聊天区） | implementer-ui | 1 |
| 6 | 聊天气泡组件（AI/用户/纠正样式） | implementer-ui | 5 |
| 7 | 录音组件 + STT 集成 | implementer | 1 |
| 8 | TTS 服务 + 播放集成 | implementer | 1 |
| 9 | 对话流程串联（录音→STT→LLM→TTS→显示） | implementer | 4,7,8 |
| 10 | 振幅驱动嘴型动画（MVP） | implementer-ui | 8 |
| 11 | 设置页面 | implementer-ui | 3 |
| 12 | 对话历史存储 | implementer | 4 |
| 13 | MVP 集成测试 | testing | 9,10,11 |

### 阶段二：学习循环

| 序号 | 任务 | Agent | 依赖 |
|------|------|-------|------|
| 14 | LLM Prompt 结构化输出（corrections[]） | implementer | 4 |
| 15 | 错误记录服务 + SQLite 存储 | implementer | 14 |
| 16 | 复习模式 Prompt 设计 | spec → implementer | 15 |
| 17 | 间隔重复算法（SM-2） | implementer | 15 |
| 18 | 复习模式 UI | implementer-ui | 16,17 |
| 19 | 场景选择界面 | implementer-ui | 1 |
| 20 | 会话管理（新建/继续/历史） | implementer + implementer-ui | 4,12 |
| 21 | Profile 导入/导出 | implementer | 2 |
| 22 | iOS/Android 适配测试 | testing | 全部 |

### 阶段三：虚拟人物

| 序号 | 任务 | Agent | 依赖 |
|------|------|-------|------|
| 23 | Live2D 模型集成（Cubism SDK） | implementer-ui | 1 |
| 24 | Rhubarb Lip Sync 管线 | implementer | 8 |
| 25 | Viseme → Live2D 参数映射 | implementer-ui | 23,24 |
| 26 | 待机动画状态机 | implementer-ui | 23 |
| 27 | 情感表情切换 | implementer-ui | 23,14 |

---

## 开发约定

### 代码规范
- 遵循 Flutter/Dart 官方 lint 规则
- 文件组织：`features/` 按功能模块划分（profile/、chat/、review/、avatar/、settings/）
- 状态管理：Riverpod，Provider 放在对应 feature 目录
- 命名：snake_case 文件名，PascalCase 类名，camelCase 变量

### Git 约定
- 分支：`feat/xxx`、`fix/xxx`、`refactor/xxx`
- Commit：`type(scope): description`
- 每个 PR 尽量 < 5 文件、< 200 行

### Review 重点
- API Key 安全（flutter_secure_storage）
- 平台条件代码（`Platform.isIOS` 等）是否有 fallback
- 音频资源释放（dispose）
- SQLite 连接管理（单例）
- 网络超时和错误处理

---

## 快速命令参考

```
# 初始化 Flutter 项目
flutter create --org com.speakflow --platforms=web,macos,ios,android speakflow

# 运行 macOS
flutter run -d macos

# 运行 Web
flutter run -d chrome

# 运行测试
flutter test

# 构建 Web
flutter build web

# 构建 iOS
flutter build ipa
```
