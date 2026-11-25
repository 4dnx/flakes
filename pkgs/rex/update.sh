#!/usr/bin/env bash
# Bump hashes.json to the Rex release that upstream's install script picks:
# the newest on the stable channel, or on preview while stable has none. The
# release API lists each archive's sha256, and each download is checked
# against it. Needs curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../scripts/update-lib.sh
. ../../scripts/update-lib.sh

api=https://blob.superlogical.com/api/releases/rex
# The API answers 404 for a channel without a release, which is no error
# here: stable has none yet.
for channel in stable preview; do
  release="$(curl -fsL --proto '=https' "$api/$channel")" && break
  release=""
done
[ -n "$release" ] || { echo "rex: no stable or preview release at $api" >&2; exit 1; }

version="$(jq -er .version <<<"$release")"
# 1.2.0 on stable, 0.1.0-preview.23 on preview.
check_version rex "$version" '^[0-9]+\.[0-9]+\.[0-9]+(-preview\.[0-9]+)?$'
skip_if_current rex "$version"
commit="$(jq -er .commit <<<"$release")"
[[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo "rex: unexpected commit '$commit'" >&2; exit 1; }

# The macOS archive holds only the rex binary, for Apple Silicon.
artifact="$(jq -ec '.artifacts[] | select(.os == "darwin" and .arch == "arm64" and .filename == "rex-darwin-arm64.zip")' <<<"$release")"
url="https://blob.superlogical.com/download/rex/$channel/$commit/rex-darwin-arm64.zip"
[ "$(jq -er .downloadUrl <<<"$artifact")" = "$url" ] ||
  { echo "rex: the release API lists another download URL than $url" >&2; exit 1; }
hash="$(prefetch "$url" "$(jq -er .sha256 <<<"$artifact")")"

jq -n --arg v "$version" --arg c "$channel" --arg r "$commit" --arg h "$hash" \
  '{version: $v, channel: $c, commit: $r, hashes: {"aarch64-darwin": $h}}' > hashes.json
echo "rex: $current -> $version"
