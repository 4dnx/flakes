#!/usr/bin/env bash
# Plans check.yml's builds: writes `matrix` to GitHub Actions outputs, a JSON
# list with one {system, runner, checks} entry (checks: names separated by
# spaces) per system whose checks differ from the baseline, and [] when none
# do, so a change that leaves a system's derivations alone starts no runner
# for it. Also evaluates every package of every system (those checks leave
# out too) and builds the formatting check, which takes the whole source and
# so always differs. Otherwise evaluation only, so check.yml runs it on
# Linux for every system. Needs gh, git, jq and nix.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GH_REPO:?}"

# Each system, and the runner that builds its checks.
runners=(
  "x86_64-linux ubuntu-latest"
  "aarch64-linux ubuntu-24.04-arm"
  "aarch64-darwin macos-latest"
)

# The baseline: the newest successful Check of an ancestor of HEAD, from this
# repository (not a fork). Its run built every check that differed from its
# own baseline, on every system, so all checks at that commit passed, and
# a check whose derivation is unchanged since needs no new build. A push or
# dispatch run built the commit it reports; so does a pull_request run,
# whose check.yml checks out the head rather than GitHub's merge commit.
# Failed or cancelled runs do not qualify.
base=""
reason="no successful ancestor found"
if ! candidates=$(gh api "repos/$GH_REPO/actions/workflows/check.yml/runs?status=success&per_page=100" \
  --jq ".workflow_runs[] | select(.head_repository.full_name == \"$GH_REPO\")
    | select(.event == \"push\" or .event == \"workflow_dispatch\" or .event == \"pull_request\")
    | .head_sha"); then
  reason="workflow run lookup failed"
  candidates=""
fi
for rev in $candidates; do
  if git merge-base --is-ancestor "$rev" HEAD 2>/dev/null; then
    base=$rev
    break
  fi
done
# Changes to the check machinery must exercise the builds too, even when
# package derivations are unchanged (for example a new Nix installer): that
# is check.yml and ci/. It also keeps runs from before check.yml checked out
# a pull request's head (they built a merge commit) from being a baseline.
# The shared files package builds read (verify/, lib) change their
# derivations instead, so only the checks that read them run.
if [ -n "$base" ] && ! git diff --quiet "$base" HEAD -- .github/workflows/check.yml ci/; then
  base=""
  reason="check workflow or CI scripts changed"
fi
[ -n "$base" ] || echo "Building all checks: $reason"
echo "Baseline: ${base:-none}"

# Evaluation errors fail the job rather than silently skipping checks.
matrix='[]'
for entry in "${runners[@]}"; do
  read -r system runner <<<"$entry"
  nix eval --json ".#packages.$system" \
    --apply 'ps: builtins.mapAttrs (n: p: p.drvPath) ps' >/dev/null
  checks="$(ci/changed-checks.sh "$system" "$base" | tr '\n' ' ' | sed 's/ *$//')"
  echo "To build on $system: ${checks:-nothing}"
  [ -z "$checks" ] || matrix="$(jq -c --arg s "$system" --arg r "$runner" --arg c "$checks" \
    '. + [{system: $s, runner: $r, checks: $c}]' <<<"$matrix")"
done

nix build --no-link -L .#checks.x86_64-linux.formatting

echo "matrix=$matrix" >>"$GITHUB_OUTPUT"
