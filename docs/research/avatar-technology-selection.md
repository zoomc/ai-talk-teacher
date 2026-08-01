# Avatar 技术选型与 Spike

核查日期：2026-08-01。以下版本、许可证和浏览器判断以官方仓库/文档为证据；模型、贴图、动画素材仍需单独核查其授权，不能因渲染器许可证宽松而自动获得素材授权。

## 需求与非目标

需求：浏览器本地渲染、上半身构图、idle/眨眼/视线/头部动作、有限手势、普通 TTS 音频可驱动口型、有 Viseme 时可增强、可中断、手机与桌面 PWA 可用、无持续 GPU 服务、能嵌入 Flutter Web/WebView。

非目标：照片驱动视频、持续 GPU 数字人、绑定单一云端数字人服务、为原生端提前开发复杂 Platform Channel。

## 候选发现与初筛

| 候选 | 官方证据与当前版本 | 许可证/成本 | 关键能力 | 初筛 |
|---|---|---|---|---|
| Three.js + glTF/GLB | [three.js](https://github.com/mrdoob/three.js) r184（官方仓库页面，2026-04-16）；[GLTFLoader](https://threejs.org/docs/pages/GLTFLoader.html) | Three.js MIT；每个 GLB/纹理/动画另行核查；浏览器本地 | WebGL 稳定，GLTFLoader、AnimationMixer、morph target；可自定义音频驱动 | 入围 |
| Babylon.js + glTF | [Babylon.js releases](https://github.com/BabylonJS/Babylon.js/releases) 9.19.0（2026-07-30） | Apache-2.0；素材另行核查；浏览器本地 | WebGL/WebGPU、glTF、Web Audio，工程能力强 | 入围但迁移成本高 |
| three-vrm + VRM | [three-vrm](https://github.com/pixiv/three-vrm) v3.5.5（2026-07-09） | MIT；VRM/模型素材另行核查 | VRM humanoid、表情和 SpringBone；更适合 VRM 资产而非当前 RPM GLB | Spike 备选 |
| TalkingHead | [TalkingHead npm](https://www.npmjs.com/package/@met4citizen/talkinghead)、[GitHub](https://github.com/met4citizen/TalkingHead) | 版本与素材/依赖需按仓库核查；浏览器本地 | 已包含音频口型、文本/音频播放和打断语义 | 作为对照，不直接替换 |
| Live2D Cubism | [CubismWebFramework](https://github.com/Live2D/CubismWebFramework)、[官方 Web SDK](https://docs.live2d.com/en/cubism-sdk-manual/cubism-sdk-for-web/) | Framework 源码与 Core/发布许可不同；Core 不在 GitHub，发布需遵守 Live2D 许可 | 2D 表情和动作强，但需要已绑定的 moc3、Core、发布授权 | 淘汰为当前默认 |

对比项：Rhubarb 是口型分析工具而不是 Avatar 引擎；官方仓库最新 release 为 [1.14.0](https://github.com/DanielSWolf/rhubarb-lip-sync/releases)（2026-04-03），保留为桌面/服务端可选增强，不把它作为 Web 必需依赖。照片驱动与 Wav2Lip/MuseTalk 需要持续推理资源，不符合本次非目标。

## 许可证与运行成本矩阵

| 方案 | 引擎许可证 | 默认是否需云/GPU | 浏览器路径 | 主要风险 |
|---|---|---|---|---|
| Three.js + RPM GLB | 引擎 MIT；RPM 头像授权需注册/条款确认 | 不需持续 GPU；当前模型 URL 需要联网 | WebGL + iframe；WebView 复用 | CDN/CORS/模型授权、Web 端资源加载失败 |
| Babylon.js | Apache-2.0 | 不需持续 GPU | WebGL/WebGPU | 引入新引擎与 Dart bridge，超出当前增量范围 |
| three-vrm | MIT | 不需持续 GPU | WebGL/WebGPU | 当前资产不是 VRM；迁移模型和表情映射 |
| TalkingHead | 需按其仓库和依赖逐项核查 | 依实现而定 | Web-first | API/资产/维护方向与现有 Flutter 边界不一致 |
| Live2D | 发布/商业许可需遵守官方协议 | 本地 GPU/CPU | WebGL | Core 不随开源仓库发布，商业发布授权成本和绑定资产风险 |

Ready Player Me 官方说明：Avatar Creator 产出的头像非商业使用按 CC4.0；商业产品需要注册开发者/合作方。当前仓库的远端 GLB URL 不能在未确认项目商业资格和该具体资产条款前宣称“商业授权已清楚”。

## 浏览器与 API 约束

- 主渲染选择 WebGL：WebGPU 作为未来增强，不作为手机 Safari 的必要条件。
- Three.js `GLTFLoader` 支持 glTF 2.0、动画和 morph target；当前 `avatar.html` 使用 GLB + ARKit/Oculus Visemes 参数。
- 普通 TTS：用播放振幅驱动 `jawOpen`，无 Viseme 仍可运行；Rhubarb/音素时间线是增强，不是核心可用性条件。
- 浏览器必须在用户手势后恢复 Web Audio/播放；[MDN autoplay guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay) 明确说明未交互页面的有声播放可能被阻止。
- 麦克风只在 HTTPS/localhost 等 secure context 中可用，并始终需要用户授权；见 [MDN getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)。
- 3D iframe 不请求麦克风；音频由 Flutter `just_audio` 播放，振幅通过受限 bridge 传入 Avatar。

## 真实 Spike

### Spike A：当前 Three.js + RPM GLB

隔离入口：`assets/3d/avatar.html`。代码核查确认：GLTFLoader 加载合法 GLB URL；模型加载后收集 Mixamo bones 和 ARKit morph dictionary；`setGesture`、`setViseme`、`setAudioLevel` bridge 可驱动状态；idle 状态跳帧到约 30fps；GLB 失败调用 `_onError`。

在 Flutter 集成中，`VirtualCharacter3D` 已验证 loading → ready3d → painter fallback 三态；`AvatarStage` 现接入该 3D 路径，并保留 Flutter painter fallback。Spike 的明确限制是模型来自远端 CDN，当前环境未把该 GLB 下载进仓库，无法把远端可用性写成稳定离线证据。

### Spike B：当前 Flutter painter + Rhubarb timeline

`AvatarStage` 以 `IdleAnimationController`、`EmotionController`、`VisemeTimelinePlayer` 合并参数；Rhubarb timeline 结束后回到振幅驱动；播放结束/中断清理 timeline；项目已有 `rhubarb_parser_test.dart`、`viseme_mapping_test.dart`、`idle_animation_test.dart`、`emotion_controller_test.dart`。

结果：在无 WebGL、无 CDN、低带宽和测试环境仍可显示人物、字幕与状态；代价是表情/嘴型不如真实模型。该路径被保留为强制降级方案。

## 选择

主方案：Three.js + GLB（当前 `VirtualCharacter3D`/`avatar.html`），状态由 Flutter AvatarStage 的语义输入驱动，口型优先振幅、可选 Viseme 增强。备选：Flutter painter + Rhubarb/振幅 fallback；不是另一套产品路线，而是可靠降级。

选择理由：迁移成本最低、已有跨 Web/WebView bridge、glTF/GLB 标准化、无需服务端 GPU、能在 WebGL 可用的手机浏览器上运行；相比 Live2D，不引入 Core/发布许可绑定；相比 VRM，不要求替换当前 GLB 资产。

## 回滚与风险

- 任意设备检测失败、模型加载超时或用户开启低带宽时，`AvatarStage(prefer3d: false)` 直接回到 painter。
- 保留 `VirtualCharacter3D` 和 `avatar.html` 作为可替换边界；业务层只传 phase/emotion/text/amplitude，不传骨骼名或 morph 数值。
- 主要未解决风险：RPM 商业授权需确认、CDN/CORS/网络延迟、WebView 对远端模块加载的限制、未取得真实目标手机帧率/内存测量。
