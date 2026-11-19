#!/usr/bin/env bash
# Bump hashes.json to the latest Firefox release. The version comes from
# Mozilla's product-details (what firefox.com offers); each download is
# checked against the release's SHA256SUMS, whose signature by Mozilla's
# release key (primary key fingerprint below) is checked first. The key file
# comes from the release directory too: gpgv takes only signatures by a
# subkey that the pinned primary key certifies, so the file can't swap the
# key, and Mozilla's rotating signing subkeys need no update here. Downloads
# the dmg (~160 MB) and both Linux tarballs (~80 MB each) on a bump to hash
# them. Needs curl, jq and nix (gnupg comes from the flake's nixpkgs).
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../build-support/update-lib.sh
. ../build-support/update-lib.sh

# Mozilla Software Releases <release@mozilla.com>, as Mozilla's KEY file and
# its docs ("Verifying Firefox downloads") list it.
fingerprint=14F26682D0916CDD81E37B6D61B7B526D98F0353

version="$(curl -fsS https://product-details.mozilla.org/1.0/firefox_versions.json |
  jq -r '.LATEST_FIREFOX_VERSION // empty')"
check_version firefox "$version" '^[0-9]+\.[0-9]+(\.[0-9]+)?$'
skip_if_current firefox "$version"
newest="$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -n1)"
[ "$newest" = "$version" ] || { echo "firefox: $current is newer than $version"; exit 0; }

base="https://archive.mozilla.org/pub/firefox/releases/$version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for f in SHA256SUMS SHA256SUMS.asc KEY; do curl -fsSL "$base/$f" -o "$tmp/$f"; done
gpg() { nix shell --inputs-from ../.. nixpkgs#gnupg --command "$@"; }
gpg gpg --dearmor <"$tmp/KEY" >"$tmp/key.gpg"
# VALIDSIG's last field is the primary key's fingerprint.
gpg gpgv --keyring "$tmp/key.gpg" --status-fd 1 "$tmp/SHA256SUMS.asc" "$tmp/SHA256SUMS" 2>/dev/null |
  awk -v f="$fingerprint" '$2 == "VALIDSIG" && $NF == f { ok = 1 } END { exit !ok }' ||
  { echo "firefox: $version's SHA256SUMS isn't signed by $fingerprint" >&2; exit 1; }

# hash PATH: the download at PATH (relative to $base, as SHA256SUMS names
# it), checked against SHA256SUMS.
hash() {
  local want
  want="$(awk -v p="$1" 'substr($0, 67) == p { print $1; exit }' "$tmp/SHA256SUMS")"
  [[ $want =~ ^[0-9a-f]{64}$ ]] || { echo "firefox: SHA256SUMS lists no $1" >&2; exit 1; }
  prefetch "$base/${1// /%20}" "$want"
}
# Each in its own assignment, so a failed check stops the script.
darwin="$(hash "mac/en-US/Firefox $version.dmg")"
aarch64="$(hash "linux-aarch64/en-US/firefox-$version.tar.xz")"
x86_64="$(hash "linux-x86_64/en-US/firefox-$version.tar.xz")"
jq -n --arg v "$version" --arg d "$darwin" --arg a "$aarch64" --arg x "$x86_64" \
  '{version: $v, hashes: {"aarch64-darwin": $d, "aarch64-linux": $a, "x86_64-linux": $x}}' > hashes.json
echo "firefox: $current -> $version"
