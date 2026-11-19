#!/usr/bin/env bash
# Follow the official stable appcast, including rebuilds of the same version.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../build-support/update-lib.sh
. ../build-support/update-lib.sh

release="$(curl -fsSL 'https://osx.telegram.org/updates/versions.xml' | python3 ../build-support/macos-app-release.py telegram)"
version="$(jq -er .version <<<"$release")"
build="$(jq -er .build <<<"$release")"
url="$(jq -er .url <<<"$release")"
check_version telegram "$version"
check_version telegram "$build" '^[0-9]{1,16}$'
current="$(jq -r '.version // "none"' hashes.json 2>/dev/null || echo none)"
current_build="$(jq -r '.build // "none"' hashes.json 2>/dev/null || echo none)"
if [ "$version" = "$current" ] && [ "$build" = "$current_build" ]; then
  echo "telegram: $version ($build) is latest"
  exit 0
fi
hash="$(prefetch "$url")"
jq -n --arg v "$version" --arg b "$build" --arg u "$url" --arg h "$hash" \
  '{version: $v, build: $b, url: $u, hashes: {"Telegram.app.zip": $h}}' > hashes.json
echo "telegram: $current ($current_build) -> $version ($build)"
