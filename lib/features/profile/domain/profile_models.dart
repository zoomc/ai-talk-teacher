import 'package:uuid/uuid.dart';

import 'provider_catalog.dart';

const _uuid = Uuid();

/// Service provider types
enum ProfileType { llm, stt, tts }

/// LLM Profile for AI dialogue (OpenAI-compatible).
class LlmProfile {
  final String id;
  final String name;
  /// Catalog provider id (see [LlmProviderCatalog]). Defaults to 'custom'.
  final String providerId;
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  LlmProfile({
    String? id,
    required this.name,
    this.providerId = LlmProviderCatalog.customId,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProviderDef get providerDef => LlmProviderCatalog.byId(providerId);

  String get providerDisplayName => providerDef.displayName;

  LlmProfile copyWith({
    String? name,
    String? providerId,
    String? baseUrl,
    String? apiKey,
    String? model,
    bool? isActive,
  }) {
    return LlmProfile(
      id: id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_id': providerId,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LlmProfile.fromMap(Map<String, dynamic> map) {
    return LlmProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      providerId: (map['provider_id'] as String?) ?? LlmProviderCatalog.customId,
      baseUrl: map['base_url'] as String? ?? '',
      apiKey: map['api_key'] as String? ?? '',
      model: map['model'] as String? ?? '',
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// STT Profile for speech-to-text.
class SttProfile {
  final String id;
  final String name;
  /// Catalog provider id (see [SttProviderCatalog]).
  final String providerId;
  /// Base URL. For openai-compatible providers, includes the version prefix.
  /// For vendor providers, the host (region placeholder replaced at runtime).
  final String baseUrl;
  final String apiKey;
  final String model;
  /// BCP-47 language code, e.g. en-US. Defaults to en-US.
  final String language;
  /// Extra JSON config (e.g. {"region":"eastus"} for Azure).
  final String? extraConfig;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SttProfile({
    String? id,
    required this.name,
    this.providerId = SttProviderCatalog.customId,
    this.baseUrl = '',
    required this.apiKey,
    this.model = '',
    this.language = 'en-US',
    this.extraConfig,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProviderDef get providerDef => SttProviderCatalog.byId(providerId);

  String get providerDisplayName => providerDef.displayName;

  ProviderKind get kind => providerDef.kind;

  /// Region parsed from extraConfig (Azure), default 'eastus'.
  String get region {
    if (extraConfig == null) return 'eastus';
    try {
      // ignore: avoid_dynamic_calls
      final cfg = extraConfig!;
      // Lightweight parse without importing dart:convert here to keep model pure.
      final m = RegExp(r'"region"\s*:\s*"([^"]+)"').firstMatch(cfg);
      return m?.group(1) ?? 'eastus';
    } catch (_) {
      return 'eastus';
    }
  }

  SttProfile copyWith({
    String? name,
    String? providerId,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? language,
    String? extraConfig,
    bool? isActive,
  }) {
    return SttProfile(
      id: id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      language: language ?? this.language,
      extraConfig: extraConfig ?? this.extraConfig,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_id': providerId,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'language': language,
      'extra_config': extraConfig,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SttProfile.fromMap(Map<String, dynamic> map) {
    // Backward compat: if provider_id absent, derive from legacy `provider` enum.
    String providerId = (map['provider_id'] as String?) ?? '';
    if (providerId.isEmpty) {
      switch (map['provider'] as String?) {
        case 'deepgram':
          providerId = 'deepgram';
          break;
        case 'openaiWhisper':
          providerId = 'openai_whisper';
          break;
        case 'googleCloud':
          providerId = 'google';
          break;
        case 'azure':
          providerId = 'azure';
          break;
        default:
          providerId = SttProviderCatalog.customId;
      }
    }
    return SttProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      providerId: providerId,
      baseUrl: (map['base_url'] as String?) ?? '',
      apiKey: (map['api_key'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      language: (map['language'] as String?) ?? 'en-US',
      extraConfig: map['extra_config'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// TTS Profile for text-to-speech.
class TtsProfile {
  final String id;
  final String name;
  /// Catalog provider id (see [TtsProviderCatalog]).
  final String providerId;
  final String baseUrl;
  final String apiKey;
  final String model;
  /// Voice id used in the API request (e.g. OpenAI voice name, ElevenLabs voice_id,
  /// Fish Audio reference_id, Azure voice name).
  final String? voiceId;
  /// Human-readable voice name for display only.
  final String? voiceName;
  final double speed;
  /// Extra JSON config (e.g. {"region":"eastus"} for Azure).
  final String? extraConfig;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TtsProfile({
    String? id,
    required this.name,
    this.providerId = TtsProviderCatalog.customId,
    this.baseUrl = '',
    required this.apiKey,
    this.model = '',
    this.voiceId,
    this.voiceName,
    this.speed = 1.0,
    this.extraConfig,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProviderDef get providerDef => TtsProviderCatalog.byId(providerId);

  String get providerDisplayName => providerDef.displayName;

  ProviderKind get kind => providerDef.kind;

  String get region {
    if (extraConfig == null) return 'eastus';
    final m = RegExp(r'"region"\s*:\s*"([^"]+)"').firstMatch(extraConfig!);
    return m?.group(1) ?? 'eastus';
  }

  TtsProfile copyWith({
    String? name,
    String? providerId,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? voiceId,
    String? voiceName,
    double? speed,
    String? extraConfig,
    bool? isActive,
  }) {
    return TtsProfile(
      id: id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      speed: speed ?? this.speed,
      extraConfig: extraConfig ?? this.extraConfig,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_id': providerId,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'voice_id': voiceId,
      'voice_name': voiceName,
      'speed': speed,
      'extra_config': extraConfig,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TtsProfile.fromMap(Map<String, dynamic> map) {
    String providerId = (map['provider_id'] as String?) ?? '';
    if (providerId.isEmpty) {
      switch (map['provider'] as String?) {
        case 'fishAudio':
          providerId = 'fish_audio';
          break;
        case 'elevenLabs':
          providerId = 'elevenlabs';
          break;
        case 'openaiTts':
          providerId = 'openai_tts';
          break;
        case 'azure':
          providerId = 'azure_tts';
          break;
        default:
          providerId = TtsProviderCatalog.customId;
      }
    }
    return TtsProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      providerId: providerId,
      baseUrl: (map['base_url'] as String?) ?? '',
      apiKey: (map['api_key'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      voiceId: map['voice_id'] as String?,
      voiceName: map['voice_name'] as String?,
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      extraConfig: map['extra_config'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
