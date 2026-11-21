#!/usr/bin/env bash
# Merges the pull request of update/<name> ($BRANCH) that check.yml has just
# checked at $SHA on every system, when that head contains main: what lands
# on main is then the tree that was built. When main has moved past it,
# rebases the update onto main instead, pushes it and starts check.yml there
# again (which cancels the run this is in), and that run merges it once it
# passes. After a merge, deletes the branch and starts cache.yml on main:
# merges and pushes with this token start no workflow themselves. Run by
# check.yml's merge job. Needs gh, git and jq.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${BRANCH:?}" "${SHA:?}" "${GH_REPO:?}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# git with gh's credential helper, which hands git $GH_TOKEN: the merge job's
# checkout keeps no token.
git_auth() { git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"; }

pr="$(gh pr view "$BRANCH" --json number,state,baseRefName,isCrossRepository,headRefOid)"
if ! jq -e --arg sha "$SHA" \
  '.state == "OPEN" and .baseRefName == "main" and .isCrossRepository == false and .headRefOid == $sha' \
  <<<"$pr" >/dev/null; then
  echo "No open update targeting main at $SHA"
  exit 0
fi
number="$(jq -r .number <<<"$pr")"

# How many commits of main the tested head lacks.
behind() {
  git_auth fetch -q origin main
  git rev-list --count "$SHA..origin/main"
}

if [ "$(behind)" = 0 ]; then
  # pull_request runs still waiting for approval at this commit
  # (ci/update-all.sh deletes those it sees): merging would fail them as
  # expired, and GitHub would mail the failure.
  for id in $(gh api "repos/$GH_REPO/actions/runs?event=pull_request&head_sha=$SHA&status=action_required" \
    -q '.workflow_runs[].id' || true); do
    gh api -X DELETE "repos/$GH_REPO/actions/runs/$id" ||
      echo "::warning::could not delete run $id, which waits for approval"
  done
  if gh pr merge "$number" --merge --match-head-commit "$SHA"; then
    # Through the API: gh pr merge --delete-branch also deletes a local
    # branch, which this detached checkout has none of.
    gh api -X DELETE "repos/$GH_REPO/git/refs/heads/$BRANCH" >/dev/null
    gh workflow run cache.yml --ref main ||
      echo "::warning::could not start cache.yml on main"
    exit 0
  fi
  # main may have moved on in the meantime: rebase then, as below.
  if [ "$(behind)" = 0 ]; then
    echo "::error::$BRANCH: could not merge pull request #$number"
    exit 1
  fi
fi

echo "$BRANCH lacks commits of main: rebasing it onto main and checking it again"
git checkout -q --detach "$SHA"
if ! git rebase -q origin/main; then
  git rebase --abort
  echo "::error::$BRANCH does not rebase onto main; the next update run proposes it again"
  exit 1
fi
rebased="$(git rev-parse HEAD)"
git_auth push -q --force-with-lease="refs/heads/$BRANCH:$SHA" origin "HEAD:refs/heads/$BRANCH"
# Before the new run starts: it cancels this one (check.yml's concurrency).
ci/drop-approval-runs.sh "$BRANCH $rebased"
gh workflow run check.yml --ref "$BRANCH"
