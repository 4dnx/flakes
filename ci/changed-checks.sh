#!/usr/bin/env bash
# Prints the checks of <system> whose derivation differs from those at <rev>
# (a git revision, such as origin/main), one name per line: what a change
# needs built on that system, the packages it takes as arguments included.
# Without <rev>, or when the checks at <rev> don't evaluate, prints them all.
# Every check's derivation is evaluated either way, so an evaluation error
# fails the script. formatting is left out: it takes the whole source, so it
# always differs, and ci/check-plan.sh builds it. Evaluation only: any system
# can run it for any other (ci/check-plan.sh does, on Linux). Needs git, jq
# and nix.
set -euo pipefail
cd "$(dirname "$0")/.."
system=$1 rev=${2:-}

drvs() {
  nix eval --json "$1#checks.$system" \
    --apply 'cs: builtins.mapAttrs (n: c: c.drvPath) (removeAttrs cs [ "formatting" ])'
}

head="$(drvs "git+file://$PWD")"
base='{}'
# shallow=1 also takes a shallow clone. A base that doesn't evaluate has
# nothing to compare against: build it all.
if [ -n "$rev" ]; then
  base="$(drvs "git+file://$PWD?shallow=1&rev=$(git rev-parse "$rev")")" ||
    { echo "warning: checks at $rev don't evaluate; building all" >&2; base='{}'; }
fi
jq -rn --argjson h "$head" --argjson b "$base" \
  '$h | to_entries[] | select($b[.key] != .value) | .key'
