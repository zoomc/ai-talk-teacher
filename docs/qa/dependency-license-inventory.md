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
| Three.js 与 GLTFLoader | 通过 `assets/3d/avatar.html` 的 CDN/importmap 使用；渲染器许可证不覆盖模型资产 | vendoring 或固定 CDN hash，并随发布物保留 MIT notice |
| Ready Player Me 风格 GLB | 远程模型/贴图没有作为本仓库自有资产提交 | 取得具体模型商业授权或更换已审查资产；不要仅凭引擎许可证上线 |
| Rhubarb Lip Sync | 可选本地增强，不是 Web 必需依赖 | 若随原生包发布，保留其许可证与二进制来源说明 |

## 证据与限制

- 依赖版本证据：`flutter pub deps --style=compact`，输出已在本轮终端检查。
- 资产研究：`docs/research/avatar-technology-selection.md`，记录了 Three.js/GLTF、
  Ready Player Me、Rhubarb、Live2D、Babylon、three-vrm 的候选和风险。
- 当前没有把远程 GLB 下载入仓库，也没有生成完整的自动化 SPDX 清单；因此最终发布门仍
  要求 legal/release owner 补做逐包 license export、模型 hash 和 notice 归档。
