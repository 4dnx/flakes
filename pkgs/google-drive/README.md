# google-drive

Google Drive for desktop for macOS, from Google's signed, notarized
universal installer, with a nix-darwin module that installs it into
`/Applications` as Google's installer does. Nothing is compiled. Unfree:
this flake's own `packages` allow it; through the overlay, the consuming
nixpkgs config has to allow `google-drive`.

Systems: `aarch64-darwin`, macOS 13 or later. Google ships no Linux build,
so Linux is unsupported.

The dmg is APFS, which `undmg` can't read: 7-Zip takes the APFS partition
out of it and `apfs-cat.py` (with `dissect.apfs`) the installer package out of
the partition. The installer holds four components:

- Google Drive for Apple Silicon: installed, untouched, as
  `$out/Applications/Google Drive.app`;
- Google Drive for Intel: left out;
- Google's updater (GoogleUpdater, Keystone): left out, updates come from
  Nix;
- shortcuts to the Docs, Sheets and Slides web apps (scripts that open them
  in a browser): left out.

## nix-darwin module

```nix
{
  imports = [ inputs.f0dnx.darwinModules.google-drive ];
  programs.google-drive.enable = true;
}
```

| Option | Default | |
|---|---|---|
| `enable` | `false` | Install Google Drive. |
| `package` | this flake's | The Google Drive package. |
| `automaticErrorReporting` | `false` | Error reports to Google (below). |

Google's installer puts the app in `/Applications/Google Drive.app` and its
postinstall script makes `Contents/MacOS/mount_helper` setuid root, which
the Nix store can't hold. So the module doesn't add the package to
`environment.systemPackages`; its activation script copies the app there as
a real directory owned by `root:wheel`, sets that bit and, as the
postinstall script does, refreshes Quick Look (`qlmanage -r`) and asks a
running Google Drive to restart (`SIGUSR1`). It copies the app again when
the package changes, or when the installed copy is no longer the one it put
there (its seal's sha256 is recorded in `/var/db/xr3t-google-drive`), such as
after Google's updater or installer replaced it. A copy already there from
Google's installer is replaced too.

With the module imported and `enable = false`, activation removes the app
again, but only if it is still the copy this module installed. Removing the
module's import altogether leaves the app in place; remove it by hand with
`sudo rm -rf "/Applications/Google Drive.app" /var/db/xr3t-google-drive`.

## Updates and telemetry

Google Drive updates through Google's updater (Google Software Update,
GoogleUpdater), which its installer installs and registers it with. The
package and module leave the updater out, and don't register Google Drive
with it, so nothing updates the copy in `/Applications`; new releases come
through this flake (`nix flake update f0dnx`). Google documents no Drive
setting that turns updates off. If Google's updater is on the machine
anyway (from an earlier install by Google's installer, or another Google
app), it may still hold a registration for Google Drive; remove it with
`sudo "/Library/Google/GoogleSoftwareUpdate/GoogleSoftwareUpdate.bundle/Contents/MacOS/ksadmin" --delete --productid com.google.drivefs`.
A copy it replaces anyway is put back at the next activation. Google says it
may disable Drive releases older than twelve months, so the flake input
needs updating regularly.

Error reports: `automaticErrorReporting = false` (the default) writes
`AutomaticErrorReporting = false` to `/Library/Preferences/com.google.drivefs.settings`,
Google's host-wide settings domain, which a user's own settings
(`~/Library/Preferences/com.google.drivefs.settings`) override, as Google
documents for its settings. The key is one the app reads among its
documented settings, but Google doesn't document it: recheck it on every
bump. `true` writes `true`; `null` writes nothing and leaves a value written
earlier in place (`sudo defaults delete /Library/Preferences/com.google.drivefs.settings AutomaticErrorReporting`
removes it). No other telemetry setting was found.

## Integrity

`update.sh` asks Google's update server (Omaha, as Google's updater does)
for the release it serves a new Apple Silicon install, and checks the
download against the sha256 the server lists. The package checks the
installer's signature by Google's Developer ID Installer certificate (team
`EQHXZ8M8AV`) and every file in it (`verify/pkg-signature-check.py`), and
the
installed app's whole Developer ID seal (`verify/codesign-check.py`);
`checks.<linux>.google-drive-codesign` runs the same on Linux, so an update
is checked before it reaches a Mac. Updates pass through a pull request, as
the module installs a setuid-root helper.

## Maintenance

On a bump, check that the dmg's APFS volume still holds `GoogleDrive.pkg`,
that its components are still `GoogleDrive_arm64.pkg` (a pbzx payload with
`Google Drive.app` at its root) and the others above, what the components'
`preinstall` and `postinstall` scripts do (the module mirrors them), and
that the app still reads `AutomaticErrorReporting`
(`strings "Google Drive.app/Contents/MacOS/Google Drive"`).
