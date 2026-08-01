# PWA 缓存与更新边界

## 允许缓存

- Flutter 应用壳、静态 JS/CSS、字体、图标和版本化构建资源。
- 仅在用户明确允许后缓存 Avatar 模型/动画；当前远端 GLB 默认由浏览器 HTTP cache 控制，不把它当作离线保证。
- SQLite Web 的 IndexedDB 数据由 sqflite Web 运行时管理。

## 禁止缓存

- API Key、Authorization header、Provider 请求和动态 AI 响应；
- 未经用户授权的录音和包含敏感内容的临时音频；
- 可能导致旧会话复用的动态 POST 响应。

`web/version_check.js` 只负责监听 Flutter Service Worker waiting/controllerchange 与版本探测；生产 Service Worker 由 Flutter Web build 生成。更新动作必须版本化清理旧 app-shell cache，不能把缓存清理误认为“删除用户数据”。

浏览器的 Service Worker 更新是 byte-by-byte 检测，旧 cache 不会自动全部删除；部署必须使用新的 cache/version 策略并保留入口资源的更新能力。参考 [web.dev Service Worker update](https://web.dev/learn/pwa/update) 与 [Service worker lifecycle](https://web.dev/articles/service-worker-lifecycle)。

## 离线行为

离线时允许打开本地历史、纠错和复习；明确显示语音识别、LLM、TTS 需要网络。不得显示“AI 可用”假状态，也不得把上一次动态回答当作当前请求结果。
