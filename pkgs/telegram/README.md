# telegram

On macOS, `telegram` runs the app's copy in Home Manager's, then nix-darwin's
app folder when its executable, `Info.plist` and code-signature seal match the
package's, and falls back to the store bundle.

Telegram's official **native macOS client**, not the cross-platform Telegram
Desktop app. The ZIP from `osx.telegram.org` is installed as the untouched
signed `$out/Applications/Telegram.app`, with a `bin/telegram` launcher.
Supports `aarch64-darwin` (Apple Silicon, macOS 11 or later). No compilation.

```nix
home.packages = [ inputs.f0dnx.packages.aarch64-darwin.telegram ];
```

## Updates and privacy

`update.sh` reads the official stable appcast, compares numeric version/build
pairs instead of its unreliable publication dates, and pins the ZIP's
SHA-256. A new build of the same version is an update too. Updates pass
through a PR. Upstream publishes a Sparkle DSA signature, not a SHA-256
manifest; this updater pins the HTTPS download but does not verify that
signature. The install check verifies the executable, version and build
number without opening the app or signing in.

The native client has a custom updater, not Sparkle's standard automatic
checking scheduler. Upstream's `Telegram-Mac/updater/AppUpdateViewController.swift`
starts its own periodic checks (`resetUpdater`); setting
`SUEnableAutomaticChecks` would not disable that loop. No supported runtime
switch to disable the loop or the app's analytics was found. This package
keeps the signed bundle intact and does not claim to disable either.
Its updater cannot replace a bundle in the read-only Nix store or
nix-darwin's root-owned copy in `/Applications/Nix Apps`, but may still check
and download updates. Home Manager's writable copy in
`~/Applications/Home Manager Apps` (`targets.darwin.copyApps`) it can replace,
and nothing in the app turns it off. The nix-darwin copy is out of its reach,
and `homeManagerModules.read-only-apps` keeps Home Manager's copy read-only
(see the [top-level README](../../README.md#updates)). Use
`nix flake update f0dnx` to update the installed package; avoid using the
in-app installer.

On a bump, recheck the appcast enclosure, version/build numbers, native
bundle executable and upstream updater behavior. The upstream source and
license are at https://github.com/TelegramMessenger/telegram-macos.
