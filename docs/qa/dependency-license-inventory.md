# 依赖与资产许可证检查

核查日期：2026-08-04

## 检查结论

`flutter pub deps --style=compact` 已在当前环境执行，锁定的主要运行依赖包括 Flutter
3.44.4、Dart 3.12.2、Riverpod 2.6.1、go_router 14.8.1、sqflite 2.4.3、just_audio
0.9.46、record 5.2.1、webview_flutter 4.14.1 和 flutter_secure_storage 9.2.4。
依赖树没有因为本轮 Avatar/会话修改新增 package。

| 范围 | 当前策略 | 发布前动作 |
|---|---|---|
| Flutter/Dart 与官方插件 | 随 SDK/package 元数据分发；以各 package 仓库 LICENSE 为准 | 在 release CI 导出完整 license notice |
| Riverpod、go_router、sqflite、just_audio、record 等 pub 依赖 | 版本已由 `pubspec.lock` 锁定；本仓库不复制其源码 | 逐包确认 LICENSE/NOTICE 与二进制再分发要求 |
| Three.js、GLTFLoader、TalkingHead、HeadAudio | 已 vendored 到 `assets/3d/vendor/`，生产 runtime 不请求 CDN；渲染器/运行时许可证不覆盖模型资产 | 随发布物保留 `assets/3d/vendor/THIRD_PARTY_NOTICES.md`，升级依赖时复核 notice |
| Microsoft Rocketbox facial GLB | `assets/3d/avatar-v2/rocketbox-female-01.glb`，由 Microsoft Rocketbox `Female_Adult_01_facial.fbx` 转换并随包自托管；MIT | 保留官方来源、commit、hash 和 MIT notice；若升级为真正电影级资产，替换为另行签署/审查的授权模型 |
| Rhubarb Lip Sync | 可选本地增强，不是 Web 必需依赖 | 若随原生包发布，保留其许可证与二进制来源说明 |

## 证据与限制

- 依赖版本证据：`flutter pub deps --style=compact`，输出已在本轮终端检查。
- 资产研究：`docs/research/avatar-technology-selection.md`，记录了 Three.js/GLTF、
  Ready Player Me、Rhubarb、Live2D、Babylon、three-vrm 的候选和风险。
- 当前仍没有生成完整的自动化 SPDX 清单；最终发布门仍要求 legal/release owner
  补做逐包 license export、模型 hash 和 notice 归档。
