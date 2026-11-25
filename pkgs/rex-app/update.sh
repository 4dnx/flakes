#!/usr/bin/env bash
# Bump hashes.json to the newest Rex for Mac build on upstream's preview
# appcast, the feed the app itself reads. Checks the dmg against the Sparkle
# EdDSA signature the feed lists, by the key pinned in sparkle-ed25519.pub
# (the app's SUPublicEDKey), as Sparkle does before it installs an update.
# Downloads the dmg (~75 MB) on a bump. Needs curl, jq, python3 and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../scripts/update-lib.sh
. ../../scripts/update-lib.sh

feed=https://blob.superlogical.com/public/rex-app/preview/appcast.xml
release="$(curl -fsSL --proto '=https' "$feed" | python3 ../../scripts/macos-app-release.py rex-app)"
bundle_version="$(jq -er .version <<<"$release")"
build="$(jq -er .build <<<"$release")"
url="$(jq -er .url <<<"$release")"
check_version rex-app "$bundle_version" '^[0-9]+\.[0-9]+\.[0-9]+$'
check_version rex-app "$build" '^[0-9]{1,16}$'
# Every build so far is 0.1.0, so the build tells releases apart.
version="$bundle_version-$build"
skip_if_current rex-app "$version"

hash="$(prefetch "$url")"
sparkle_verify rex-app "$url" "$hash" "$(<sparkle-ed25519.pub)" "$(jq -r .edSignature <<<"$release")"

jq -n --arg v "$version" --arg bv "$bundle_version" --arg b "$build" --arg u "$url" --arg h "$hash" \
  '{version: $v, bundleVersion: $bv, build: $b, url: $u, hashes: {"Rex.dmg": $h}}' > hashes.json
echo "rex-app: $current -> $version"
