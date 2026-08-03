# 已知限制与后续 backlog

核查日期：2026-08-04

## 已知限制

- `assets/3d/avatar.html` 依赖 Three.js CDN 与 Ready Player Me 风格 GLB；当前仓库没有把
  远程角色资产作为自有可再分发资产提交。上线前必须取得明确的资产/商用许可，或换成
  已审查并 vendored 的模型。
- 浏览器端 BYOK 仍会把 key 暴露给浏览器运行时；PWA cache、URL、日志和构建物不保存 key，
  但这不能抵御 XSS。高风险部署需同源后端 relay、CSP、Trusted Types、短期 token 和服务端审计。
- 真实 Provider 的 CORS、HTTP 5xx、超时、流中断和 TTS/STT 计费没有用真实 key 做 CI；E2E
  使用显式 fake fixture/mocked network，不能证明第三方服务可用。
- Rhubarb 是可选的本地分析器；Web 端没有 native binary 时使用振幅 fallback。Avatar 加载
  失败或 low-bandwidth 会使用 painter，不保证所有模型都有同名骨骼/morph target。
- 当前自动化覆盖 Chromium/mobile viewport；WebKit/Safari standalone、真实麦克风拒绝、
  真实 iOS/Android 音频策略和硬件 FPS/内存需发布前实测。
- Flutter Web 的 web bridge 仍有 `dart:html` 兼容性提示，后续应迁移到稳定的 JS interop
  API；这不是本轮功能阻塞项。

## Backlog

1. 固定一个有许可的角色资产并把版本、hash、骨骼/morph 清单和许可证纳入 release artifact。
2. 增加同源 Provider relay 与 CSP/Trusted Types 方案，默认关闭浏览器直连高敏感 Provider。
3. 用真实设备测首屏、GLB ready、TTS 首音、FPS、内存及 30 分钟连续会话增长。
4. 增加 WebKit、Safari standalone、Android Chrome、iOS Safari 的权限与音频回归。
5. 把 `dart:html` bridge 迁移到 `dart:js_interop`，消除 web library 弃用提示。
6. 增加 schema v10 的旧库升级 fixture、备份/恢复演练及数据导入导出脱敏测试。
7. 为真实 STT/LLM/TTS relay 建立 opt-in nightly smoke，而不是把 secret 放入 PR CI。
