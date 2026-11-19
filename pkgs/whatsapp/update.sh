#!/usr/bin/env bash
# Follow the official stable appcast, including rebuilds of the same version.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../helpers/update-lib.sh
. ../../helpers/update-lib.sh

release="$(curl -fsSL 'https://web.whatsapp.com/desktop/mac_native/updates/?branch=master&configuration=Release' | python3 ../../helpers/macos-app-release.py whatsapp)"
version="$(jq -er .version <<<"$release")"
build="$(jq -er .build <<<"$release")"
url="$(jq -er .url <<<"$release")"
check_version whatsapp "$version"
check_version whatsapp "$build" '^[0-9]{1,16}$'
current="$(jq -r '.version // "none"' hashes.json 2>/dev/null || echo none)"
current_build="$(jq -r '.build // "none"' hashes.json 2>/dev/null || echo none)"
if [ "$version" = "$current" ] && [ "$build" = "$current_build" ]; then
  echo "whatsapp: $version ($build) is latest"
  exit 0
fi
hash="$(prefetch "$url")"
jq -n --arg v "$version" --arg b "$build" --arg u "$url" --arg h "$hash" \
  '{version: $v, build: $b, url: $u, hashes: {"WhatsApp.app.zip": $h}}' > hashes.json
echo "whatsapp: $current ($current_build) -> $version ($build)"
