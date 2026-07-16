import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MessageRole { user, assistant, system }

/// S5/S6 v7 — `fluency` added so the LLM can flag disfluency / hesitation
/// errors (fillers, false starts, run-on sentences) that aren't strictly
/// grammar or vocabulary. Mirrors the four-dimension AbilityScores used by
/// the home dashboard radar.
enum CorrectionType { grammar, vocabulary, pronunciation, fluency }

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
  // How many times this exact mistake has been seen across sessions. Used
  // for deduplication: when the LLM flags the same (original, corrected, type)
  // again, we increment this instead of inserting a duplicate row.
  final int occurrenceCount;
  // Last time this mistake was flagged. Drives "recently seen" sort and lets
  // the user see recurring errors vs one-offs.
  final DateTime lastSeenAt;
  // Phase-1 P0 #4: importance score (0–100) the LLM assigns to each flagged
  // error so the review list can be sorted by "what matters most" rather than
  // by insertion order. Higher = more important to fix soon. Defaults to 50
  // when the LLM omits the field (older sessions / graceful degradation).
  final int importance;
  // Phase-1 P0 #4: user-starred corrections. Starred items always surface at
  // the top of the review list and never fall out of the active rotation.
  final bool isFavorite;
  // When [isFavorite] was last toggled on. Null when not starred. Used to
  // keep starred ordering stable (newest star first).
  final DateTime? favoriteAt;
  // S5/S6 v7 — skill tag for this error (e.g. 'grammar/subject-verb-agreement',
  // 'pronunciation/th-digraph', 'vocabulary/collocation'). Free-text so the
  // LLM can introduce new skill points without a schema change. Drives the
  // skill_mastery roll-up: each distinct skill_id gets a 0-100 mastery score.
  // Null for legacy rows + when the LLM omits the field (graceful degrade).
  final String? skill;

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
    this.occurrenceCount = 1,
    DateTime? lastSeenAt,
    this.importance = 50,
    this.isFavorite = false,
    this.favoriteAt,
    this.skill,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       lastSeenAt = lastSeenAt ?? createdAt ?? DateTime.now();

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
    int? occurrenceCount,
    DateTime? lastSeenAt,
    int? importance,
    bool? isFavorite,
    DateTime? favoriteAt,
    bool clearFavoriteAt = false,
    String? skill,
    bool clearSkill = false,
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
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      importance: importance ?? this.importance,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteAt: clearFavoriteAt ? null : (favoriteAt ?? this.favoriteAt),
      skill: clearSkill ? null : (skill ?? this.skill),
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
      'occurrence_count': occurrenceCount,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'importance': importance,
      'is_favorite': isFavorite ? 1 : 0,
      'favorite_at': favoriteAt?.toIso8601String(),
      'skill': skill,
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
      // v3 migration back-fills these for pre-existing rows.
      occurrenceCount: (map['occurrence_count'] as int?) ?? 1,
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.parse(map['last_seen_at'] as String)
          : DateTime.parse(map['created_at'] as String),
      // v4 migration back-fills these (default importance 50, not starred).
      importance: (map['importance'] as int?) ?? 50,
      isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
      favoriteAt: map['favorite_at'] != null
          ? DateTime.parse(map['favorite_at'] as String)
          : null,
      // v7 migration back-fills NULL for pre-existing rows.
      skill: map['skill'] as String?,
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
  // Phase-1 P0 #1: marks a guest-trial session. Guest sessions are
  // time-boxed (3 minutes) and use built-in restricted provider profiles
  // so a brand-new user can try the app before configuring their own keys.
  // Stored as an integer (0/1) in SQLite — see v4 migration.
  final bool isGuest;

  ChatSession({
    String? id,
    this.topic,
    this.scenarioId,
    this.status = SessionStatus.active,
    this.levelTag,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isGuest = false,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ChatSession copyWith({
    String? topic,
    String? scenarioId,
    SessionStatus? status,
    String? levelTag,
    bool? isGuest,
  }) {
    return ChatSession(
      id: id,
      topic: topic ?? this.topic,
      scenarioId: scenarioId ?? this.scenarioId,
      status: status ?? this.status,
      levelTag: levelTag ?? this.levelTag,
      createdAt: createdAt,
      isGuest: isGuest ?? this.isGuest,
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
      'is_guest': isGuest ? 1 : 0,
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
      // v4 back-fill: pre-existing rows predate the guest column; treat as
      // a normal (non-guest) session.
      isGuest: ((map['is_guest'] as int?) ?? 0) == 1,
    );
  }
}

/// S7/S8 — one structured expression inside a scenario.
///
/// Each scenario ships 5–8 core expressions (the "what to say" backbone).
/// `practiceType` controls how the practice screen presents the item:
///   'repeat'   — listen to the demo and repeat
///   'read'     — read the expression aloud
///   'respond'  — answer a follow-up prompt
///   'listen'   — identify the expression from audio
/// `score` is the user's latest 0–100 mastery score on this item; 0 means
/// "not practised yet". `audioUrl` is an optional TTS demo clip; null when
/// the app should synthesise on demand from [expression].
class ScenarioItem {
  final String id;
  final String scenarioId;
  final String expression;
  final String translation;
  final String? audioUrl;
  final String practiceType;
  final int score;

  ScenarioItem({
    String? id,
    required this.scenarioId,
    required this.expression,
    required this.translation,
    this.audioUrl,
    this.practiceType = 'repeat',
    this.score = 0,
  }) : id = id ?? _uuid.v4();

  ScenarioItem copyWith({
    String? expression,
    String? translation,
    String? audioUrl,
    String? practiceType,
    int? score,
    bool clearAudioUrl = false,
  }) {
    return ScenarioItem(
      id: id,
      scenarioId: scenarioId,
      expression: expression ?? this.expression,
      translation: translation ?? this.translation,
      audioUrl: clearAudioUrl ? null : (audioUrl ?? this.audioUrl),
      practiceType: practiceType ?? this.practiceType,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scenario_id': scenarioId,
      'expression': expression,
      'translation': translation,
      'audio_url': audioUrl,
      'practice_type': practiceType,
      'score': score,
    };
  }

  factory ScenarioItem.fromMap(Map<String, dynamic> map) {
    return ScenarioItem(
      id: map['id'] as String,
      scenarioId: map['scenario_id'] as String,
      expression: map['expression'] as String,
      translation: (map['translation'] as String?) ?? '',
      audioUrl: map['audio_url'] as String?,
      practiceType: (map['practice_type'] as String?) ?? 'repeat',
      score: (map['score'] as int?) ?? 0,
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

  /// S7/S8 — free-text learning goal for this scenario (e.g.
  /// "Order a coffee with confidence"). Shown on the scenario detail card
  /// and surfaced in the home dashboard's recommendation. Nullable for
  /// backward compatibility with pre-v8 rows.
  final String? goal;

  /// S7/S8 — arbitrary tags used for filtering / recommendations
  /// (e.g. ['daily', 'food', 'beginner']). Stored as a JSON-encoded
  /// array in SQLite. Empty list for pre-v8 rows that have no tags.
  final List<String> tags;

  /// S7/S8 — the 5–8 structured core expressions. Loaded lazily via
  /// [ChatRepository.getScenarioItems]; empty when the Scenario was
  /// constructed straight from the row without joining scenario_items.
  final List<ScenarioItem> items;

  Scenario({
    String? id,
    required this.name,
    required this.description,
    required this.icon,
    required this.difficulty,
    required this.category,
    required this.systemPrompt,
    this.goal,
    this.tags = const [],
    this.items = const [],
  }) : id = id ?? _uuid.v4();

  Scenario copyWith({
    String? name,
    String? description,
    String? icon,
    String? difficulty,
    String? category,
    String? systemPrompt,
    String? goal,
    bool clearGoal = false,
    List<String>? tags,
    List<ScenarioItem>? items,
  }) {
    return Scenario(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      goal: clearGoal ? null : (goal ?? this.goal),
      tags: tags ?? this.tags,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'difficulty': difficulty,
      'category': category,
      'system_prompt': systemPrompt,
      'goal': goal,
      'tags': tags.isEmpty ? null : jsonEncode(tags),
    };
  }

  factory Scenario.fromMap(Map<String, dynamic> map) {
    // S7/S8 — parse the optional goal / tags columns. Both ship as NULL
    // for pre-v8 rows, so default to null / empty list.
    final tagsRaw = map['tags'];
    List<String> parsedTags = const [];
    if (tagsRaw is String && tagsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tagsRaw);
        if (decoded is List) {
          parsedTags = decoded
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        // Malformed JSON — fall back to empty tags rather than crashing.
      }
    }
    return Scenario(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      difficulty: map['difficulty'] as String,
      category: map['category'] as String,
      systemPrompt: map['system_prompt'] as String,
      goal: map['goal'] as String?,
      tags: parsedTags,
    );
  }
}

/// Phase 5 — AI-generated alternative expression suggestion for a user's
/// utterance. Stored in the `expression_suggestions` table and surfaced in
/// the chat bubble as a "try this instead" panel.
class ExpressionSuggestion {
  final String id;
  final String sessionId;
  final String messageId;
  final String userText;
  final List<String> suggestions;
  final DateTime createdAt;

  ExpressionSuggestion({
    String? id,
    required this.sessionId,
    required this.messageId,
    required this.userText,
    required this.suggestions,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'message_id': messageId,
      'user_text': userText,
      'suggestions': jsonEncode(suggestions),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExpressionSuggestion.fromMap(Map<String, dynamic> map) {
    final raw = map['suggestions'];
    List<String> parsed = [];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          parsed = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return ExpressionSuggestion(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      messageId: map['message_id'] as String,
      userText: map['user_text'] as String,
      suggestions: parsed,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

/// Phase 5 — snapshot of session state for crash recovery.
///
/// Saved periodically during a conversation so the app can restore
/// the last known-good state if the user is interrupted (crash, app
/// background-kill, network loss). `lastMessageId` is the last
/// successfully saved message; `contextSummary` is an opaque JSON
/// blob the LLM provider can use to reconstruct conversation context.
class SessionSnapshot {
  final String id;
  final String sessionId;
  final String? lastMessageId;
  final String? contextSummary;
  final DateTime createdAt;

  SessionSnapshot({
    String? id,
    required this.sessionId,
    this.lastMessageId,
    this.contextSummary,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'last_message_id': lastMessageId,
      'context_summary': contextSummary,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SessionSnapshot.fromMap(Map<String, dynamic> map) {
    return SessionSnapshot(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      lastMessageId: map['last_message_id'] as String?,
      contextSummary: map['context_summary'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

/// Phase 5 — session-level metadata for history browsing and summary.
///
/// One row per session (UNIQUE on session_id), updated atomically as the
/// conversation progresses. `summary` is an auto-generated session summary
/// (set when the LLM produces one at conversation end). `topicTags` is a
/// JSON-encoded list of discovered topics. `difficultyLevel` is the
/// adaptive difficulty estimate for the session ('beginner'/'intermediate'/
/// 'advanced').
class SessionMetadata {
  final String id;
  final String sessionId;
  final int durationSeconds;
  final int messageCount;
  final int correctionCount;
  final String? summary;
  final List<String> topicTags;
  final String? difficultyLevel;
  final DateTime updatedAt;

  SessionMetadata({
    String? id,
    required this.sessionId,
    this.durationSeconds = 0,
    this.messageCount = 0,
    this.correctionCount = 0,
    this.summary,
    this.topicTags = const [],
    this.difficultyLevel,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        updatedAt = updatedAt ?? DateTime.now();

  SessionMetadata copyWith({
    int? durationSeconds,
    int? messageCount,
    int? correctionCount,
    String? summary,
    bool clearSummary = false,
    List<String>? topicTags,
    String? difficultyLevel,
    bool clearDifficulty = false,
    DateTime? updatedAt,
  }) {
    return SessionMetadata(
      id: id,
      sessionId: sessionId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      messageCount: messageCount ?? this.messageCount,
      correctionCount: correctionCount ?? this.correctionCount,
      summary: clearSummary ? null : (summary ?? this.summary),
      topicTags: topicTags ?? this.topicTags,
      difficultyLevel: clearDifficulty ? null : (difficultyLevel ?? this.difficultyLevel),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'duration_seconds': durationSeconds,
      'message_count': messageCount,
      'correction_count': correctionCount,
      'summary': summary,
      'topic_tags': topicTags.isEmpty ? null : jsonEncode(topicTags),
      'difficulty_level': difficultyLevel,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SessionMetadata.fromMap(Map<String, dynamic> map) {
    final tagsRaw = map['topic_tags'];
    List<String> parsedTags = const [];
    if (tagsRaw is String && tagsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tagsRaw);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return SessionMetadata(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      messageCount: (map['message_count'] as int?) ?? 0,
      correctionCount: (map['correction_count'] as int?) ?? 0,
      summary: map['summary'] as String?,
      topicTags: parsedTags,
      difficultyLevel: map['difficulty_level'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
