# kiri

[Kiri](https://runkiri.com), a small container runtime (one Rust daemon and a
lightweight VM) that brings its own `docker` CLI, Compose and buildx, from
upstream's signed, notarized `Kiri.app`. `$out/Applications/Kiri.app` is the
bundle unchanged, with `bin/kiri` linked to its binary. Nothing is compiled.

Systems: `aarch64-darwin`, macOS 14 or later. Upstream also ships an Intel
app, Windows and Linux builds; this flake doesn't package them yet.

```nix
imports = [ inputs.f0dnx.homeManagerModules.kiri ];
programs.kiri.enable = true;
```

or just the package, in `environment.systemPackages` (nix-darwin) or
`home.packages`. Home Manager-managed shells require the module for the
first-launch integration described below.

## Setup

Kiri sets itself up when the app opens, as its own installer does (`kiri
setup`): a LaunchAgent that starts `kiri daemon` at login, `docker` and `kiri`
in `~/.kiri/bin` (appended to `PATH` in the shell profiles), a `kiri` docker
context, a buildx builder, and, given an administrator password once,
`*.kiri.local` names and `/var/run/docker.sock`. `kiri setup --uninstall`
takes them back.

Kiri 0.2.1 writes shell profiles before opening its window. Home Manager's
profiles are read-only, so this fails with `Permission denied (os error 13)`.
The module adds Kiri's PATH entry and exact setup marker to the profiles of
enabled Home Manager-managed zsh and bash, and to `fish/conf.d/kiri.fish`
for fish. Kiri recognizes the marker and skips writing those files. Shells
are not enabled by the module; unmanaged profiles remain upstream's to edit.
The PATH entry appends `~/.kiri/bin`, preserving existing command priority.

The LaunchAgent and the links name the binary of the copy that was opened:
the store path, nix-darwin's `/Applications/Nix Apps` or Home Manager's
`~/Applications/Home Manager Apps`. A newly opened copy of Kiri replaces those
of the one before, so after an update, or after moving the install, open the
app once; until then the daemon at login is the old version (or none, if the
old copy is gone).

## Integrity

`update.sh` follows the release feed the app's updater reads
(`download.runkiri.com/latest-mac-arm64.json`) and checks the tar.gz against
the SHA-256 it lists. The bundle's Apple code signature is checked too,
without macOS (`verify/codesign-check.py`): every file matches the seal, and the
app is signed by the Developer ID of team `Z44N5GDT9Q`, the maintainer who
signs Kiri's release tags, chaining to Apple's root CA. The macOS install
check runs it on the installed bundle and `checks.<linux>.kiri-codesign` on
the pinned download. Updates pass through a pull request.

The archive, made on a Mac, carries AppleDouble files (`._*`) that only a
Mac's tar folds back into extended attributes; they aren't part of the app
and aren't unpacked.

## Updates and telemetry

Kiri checks its feed when the window opens and every 6 hours, and offers to
install a newer app; `kiri update` installs it at once. The updater stages
the new app in `.kiri-update/` beside the running one and swaps it in by
renaming, so it can't replace the read-only store copy or nix-darwin's
root-owned copy in `/Applications/Nix Apps`. Home Manager's copy in
`~/Applications/Home Manager Apps` (`targets.darwin.copyApps`) is writable:
`kiri update` replaces it in place, and the next activation copies the pinned
version back. `homeManagerModules.read-only-apps` keeps that copy read-only
(see the [top-level README](../../README.md#updates)). Updates come through this flake (`nix flake update f0dnx`). The
module installs the package with Home Manager; to keep its shell integration
and settings with the app in `environment.systemPackages`, set
`programs.kiri.package = null`.

The Home Manager module turns **Settings › Check for updates automatically**
off, through its key (`updateAuto`) in `~/.kiri/ui.json`, on every
activation, so turning it back on in Settings lasts until the next one;
`programs.kiri.checkUpdates = true` leaves it to Kiri. It writes the key
only into a file the app has made: Kiri takes a missing file for its first
start. So the check stays on until the first activation after Kiri is first
opened. This is the app's own setting, not a documented redistribution switch;
recheck it on a bump.

Telemetry: none found. Crash reports are off unless turned on in
Settings, and the code sends nothing else to an analytics service.

## Rechecking on a bump

The feed's layout and URL pattern, the bundle identifier and minimum macOS
version, the signing team, the `updateAuto` key and the settings file's
location, the shell-profile marker and PATH entry in `setup.rs`, and what
`kiri setup` installs.
