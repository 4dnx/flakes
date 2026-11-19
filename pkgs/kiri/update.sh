#!/usr/bin/env bash
# Follow Kiri's macOS release feed (download.runkiri.com/latest-mac-arm64.json,
# what the app's own updater reads): one JSON file naming the version, the
# app's tar.gz and its SHA-256, which the download is checked against.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../scripts/update-lib.sh
. ../../scripts/update-lib.sh

feed="$(curl -fsSL https://download.runkiri.com/latest-mac-arm64.json)"
version="$(jq -er .version <<<"$feed")"
check_version kiri "$version" '^[0-9]+\.[0-9]+\.[0-9]+$'
url="$(jq -er .url <<<"$feed")"
[ "$url" = "https://download.runkiri.com/Kiri-$version-arm64.tar.gz" ] ||
  { echo "kiri: unexpected download URL '$url'" >&2; exit 1; }
sha256="$(jq -er .sha256 <<<"$feed")"
skip_if_current kiri "$version"
hash="$(prefetch "$url" "$sha256")"
jq -n --arg v "$version" --arg u "$url" --arg h "$hash" \
  '{version: $v, url: $u, hashes: {"Kiri.app.tar.gz": $h}}' > hashes.json
echo "kiri: $current -> $version"
