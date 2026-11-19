#!/usr/bin/env bash
# Bump hashes.json to the latest llama.cpp release. Needs curl, gh, git, jq and
# nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../build-support/update-lib.sh
. ../build-support/update-lib.sh

version="$(gh_latest llama ggml-org/llama.cpp)"
skip_if_current llama "$version"

# The release tag v<version> sits on the same commit as a tag that names the
# build: v<version>-b<number>-<short commit>. The tarball has no git history,
# so the build needs both.
tag="$(git ls-remote --tags https://github.com/ggml-org/llama.cpp "refs/tags/v$version-b*" |
  awk '{ sub("refs/tags/", "", $2); print $2 }' | sort -V | tail -n 1)"
re="^v${version//./\\.}-b([0-9]+)-([0-9a-f]{7,12})$"
[[ $tag =~ $re ]] || { echo "llama: no build tag for v$version" >&2; exit 1; }
build="${BASH_REMATCH[1]}"
commit="${BASH_REMATCH[2]}"

src="$(nix store prefetch-file --unpack --json \
  "https://github.com/ggml-org/llama.cpp/archive/refs/tags/v$version.tar.gz" | jq -er .hash)"

# The chat UI built for that build, checked against the sha256 upstream lists.
ui_url="https://huggingface.co/buckets/ggml-org/llama-ui/resolve/b$build/dist.tar.gz"
ui_sum="$(curl -fsSL "$ui_url.sha256" | awk '{ print $1 }')"
ui="$(prefetch "$ui_url" "$ui_sum")"

jq -n --arg v "$version" --arg b "$build" --arg c "$commit" --arg s "$src" --arg u "$ui" \
  '{version: $v, build: $b, commit: $c, hashes: {src: $s, ui: $u}}' > hashes.json
jq -e '.hashes | all(.[]; startswith("sha256-"))' hashes.json >/dev/null ||
  { echo "llama: a download failed" >&2; exit 1; }
echo "llama: $current -> $version"
