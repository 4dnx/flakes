#!/usr/bin/env bash
# Bump hashes.json to the latest llama.cpp release. Needs curl, gh, git, jq and
# nix.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../scripts/update-lib.sh
. ../../scripts/update-lib.sh

version="$(gh_latest llama ggml-org/llama.cpp)"
skip_if_current llama "$version"

# The tarball has no git history, so the build needs the build number and
# commit that `llama version` reports. They come from the build tag on the
# release's commit: v<version>-b<number>-<short commit> (v1.0.0), or only
# b<number> (v1.1.0).
tags="$(git ls-remote --tags https://github.com/ggml-org/llama.cpp)"
# An annotated tag's commit is on its peeled (^{}) line, a lightweight one's
# on its own.
full="$(awk -v t="refs/tags/v$version" '$2 == t "^{}" { print $1; exit }' <<<"$tags")"
[ -n "$full" ] ||
  full="$(awk -v t="refs/tags/v$version" '$2 == t { print $1; exit }' <<<"$tags")"
[[ $full =~ ^[0-9a-f]{40}$ ]] || { echo "llama: no tag v$version" >&2; exit 1; }
build="$(awk -v c="$full" '$1 == c && $2 ~ /^refs\/tags\/(v[0-9.]+-)?b[0-9]+(-[0-9a-f]+)?$/ {
    n = $2; sub(/^refs\/tags\/(v[0-9.]+-)?b/, "", n); sub(/-.*/, "", n); print n
  }' <<<"$tags" | sort -n | tail -n 1)"
[[ $build =~ ^[0-9]+$ ]] || { echo "llama: no build tag for v$version" >&2; exit 1; }
commit="${full:0:7}"

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
