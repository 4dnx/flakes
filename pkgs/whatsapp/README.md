# whatsapp

The official native WhatsApp for macOS, downloaded as a ZIP from
`web.whatsapp.com`. The signed `WhatsApp.app` is installed unchanged under
`$out/Applications`, with a `bin/whatsapp` launcher. No compilation.
Supports `aarch64-darwin`, macOS 12.1 or later. Unfree: overlay users must
allow `whatsapp` in their nixpkgs configuration.

```nix
home.packages = [ inputs.xr3t.packages.aarch64-darwin.whatsapp ];
```

## Updates and privacy

`update.sh` follows WhatsApp's official stable Sparkle appcast and pins the
ZIP's SHA-256, version and bundle build number. Updates pass through a PR.
Upstream publishes an Ed25519 appcast signature, not a SHA-256 manifest;
the updater pins the HTTPS download and does not verify that signature.
The install check verifies the executable, version and build number without
opening the app or logging into an account.

Updates come through `nix flake update xr3t`. Nothing in the package turns
the embedded updater off. WhatsApp's Sparkle plugin (`MacPlugin.bundle`)
supplies its feed URL itself (`feedURLStringForUpdater:`,
`https://web.whatsapp.com/desktop/mac_native/updates`), sets
`SUEnableAutomaticChecks` and `SUAutomaticallyUpdate` back to true when the
app starts (`setAutomaticallyChecksForUpdates:`,
`setAutomaticallyDownloadsUpdates:`) and checks the feed a few seconds after
every launch, not on Sparkle's daily schedule. The check happens whatever
those keys hold, in the user's preferences or forced through managed
preferences (a configuration profile). So the app offers an update whenever
upstream has released one this flake hasn't picked up yet; it stays quiet
while the pinned version is the newest.

The updater cannot replace the read-only Nix store bundle or nix-darwin's
root-owned copy in `/Applications/Nix Apps`. Home Manager copies the app into
`~/Applications/Home Manager Apps` (`targets.darwin.copyApps`) writable by
the user; the Home Manager module below makes that copy read-only. Without
the module, install it with nix-darwin (`environment.systemPackages`) to keep
it out of the updater's reach, or decline the update. Only the network can stop the check: a firewall rule
that denies the app `web.whatsapp.com` (WhatsApp Web in a browser is a
different process and isn't affected).

The Home Manager module installs the app and writes `SUSendProfileInfo` =
false only while it is absent:

```nix
imports = [ inputs.xr3t.homeManagerModules.whatsapp ];
programs.whatsapp.enable = true;
```

With `targets.darwin.copyApps` on, the module also makes Home Manager's copy,
`~/Applications/Home Manager Apps/WhatsApp.app`, read-only (`chmod -R a-w`)
after every copy, so an updater running as the user can't write to, delete or
move the bundle without first changing its permissions back. Activation makes
the copy writable again just before Home Manager's App Management check and
copy, which write into it, and then locks the new copy; it does that while
`programs.whatsapp.enable` is false too, so the copy can be removed. With the
module dropped from the imports, nothing unlocks the copy and Home Manager's
copy fails to delete it (`cannot delete non-empty directory`); make it
writable before switching:

```sh
chmod -R u+w ~/Applications/Home\ Manager\ Apps/WhatsApp.app
```

`SUSendProfileInfo` controls Sparkle's optional system profile only. No
supported application-wide WhatsApp telemetry switch was found in its
published settings or bundle; this package does not claim to disable the
messenger's own analytics or communication with Meta.

On every bump, recheck the appcast URL, bundle identifier, Sparkle preference
keys, whether the plugin still supplies the feed and checks on launch
whatever they hold, and the app's minimum macOS version. Keep the app bundle
untouched to preserve its code signature.
