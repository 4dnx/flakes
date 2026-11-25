# rex-app

Rex for Mac, the app of [Rex](https://www.superlogical.com/rex/docs),
Superlogical's multiplexer for all work, from upstream's signed, notarized
dmg (unfree). Nothing is compiled: `$out/Applications/Rex.app` is upstream's
bundle, untouched.

Systems: `aarch64-darwin`, macOS 15 or later. The bundle is universal; this
flake declares only Apple Silicon.

The app runs its own Rex server (`Contents/Helpers/Rex Server.rex`), whose
version the release notes of each build name (build 2116 holds server
0.1.0-preview.23). The `rex` command for the shell is the separate
[`rex`](../rex) package; the two don't need to be the same version.

```nix
{ environment.systemPackages = [ inputs.xr3t.packages.aarch64-darwin.rex-app ]; }
```

Rex is in testing. The package follows the app's preview channel, the feed
the app reads by default: every build so far is 0.1.0, so the package's
version is the bundle version and the build (`0.1.0-2116`).

## Updates and telemetry

Upstream's [privacy page](https://www.superlogical.com/rex/docs/reference/privacy.md)
says Rex for Mac collects no telemetry and has no crash reporting of its own.
Its only connection to Superlogical is the update check.

The app checks for updates with Sparkle at launch and once a day, and upstream
says that check can't be turned off. Nothing in this package turns it off: the
app supplies its feed itself (`feedURLStringForUpdater:`, by its update
channel, preview or snapshot) and sets Sparkle's automatic checks itself
(`setAutomaticallyChecksForUpdates:`), so no preference, in the user's
defaults or a configuration profile, is known to hold. Whether it downloads
and installs updates on its own is set in Settings > General > App Version
(the info button beside Update Channel); that is off unless the user turns it
on.

The updater can't replace the read-only Nix store bundle or nix-darwin's
root-owned copy in `/Applications/Nix Apps`. It can replace Home Manager's
writable copy in `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`), unless `homeManagerModules.read-only-apps` keeps
it read-only (see the [top-level README](../../README.md#updates)). Only the
network stops the check itself:
[`firewall/updaters.lsrules`](../../firewall) denies the app
`blob.superlogical.com`, its feed and download host, which it uses for nothing
else.

`update.sh` follows the preview appcast
(`https://blob.superlogical.com/public/rex-app/preview/appcast.xml`) and
checks each dmg against the Sparkle EdDSA signature the feed lists, by the key
pinned in `sparkle-ed25519.pub`, as Sparkle does before it installs an update.
The install check (on macOS) and `checks.<linux>.rex-app-codesign` check
`Rex.app`'s whole Developer ID seal (Superlogical's team `AG92C3PT77`), the
server and Sparkle included; the install check also checks that the app
still names the pinned key. Updates pass through a pull request: Rex runs
shells and agents with the user's access.

## Maintenance

On a bump, recheck that the feed still lists `Rex-<version>-<build>.dmg` at
the same path, that `Rex.app` is still at `Rex/Rex.app` in the dmg, and
whether the app still supplies its feed and sets its automatic checks
itself. If upstream rotates its Sparkle key, the install check fails; check
the new key against an app build signed by team `AG92C3PT77` before pinning
it.
