# utm

On macOS, `UTM` and `utmctl` run the app's copy in Home Manager's, then
nix-darwin's app folder when its executable, `Info.plist` and code-signature
seal match the package's, and fall back to the store bundle.

[UTM](https://mac.getutm.app/) from upstream's release `UTM.dmg`, as
`$out/Applications/UTM.app` plus `bin/UTM` and `bin/utmctl` launchers. Nothing
is compiled: the derivation only unpacks the dmg and copies the signed,
notarized bundle, left untouched (`dontFixup`). Unlike nixpkgs' `utm`, which
lags upstream, `update.sh` bumps it to the latest upstream (non-pre-)release.
Upstream re-releases a version as `vX.Y.Z-N` (`v5.0.9-2`); such a release is
pinned as its version, and the install check compares the app's own version
(`appVersion`, `5.0.9`).

macOS only (universal binary, macOS 12+). Home Manager and nix-darwin link
`Applications/*.app` into the usual app folders.
