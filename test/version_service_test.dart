import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/core/services/version_service.dart';

void main() {
  group('compareVersions', () {
    test('equal versions return 0', () {
      expect(compareVersions('1.0.0+1', '1.0.0+1'), 0);
      expect(compareVersions('2.5.3', '2.5.3'), 0);
    });

    test('major version dominates', () {
      expect(compareVersions('2.0.0', '1.9.9') > 0, true);
      expect(compareVersions('1.0.0', '2.0.0') < 0, true);
    });

    test('minor version compared when major equal', () {
      expect(compareVersions('1.2.0', '1.1.9') > 0, true);
      expect(compareVersions('1.0.5', '1.1.0') < 0, true);
    });

    test('patch version compared when major+minor equal', () {
      expect(compareVersions('1.0.2', '1.0.1') > 0, true);
      expect(compareVersions('1.0.0', '1.0.5') < 0, true);
    });

    test('build metadata tiebreaker', () {
      // Same semver, different build → higher build wins.
      expect(compareVersions('1.0.0+2', '1.0.0+1') > 0, true);
      expect(compareVersions('1.0.0+1', '1.0.0+2') < 0, true);
      // Missing build is treated as 0.
      expect(compareVersions('1.0.0+1', '1.0.0') > 0, true);
      expect(compareVersions('1.0.0', '1.0.0+1') < 0, true);
    });

    test('semver takes precedence over build', () {
      // 1.0.1+0 > 1.0.0+99 — patch wins over build.
      expect(compareVersions('1.0.1', '1.0.0+99') > 0, true);
      expect(compareVersions('1.0.0+99', '1.0.1') < 0, true);
    });

    test('handles missing patch segment', () {
      // Some servers ship "1.2" without a patch.
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2') > 0, true);
    });

    test('handles non-numeric segments gracefully', () {
      // int.tryParse falls back to 0 for non-numeric segments.
      expect(compareVersions('a.b.c', '0.0.0'), 0);
      expect(compareVersions('1.x.0', '1.0.0'), 0);
    });

    test('real-world ordering sample', () {
      // Simulates a deploy cycle: 1.0.0+1 → 1.0.1+1 → 1.0.1+2 (hotfix).
      expect(compareVersions('1.0.1+1', '1.0.0+1') > 0, true);
      expect(compareVersions('1.0.1+2', '1.0.1+1') > 0, true);
      expect(compareVersions('1.0.1+1', '1.0.1+2') < 0, true);
    });
  });

  group('VersionState', () {
    test('copyWith preserves currentVersion', () {
      final s = VersionState(currentVersion: '1.0.0+1');
      final s2 = s.copyWith(serverVersion: '1.0.1+1');
      expect(s2.currentVersion, '1.0.0+1');
      expect(s2.serverVersion, '1.0.1+1');
    });

    test('copyWith preserves unspecified fields', () {
      final s = VersionState(
        currentVersion: '1.0.0+1',
        serverVersion: '1.0.1+1',
        serverCommit: 'abc123',
        newVersionAvailable: true,
        swUpdateWaiting: true,
      );
      final s2 = s.copyWith(isChecking: true);
      expect(s2.serverVersion, '1.0.1+1');
      expect(s2.serverCommit, 'abc123');
      expect(s2.newVersionAvailable, true);
      expect(s2.swUpdateWaiting, true);
      expect(s2.isChecking, true);
    });

    test('copyWith cannot clear nullable fields via copyWith (by design)', () {
      // copyWith doesn't accept null for nullable fields — clearing is
      // done by direct construction. This is intentional: callers either
      // set a value or keep the existing one. The 404 path uses direct
      // construction (see VersionService.checkNow) for clearing.
      final s = VersionState(
        currentVersion: '1.0.0+1',
        serverVersion: '1.0.1+1',
      );
      final s2 = s.copyWith(serverVersion: '1.0.2+1');
      expect(s2.serverVersion, '1.0.2+1');
    });

    test('defaults are sane', () {
      final s = VersionState(currentVersion: '1.0.0+1');
      expect(s.serverVersion, isNull);
      expect(s.serverBuildTime, isNull);
      expect(s.serverCommit, isNull);
      expect(s.newVersionAvailable, false);
      expect(s.swUpdateWaiting, false);
      expect(s.isChecking, false);
    });
  });

  group('kAppVersion', () {
    test('matches expected default format', () {
      // Default comes from String.fromEnvironment; without --dart-define
      // we get the defaultValue '1.0.3+4'.
      expect(kAppVersion, '1.0.4+5');
    });
  });
}
