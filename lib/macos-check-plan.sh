#!/usr/bin/env bash
# Write the macOS checks and package cache key to GitHub Actions outputs.
set -euo pipefail
cd "$(dirname "$0")/.."
system=aarch64-darwin
base=${BASE:-origin/main}
if [ "${GITHUB_REF:-}" = refs/heads/main ]; then
  base=""
  # A successful merged PR or update branch can validate the same package
  # derivations as main. Reuse it only when its commit is an ancestor.
  # Failed/cancelled runs and unmerged side branches cannot be baselines.
  candidates=$(gh api "repos/$GH_REPO/actions/workflows/check.yml/runs?status=success&per_page=100" \
    --jq '.workflow_runs[] | select(.event == "push" or .event == "workflow_dispatch" or .event == "pull_request") | .head_sha') || candidates=""
  for rev in $candidates; do
    if git merge-base --is-ancestor "$rev" HEAD; then
      base=$rev
      break
    fi
  done
fi
# Changes to the check machinery must exercise the builds too, even when
# package derivations are unchanged (for example a new Nix installer).
if [ -n "$base" ] && ! git diff --quiet "$base" HEAD -- .github/workflows/check.yml lib/; then
  base=""
fi
if [ -n "$base" ]; then
  checks=$(lib/changed-checks.sh "$system" "$base")
else
  checks=$(nix eval --json ".#checks.$system" \
    --apply 'cs: builtins.attrNames (removeAttrs cs [ "formatting" ])' | jq -r '.[]')
fi
printf 'Baseline: %s\nTo build: %s\n' "${base:-none; build all}" "${checks:-nothing}"
# Always evaluate packages for the key, even when no builds are needed.
# Evaluation errors fail the job rather than silently skipping checks.
key=$(lib/macos-cache-key.sh)
echo "cache-key=$key" >>"$GITHUB_OUTPUT"
echo "checks=$(echo $checks)" >>"$GITHUB_OUTPUT"
