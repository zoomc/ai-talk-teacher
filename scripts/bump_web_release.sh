#!/usr/bin/env bash
# Prepare every source-controlled version marker for a Flutter-web release.
set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  echo "Usage: $0 MAJOR.MINOR.PATCH+BUILD" >&2
  exit 2
fi

perl -0pi -e "s/^version: .*/version: $version/m" pubspec.yaml
perl -0pi -e "s/defaultValue: '[^']+'/defaultValue: '$version'/" \
  lib/core/services/version_service.dart
perl -0pi -e "s/version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+/version: $version/" \
  lib/core/services/version_service.dart
perl -0pi -e "s/expect\(kAppVersion, '[^']+'\)/expect(kAppVersion, '$version')/" \
  test/version_service_test.dart
perl -0pi -e "s/\"version\": \"[^\"]+\"/\"version\": \"$version\"/" \
  web/version.json
perl -0pi -e "s/\?v=[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+/?v=$version/g" web/index.html

echo "Prepared web release $version. Update CHANGELOG.md, test, commit, then run scripts/deploy_web.sh."
