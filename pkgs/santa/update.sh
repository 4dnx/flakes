#!/usr/bin/env bash
# Bump hashes.json to Santa's latest release on GitHub: its installer
# package, checked against GitHub's digest (prefetch), and the bundle build
# its Distribution lists. Downloads the package (~55 MB) on a bump. Needs gh,
# jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../helpers/update-lib.sh
. ../../helpers/update-lib.sh

# Calendar versions without a "v": 2026.9.
version="$(gh_latest santa northpolesec/santa '^[0-9]{4}\.[0-9]+$')"
skip_if_current santa "$version"

url="https://github.com/northpolesec/santa/releases/download/$version/santa-$version.pkg"
hash="$(prefetch "$url")"
pkg="$(nix store prefetch-file --json --name "santa-$version.pkg" --expected-hash "$hash" "$url" | jq -er .storePath)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && nix shell --inputs-from "$(realpath "$OLDPWD/../..")" nixpkgs#xar --command xar -xf "$pkg" Distribution)
build="$(grep -oE 'id="com\.northpolesec\.santa" version="[0-9.]+"' "$tmp/Distribution" | head -n1 | grep -oE '[0-9.]+"$' | tr -d '"')"
check_version santa "$build" '^[0-9]{4}(\.[0-9]+){2}$'
[[ $build == "$version".* ]] || { echo "santa: package build $build isn't $version" >&2; exit 1; }

jq -n --arg v "$version" --arg b "$build" --arg h "$hash" \
  '{version: $v, build: $b, hashes: {"aarch64-darwin": $h}}' > hashes.json
echo "santa: $current -> $version"
