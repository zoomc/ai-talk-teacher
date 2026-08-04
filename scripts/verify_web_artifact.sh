#!/usr/bin/env bash
set -euo pipefail

build_dir="${1:?build directory is required}"
expected_base="${2:?expected base href is required}"
expected_mode="${3:?expected mode is required}"
release_sha="${4:?release SHA is required}"

test -s "$build_dir/index.html"
test -s "$build_dir/flutter_bootstrap.js"
test -s "$build_dir/version.json"

actual_base="$(sed -n 's/.*<base href="\([^"]*\)".*/\1/p' "$build_dir/index.html" | head -n 1)"
test "$actual_base" = "$expected_base"
jq -e --arg sha "$release_sha" --arg mode "$expected_mode" \
  '.commit == $sha and .mode == $mode' "$build_dir/version.json" >/dev/null

if [[ "$expected_mode" == production || "$expected_mode" == demo ]]; then
  # Offline-first builds must contain a worker under the same base path. The
  # server must therefore serve each environment's worker from its own root.
  test -s "$build_dir/flutter_service_worker.js"
  if grep -aE -n 'speakflowE2E' "$build_dir/main.dart.js"; then
    echo "E2E bridge leaked into $expected_mode artifact" >&2
    exit 1
  fi
else
  grep -aE -n 'speakflowE2E' "$build_dir/main.dart.js" >/dev/null
fi
