#!/usr/bin/env bash
set -euo pipefail

# Sourced into a writeShellApplication; WARP_CLI comes from the module.
# Limit the wait so an unregistered or stopped daemon cannot block activation.
ready=false
for _ in $(seq 1 15); do
  if ranges=$("$WARP_CLI" --no-ansi tunnel ip list 2>/dev/null); then
    ready=true
    break
  fi
  sleep 1
done
if [ "$ready" != true ]; then
  echo "warp-apply-exclusions: daemon unavailable or client not registered" >&2
  exit 1
fi
if [ "$WARP_EXCLUDE_RAYFISH" = true ] && ! printf '%s\n' "$ranges" | grep -Eq '(^|[[:space:]])200::/7([[:space:]]|$)'; then
  if ! "$WARP_CLI" --no-ansi tunnel ip add-range 200::/7; then
    # A startup hook and an explicit helper invocation can race.
    ranges=$("$WARP_CLI" --no-ansi tunnel ip list)
    printf '%s\n' "$ranges" | grep -Eq '(^|[[:space:]])200::/7([[:space:]]|$)' || exit 1
  fi
fi

if [ -n "$WARP_EXCLUDE_HOSTS" ]; then
  hosts=$("$WARP_CLI" --no-ansi tunnel host list)
  while IFS= read -r host; do
    [ -n "$host" ] || continue
    if ! printf '%s\n' "$hosts" | awk -v wanted="$host" '
      $1 == wanted { found = 1 }
      END { exit !found }
    '; then
      if ! "$WARP_CLI" --no-ansi tunnel host add "$host"; then
        hosts=$("$WARP_CLI" --no-ansi tunnel host list)
        printf '%s\n' "$hosts" | awk -v wanted="$host" '
          $1 == wanted { found = 1 }
          END { exit !found }
        ' || exit 1
      fi
    fi
  done <<< "$WARP_EXCLUDE_HOSTS"
fi
