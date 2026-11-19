#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../helpers/update-lib.sh
. ../../helpers/update-lib.sh

# gh_latest skips pre-releases. Upstream re-releases a version as vX.Y.Z-N
# (v5.0.9-1, v5.0.9-2): the same app version, rebuilt. hashes.json's version
# is the release, appVersion the app's own, which the install check compares.
version="$(gh_latest utm utmapp/UTM '^[0-9]+(\.[0-9]+){1,3}(-[0-9]+)?$')"
skip_if_current utm "$version"

write_hashes "$version" \
  UTM.dmg="https://github.com/utmapp/UTM/releases/download/v$version/UTM.dmg"
jq --arg a "${version%-*}" '.appVersion = $a' hashes.json > hashes.json.tmp
mv hashes.json.tmp hashes.json
echo "utm: $current -> $version"
