#!/usr/bin/env bash
set -euo pipefail

build_dir="${1:?build directory is required}"
release_sha="${2:?release SHA is required}"
app_mode="${3:?APP_MODE is required}"
version_file="$build_dir/version.json"

test -s "$version_file"
tmp_file="$version_file.tmp"
jq --arg sha "$release_sha" \
  --arg mode "$app_mode" \
  --arg build_time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  '.commit = $sha | .mode = $mode | .buildTime = $build_time' \
  "$version_file" > "$tmp_file"
mv "$tmp_file" "$version_file"
