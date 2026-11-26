# firefox

On macOS, `firefox` runs the app's copy in Home Manager's, then nix-darwin's
app folder when its executable, `Info.plist` and code-signature seal match the
package's, and falls back to the store bundle.

Mozilla Firefox, the latest release, from Mozilla's own builds (en-US;
other languages install as language packs from within Firefox). Nothing is
compiled:

- macOS: Mozilla's signed, notarized universal `Firefox.app` from the
  release dmg, untouched (`dontFixup`), in `$out/Applications`, with a
  `bin/firefox` launcher.
- Linux: the release tarball, linked against the store's libraries and run
  through nixpkgs' `wrapFirefox`, as nixpkgs' `firefox-bin` is: the libraries
  Firefox loads at run time, the desktop entry and icons, `policies.json` and
  autoconfig prefs.

Systems: `aarch64-darwin` (macOS 10.15 or later), `x86_64-linux`,
`aarch64-linux`. The binaries come under the Firefox Terms of Use, which
nixpkgs counts as unfree (the code itself is MPL-2.0): this flake's own
`packages` allow them; through the overlay, the consuming nixpkgs config has
to allow `firefox` and `firefox-unwrapped`.

nixpkgs packages the same Mozilla builds as `firefox-bin`; this package
follows Mozilla's releases directly, on the day they ship.

## Usage

```nix
home.packages = [ inputs.flakes.packages.${pkgs.stdenv.hostPlatform.system}.firefox ];
```

The Linux package is a `wrapFirefox` wrapper, so NixOS' and Home Manager's
`programs.firefox` take it as their `package` and add their policies, prefs
and native messaging hosts through its `override`:

```nix
# NixOS
programs.firefox = {
  enable = true;
  package = inputs.flakes.packages.x86_64-linux.firefox;
};
```

The Home Manager module `homeManagerModules.firefox` extends Home Manager's
own `programs.firefox`: it sets this flake's Firefox as its `package` (a
default) and, on macOS, the policies below.

```nix
{
  imports = [ inputs.flakes.homeManagerModules.firefox ];
  programs.firefox.enable = true;
}
```

## Updates and telemetry

Firefox's own updater can't replace the copy in the read-only Nix store or
nix-darwin's root-owned copy in `/Applications/Nix Apps`, but it can replace
Home Manager's writable copy in `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`); on macOS the Home Manager module's
`DisableAppUpdate` (below) turns it off. Updates come from this flake
(`nix flake update flakes`).

On Linux the package turns the update check off with Mozilla's documented
`DisableAppUpdate` policy (in the wrapper's `policies.json`; the wrapper's
`is-packaged-app` marker turns it off as well). Telemetry is off by
default: the wrapper's autoconfig file (`mozilla.cfg`) sets, as default
values (`defaultPref`), `datareporting.healthreport.uploadEnabled` (technical
and interaction data), `datareporting.usage.uploadEnabled` (the daily usage
ping) and `app.shield.optoutstudies.enabled` (studies) to `false`. A value
the user sets wins: the checkboxes under Settings → Privacy & Security →
Firefox Data Collection and Use, `about:config`, or a `user.js`. A policy
from NixOS' or Home Manager's `programs.firefox.policies` is added to these;
a `/etc/firefox/policies/policies.json` replaces the package's
`policies.json` altogether, so it should set `DisableAppUpdate` too.

On macOS nothing inside the signed bundle can change, and Firefox there has
no wrapper, so the plain package keeps upstream's defaults: it checks for
updates and sends telemetry. Firefox reads policies from the
`org.mozilla.firefox` defaults domain, the user's included, once
`EnterprisePoliciesEnabled` is set there. The Home Manager module sets,
through Home Manager's `programs.firefox.policies`:

- `DisableAppUpdate = true`: no update checks;
- `DisableTelemetry = true`, a default: `programs.firefox.policies.DisableTelemetry = false`
  turns telemetry back on. As a policy it also locks the setting in Firefox.

Without Home Manager, the same by hand:

```sh
defaults write org.mozilla.firefox EnterprisePoliciesEnabled -bool true
defaults write org.mozilla.firefox DisableAppUpdate -bool true
defaults write org.mozilla.firefox DisableTelemetry -bool true
```

`about:policies` lists the policies in effect.

`update.sh` follows Mozilla's latest release (product-details, as
firefox.com offers it) and checks every download against the release's
`SHA256SUMS`, whose signature by Mozilla's release key
(`14F26682D0916CDD81E37B6D61B7B526D98F0353`) it checks first. On macOS, the
install check and `checks.<linux>.firefox-codesign` check the bundle's whole
Developer ID seal (Mozilla's team `43AQ936H96`).

## Maintenance

On a bump, check that the release directory still has
`mac/en-US/Firefox <version>.dmg` and
`linux-{x86_64,aarch64}/en-US/firefox-<version>.tar.xz`, that the bundle is
still `Firefox.app` with executable `firefox` and bundle identifier
`org.mozilla.firefox`, that the three telemetry prefs still exist under these
names (`greprefs.js` and `defaults/preferences` in `omni.ja`), and that
nixpkgs' `firefox-bin` still links the tarball against the same libraries.
