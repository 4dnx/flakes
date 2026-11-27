#!/usr/bin/env bash
# Turns Determinate Nix's telemetry off on a CI runner, after
# DeterminateSystems/determinate-nix-action installed it: the daemon gets
# DETSYS_IDS_TELEMETRY=disabled, Determinate's documented opt-out of all its
# telemetry, and NIX_SENTRY_ENDPOINT="", which turns crash reports off;
# /etc/determinate/config.json gets telemetry.sentry.endpoint null. The
# workflows set the same two variables for the nix commands their steps run.
# Then checks that the running daemon has them.
# Daemon names: nix-installer's configure_determinate_nixd_init_service.
set -euo pipefail

config=/etc/determinate/config.json
sudo mkdir -p "$(dirname "$config")"
if sudo test -s "$config"; then
  sudo cat "$config"
else
  echo '{}'
fi | jq '.telemetry.sentry.endpoint = null' | sudo tee "$config.new" >/dev/null
sudo mv "$config.new" "$config"

case "$(uname -s)" in
Linux)
  sudo mkdir -p /etc/systemd/system/nix-daemon.service.d
  printf '%s\n' '[Service]' \
    'Environment=DETSYS_IDS_TELEMETRY=disabled' \
    'Environment=NIX_SENTRY_ENDPOINT=' |
    sudo tee /etc/systemd/system/nix-daemon.service.d/telemetry.conf >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl restart nix-daemon.service
  ;;
Darwin)
  plist=/Library/LaunchDaemons/systems.determinate.nix-daemon.plist
  sudo plutil -remove EnvironmentVariables "$plist" 2>/dev/null || true
  sudo plutil -insert EnvironmentVariables \
    -json '{"DETSYS_IDS_TELEMETRY":"disabled","NIX_SENTRY_ENDPOINT":""}' "$plist"
  sudo launchctl bootout system/systems.determinate.nix-daemon || true
  # bootout returns before the service is gone; bootstrap fails until then.
  for _ in $(seq 1 30); do
    sudo launchctl bootstrap system "$plist" 2>/dev/null && break
    sleep 1
  done
  ;;
*)
  echo "determinate-telemetry-off: unknown system $(uname -s)" >&2
  exit 1
  ;;
esac

# The daemon answers again (and a socket-activated one is started).
for _ in $(seq 1 30); do
  nix store info >/dev/null 2>&1 && break
  sleep 1
done
nix store info

case "$(uname -s)" in
Linux)
  pid="$(systemctl show -p MainPID --value nix-daemon.service)"
  env="$(sudo cat "/proc/$pid/environ" | tr '\0' '\n')"
  ;;
Darwin)
  env="$(sudo launchctl print system/systems.determinate.nix-daemon)"
  ;;
esac
if ! grep -Eq 'DETSYS_IDS_TELEMETRY( => |=)disabled' <<<"$env"; then
  echo "determinate-telemetry-off: the Nix daemon lacks DETSYS_IDS_TELEMETRY=disabled" >&2
  exit 1
fi
echo "Determinate Nix telemetry is off for the daemon."
