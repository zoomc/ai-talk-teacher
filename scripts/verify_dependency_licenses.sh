#!/usr/bin/env bash
set -euo pipefail

# This is a release gate for the license evidence we can verify in-repository.
# Pub packages publish their authoritative notices with the package metadata;
# the inventory records the remaining legal-owner actions instead of silently
# treating an unreviewed model or CDN asset as cleared.
test -s docs/qa/dependency-license-inventory.md
rg -q '依赖与资产许可证检查|license|License' docs/qa/dependency-license-inventory.md

# The committed npm lockfile must carry license metadata. The full Flutter/pub
# package notice export remains a release-owner action recorded in the inventory
# because pub packages do not expose a uniform license field in pubspec.lock.
test -s e2e/package-lock.json
if ! rg -q '"license"[[:space:]]*:' e2e/package-lock.json; then
  echo 'The E2E npm lockfile has no license metadata.' >&2
  exit 1
fi

# Live2D assets are intentionally not shipped until a model license and notice
# are reviewed. An empty directory is safe; any future file must be accompanied
# by an explicit update to the inventory before release.
if find assets/live2d -type f ! -name '.gitkeep' -print -quit 2>/dev/null | rg -q '.'; then
  echo 'Unreviewed assets/live2d files are not allowed in a release.' >&2
  exit 1
fi

echo 'Dependency and asset license evidence checks passed.'
