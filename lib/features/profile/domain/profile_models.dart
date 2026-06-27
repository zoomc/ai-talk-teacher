import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Service provider types
enum ProfileType { llm, stt, tts }

/// LLM Profile for AI dialogue
class LlmProfile {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  LlmProfile({
    String? id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  LlmProfile copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    bool? isActive,
  }) {
    return LlmProfile(
      id: id,
      name: name ?? this.name,
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
      baseUrl: map['base_url'] as String,
      apiKey: map['api_key'] as String,
      model: map['model'] as String,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// STT Profile for speech-to-text
enum SttProvider { deepgram, openaiWhisper, googleCloud, azure }

class SttProfile {
  final String id;
  final String name;
  final SttProvider provider;
  final String apiKey;
  final String? extraConfig;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SttProfile({
    String? id,
    required this.name,
    required this.provider,
    required this.apiKey,
    this.extraConfig,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  SttProfile copyWith({
    String? name,
    SttProvider? provider,
    String? apiKey,
    String? extraConfig,
    bool? isActive,
  }) {
    return SttProfile(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
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
      'provider': provider.name,
      'api_key': apiKey,
      'extra_config': extraConfig,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SttProfile.fromMap(Map<String, dynamic> map) {
    return SttProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      provider: SttProvider.values.byName(map['provider'] as String),
      apiKey: map['api_key'] as String,
      extraConfig: map['extra_config'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String get providerDisplayName {
    switch (provider) {
      case SttProvider.deepgram:
        return 'Deepgram';
      case SttProvider.openaiWhisper:
        return 'OpenAI Whisper';
      case SttProvider.googleCloud:
        return 'Google Cloud Speech';
      case SttProvider.azure:
        return 'Azure Speech';
    }
  }
}

/// TTS Profile for text-to-speech
enum TtsProvider { fishAudio, elevenLabs, openaiTts, azure }

class TtsProfile {
  final String id;
  final String name;
  final TtsProvider provider;
  final String apiKey;
  final String? voiceId;
  final String? voiceName;
  final double speed;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TtsProfile({
    String? id,
    required this.name,
    required this.provider,
    required this.apiKey,
    this.voiceId,
    this.voiceName,
    this.speed = 1.0,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  TtsProfile copyWith({
    String? name,
    TtsProvider? provider,
    String? apiKey,
    String? voiceId,
    String? voiceName,
    double? speed,
    bool? isActive,
  }) {
    return TtsProfile(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      speed: speed ?? this.speed,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider': provider.name,
      'api_key': apiKey,
      'voice_id': voiceId,
      'voice_name': voiceName,
      'speed': speed,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TtsProfile.fromMap(Map<String, dynamic> map) {
    return TtsProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      provider: TtsProvider.values.byName(map['provider'] as String),
      apiKey: map['api_key'] as String,
      voiceId: map['voice_id'] as String?,
      voiceName: map['voice_name'] as String?,
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String get providerDisplayName {
    switch (provider) {
      case TtsProvider.fishAudio:
        return 'Fish Audio';
      case TtsProvider.elevenLabs:
        return 'ElevenLabs';
      case TtsProvider.openaiTts:
        return 'OpenAI TTS';
      case TtsProvider.azure:
        return 'Azure TTS';
    }
  }
}
