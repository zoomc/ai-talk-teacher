# 测试与性能报告

核查日期：2026-08-04

## 基线与本轮证据

| 检查 | 结果 |
|---|---|
| `git fetch --all --prune` | 成功；清理已删除远端 agent refs |
| `git pull --ff-only origin main` | `Already up to date`；基线 `9cb74e2` |
| `flutter test --reporter compact` | 255 passed |
| `flutter analyze` | 0 errors；13 条既有 info/warning |
| Playwright TypeScript | `npm run typecheck` 通过；`npm run test:list` 共 2976 tests / 32 files |
| Playwright 核心 Chromium | 9 个主闭环用例通过；另有 1 个处理态取消用例通过 |
| Playwright 首页跨浏览器 | Chromium 5/5；mobile-chrome 5/5；WebKit 5/5 |
| Flutter Web E2E build | `flutter build web --release --dart-define=E2E=true` 成功 |
| Flutter Web production build | `flutter build web --release --base-href /talk/` 成功 |
| 浏览器真实设备/Standalone | 真实 iOS/Android、PWA 安装态和物理麦克风仍未完成 |

## 性能测量边界

本轮不编造首屏、Avatar、帧率、内存或 TTS 延迟数字。当前只能确认代码有 idle 跳帧、low-bandwidth 禁用 3D、GLB LOD/纹理限制和 painter fallback；正式发布前需在 Chromium desktop、mobile viewport、Safari/WebKit 等价环境测量并记录。

## 核心 E2E 证据

以下均为 deterministic mock-backed 浏览器测试，不调用真实 Provider：

- 根练习入口：Chromium、mobile-chrome、WebKit 各 5/5；验证 AI 老师、主 CTA、场景二级入口、
  空数据和移动视口。
- 对话闭环：文本发送、TTS autoplay、TTS barge-in、语音转写、纠错保存、Avatar 唇形和 SM-2
  review 主用例通过；学习闭环 Home → Chat → Review → Progress 2/2 通过。
- 中断回归：LLM 请求被模拟为 stalled 时，处理态仍显示 Cancel，切换语音控制并取消后无异常。
- 曾发现并修复的测试数据问题：review fixture 缺少外键引用的 session/message；现已补齐有效 fixture，
  避免把数据层失败误判成 UI 失败。

情绪 marker 的一个历史 E2E 断言仍与当前聊天准备态/异步 mock 时序不稳定，未把它计入“通过”；
它不影响 Dart parser/state unit tests，但应在后续把断言改成 DB snapshot + 明确等待。

## 最小回归集

- conversation state machine：合法转移、重复转移、过期 turn token、interrupt；
- Avatar：3D loading/ready/fallback、低带宽 painter、播放结束闭嘴；
- learning loop：保存 correction → review_queue → SM-2 → refresh persistence；
- PWA：manifest、version check、SW waiting，不缓存 Authorization/API Key；
- production：`flutter analyze`、`flutter test`、`flutter build web --release`、`npx tsc --noEmit`、Playwright Chromium/mobile。
