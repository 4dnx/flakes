#!/usr/bin/env bash
# Runs pkgs/*/update.sh and lands each update that builds: committed to main,
# or proposed as a pull request (branch update/<name>) for the packages in
# $REVIEW. Run by update.yml, once per $UPDATE_SYSTEM:
#   x86_64-linux    every package that builds there, and nixpkgs weekly
#   aarch64-darwin  the packages that build only on macOS
# so every update is built before it lands. $PACKAGES limits the run to the
# named packages (nixpkgs for the nixpkgs input); without it, the packages in
# $ON_REQUEST are skipped, so they update only when named. Needs gh, git, jq
# and nix.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${UPDATE_SYSTEM:?}"
REVIEW="${REVIEW:-}"
ON_REQUEST="${ON_REQUEST:-}"
PACKAGES="${PACKAGES:-}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# git with gh's credential helper, which hands git $GH_TOKEN (or gh's own
# login): update.yml's checkout keeps no token, so later steps and actions'
# post steps can't read one from .git/config.
git_auth() { git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"; }

attrs() { nix eval --json ".#packages.$1" --apply builtins.attrNames | jq -r '.[]'; }
linux="$(attrs x86_64-linux)"
darwin="$(attrs aarch64-darwin)"

# Whether <name> is this system's to update: Linux takes everything that
# builds there, macOS what builds nowhere else.
ours() {
  local name=$1
  case $UPDATE_SYSTEM in
    x86_64-linux) grep -qxF -- "$name" <<<"$linux" ;;
    aarch64-darwin) grep -qxF -- "$name" <<<"$darwin" && ! grep -qxF -- "$name" <<<"$linux" ;;
    *) echo "unknown UPDATE_SYSTEM $UPDATE_SYSTEM" >&2; exit 1 ;;
  esac
}

# The path an update of <name> changes: pkgs/<name>, or flake.lock for the
# nixpkgs input.
paths() { if [ "$1" = nixpkgs ]; then echo flake.lock; else echo "pkgs/$1"; fi; }

# Puts a checked update on update/<name>, on top of main, opens (or retitles)
# its pull request, and starts check.yml there for the other systems, which
# merges it once they all pass: this token's pushes start no workflow
# themselves.
propose() {
  local name=$1 title=$2 branch="update/$1" commit commit_sha
  git add -A -- "$(paths "$name")"
  git commit -qm "$title"
  commit="$(git rev-parse HEAD)"
  git reset -q --hard HEAD~1
  git switch -q --detach origin/main
  git cherry-pick "$commit" >/dev/null
  commit_sha="$(git rev-parse HEAD)"
  git_auth push -qf origin "HEAD:refs/heads/$branch"
  git switch -q main
  if [ "$(gh pr view "$branch" --json state -q .state 2>/dev/null)" = OPEN ]; then
    gh pr edit "$branch" --title "$title" >/dev/null
  else
    gh pr create --head "$branch" --base main --title "$title" \
      --body "Automated update of \`$name\`, built by the Update workflow on $UPDATE_SYSTEM; check.yml runs the other systems and merges this pull request once all of them pass." ||
      { echo "::error::$name: could not open a pull request (Settings → Actions → allow GitHub Actions to create pull requests)"; failed=1; }
  fi
  gh workflow run check.yml --ref "$branch" ||
    { echo "::error::$name: could not start check.yml on $branch"; failed=1; }
  proposals+=("$branch $commit_sha")
}

# The proposed commits ("<branch> <sha>"), whose pull_request runs that wait
# for approval ci/drop-approval-runs.sh deletes at the end: GitHub fails them
# once the pull request merges, and mails the failure. The dispatched
# check.yml checks and merges the update instead.
proposals=()

# Whether update/<name> already holds exactly this update, on top of main: a
# branch that main has moved past is proposed again, as check.yml's merge job
# merges only a head that contains main.
proposed() {
  git_auth fetch -q origin "update/$1" 2>/dev/null || return 1
  git merge-base --is-ancestor origin/main FETCH_HEAD &&
    git diff --quiet FETCH_HEAD -- "$(paths "$1")" &&
    [ -z "$(git ls-files --others --exclude-standard -- "$(paths "$1")")" ]
}

# Drops what a failed update left behind.
discard() { git checkout -q -- "$(paths "$1")"; git clean -fdq -- "$(paths "$1")"; }

# Deletes <name>'s build and download from the store again when checks leave
# it out (flake.nix: rolling and heavy, such as the Office apps with ~4 GB
# each), so the store the macOS job caches between runs (update.yml) keeps
# what the checks need rather than these. A failure is only a warning.
forget() {
  local name=$1 attr=".#packages.$UPDATE_SYSTEM.\"$1\"" paths
  [ "$name" != nixpkgs ] || return 0
  [ "$(nix eval ".#checks.$UPDATE_SYSTEM" --apply "cs: cs ? \"$name\"")" = false ] || return 0
  paths="$(nix eval --raw "$attr" \
    --apply 'p: toString (map (o: builtins.getAttr o p) p.outputs ++ [ (p.src or "") ])' 2>/dev/null)" ||
    return 0
  local present=() path
  for path in $paths; do [ ! -e "$path" ] || present+=("$path"); done
  [ ${#present[@]} = 0 ] || nix store delete "${present[@]}" ||
    echo "::warning::$name: could not delete its build from the store"
}

# Checks the flake with <name>'s update, then commits it to main, or proposes
# it when it needs review. Sets failed=1 when it fails.
land() {
  local name=$1 title=$2 review=$3
  if $review && proposed "$name"; then
    echo "$name: already proposed on update/$name"
    discard "$name"; return 0
  fi
  # Evaluate every system's checks, then build this system's, so packages
  # built on this one (they take it as an argument) are checked too, and this
  # one itself if checks leave it out (a rolling build). Determinate Nix's
  # `nix flake check --all-systems` builds every system's checks, which fails
  # on the systems this runner can't build, so the other systems are only
  # evaluated, to their derivation paths. --keep-going reports every failure.
  if ! nix eval --json .#checks --apply 'builtins.mapAttrs (_: builtins.mapAttrs (_: c: c.drvPath))' >/dev/null ||
    ! nix flake check --keep-going -L ||
    { [ "$name" != nixpkgs ] &&
      nix eval --quiet ".#packages.$UPDATE_SYSTEM.\"$name\".drvPath" >/dev/null 2>&1 &&
      ! nix build --no-link -L ".#packages.$UPDATE_SYSTEM.\"$name\""; }; then
    echo "::error::$name failed to build after update"
    forget "$name"; discard "$name"; failed=1; return 0
  fi
  forget "$name"
  if $review; then
    propose "$name" "$title"
  else
    git add -A -- "$(paths "$name")"
    git commit -qm "$title"
  fi
}

failed=0
for script in pkgs/*/update.sh; do
  name="$(basename "$(dirname "$script")")"
  if [ -n "$PACKAGES" ]; then
    [[ " $PACKAGES " == *" $name "* ]] || continue
  elif [[ " $ON_REQUEST " == *" $name "* ]]; then
    echo "$name: updated on request only (ON_REQUEST)"; continue
  fi
  ours "$name" || continue
  # A failing script (upstream down, unexpected data) skips only its own
  # package.
  if ! "$script"; then
    echo "::error::$name: update.sh failed"
    discard "$name"; failed=1; continue
  fi
  [ -n "$(git status --porcelain -- "pkgs/$name")" ] || continue
  version="$(jq -r .version "pkgs/$name/hashes.json" 2>/dev/null || echo new)"
  review=false
  [[ " $REVIEW " != *" $name "* ]] || review=true
  land "$name" "Update $name to v$version" "$review"
done

# nixpkgs, which every package's libraries and tools come from, with the
# nix-darwin, Home Manager and Determinate the module checks evaluate against
# it: weekly, by the first run once the locked nixpkgs is a week old, or when
# asked for, always through a pull request, since it touches every package.
# The age, not a run's time, decides, as GitHub delays and drops scheduled
# runs. Linux only; check.yml builds the rest.
# The root's nixpkgs: other inputs' nixpkgs share its node names.
nixpkgs_modified="$(jq -er '.nodes[.nodes.root.inputs.nixpkgs].locked.lastModified' flake.lock)"
if [ "$UPDATE_SYSTEM" = x86_64-linux ] &&
  { { [ -z "$PACKAGES" ] && [ $(($(date -u +%s) - nixpkgs_modified)) -ge $((7 * 86400)) ]; } ||
    [[ " $PACKAGES " == *" nixpkgs "* ]]; }; then
  if nix flake update nixpkgs nix-darwin home-manager determinate; then
    if [ -n "$(git status --porcelain -- flake.lock)" ]; then
      # The root's nixpkgs: other inputs' nixpkgs share its node names.
      rev="$(jq -r '.nodes[.nodes.root.inputs.nixpkgs].locked.rev' flake.lock)"
      land nixpkgs "Update nixpkgs to ${rev:0:12}" true
    fi
  else
    echo "::error::nixpkgs: nix flake update failed"
    discard nixpkgs; failed=1
  fi
fi

[ ${#proposals[@]} = 0 ] || ci/drop-approval-runs.sh "${proposals[@]}"
git_auth pull -q --rebase origin main
git_auth push -q origin HEAD:main
exit "$failed"
