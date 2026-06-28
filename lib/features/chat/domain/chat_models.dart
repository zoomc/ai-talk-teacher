import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MessageRole { user, assistant, system }

enum CorrectionType { grammar, vocabulary, pronunciation }

class Correction {
  final String id;
  final String original;
  final String corrected;
  final CorrectionType type;
  final String? explanation;
  final String? messageId;
  final String? sessionId;
  final int reviewCount;
  final double easinessFactor;
  final int intervalDays;
  final DateTime? nextReviewAt;
  final DateTime createdAt;

  Correction({
    String? id,
    required this.original,
    required this.corrected,
    required this.type,
    this.explanation,
    this.messageId,
    this.sessionId,
    this.reviewCount = 0,
    this.easinessFactor = 2.5,
    this.intervalDays = 0,
    this.nextReviewAt,
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  Correction copyWith({
    String? original,
    String? corrected,
    CorrectionType? type,
    String? explanation,
    String? messageId,
    String? sessionId,
    int? reviewCount,
    double? easinessFactor,
    int? intervalDays,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
  }) {
    return Correction(
      id: id,
      original: original ?? this.original,
      corrected: corrected ?? this.corrected,
      type: type ?? this.type,
      explanation: explanation ?? this.explanation,
      messageId: messageId ?? this.messageId,
      sessionId: sessionId ?? this.sessionId,
      reviewCount: reviewCount ?? this.reviewCount,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      nextReviewAt: clearNextReviewAt
          ? null
          : (nextReviewAt ?? this.nextReviewAt),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original': original,
      'corrected': corrected,
      'type': type.name,
      'explanation': explanation,
      'message_id': messageId,
      'session_id': sessionId,
      'review_count': reviewCount,
      'easiness_factor': easinessFactor,
      'interval_days': intervalDays,
      'next_review_at': nextReviewAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Correction.fromMap(Map<String, dynamic> map) {
    return Correction(
      id: map['id'] as String,
      original: map['original'] as String,
      corrected: map['corrected'] as String,
      type: CorrectionType.values.byName(map['type'] as String),
      explanation: map['explanation'] as String?,
      messageId: map['message_id'] as String?,
      sessionId: map['session_id'] as String?,
      reviewCount: (map['review_count'] as int?) ?? 0,
      easinessFactor: (map['easiness_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (map['interval_days'] as int?) ?? 0,
      nextReviewAt: map['next_review_at'] != null
          ? DateTime.parse(map['next_review_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class ChatMessage {
  final String id;
  final String sessionId;
  final MessageRole role;
  final String content;
  final List<Correction> corrections;
  final String? audioPath;
  final DateTime createdAt;

  ChatMessage({
    String? id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.corrections = const [],
    this.audioPath,
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role.name,
      'content': content,
      'audio_path': audioPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: MessageRole.values.byName(map['role'] as String),
      content: map['content'] as String,
      audioPath: map['audio_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

enum SessionStatus { active, completed, archived }

class ChatSession {
  final String id;
  final String? topic;
  final String? scenarioId;
  final SessionStatus status;
  final String? levelTag;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    String? id,
    this.topic,
    this.scenarioId,
    this.status = SessionStatus.active,
    this.levelTag,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ChatSession copyWith({
    String? topic,
    String? scenarioId,
    SessionStatus? status,
    String? levelTag,
  }) {
    return ChatSession(
      id: id,
      topic: topic ?? this.topic,
      scenarioId: scenarioId ?? this.scenarioId,
      status: status ?? this.status,
      levelTag: levelTag ?? this.levelTag,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
      'scenario_id': scenarioId,
      'status': status.name,
      'level_tag': levelTag,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      topic: map['topic'] as String?,
      scenarioId: map['scenario_id'] as String?,
      status: SessionStatus.values.byName(map['status'] as String),
      levelTag: map['level_tag'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class Scenario {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String difficulty; // beginner, intermediate, advanced
  final String category;
  final String systemPrompt;

  Scenario({
    String? id,
    required this.name,
    required this.description,
    required this.icon,
    required this.difficulty,
    required this.category,
    required this.systemPrompt,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'difficulty': difficulty,
      'category': category,
      'system_prompt': systemPrompt,
    };
  }

  factory Scenario.fromMap(Map<String, dynamic> map) {
    return Scenario(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      difficulty: map['difficulty'] as String,
      category: map['category'] as String,
      systemPrompt: map['system_prompt'] as String,
    );
  }
}
