import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/project_space/domain/project_models.dart';

void main() {
  group('Project', () {
    test('toMap/fromMap round-trips all fields', () {
      final now = DateTime.parse('2026-07-16T00:00:00.000Z');
      final p = Project(
        id: 'p1',
        name: 'IELTS Speaking',
        icon: 'school',
        color: '#6C5CE7',
        description: 'Daily speaking drills',
        goal: 'Band 7 by October',
        status: ProjectStatus.active,
        topics: const ['ielts', 'speaking'],
        createdAt: now,
        updatedAt: now,
        lastActivityAt: now,
      );
      final map = p.toMap();
      expect(map['id'], 'p1');
      expect(map['status'], 'active');
      expect(map['topics'], '["ielts","speaking"]');
      final back = Project.fromMap(map);
      expect(back.name, 'IELTS Speaking');
      expect(back.status, ProjectStatus.active);
      expect(back.topics, ['ielts', 'speaking']);
      expect(back.color, '#6C5CE7');
    });

    test('fromMap tolerates null optional fields', () {
      final back = Project.fromMap({
        'id': 'p2',
        'name': 'Empty',
        'icon': 'star',
        'color': '#00D2FF',
        'description': null,
        'goal': null,
        'status': 'active',
        'topics': null,
        'created_at': '2026-07-16T00:00:00.000Z',
        'updated_at': '2026-07-16T00:00:00.000Z',
        'last_activity_at': null,
      });
      expect(back.description, isEmpty);
      expect(back.goal, isEmpty);
      expect(back.topics, isEmpty);
      expect(back.lastActivityAt, isNull);
    });

    test('copyWith updates only the specified fields', () {
      final p = Project(
        id: 'p',
        name: 'n',
        icon: 'i',
        color: '#000000',
        description: '',
        goal: '',
        status: ProjectStatus.active,
        topics: const [],
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        lastActivityAt: null,
      );
      final updated = p.copyWith(status: ProjectStatus.archived, name: 'new');
      expect(updated.status, ProjectStatus.archived);
      expect(updated.name, 'new');
      expect(updated.icon, 'i'); // unchanged
    });
  });

  group('ProjectLink', () {
    test('round-trips through toMap/fromMap', () {
      final link = ProjectLink(
        id: 'l1',
        projectId: 'p1',
        contentType: ProjectContentType.chatSession,
        contentId: 'sess-123',
        createdAt: DateTime.parse('2026-07-16T00:00:00.000Z'),
      );
      final map = link.toMap();
      expect(map['content_type'], 'chat_session');
      final back = ProjectLink.fromMap(map);
      expect(back.contentType, ProjectContentType.chatSession);
      expect(back.contentId, 'sess-123');
    });
  });

  group('ProjectActivity', () {
    test('serialises payload as JSON', () {
      final a = ProjectActivity(
        id: 'a1',
        projectId: 'p1',
        type: ProjectActivityType.linkAdded,
        payload: const {'content_type': 'chat_session', 'title': 'Session 42'},
        createdAt: DateTime.parse('2026-07-16T00:00:00.000Z'),
      );
      final map = a.toMap();
      expect(map['type'], 'link_added');
      expect(map['payload'], isA<String>());
      final back = ProjectActivity.fromMap(map);
      expect(back.payload['title'], 'Session 42');
    });
  });
}
