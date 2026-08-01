# 测试与性能报告

核查日期：2026-08-01

## 基线与本轮证据

| 检查 | 结果 |
|---|---|
| `git fetch --all --prune` | 成功；清理已删除远端 agent refs |
| `git pull --ff-only origin main` | `Already up to date` |
| `flutter analyze` | 0 errors；21 条 info/warning |
| `flutter test` 基线 | 248 项中 2 项失败，均为 SkillMastery 评分期望 |
| Playwright TypeScript | 待本轮最终构建后重新执行 |
| Flutter Web production build | 待最终实现后执行 |
| 浏览器真实设备/Standalone | 当前环境尚未完成，不能宣称通过 |

## 性能测量边界

本轮不编造首屏、Avatar、帧率、内存或 TTS 延迟数字。当前只能确认代码有 idle 跳帧、low-bandwidth 禁用 3D、GLB LOD/纹理限制和 painter fallback；正式发布前需在 Chromium desktop、mobile viewport、Safari/WebKit 等价环境测量并记录。

## 最小回归集

- conversation state machine：合法转移、重复转移、过期 turn token、interrupt；
- Avatar：3D loading/ready/fallback、低带宽 painter、播放结束闭嘴；
- learning loop：保存 correction → review_queue → SM-2 → refresh persistence；
- PWA：manifest、version check、SW waiting，不缓存 Authorization/API Key；
- production：`flutter analyze`、`flutter test`、`flutter build web --release`、`npx tsc --noEmit`、Playwright Chromium/mobile。
