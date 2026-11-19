#!/usr/bin/env bash
# Bump hashes.json to the Google Drive release Google's update server
# (Omaha, which Google's own updater asks) serves to a new Apple Silicon
# install: its download URL and the dmg's sha256, which the download must
# match. The bundle's version and build come from the app's Info.plist,
# read from the downloaded dmg once the installer's signature checks out (as
# the package does). Never
# downgrades. Downloads the dmg (~140 MB) on a bump. Needs curl, jq, uuidgen
# and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

response=""
for _ in $(seq 1 5); do
  id="$(uuidgen)"
  response="$(curl -fsS -X POST -H 'Content-Type: text/xml' \
    --data "<?xml version='1.0' encoding='UTF-8'?>
<request protocol='3.0' ismachine='1' installsource='ondemandcheckforupdate'
  sessionid='{$id}' requestid='{$id}'>
  <os platform='mac' version='15.0' arch='arm64'/>
  <app appid='com.google.drivefs' version='' lang=''><updatecheck/></app>
</request>" https://tools.google.com/service/update2)" && break
  sleep 3
done
version="$(grep -oE "<manifest version=['\"][0-9.]+" <<<"$response" | grep -oE '[0-9.]+$' || true)"
check_version google-drive "$version" '^[0-9]+(\.[0-9]+){3}$'
skip_if_current google-drive "$version"
newest="$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -n1)"
[ "$newest" = "$version" ] || { echo "google-drive: $current is newer than $version"; exit 0; }

base="$(grep -oE "codebase=['\"]https://dl\.google\.com/release2/[^'\"]+" <<<"$response" |
  head -n1 | sed -E "s/codebase=['\"]//")"
pkg="$(grep -oE "<package [^>]*name=['\"][^'\"]+\.dmg" <<<"$response" | sed -E "s/.*name=['\"]//")"
# The sha256 Google lists for the dmg, which the download must match.
sha256="$(grep -oE "<package [^>]*>" <<<"$response" | grep -oE "hash_sha256=['\"][0-9a-f]{64}" |
  head -n1 | grep -oE '[0-9a-f]{64}$' || true)"
url="$base$pkg"
# Only Google's release host, and nothing that could break out of the URL.
[[ $url =~ ^https://dl\.google\.com/release2/drive-file-stream/[A-Za-z0-9._/-]+\.dmg$ && -n $sha256 ]] ||
  { echo "google-drive: unexpected update response (URL '$url')" >&2; exit 1; }
hash="$(prefetch "$url" "$sha256")"

# The bundle's version and build, from the app's Info.plist.
dmg="$(nix store prefetch-file --json --name GoogleDrive.dmg --expected-hash "$hash" "$url" | jq -er .storePath)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
flake="$(realpath ../..)"
nix_run() { nix shell --inputs-from "$flake" "$@"; }
(cd "$tmp" && nix_run nixpkgs#_7zz --command 7zz x -tdmg -y -bd "$dmg" >/dev/null)
apfs=("$tmp"/*.apfs)
[ ${#apfs[@]} = 1 ] || { echo "google-drive: expected one APFS partition" >&2; exit 1; }
# dissect.apfs from the flake's own nixpkgs, as the package uses it.
nix shell --impure --expr "with (builtins.getFlake \"git+file://$flake\").inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}; python3.withPackages (p: [ p.dissect-apfs ])" \
  --command python3 -I apfs-cat.py "${apfs[0]}" /GoogleDrive.pkg "$tmp/GoogleDrive.pkg"
nix_run nixpkgs#python3 nixpkgs#openssl --command python3 -I \
  ../../lib/pkg-signature-check.py ../../lib/apple-root-ca.pem EQHXZ8M8AV "$tmp/GoogleDrive.pkg" \
  --cat GoogleDrive_arm64.pkg/Payload 2>/dev/null |
  nix_run nixpkgs#pbzx --command pbzx - |
  (cd "$tmp" && nix_run nixpkgs#cpio --command cpio -id --quiet "./Google Drive.app/Contents/Info.plist")
read -r shortVersion build < <(python3 -I -c '
import plistlib, sys
info = plistlib.load(open(sys.argv[1], "rb"))
print(info["CFBundleShortVersionString"], info["CFBundleVersion"])
' "$tmp/Google Drive.app/Contents/Info.plist")
check_version google-drive "$shortVersion"
check_version google-drive "$build"

jq -n --arg v "$version" --arg s "$shortVersion" --arg b "$build" --arg u "$url" --arg h "$hash" \
  '{version: $v, shortVersion: $s, build: $b, url: $u, hashes: {"GoogleDrive.dmg": $h}}' > hashes.json
echo "google-drive: $current -> $version"
