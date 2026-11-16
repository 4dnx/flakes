# telegram

Telegram's official **native macOS client**, not the cross-platform Telegram
Desktop app. The ZIP from `osx.telegram.org` is installed as the untouched
signed `$out/Applications/Telegram.app`, with a `bin/telegram` launcher.
Supports `aarch64-darwin` (Apple Silicon, macOS 11 or later). No compilation.

```nix
home.packages = [ inputs.xr3t.packages.aarch64-darwin.telegram ];
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
Its updater cannot replace a bundle in the read-only Nix store, but may
still check and download updates. Use `nix flake update xr3t` to update the
installed package; avoid using the in-app installer for the store copy.

On a bump, recheck the appcast enclosure, version/build numbers, native
bundle executable and upstream updater behavior. The upstream source and
license are at https://github.com/TelegramMessenger/telegram-macos.
