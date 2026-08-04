#!/usr/bin/env bash
set -euo pipefail

# This is a release gate for the license evidence we can verify in-repository.
# Pub packages publish their authoritative notices with the package metadata;
# the inventory records the remaining legal-owner actions instead of silently
# treating an unreviewed model or CDN asset as cleared.
test -s docs/qa/dependency-license-inventory.md
rg -q '依赖与资产许可证检查|license|License' docs/qa/dependency-license-inventory.md

# npm lockfile v3 carries license metadata for every resolved E2E package.
test -s e2e/package-lock.json
missing_npm_license="$(jq -r '[.packages | to_entries[] | select(.key != "") | select(.value.license == null) | .key] | .[]' e2e/package-lock.json)"
if [ -n "$missing_npm_license" ]; then
  echo "Resolved npm packages missing license metadata:" >&2
  echo "$missing_npm_license" >&2
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
