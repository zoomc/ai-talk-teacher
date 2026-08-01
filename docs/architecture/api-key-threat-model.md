# PWA API Key 威胁模型

## 资产

用户填写的 LLM/STT/TTS API Key、Provider URL、对话文本、录音和生成音频。

## 现实边界

浏览器 PWA 的 Key 必须在浏览器进程中被读取并参与请求，因此无法获得原生系统钥匙串的同等级保护。`flutter_secure_storage` 的 Web 实现不能抵消 XSS、恶意浏览器扩展、受控设备或恶意部署域名风险。产品文案必须说“本地保存/不会主动上传”，不能说“完全安全”。

## 现行控制

- SQLite profile 只保存 `***stored***` placeholder，真实 Key 交给 `SecureStorageService`。
- Profile 导出掩码；掩码导入会被清空。
- 服务错误展示经过 `AppError.redact`，不把完整请求头、Key 或原始 Provider 响应放进日志/界面。
- Service Worker/缓存策略不缓存 Provider POST、Authorization header、录音和动态 AI 响应。
- 设置提供清除音频缓存；删除 Profile 会删除对应 Key。

## 不兼容 Provider

浏览器直连可能因 CORS、混合内容、自签证书、地区网络或服务商策略失败。此时用户可配置自托管 relay；relay 不是本项目强制服务，也不改变 Key 在浏览器端的风险边界，除非由用户自行托管并管理密钥。

## 证据

- [MDN Web Storage](https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API) 说明 localStorage 是同源、持久、可被该 origin 文档访问的存储，不应被描述为系统钥匙串。
- [MDN getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia) 说明麦克风必须在 secure context 并经过用户授权。
