import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:speakflow/features/project_space/data/project_repository.dart';
import 'package:speakflow/features/project_space/domain/project_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('createProject persists and returns the project', () async {
    final repo = ProjectRepository.forTesting();
    await repo.resetForTesting();
    final p = await repo.createProject(
      name: 'IELTS',
      icon: 'school',
      color: '#6C5CE7',
      description: 'drills',
      goal: 'band 7',
      topics: const ['ielts'],
    );
    expect(p.id, isNotEmpty);
    expect(p.status, ProjectStatus.active);
    final all = await repo.getAllProjects();
    expect(all.length, 1);
    expect(all.first.id, p.id);
  });

  test('updateProject changes editable fields', () async {
    final repo = ProjectRepository.forTesting();
    await repo.resetForTesting();
    final p = await repo.createProject(name: 'n', icon: 'star', color: '#000000');
    await repo.updateProject(p.copyWith(name: 'renamed', color: '#00D2FF'));
    final fetched = await repo.getProject(p.id);
    expect(fetched!.name, 'renamed');
    expect(fetched.color, '#00D2FF');
  });

  test('deleteProject cascades to links and activities', () async {
    final repo = ProjectRepository.forTesting();
    await repo.resetForTesting();
    final p = await repo.createProject(name: 'n', icon: 'star', color: '#000000');
    await repo.addLink(p.id, ProjectContentType.chatSession, 'sess-1');
    await repo.deleteProject(p.id);
    expect(await repo.getProject(p.id), isNull);
    expect(await repo.getLinksForProject(p.id), isEmpty);
    expect(await repo.getActivitiesForProject(p.id), isEmpty);
  });

  test('addLink is idempotent for the same project+type+content_id', () async {
    final repo = ProjectRepository.forTesting();
    await repo.resetForTesting();
    final p = await repo.createProject(name: 'n', icon: 'star', color: '#000000');
    await repo.addLink(p.id, ProjectContentType.chatSession, 'sess-1');
    await repo.addLink(p.id, ProjectContentType.chatSession, 'sess-1');
    final links = await repo.getLinksForProject(p.id);
    expect(links.length, 1);
  });

  test('addLink records a link_added activity', () async {
    final repo = ProjectRepository.forTesting();
    await repo.resetForTesting();
    final p = await repo.createProject(name: 'n', icon: 'star', color: '#000000');
    await repo.addLink(p.id, ProjectContentType.scenario, 'restaurant');
    final acts = await repo.getActivitiesForProject(p.id);
    // created_project activity is also recorded, so >= 1 link_added.
    final linkAdded = acts.where(
      (a) => a.type == ProjectActivityType.linkAdded,
    );
    expect(linkAdded.length, 1);
    expect(linkAdded.first.payload['content_type'], 'scenario');
  });

  test('getAllProjects supports status filter', () async {
    final repo = ProjectRepository.forTesting();
    await repo.resetForTesting();
    final a = await repo.createProject(name: 'a', icon: 'star', color: '#000000');
    final b = await repo.createProject(name: 'b', icon: 'star', color: '#000000');
    await repo.updateProject(b.copyWith(status: ProjectStatus.archived));
    final active = await repo.getAllProjects(status: ProjectStatus.active);
    expect(active.map((p) => p.id).toSet(), {a.id});
  });
}
