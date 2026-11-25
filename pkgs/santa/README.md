# santa

[Santa](https://northpole.dev), North Pole Security's binary and file access
authorization system for macOS, from upstream's signed, notarized installer
package (Apache-2.0), with a nix-darwin module that installs it as the
package does. Nothing is compiled.

Systems: `aarch64-darwin`, macOS 14 or later. Santa is macOS-only.

The package holds `Santa.app` untouched (`$out/Applications/Santa.app`: the
GUI agent, `santactl`, the helper services and the system extensions) and
`bin/santactl`. The installer's launch job that migrates from Google's Santa
is left out.

## nix-darwin module

```nix
{
  imports = [ inputs.xr3t.darwinModules.santa ];
  services.santa.enable = true;
}
```

| Option | Default | |
|---|---|---|
| `enable` | `false` | Install Santa. |
| `package` | this flake's | The Santa package. |

Santa must live in `/Applications/Santa.app`: its system extension is
loaded from there and installs Santa's launch jobs itself. So the module
doesn't add the package to `environment.systemPackages`; when the installed
copy's build differs from the package's, its activation script does what the
installer's postinstall script does:

- copies `Santa.app` to `/var/db/santa/migration`, owned by `root:wheel`;
- removes `/Applications/Santa.app`. If that works (Santa isn't running), it
  moves the new copy there and runs `Santa --load-system-extension`.
  Otherwise Santa's tamper protection kept it, and `santactl install` asks
  the running Santa to install the staged copy, which it does once its
  signature checks out;
- links `/usr/local/bin/santactl`.

The system extension then installs and loads the GUI agent and the helper
services (`com.northpolesec.santa.*` in `/Library/LaunchAgents` and
`/Library/LaunchDaemons`), as with upstream's package. It also installs the
newsyslog config for Santa's log
(`/private/etc/newsyslog.d/com.northpolesec.santa.newsyslog.conf`) when it is
missing or is one Santa shipped before, and leaves one the admin changed.

The module stops there, as upstream's package does: macOS asks the user to
allow the system extension (System Settings → General → Login Items &
Extensions) and to give it Full Disk Access, unless an MDM installs
upstream's configuration profiles for these
([deployment docs](https://northpole.dev/deployment/getting-started)).
Santa reads its configuration (mode, sync server, rules) only from the
`com.northpolesec.santa` configuration profile; see
[upstream's configuration keys](https://northpole.dev/configuration/keys).

When Google's Santa is still running, the module installs nothing and says
so; upstream's package waits for it to be removed instead. Upgrades from
Santa 2024.10 or 2024.11 in Lockdown mode need the allow rules upstream's
postinstall script adds; the module doesn't add them.

Turning the module off leaves Santa installed: its tamper protection keeps
it. Remove it with upstream's `conf/uninstall.sh` from the release's
`.tar.gz` (`sudo ./uninstall.sh`).

## Updates and telemetry

Santa has no self-update: the installed version changes only when a new
package is installed. Updates come from this flake (`nix flake update xr3t`)
and the module's activation installs them. Santa sends nothing anywhere
unless its configuration names a sync server (`SyncBaseURL`) or a metrics
endpoint (`MetricURL`); neither is set by default.

`update.sh` follows upstream's latest GitHub release and checks the package
against GitHub's digest. The install check and `checks.<linux>.santa-codesign`
check `Santa.app`'s whole Developer ID seal (North Pole Security's team
`ZMCG7MLDV9`), its system extensions and helpers included.
`verify/codesign-check.py` checks each code page against its signed hash itself
for `sleigh`, a Go binary whose layout `rcodesign verify` rejects. Updates
pass through a pull request: the module installs a root system extension.

## Maintenance

On a bump, check that the release still has `santa-<version>.pkg` with one
component `app.pkg` (a gzip cpio payload) holding
`var/db/santa/migration/Santa.app`, and what its `preinstall` and
`postinstall` scripts, upstream's `Conf/install.sh` and the system
extension's `install_services.sh` do (the module mirrors them). Since 2026.10
the payload no longer holds the newsyslog config: it is in the daemon's
system extension (`Contents/Resources`), and `install_services.sh` installs
it.
