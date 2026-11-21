#!/usr/bin/env bash
# Deletes the pull_request runs that GitHub holds for approval at the given
# commits, each argument "<branch> <sha>": GitHub holds the runs of pull
# requests that GITHUB_TOKEN opened or pushed to, starts them only when
# someone approves them, and fails them once the pull request merges, which
# mails a failure for every update. A dispatched check.yml checks and merges
# those pull requests instead. Runs can take a moment to appear, so this
# waits once, up to a minute, for all commits together rather than for each.
# A failure here is only a warning. Run by ci/update-all.sh and
# ci/merge-update.sh. Needs gh.
set -euo pipefail

pending=("$@")
for try in 1 2 3 4 5 6; do
  [ ${#pending[@]} -gt 0 ] || exit 0
  left=()
  for entry in "${pending[@]}"; do
    ids="$(gh api "repos/{owner}/{repo}/actions/runs?event=pull_request&head_sha=${entry#* }&status=action_required" \
      -q '.workflow_runs[].id' 2>/dev/null)" || ids=""
    if [ -z "$ids" ]; then left+=("$entry"); continue; fi
    for id in $ids; do
      gh api -X DELETE "repos/{owner}/{repo}/actions/runs/$id" >/dev/null ||
        echo "::warning::${entry% *}: could not delete run $id, which waits for approval"
    done
  done
  pending=("${left[@]}")
  [ ${#pending[@]} = 0 ] || [ "$try" = 6 ] || sleep 10
done
