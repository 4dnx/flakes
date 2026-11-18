#!/usr/bin/env bash
# Follow Claude Desktop's macOS release feed (Squirrel.Mac's RELEASES.json,
# what the app's own updater reads). Upstream publishes no checksum for the
# zip; its integrity rests on the bundle's Developer ID seal, which the
# install check and checks.<linux>.claude-desktop-codesign verify.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

feed="$(curl -fsSL https://downloads.claude.ai/releases/darwin/universal/RELEASES.json)"
version="$(jq -er .currentRelease <<<"$feed")"
check_version claude-desktop "$version"
url="$(jq -er --arg v "$version" '[.releases[] | select(.version == $v) | .updateTo.url] | first' <<<"$feed")"
[[ $url =~ ^https://downloads\.claude\.ai/releases/darwin/universal/${version//./\\.}/Claude-[0-9a-f]{40}\.zip$ ]] ||
  { echo "claude-desktop: unexpected download URL '$url'" >&2; exit 1; }
current="$(jq -r '.version // "none"' hashes.json 2>/dev/null || echo none)"
current_url="$(jq -r '.url // "none"' hashes.json 2>/dev/null || echo none)"
if [ "$version" = "$current" ] && [ "$url" = "$current_url" ]; then
  echo "claude-desktop: $version is latest"
  exit 0
fi
hash="$(prefetch "$url")"
jq -n --arg v "$version" --arg u "$url" --arg h "$hash" \
  '{version: $v, url: $u, hashes: {"Claude.zip": $h}}' > hashes.json
echo "claude-desktop: $current -> $version"
