#!/usr/bin/env bash
# Hash all macOS package derivations, including the rolling update-only ones.
# Unlike a repository file hash, Linux-only changes do not invalidate this key.
set -euo pipefail
cd "$(dirname "$0")/.."
nix eval --json .#packages.aarch64-darwin \
  --apply 'ps: builtins.mapAttrs (n: p: p.drvPath) ps' |
  jq -cS . | shasum -a 256 | cut -d ' ' -f 1
