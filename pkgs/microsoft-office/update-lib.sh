# shellcheck shell=bash
# The update of an Office app (pkgs/microsoft-{excel,powerpoint,word}/
# update.sh). Source it after helpers/update-lib.sh, then:
#   office_update NAME FWLINK_ID MAU_APP_ID BUNDLE_ID
# Needs curl, jq, nix and python3 (standard library); openssl comes from
# nixpkgs (macOS' own LibreSSL has no `cms`).
#
# Microsoft's download link (go.microsoft.com/fwlink) redirects to the
# current installer on its CDN, with the build in the file name. The update
# lands only once MAU's own manifest for the app (<APP_ID>-chk.xml beside
# the installers) offers the same build, and never as a downgrade. Microsoft
# publishes no checksum of the installer (the catalogs beside the manifests
# list only the MAU update packages), so the download is pinned by its hash,
# after helpers/pkg-signature-check.py has checked its signature (Microsoft's
# Developer ID Installer certificate, chaining to Apple's root CA) and every
# file in it; the version comes from the signed Distribution. Downloads the
# installer (~1.4 GB) on a bump.

office_cdn='https://res.public.onecdn.static.microsoft/mro1cdnstorage/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate'
office_team=UBF8T346G9

office_update() {
  local name=$1 link=$2 app_id=$3 bundle=$4
  local url build offered current_build newest hash path versions version bundle_build re

  url="$(curl -fsSI "https://go.microsoft.com/fwlink/?linkid=$link" |
    tr -d '\r' | awk 'tolower($1) == "location:" { print $2; exit }')"
  # Only Microsoft's CDN, and nothing that could break out of the URL.
  re="^${office_cdn//./\\.}/Microsoft_[A-Za-z]+_([0-9.]+)_Installer\\.pkg$"
  [[ $url =~ $re ]] || { echo "$name: unexpected download URL '$url'" >&2; exit 1; }
  build="${BASH_REMATCH[1]}"
  check_version "$name" "$build" '^16\.[0-9]+\.[0-9]{8}$'

  offered="$(curl -fsS "$office_cdn/0409$app_id-chk.xml" |
    python3 -I -c 'import plistlib, sys; print(plistlib.loads(sys.stdin.buffer.read())["Update Version"])')"
  [ "$offered" = "$build" ] ||
    { echo "$name: the installer is $build but MAU offers ${offered:-nothing}; skipping"; exit 0; }

  current_build="$(jq -r '.build // "none"' hashes.json 2>/dev/null || echo none)"
  [ "$build" != "$current_build" ] || { echo "$name: $build is latest"; exit 0; }
  if [ "$current_build" != none ]; then
    newest="$(printf '%s\n%s\n' "$current_build" "$build" | sort -V | tail -n1)"
    [ "$newest" = "$build" ] || { echo "$name: $current_build is newer than $build"; exit 0; }
  fi

  hash="$(prefetch "$url")"
  path="$(nix store prefetch-file --json --expected-hash "$hash" "$url" | jq -er .storePath)"
  versions="$(nix shell --inputs-from ../.. nixpkgs#openssl --command \
    python3 -I ../../helpers/pkg-signature-check.py ../../helpers/apple-root-ca.pem "$office_team" "$path" \
    --bundle "$bundle")"
  read -r version bundle_build <<<"$versions"
  check_version "$name" "$version"
  [ "$bundle_build" = "$build" ] ||
    { echo "$name: the installer holds build $bundle_build, its URL says $build" >&2; exit 1; }

  jq -n --arg v "$version" --arg b "$build" --arg u "$url" --arg h "$hash" \
    '{version: $v, build: $b, url: $u, hashes: {installer: $h}}' > hashes.json
  echo "$name: $current_build -> $build ($version)"
}
