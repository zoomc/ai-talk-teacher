# SpeakFlow 项目说明

## 产品

SpeakFlow 是一个 Flutter 多端 AI 英语口语练习应用，支持 Web、iOS、Android
和 macOS。核心体验是语音转写、AI 对话、气泡内即时纠错、自动语音回复和 3D
虚拟外教。

## 当前架构

- Flutter + Riverpod + SQLite（Web 使用 sqflite Common FFI）。
- LLM、STT、TTS 由用户配置的 Provider Profile 驱动，密钥本地安全保存。
- 3D 外教为 Three.js + Ready Player Me GLB：Web 使用同源 iframe，移动/桌面
  使用 `webview_flutter`，TTS 振幅驱动口型；失败时回退到 Flutter 绘制角色。
- 界面语言的优先级：用户设置 > 浏览器语言（Web）> 系统语言 > 中文。

## 3D 方案与性能策略

继续采用 Ready Player Me GLB + Three.js，是当前 Web 与 Flutter WebView 端最轻量
的统一方案：标准 GLB、完整骨骼，且可请求 ARKit/Oculus Visemes 以实现口型。
默认角色使用 `lod=1`、512px 纹理图集和 WebP；保留所需 morph targets，空闲时
降低渲染频率。后续如需要用户自定义角色，可接 Ready Player Me Avatar Creator，
持久化其 GLB URL。

## 发布（阿里云）

- 线上地址：`https://zoomlab.top/talk/`
- nginx：`location /talk/` 映射到 `/opt/ai-talk-teacher/`，SPA 回退
  `/talk/index.html`。
- 发布步骤：
  1. `flutter build web --release --base-href /talk/`
  2. 通过 `rsync` 同步 `build/web/` 到服务器的临时目录。
  3. 在服务器以原子目录切换发布到 `/opt/ai-talk-teacher/`，保留一个备份。
  4. 用 `curl https://zoomlab.top/talk/version.json` 和页面响应确认。

部署不需要重启 nginx，因为仅更新静态资源。发布前必须更新 `web/version.json`，
否则已打开的 PWA 无法可靠显示更新提示。
