/// Live2D model loader.
///
/// Phase 3 task 1 framework code — locates and parses a Live2D Cubism
/// `.model3.json` manifest from the bundled assets. When a model exists
/// under `assets/live2d/<model-name>/` (configurable via [kLive2DAssetDir]
/// + [Live2DLoader.tryLoad]'s `modelSubdir` parameter), the loader returns
/// a populated [Live2DModel]; otherwise it returns null and the avatar
/// stage falls back to the existing placeholder illustration
/// (`assets/images/tutor-hero-v1.png`).
///
/// The actual Cubism SDK rendering binding is *not* included here — by
/// design. Per the project plan in `project.md`:
///
///   "生产级 Live2D 需要定稿原画的分层 PSD 和 Cubism 绑定产物（.moc3 /
///    motions）。Live2D 模型本体需外部制作（推荐外包 Live2D 画师），
///    框架代码先行。"
///
/// When the model + a Flutter Cubism binding land, the only change needed
/// is to plug a native renderer into [Live2DView] (the future widget that
/// subscribes to parameter updates emitted by the avatar controllers).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

import '../domain/live2d_model.dart';

/// Asset directory containing Live2D models. Each subdirectory under this
/// holds one model (`.model3.json` + `.moc3` + textures + motions + exprs).
/// The default `tutor` model resolves to `assets/live2d/tutor/tutor.model3.json`.
const String kLive2DAssetDir = 'assets/live2d';

/// Default model subdirectory used by [Live2DLoader.tryLoadDefault].
const String kDefaultLive2DModelSubdir = 'tutor';

/// Loader for Live2D models. Pure async — no caching beyond the
/// `AssetManifest` lookup that flutter itself caches.
class Live2DLoader {
  const Live2DLoader();

  /// Probe whether *any* Live2D model is bundled under [kLive2DAssetDir].
  /// Cheap — uses the cached `AssetManifest`. Returns false on Flutter
  /// Web when the manifest hasn't loaded yet (handled defensively).
  Future<bool> hasAnyModel() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final entries = manifest.listAssets();
      for (final entry in entries) {
        if (entry.startsWith('$kLive2DAssetDir/') &&
            entry.endsWith('.model3.json')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Try to load the default tutor model. Returns null when the manifest
  /// has no entry under `assets/live2d/tutor/`.
  Future<Live2DModel?> tryLoadDefault() =>
      tryLoad(modelSubdir: kDefaultLive2DModelSubdir);

  /// Try to load the Live2D model at `assets/live2d/<modelSubdir>/`.
  ///
  /// Looks up the `.model3.json` file in the asset manifest, loads + parses
  /// it, and returns a populated [Live2DModel] (with all referenced
  /// `.moc3` / texture / motion paths resolved relative to the manifest's
  /// directory).
  ///
  /// Returns null when:
  ///   - The asset manifest has no `.model3.json` under the subdir
  ///   - The manifest can't be loaded (Flutter Web race)
  ///   - The `.model3.json` is malformed beyond recovery
  Future<Live2DModel?> tryLoad({
    String modelSubdir = kDefaultLive2DModelSubdir,
  }) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final entries = manifest.listAssets();
      String? manifestPath;
      for (final entry in entries) {
        if (entry.startsWith('$kLive2DAssetDir/$modelSubdir/') &&
            entry.endsWith('.model3.json')) {
          manifestPath = entry;
          break;
        }
      }
      if (manifestPath == null) return null;
      return await loadFromManifest(manifestPath);
    } catch (_) {
      return null;
    }
  }

  /// Parse a specific `.model3.json` manifest by its asset path.
  /// Throws when the file can't be read or parsed — callers should catch
  /// and fall back. Used by [tryLoad] internally; exposed for tests so a
  /// fixture manifest can be loaded directly from `rootBundle`.
  Future<Live2DModel> loadFromManifest(String manifestAssetPath) async {
    final raw = await rootBundle.loadString(manifestAssetPath);
    final parentDir = manifestAssetPath.substring(
      0,
      manifestAssetPath.lastIndexOf('/'),
    );
    return parseModel3Json(raw, manifestAssetPath: manifestAssetPath, parentDir: parentDir);
  }

  /// Pure-Dart `.model3.json` parser. Exposed for unit tests so a fixture
  /// string can be parsed without going through `rootBundle`.
  ///
  /// Schema (abridged; see Cubism SDK docs for full):
  /// ```json
  /// {
  ///   "Version": 3,
  ///   "Name": "Tutor",
  ///   "FileReferences": {
  ///     "Moc": "tutor.moc3",
  ///     "Textures": ["tutor.2048/texture_00.png"],
  ///     "Physics": "tutor.physics3.json",
  ///     "Pose": "tutor.pose3.json",
  ///     "DisplayInfo": "tutor.cdi3.json",
  ///     "Expressions": [{"Name": "happy", "File": "expressions/happy.exp3.json"}],
  ///     "Motions": {
  ///       "Idle": [{"File": "motions/idle_01.motion3.json", "Name": "idle_01"}],
  ///       "TapBody": [{"File": "motions/tap_01.motion3.json", "Name": "tap_01"}]
  ///     }
  ///   }
  /// }
  /// ```
  static Live2DModel parseModel3Json(
    String raw, {
    required String manifestAssetPath,
    required String parentDir,
  }) {
    final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;

    final version = (decoded['Version'] as num?)?.toInt() ?? 3;
    final name = (decoded['Name'] as String?) ?? 'Live2DModel';

    final fileRefs = decoded['FileReferences'];
    if (fileRefs is! Map<String, dynamic>) {
      throw const FormatException('Live2D model3.json missing FileReferences');
    }

    // Moc — required.
    final mocRel = fileRefs['Moc'] as String?;
    if (mocRel == null || mocRel.isEmpty) {
      throw const FormatException('Live2D model3.json missing FileReferences.Moc');
    }
    final moc3Path = '$parentDir/$mocRel';

    // Textures.
    final List<Live2DTextureRef> textures = [];
    final texturesRaw = fileRefs['Textures'];
    if (texturesRaw is List) {
      for (final t in texturesRaw) {
        if (t is String && t.isNotEmpty) {
          textures.add(Live2DTextureRef('$parentDir/$t'));
        }
      }
    }

    // Physics / pose / cdi — optional.
    String? physicsPath;
    final physicsRel = fileRefs['Physics'];
    if (physicsRel is String && physicsRel.isNotEmpty) {
      physicsPath = '$parentDir/$physicsRel';
    }
    String? posePath;
    final poseRel = fileRefs['Pose'];
    if (poseRel is String && poseRel.isNotEmpty) {
      posePath = '$parentDir/$poseRel';
    }
    String? cdiPath;
    final cdiRel = fileRefs['DisplayInfo'];
    if (cdiRel is String && cdiRel.isNotEmpty) {
      cdiPath = '$parentDir/$cdiRel';
    }

    // Expressions.
    final List<Live2DExpressionRef> expressions = [];
    final exprRaw = fileRefs['Expressions'];
    if (exprRaw is List) {
      for (final e in exprRaw) {
        if (e is Map<String, dynamic>) {
          final n = e['Name'] as String?;
          final f = e['File'] as String?;
          if (n != null && f != null && f.isNotEmpty) {
            expressions.add(Live2DExpressionRef(
              name: n,
              relativePath: '$parentDir/$f',
            ));
          }
        }
      }
    }

    // Motions — grouped by trigger key (Idle / TapBody / custom).
    final List<Live2DMotionRef> motions = [];
    final motionsRaw = fileRefs['Motions'];
    if (motionsRaw is Map<String, dynamic>) {
      motionsRaw.forEach((trigger, list) {
        if (list is List) {
          for (final m in list) {
            if (m is Map<String, dynamic>) {
              final n = m['Name'] as String?;
              final f = m['File'] as String?;
              if (n != null && f != null && f.isNotEmpty) {
                motions.add(Live2DMotionRef(
                  name: n,
                  relativePath: '$parentDir/$f',
                  trigger: trigger,
                ));
              }
            }
          }
        }
      });
    }

    return Live2DModel(
      manifestPath: manifestAssetPath,
      moc3Path: moc3Path,
      textures: List.unmodifiable(textures),
      motions: List.unmodifiable(motions),
      expressions: List.unmodifiable(expressions),
      displayName: name,
      version: version,
      physicsPath: physicsPath,
      posePath: posePath,
      cdiPath: cdiPath,
    );
  }
}
