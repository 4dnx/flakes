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
the user, and Sparkle can replace that copy while its automatic installation
is on.

### Update check

WhatsApp's update check can't be turned off. The app and its Sparkle plugin
start checks themselves (`checkForUpdatesInBackground`,
`checkForUpdatesWithIsCurrentBuildExpired:…`), which `SUEnableAutomaticChecks`
doesn't stop; that key only turns off Sparkle's own scheduled check. The plugin also adds its own
parameters to the appcast request (`feedParametersForUpdater:`). A firewall
rule can't single out the check: the appcast is on `web.whatsapp.com`, which
serves more than updates (see `firewall/README.md`).

### Automatic installation

The plugin also turns Sparkle's scheduled check and automatic installation
back on whenever it starts (`setAutomaticallyChecksForUpdates:`,
`setAutomaticallyDownloadsUpdates:`). The app is sandboxed, so its
preferences live in
`~/Library/Containers/net.whatsapp.WhatsApp/Data/Library/Preferences`, not in
`~/Library/Preferences`: `defaults write net.whatsapp.WhatsApp` doesn't
reach them, and the plugin would overwrite them anyway. Managed preferences
take precedence over both, and macOS fills them only from a configuration
profile the user approves, so no module can install it. The package ships
one, `share/whatsapp/disable-auto-updates.mobileconfig`, which forces
`SUAutomaticallyUpdate` and `SUEnableAutomaticChecks` off: Sparkle then asks
before installing an update a check finds, instead of installing it on its
own. nix-darwin's per-user profiles (Home Manager with `useUserPackages`)
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
as unsigned, "WhatsApp: updates through Nix"). The managed values show in
`/Library/Managed Preferences/$USER/net.whatsapp.WhatsApp.plist`. To turn
automatic installation back on, remove the profile there.

### Read-only Home Manager copy

The Home Manager module installs the package and keeps Home Manager's copy
read-only:

```nix
imports = [ inputs.xr3t.homeManagerModules.whatsapp ];
programs.whatsapp.enable = true;
```

With `targets.darwin.copyApps` on, it makes
`~/Applications/Home Manager Apps/WhatsApp.app` read-only (`chmod -R a-w`)
after every copy, so an updater running as the user can't write to, delete or
move the bundle without first changing its permissions back. Activation makes the copy
writable again just before Home Manager's App Management check and copy,
which write into it, and then locks the new copy; it does that while
`programs.whatsapp.enable` is false too, so the copy can be removed. With the
module dropped from the imports, nothing unlocks the copy and Home Manager's
copy fails to delete it (`cannot delete non-empty directory`); make it
writable before switching:

```sh
chmod -R u+w ~/Applications/Home\ Manager\ Apps/WhatsApp.app
```

The module's former `programs.whatsapp.checkUpdates` option is removed: the
keys it wrote went to `~/Library/Preferences`, which the sandboxed app
doesn't read.

### Telemetry

Sparkle's optional system profile (`SUSendProfileInfo`) is off: Sparkle
leaves it off by default, the bundle's `Info.plist` doesn't turn it on, and
neither the app nor its plugin sets it. No supported application-wide
WhatsApp telemetry switch was found in its published settings or bundle;
this package does not claim to disable the messenger's own analytics or
communication with Meta.

### Rechecking on a bump

The appcast URL, bundle identifier, Sparkle preference keys, whether the
plugin still sets them and starts checks itself, whether the app is still
sandboxed, and the app's minimum macOS version. Keep the app bundle
untouched to preserve its code signature.
