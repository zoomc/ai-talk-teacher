import 'dart:convert';

/// Lifecycle state of a project. Stored as TEXT in SQLite; parsed via [name].
enum ProjectStatus {
  active,
  archived,
  completed,
}

/// Which kind of SpeakFlow entity a [ProjectLink] points at. Mirrors the
/// existing features that ship today: chat sessions, scenarios, and the
/// corrections surfaced on the review screen. Add new values here when
/// Notes / Favorites / Lab / Paper / News features land.
enum ProjectContentType {
  chatSession,
  scenario,
  correction,
}

/// Event types appended to the project activity timeline.
enum ProjectActivityType {
  projectCreated,
  projectEdited,
  statusChanged,
  linkAdded,
  linkRemoved,
}

class Project {
  final String id;
  final String name;
  final String icon; // name in ProjectIconCatalog
  final String color; // hex string, e.g. '#6C5CE7'
  final String description;
  final String goal;
  final ProjectStatus status;
  final List<String> topics;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActivityAt;

  const Project({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.goal,
    required this.status,
    required this.topics,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
  });

  factory Project.fromMap(Map<String, dynamic> m) => Project(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? 'star',
        color: (m['color'] as String?) ?? '#6C5CE7',
        description: (m['description'] as String?) ?? '',
        goal: (m['goal'] as String?) ?? '',
        status: ProjectStatus.values.byName(
          (m['status'] as String?) ?? 'active',
        ),
        topics: m['topics'] == null
            ? const []
            : List<String>.from(jsonDecode(m['topics'] as String) as List),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        lastActivityAt: m['last_activity_at'] == null
            ? null
            : DateTime.parse(m['last_activity_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'description': description,
        'goal': goal,
        'status': status.name,
        'topics': jsonEncode(topics),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_activity_at': lastActivityAt?.toIso8601String(),
      };

  Project copyWith({
    String? name,
    String? icon,
    String? color,
    String? description,
    String? goal,
    ProjectStatus? status,
    List<String>? topics,
    DateTime? updatedAt,
    DateTime? lastActivityAt,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        description: description ?? this.description,
        goal: goal ?? this.goal,
        status: status ?? this.status,
        topics: topics ?? this.topics,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );
}

class ProjectLink {
  final String id;
  final String projectId;
  final ProjectContentType contentType;
  final String contentId;
  final DateTime createdAt;

  const ProjectLink({
    required this.id,
    required this.projectId,
    required this.contentType,
    required this.contentId,
    required this.createdAt,
  });

  factory ProjectLink.fromMap(Map<String, dynamic> m) => ProjectLink(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        contentType: ProjectContentType.values.byName(
          (m['content_type'] as String? ?? 'chat_session')
              .replaceAll('-', '_'),
        ),
        contentId: m['content_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'content_type': contentType.name,
        'content_id': contentId,
        'created_at': createdAt.toIso8601String(),
      };
}

class ProjectActivity {
  final String id;
  final String projectId;
  final ProjectActivityType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const ProjectActivity({
    required this.id,
    required this.projectId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  factory ProjectActivity.fromMap(Map<String, dynamic> m) => ProjectActivity(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        type: ProjectActivityType.values.byName(
          (m['type'] as String? ?? 'project_created')
              .replaceAll('-', '_'),
        ),
        payload: m['payload'] == null || (m['payload'] as String).isEmpty
            ? const {}
            : Map<String, dynamic>.from(
                jsonDecode(m['payload'] as String) as Map),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'type': type.name,
        'payload': jsonEncode(payload),
        'created_at': createdAt.toIso8601String(),
      };
}
