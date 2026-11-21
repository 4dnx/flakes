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

Updates come through `nix flake update xr3t`. The embedded Sparkle updater
cannot replace the read-only Nix store bundle or nix-darwin's root-owned copy
in `/Applications/Nix Apps`. Home Manager copies the app into
`~/Applications/Home Manager Apps` (`targets.darwin.copyApps`) writable by
the user, and without the module below Sparkle can replace that copy while
its automatic installation is on.

The Home Manager module turns Sparkle's automatic update check and automatic
installation off:

```nix
imports = [ inputs.xr3t.homeManagerModules.whatsapp ];
programs.whatsapp.enable = true;
```

It sets `SUEnableAutomaticChecks` and `SUAutomaticallyUpdate` to false in
`net.whatsapp.WhatsApp` on every activation (`targets.darwin.defaults`),
whatever the domain held, and writes `SUSendProfileInfo` = false only while
it is absent. `programs.whatsapp.checkUpdates = true` leaves the update check
to the app; automatic installation stays off.

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

WhatsApp's Sparkle plugin sets the check and automatic installation itself
(`setAutomaticallyChecksForUpdates:`, `setAutomaticallyDownloadsUpdates:`),
so they can be back on after the app starts, until the next activation. User
preferences can't hold them; managed preferences can, and macOS fills those
only from a configuration profile the user approves, so no module can
install it. The package ships one,
`share/whatsapp/disable-auto-updates.mobileconfig`, which forces both keys
off. nix-darwin's per-user profiles (Home Manager with `useUserPackages`)
link only the paths in `environment.pathsToLink`, so a nix-darwin
configuration adds the folder there first:

```nix
environment.pathsToLink = [ "/share/whatsapp" ];
```

```sh
# installed with nix-darwin's Home Manager module and useUserPackages
open /etc/profiles/per-user/$USER/share/whatsapp/disable-auto-updates.mobileconfig
# installed with standalone Home Manager
open ~/.nix-profile/share/whatsapp/disable-auto-updates.mobileconfig
```

Then approve it in System Settings → General → Device Management (it shows
as unsigned, "WhatsApp: updates through Nix"). To turn the updater back on,
remove the profile there and set `programs.whatsapp.checkUpdates = true`.
Without the module, install the profile, or set the keys with
`defaults write net.whatsapp.WhatsApp <key> -bool false` before launching.

`SUSendProfileInfo` controls Sparkle's optional system profile only. No
supported application-wide WhatsApp telemetry switch was found in its
published settings or bundle; this package does not claim to disable the
messenger's own analytics or communication with Meta.

On every bump, recheck the appcast URL, bundle identifier, Sparkle preference
keys, whether the plugin still sets them itself and the app's minimum macOS
version. Keep the app bundle untouched to
preserve its code signature.
