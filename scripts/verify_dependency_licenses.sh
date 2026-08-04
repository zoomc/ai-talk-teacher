#!/usr/bin/env bash
set -euo pipefail

# This is a release gate for the license evidence we can verify in-repository.
# Pub packages publish their authoritative notices with the package metadata;
# the inventory records the remaining legal-owner actions instead of silently
# treating an unreviewed model or CDN asset as cleared.
test -s docs/qa/dependency-license-inventory.md

# The committed lockfile and inventory must exist. The full Flutter/pub package
# notice export remains a release-owner action recorded in the inventory because
# pub packages do not expose a uniform license field in pubspec.lock.
test -s e2e/package-lock.json
# Live2D assets are intentionally not shipped until a model license and notice
# are reviewed. The inventory is the release-owner evidence record for this
# path; the empty placeholder is retained so Flutter asset resolution remains
# stable across builds.
test -d assets/live2d

echo 'Dependency and asset license evidence checks passed.'
