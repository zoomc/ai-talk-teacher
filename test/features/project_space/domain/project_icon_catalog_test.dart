import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/project_space/domain/project_icon_catalog.dart';

void main() {
  test('forName returns the registered IconData for known names', () {
    expect(ProjectIconCatalog.forName('school'), Icons.school);
    expect(ProjectIconCatalog.forName('star'), Icons.star);
  });

  test('forName falls back to Icons.star for unknown names', () {
    expect(ProjectIconCatalog.forName('does_not_exist'), Icons.star);
  });

  test('allNames contains every registered name', () {
    for (final name in ProjectIconCatalog.allNames) {
      expect(ProjectIconCatalog.forName(name), isA<IconData>());
    }
    expect(ProjectIconCatalog.allNames.length,
        greaterThanOrEqualTo(ProjectIconCatalog.minCount));
  });

  test('defaultName is a registered name', () {
    expect(ProjectIconCatalog.allNames, contains(ProjectIconCatalog.defaultName));
  });
}
