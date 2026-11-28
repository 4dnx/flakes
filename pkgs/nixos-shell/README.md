# NixOS shell

`nixos-shell` boots this flake's ARM64 NixOS guest in a headless QEMU VM on
Apple Silicon. The terminal attaches to the guest's console, logged in as
`nixos`, a user with passwordless `sudo`. The guest
runs [Determinate Nix](https://docs.determinate.systems) (Determinate's NixOS
module, with Determinate Nixd as its daemon) with flakes enabled, includes
`jq` and `ripgrep` and uses QEMU user networking for outbound access.

Configure the public `nan` Cachix cache, then run a revision whose Cache workflow
has built, published and booted the VM:

```sh
nix run --builders "" --max-jobs 0 'github:xr3t/flakes/<commit-sha>#nixos-shell'
```

The launcher allocates 1 GiB of guest RAM, two vCPUs and a 4 GiB virtual disk.
Run from the same directory to reuse the guest's `nixos-shell.qcow2` disk.
The guest's home and writable Nix store overlay live on that disk. The
host's home and Nix profile are excluded from shares. The host Nix store is
mounted read-only, and QEMU also provides its standard exchange directory.
Enter `sudo poweroff` at the guest console to return to macOS.

The launcher uses the guest defaults from Mic92's nixos-shell module and the
NixOS QEMU runner for macOS, which the flake's `nixos-shell` package wraps
to set the shared folder. The guest's own configuration (hostname, user, VM
size, shares, packages) is `vm.nix` in this folder. The Cache workflow
builds the guest on ARM Linux, then builds the macOS launcher using the
published guest. VPN credentials can be provisioned inside the running guest
and kept on its disk, outside the flake and binary cache.

## User

The console logs in as `nixos` (UID 501, group `users`, home `/home/nixos`),
in `wheel` with passwordless `sudo` and trusted by the Nix daemon. `root`
keeps nixos-shell's empty password and is reached with `sudo -i`. On a
`nixos-shell.qcow2` from before the `nixos` user, the user is created on the
next boot; earlier files stay in `/root`.

## Shared folder

The launcher shares one Mac folder at `/tmp/shared` in the guest, writable:
`$SHARED_DIR` if set, else `/tmp/nixos-shell`, which it creates when missing.

```sh
SHARED_DIR="$HOME/Projects/demo" nix run --builders "" --max-jobs 0 'github:xr3t/flakes/<commit-sha>#nixos-shell'
```

`/tmp` on macOS is shared by every user of the Mac and emptied on reboot,
so the default suits scratch files; anything to keep belongs in a folder
given as `SHARED_DIR`. QEMU on macOS shares folders over 9p (nixpkgs' VM
runner uses virtiofs only on Linux hosts) with `security_model=none`: the
guest sees the host's owners and permissions. `nixos` has UID 501, the first
account's on a Mac, so it owns the Mac user's files there and can write
them. For a Mac account with another UID, write in the shared folder with
`sudo`.

## Telemetry

Determinate Nix collects telemetry and uploads crash reports to Sentry by
default. The guest sets `DETSYS_IDS_TELEMETRY=disabled`, Determinate's
documented opt-out of all of it, for the daemon and for login shells, with
`lib.mkDefault` in `vm.nix`. Determinate's documentation
notes that this also turns off its staged rollout of new features, so some
Determinate Nix features may not be available. To turn telemetry back on, set
`systemd.services.nix-daemon.environment.DETSYS_IDS_TELEMETRY` and
`environment.variables.DETSYS_IDS_TELEMETRY` to another value, or unset the
variable inside the guest.

## Binary cache

Determinate Nix isn't in `cache.nixos.org`. The Cache workflow builds the
guest with Determinate's public cache, `install.determinate.systems`, as an
extra substituter, and pushes the guest's closure, Determinate Nix included,
to `nan.cachix.org`, so the launcher needs only that cache. Recheck on a bump
of the `determinate` input that the guest still boots with builds disabled
(the Cache workflow's smoke test).
