#!/usr/bin/env bash
# Follow stable native releases; prefetch verifies GitHub's asset digests.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh

version="$(gh_latest zed zed-industries/zed)"
skip_if_current zed "$version"
base="https://github.com/zed-industries/zed/releases/download/v$version"
write_hashes "$version" \
  aarch64-darwin="$base/Zed-aarch64.dmg" \
  aarch64-linux="$base/zed-linux-aarch64.tar.gz" \
  x86_64-linux="$base/zed-linux-x86_64.tar.gz"
echo "zed: $current -> $version"
