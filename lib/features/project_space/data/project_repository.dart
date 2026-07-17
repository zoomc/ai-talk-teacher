import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../domain/project_models.dart';

class ProjectRepository {
  ProjectRepository();
  factory ProjectRepository.forTesting() = ProjectRepository;

  /// Test helper: drops the three tables and recreates them. Used in
  /// setUp of repository tests so each test starts from a clean slate.
  /// Only call from tests — uses DROP TABLE, which is destructive.
  Future<void> resetForTesting() async {
    final db = await DatabaseHelper.database;
    await db.execute('DROP TABLE IF EXISTS project_activities');
    await db.execute('DROP TABLE IF EXISTS project_links');
    await db.execute('DROP TABLE IF EXISTS projects');
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'star',
        color TEXT NOT NULL DEFAULT '#6C5CE7',
        description TEXT NOT NULL DEFAULT '',
        goal TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'active',
        topics TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_activity_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE project_links (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        content_type TEXT NOT NULL,
        content_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE project_activities (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        type TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id)
      )
    ''');
  }

  // ========== Projects ==========

  Future<List<Project>> getAllProjects({ProjectStatus? status}) async {
    final db = await DatabaseHelper.database;
    final maps = status == null
        ? await db.query('projects', orderBy: 'updated_at DESC')
        : await db.query(
            'projects',
            where: 'status = ?',
            whereArgs: [status.name],
            orderBy: 'updated_at DESC',
          );
    return maps.map(Project.fromMap).toList();
  }

  Future<Project?> getProject(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  Future<Project> createProject({
    required String name,
    required String icon,
    required String color,
    String description = '',
    String goal = '',
    List<String> topics = const [],
    ProjectStatus status = ProjectStatus.active,
  }) async {
    final now = DateTime.now();
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      color: color,
      description: description,
      goal: goal,
      status: status,
      topics: topics,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    );
    final db = await DatabaseHelper.database;
    await db.insert('projects', project.toMap());
    await _recordActivity(
      project.id,
      ProjectActivityType.projectCreated,
      {'name': name},
    );
    return project;
  }

  Future<void> updateProject(Project project) async {
    final updated = project.copyWith(updatedAt: DateTime.now());
    final db = await DatabaseHelper.database;
    await db.update(
      'projects',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
    await _recordActivity(
      project.id,
      ProjectActivityType.projectEdited,
      {'name': updated.name},
    );
  }

  Future<void> deleteProject(String id) async {
    final db = await DatabaseHelper.database;
    // sqflite ships with FK enforcement off; delete children explicitly
    // (mirrors ChatRepository.deleteSession).
    await db.delete('project_activities', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('project_links', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Links ==========

  Future<ProjectLink?> addLink(
    String projectId,
    ProjectContentType contentType,
    String contentId,
  ) async {
    final db = await DatabaseHelper.database;
    // Idempotent: if the same (project, type, content) link already exists,
    // return it without creating a duplicate or recording a new activity.
    final existing = await db.query(
      'project_links',
      where: 'project_id = ? AND content_type = ? AND content_id = ?',
      whereArgs: [projectId, contentType.toStorage, contentId],
      limit: 1,
    );
    if (existing.isNotEmpty) return ProjectLink.fromMap(existing.first);
    final link = ProjectLink(
      id: const Uuid().v4(),
      projectId: projectId,
      contentType: contentType,
      contentId: contentId,
      createdAt: DateTime.now(),
    );
    await db.insert('project_links', link.toMap());
    await db.update(
      'projects',
      {'last_activity_at': link.createdAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [projectId],
    );
    await _recordActivity(
      projectId,
      ProjectActivityType.linkAdded,
      {'content_type': contentType.toStorage, 'content_id': contentId},
    );
    return link;
  }

  Future<void> removeLink(String linkId) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query(
      'project_links',
      where: 'id = ?',
      whereArgs: [linkId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final link = ProjectLink.fromMap(rows.first);
    await db.delete('project_links', where: 'id = ?', whereArgs: [linkId]);
    await _recordActivity(
      link.projectId,
      ProjectActivityType.linkRemoved,
      {'content_type': link.contentType.toStorage, 'content_id': link.contentId},
    );
  }

  Future<List<ProjectLink>> getLinksForProject(String projectId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'project_links',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return maps.map(ProjectLink.fromMap).toList();
  }

  /// Returns every project that links to (contentType, contentId), for the
  /// "already in N projects" indicator on detail screens.
  Future<List<Project>> getProjectsForContent(
    ProjectContentType contentType,
    String contentId,
  ) async {
    final db = await DatabaseHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT p.* FROM projects p
      INNER JOIN project_links l ON l.project_id = p.id
      WHERE l.content_type = ? AND l.content_id = ?
      ORDER BY p.updated_at DESC
      ''',
      [contentType.toStorage, contentId],
    );
    return maps.map(Project.fromMap).toList();
  }

  // ========== Activities ==========

  Future<List<ProjectActivity>> getActivitiesForProject(
    String projectId, {
    int limit = 100,
  }) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'project_activities',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map(ProjectActivity.fromMap).toList();
  }

  Future<void> _recordActivity(
    String projectId,
    ProjectActivityType type,
    Map<String, dynamic> payload,
  ) async {
    final a = ProjectActivity(
      id: const Uuid().v4(),
      projectId: projectId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    final db = await DatabaseHelper.database;
    await db.insert('project_activities', a.toMap());
  }
}
