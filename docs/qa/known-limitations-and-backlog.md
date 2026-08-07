# 已知限制与后续 backlog

核查日期：2026-08-04

## 已知限制

- 当前 3D runtime 使用本地 vendored Three.js/TalkingHead/HeadAudio 与 CC0 MPFB GLB，
  不依赖 Three.js CDN 或 Ready Player Me 在线模型。MPFB 仍是高质量 prototype，不是
  电影/MetaHuman 级资产；若产品要求该级别，需要另行制作并审查授权的 PBR、高模、
  毛发/布料与 facial-rig asset。
- 浏览器端 BYOK 仍会把 key 暴露给浏览器运行时；PWA cache、URL、日志和构建物不保存 key，
  但这不能抵御 XSS。高风险部署需同源后端 relay、CSP、Trusted Types、短期 token 和服务端审计。
- 真实 Provider 的 CORS、HTTP 5xx、超时、流中断和 TTS/STT 计费没有用真实 key 做 CI；E2E
  使用显式 fake fixture/mocked network，不能证明第三方服务可用。
- Web 生产主路径将 Flutter 正在播放的原始 TTS 字节交给 HeadAudio worklet；Rhubarb
  仍是 native 可用时的增强时间线，AudioWorklet 不可用时才使用振幅/文字 fallback。
  Avatar 加载失败或 low-bandwidth 会使用 painter，不保证所有模型都有同名骨骼/morph target。
- 当前自动化覆盖 Chromium/mobile viewport；WebKit/Safari standalone、真实麦克风拒绝、
  真实 iOS/Android 音频策略和硬件 FPS/内存需发布前实测。
- Flutter Web 的 web bridge 仍有 `dart:html` 兼容性提示，后续应迁移到稳定的 JS interop
  API；这不是本轮功能阻塞项。

## Backlog

1. 将 CC0 prototype 替换为授权的电影级角色资产，并把版本、hash、骨骼/morph 清单和许可证纳入 release artifact。
2. 增加同源 Provider relay 与 CSP/Trusted Types 方案，默认关闭浏览器直连高敏感 Provider。
3. 用真实设备测首屏、GLB ready、TTS 首音、FPS、内存及 30 分钟连续会话增长。
4. 增加 WebKit、Safari standalone、Android Chrome、iOS Safari 的权限与音频回归。
5. 把 `dart:html` bridge 迁移到 `dart:js_interop`，消除 web library 弃用提示。
6. 增加 schema v10 的旧库升级 fixture、备份/恢复演练及数据导入导出脱敏测试。
7. 为真实 STT/LLM/TTS relay 建立 opt-in nightly smoke，而不是把 secret 放入 PR CI。
