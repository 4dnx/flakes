#!/usr/bin/env bash
# Bump hashes.json to Claude Code's `latest` channel. Each release's manifest
# lists the sha256 of every platform's binary and is signed with upstream's
# release key (release-key.asc, fingerprint below), so the signature is
# checked first and each download against the manifest. Needs curl, jq and
# nix (gnupg comes from the flake's nixpkgs).
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../scripts/update-lib.sh
. ../../scripts/update-lib.sh

base=https://downloads.claude.ai/claude-code-releases
# Anthropic Claude Code Release Signing <security@anthropic.com>, as
# code.claude.com/docs/en/setup lists it.
fingerprint=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE

version="$(curl -fsSL "$base/latest")"
check_version claude-code "$version" '^[0-9]+\.[0-9]+\.[0-9]+$'
skip_if_current claude-code "$version"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$version/manifest.zst.json" -o "$tmp/manifest.json"
curl -fsSL "$base/$version/manifest.zst.json.sig" -o "$tmp/manifest.json.sig"
gpg() { nix shell --inputs-from ../.. nixpkgs#gnupg --command "$@"; }
gpg gpg --dearmor <release-key.asc >"$tmp/key.gpg"
# VALIDSIG's last field is the primary key's fingerprint.
gpg gpgv --keyring "$tmp/key.gpg" --status-fd 1 "$tmp/manifest.json.sig" "$tmp/manifest.json" 2>/dev/null |
  awk -v f="$fingerprint" '$2 == "VALIDSIG" && $NF == f { ok = 1 } END { exit !ok }' ||
  { echo "claude-code: $version's manifest isn't signed by $fingerprint" >&2; exit 1; }
[ "$(jq -er .version "$tmp/manifest.json")" = "$version" ] ||
  { echo "claude-code: manifest is for another version" >&2; exit 1; }

hash() {
  local entry
  entry="$(jq -ec --arg p "$1" '.platforms[$p] | select(.binary == "claude.zst")' "$tmp/manifest.json")"
  prefetch "$base/$version/$1/claude.zst" "$(jq -er .checksum <<<"$entry")"
}
jq -n --arg v "$version" \
  --arg d "$(hash darwin-arm64)" \
  --arg l "$(hash linux-x64)" \
  --arg a "$(hash linux-arm64)" \
  '{version: $v, hashes: {"aarch64-darwin": $d, "x86_64-linux": $l, "aarch64-linux": $a}}' > hashes.json
echo "claude-code: $current -> $version"
