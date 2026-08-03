# 响应式与跨浏览器设计

核查日期：2026-08-04

## 布局决策

响应式断点集中在 `lib/core/util/responsive.dart`，页面不通过缩放桌面布局来冒充移动端：

| 环境 | 结构 | 目标 |
|---|---|---|
| 手机（约 < 700px） | Avatar 置顶、消息列表、底部输入；`SafeArea` 保留刘海与 Home indicator 空间 | 单手操作、键盘不遮挡主 CTA |
| 平板/窄桌面 | Avatar 紧凑面板 + 对话列，可隐藏低带宽人物面板 | 保持上下文，同时控制高度 |
| 宽桌面（约 ≥ 1000px） | 左侧 Avatar/状态面板 + 右侧对话列，内容有最大宽度 | 让主对话保持可读宽度，避免横向铺满 |

练习首页只有一个主操作：AI 老师、主题、当前状态和“开始对话”；场景、人物、历史、
项目是二级入口。设置/我的与复习构成不超过三个一级方向。

## 交互与无障碍

- 录音按钮同时支持 pointer down/up、键盘 Escape 和明确的取消语义；处理中的语音按钮
  仍可用来中断慢 STT/LLM。
- 文本输入、发送、切换输入模式、场景和状态提示有 Semantics/tooltip；麦克风拒绝时
  进入 `permissionRequired` 并显示可配置提示。
- `resizeToAvoidBottomInset`、`SafeArea`、底部 padding 和最大内容宽度共同处理软键盘、
  刘海和桌面宽屏。
- low-bandwidth 模式隐藏 3D iframe 并使用 Flutter painter；Avatar 加载失败不会阻塞
  对话。

## PWA 与低带宽

应用壳、manifest、版本检查和 Service Worker 更新逻辑位于 `web/`。动态 AI 请求、
Authorization、API key、录音和对话响应不进入 cache。离线时显示提示，但不假装可以调用
未缓存的 Provider。Standalone 更新通过 waiting SW/版本 banner 双重提示。

## 验证矩阵

自动验证至少覆盖：Chromium desktop、mobile-chrome（375×812）以及宽桌面。WebKit/Safari、
真实 standalone 安装、真实麦克风权限、长会话和硬件帧率需要在发布前补做；当前报告不会把
这些未执行项目标记为“通过”。

建议命令：

```text
cd e2e && npm run typecheck
cd e2e && npx playwright test specs/home/practice-home.spec.ts --project=chromium --workers=1
cd e2e && npx playwright test specs/home/practice-home.spec.ts --project=mobile-chrome --workers=1
cd e2e && npx playwright test specs/home/practice-home.spec.ts --project=webkit --workers=1
```

性能数字必须在固定设备、浏览器版本、网络条件下记录首屏、Avatar ready、TTS 首音、FPS、
内存和长会话增长；没有测量时只记录代码层面的降级与约束，不编造数字。
