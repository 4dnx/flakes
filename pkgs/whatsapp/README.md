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

Use the Home Manager module to seed Sparkle's automatic update check,
automatic installation and system-profile submission to off:

```nix
imports = [ inputs.xr3t.homeManagerModules.whatsapp ];
programs.whatsapp.enable = true;
```

The module writes `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate` and
`SUSendProfileInfo` to `net.whatsapp.WhatsApp` only while each preference is
absent and the app is closed. Existing preferences are respected. Change a
preference with `defaults write net.whatsapp.WhatsApp <key> -bool true` to
re-enable it. Without the module, set those preferences by hand before
launching. Updates come through `nix flake update xr3t`. The embedded
updater cannot replace the read-only Nix store bundle or nix-darwin's
root-owned copy in `/Applications/Nix Apps`, but it can replace Home Manager's
writable copy in `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`) while these preferences are on.

`SUSendProfileInfo` controls Sparkle's optional system profile only. No
supported application-wide WhatsApp telemetry switch was found in its
published settings or bundle; this package does not claim to disable the
messenger's own analytics or communication with Meta.

On every bump, recheck the appcast URL, bundle identifier, Sparkle preference
keys and the app's minimum macOS version. Keep the app bundle untouched to
preserve its code signature.
