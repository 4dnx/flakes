# google-chrome

On macOS, `google-chrome` runs the app's copy in Home Manager's, then
nix-darwin's app folder when its executable, `Info.plist` and code-signature
seal match the package's, and falls back to the store bundle.

Google Chrome's latest Stable release for macOS, from Google's signed,
notarized universal dmg, installed untouched as
`$out/Applications/Google Chrome.app` with a `bin/google-chrome` wrapper.
Nothing is compiled. Unfree: this flake's own `packages` allow it; through the
overlay, the consuming nixpkgs config has to allow `google-chrome`.

## Updates

`update.sh` takes the newest version Google serves to at least half of Stable
users (the versionhistory API) and its download URL from Google's update
server, and never downgrades. It downloads the dmg (~280 MB) to hash it.

Chrome's updater, Google's GoogleUpdater, can't replace the copy in the
read-only Nix store or nix-darwin's root-owned copy in `/Applications/Nix Apps`,
so updates come from this flake (`nix flake update xr3t`). Chrome may still
install Google's updater under `~/Library` on first launch and show an update
notice. Home Manager's writable copy in `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`) is within that updater's reach unless
`homeManagerModules.read-only-apps` keeps it read-only (see the
[modules README](../../modules/README.md#read-only-apps)), and nothing in the package turns the updater off: GoogleUpdater reads its `updatePolicies`
(`UpdateDefault`) only from managed preferences, and only on a Mac enrolled in
MDM (`profiles status -type enrollment`). Chrome's **Set Up Automatic Updates
for All Users** installs a system-wide updater that runs as root and could
replace either copy.

On Linux use nixpkgs' `google-chrome`.
