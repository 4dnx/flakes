#!/usr/bin/env bash
# Plans cache.yml's builds: writes `matrix` to GitHub Actions outputs, a
# JSON list with one {system, runner, packages} entry (packages: names
# separated by spaces) per Linux system whose cached packages
# (ci/cached-packages.sh) nan.cachix.org doesn't hold yet at this commit,
# and [] when it holds them all, so a change that leaves them alone builds
# nothing. Evaluation and cache lookups only, so it runs on one Linux runner
# for both systems. nan.cachix.org holds nothing for macOS. Needs jq and nix.
set -euo pipefail
cd "$(dirname "$0")/.."

# Each system, and the runner that builds its cached packages.
runners=(
  "x86_64-linux ubuntu-latest"
  "aarch64-linux ubuntu-24.04-arm"
)

matrix='[]'
for entry in "${runners[@]}"; do
  read -r system runner <<<"$entry"
  missing=()
  for name in $(ci/cached-packages.sh "$system"); do
    out="$(nix eval --raw ".#packages.$system.\"$name\".outPath")"
    # A failed lookup (the cache unreachable) counts as missing: building
    # again is harmless, skipping a push is not.
    if nix path-info --store https://nan.cachix.org "$out" >/dev/null 2>&1; then
      echo "$system $name: in nan.cachix.org ($out)"
    else
      echo "$system $name: missing ($out)"
      missing+=("$name")
    fi
  done
  [ ${#missing[@]} = 0 ] || matrix="$(jq -c --arg s "$system" --arg r "$runner" --arg p "${missing[*]}" \
    '. + [{system: $s, runner: $r, packages: $p}]' <<<"$matrix")"
done

echo "matrix=$matrix" >>"$GITHUB_OUTPUT"
