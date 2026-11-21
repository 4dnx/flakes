#!/usr/bin/env bash
# Prints the packages of <system> that CI pushes to ret.cachix.org, one per
# line: only those that compile for minutes (hermes-agent, x86_64-linux
# only, and llama), so their users can download them instead. Every other
# package is upstream's binary or builds quickly, and stays out of the cache.
# The one list cache.yml and update.yml read. Evaluation only. Needs jq and
# nix.
set -euo pipefail
cd "$(dirname "$0")/.."
system=$1
cached=(hermes-agent llama)

nix eval --json ".#packages.$system" \
  --apply "ps: builtins.filter (n: ps ? \${n}) [ $(printf '"%s" ' "${cached[@]}")]" |
  jq -r '.[]'
