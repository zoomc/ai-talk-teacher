#!/usr/bin/env bash
# Build, publish and prove a Flutter Web release served at /talk/.
set -euo pipefail

host="${SPEAKFLOW_DEPLOY_HOST:-zoomlab}"
target="${SPEAKFLOW_DEPLOY_TARGET:-/opt/ai-talk-teacher}"
url="${SPEAKFLOW_PUBLIC_URL:-https://zoomlab.top/talk}"
wait_seconds="${SPEAKFLOW_VERIFY_WAIT_SECONDS:-300}"
version="$(sed -n "s/^version: \(.*\)$/\1/p" pubspec.yaml)"

require() { [[ "$1" == "$2" ]] || { echo "release marker mismatch: $3" >&2; exit 1; }; }
require "$version" "$(jq -r .version web/version.json)" "web/version.json"
grep -Fq "flutter_bootstrap.js?v=$version" web/index.html || { echo "index release URL missing" >&2; exit 1; }
grep -Fq "defaultValue: '$version'" lib/core/services/version_service.dart || { echo "Dart version missing" >&2; exit 1; }

flutter test
flutter build web --release --base-href /talk/
# Flutter emits a stable main.dart.js filename. Version its request URL so a
# CDN can never choose an old object for a new application release.
perl -0pi -e "s/\"mainJsPath\":\"main\\.dart\\.js\"/\"mainJsPath\":\"main.dart.js?v=$version\"/" build/web/flutter_bootstrap.js
grep -Fq "main.dart.js?v=$version" build/web/flutter_bootstrap.js

git push origin main
release_dir="/home/admin/ai-talk-teacher.release"
rsync -az --delete build/web/ "$host:$release_dir/"
ssh -o BatchMode=yes "$host" "set -e; sudo -n rm -rf '$target.previous'; sudo -n mv '$target' '$target.previous'; sudo -n mv '$release_dir' '$target'; sudo -n chown -R admin:admin '$target'"

# Verify each public hop immediately. Query strings deliberately select the
# exact release object even while a CDN expires old stable-name cache entries.
curl -fsS "$url/?release=$version" | grep -Fq "flutter_bootstrap.js?v=$version"
curl -fsS "$url/flutter_bootstrap.js?v=$version" | grep -Fq "main.dart.js?v=$version"
local_hash="$(sha256sum build/web/main.dart.js | awk '{print $1}')"
public_hash="$(curl -fsS "$url/main.dart.js?v=$version" | sha256sum | awk '{print $1}')"
require "$local_hash" "$public_hash" "public main.dart.js"
curl -fsSI "$url/main.dart.js?v=$version" | grep -qi '^cache-control:.*no-cache'

echo "Published $version. Waiting $wait_seconds seconds for edge propagation."
sleep "$wait_seconds"
curl -fsS "$url/version.json?release=$version" | jq -e --arg v "$version" '.version == $v' >/dev/null
echo "Release $version verified at $url"
