#!/usr/bin/env bash
set -euo pipefail

# This is a release gate for the license evidence we can verify in-repository.
# Pub packages publish their authoritative notices with the package metadata;
# the inventory records the remaining legal-owner actions instead of silently
# treating an unreviewed model or CDN asset as cleared.
test -s docs/qa/dependency-license-inventory.md
rg -q '依赖与资产许可证检查|license|License' docs/qa/dependency-license-inventory.md

# The committed lockfile and inventory must exist. The full Flutter/pub package
# notice export remains a release-owner action recorded in the inventory because
# pub packages do not expose a uniform license field in pubspec.lock.
test -s e2e/package-lock.json
test -s docs/qa/dependency-license-inventory.md

# Live2D assets are intentionally not shipped until a model license and notice
# are reviewed. An empty directory is safe; any future file must be accompanied
# by an explicit update to the inventory before release.
live2d_files="$(git ls-files assets/live2d | sed '/\/\.gitkeep$/d')"
if [ -n "$live2d_files" ]; then
  echo 'Unreviewed assets/live2d files are not allowed in a release.' >&2
  exit 1
fi

echo 'Dependency and asset license evidence checks passed.'
