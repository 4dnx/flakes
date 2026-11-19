#!/usr/bin/env bash
# Write the macOS checks to build to GitHub Actions outputs (checks, names
# separated by spaces; empty when none differ from the baseline). Evaluation
# only, so check.yml runs it on Linux. Needs gh, git, jq and nix.
set -euo pipefail
cd "$(dirname "$0")/.."
system=aarch64-darwin
target=${BASE:-origin/main}
if [ "${GITHUB_REF:-}" = refs/heads/main ]; then
  target=HEAD
fi
base=""
# A successful run of a commit that is an ancestor validated that commit's
# derivations: a push to main, or a dispatch (main, or an update branch that
# was merged). Not a pull_request run: it built a merge commit with the base
# of that moment, not the head_sha it reports, so the head's derivations may
# never have been built. PRs also require a successful baseline, rather than
# assuming that every commit on their base branch passed. Failed/cancelled
# runs do not qualify.
candidates=$(gh api "repos/$GH_REPO/actions/workflows/check.yml/runs?status=success&per_page=100" \
  --jq '.workflow_runs[] | select(.event == "push" or .event == "workflow_dispatch") | .head_sha') || candidates=""
for rev in $candidates; do
  if git merge-base --is-ancestor "$rev" "$target"; then
    base=$rev
    break
  fi
done
# Changes to the check machinery must exercise the builds too, even when
# package derivations are unchanged (for example a new Nix installer): that
# is check.yml and ci/. The shared files package builds read
# (verify/, lib) change their derivations instead, so only the
# checks that read them run.
if [ -n "$base" ] && ! git diff --quiet "$base" HEAD -- .github/workflows/check.yml ci/; then
  base=""
fi
if [ -n "$base" ]; then
  checks=$(ci/changed-checks.sh "$system" "$base")
else
  checks=$(nix eval --json ".#checks.$system" \
    --apply 'cs: builtins.attrNames (removeAttrs cs [ "formatting" ])' | jq -r '.[]')
fi
printf 'Baseline: %s\nTo build: %s\n' "${base:-none; build all}" "${checks:-nothing}"
# Evaluation errors above fail the job rather than silently skipping checks.
echo "checks=$(tr '\n' ' ' <<<"$checks" | sed 's/ *$//')" >>"$GITHUB_OUTPUT"
