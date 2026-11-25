# claude-desktop

On macOS, `claude-desktop` runs the app's copy in Home Manager's, then
nix-darwin's app folder when its executable, `Info.plist` and code-signature
seal match the package's, and falls back to the store bundle.

Claude Desktop for macOS (Claude, Claude Code and Cowork in one app), from
upstream's signed, notarized universal zip. `$out/Applications/Claude.app`
is the bundle unchanged, with a `bin/claude-desktop` launcher. Nothing is
compiled. Unfree: overlay users must allow `claude-desktop` in their nixpkgs
configuration.

Systems: `aarch64-darwin`, macOS 13 or later. Upstream also ships Linux
`.deb` builds (beta); this flake doesn't package them yet.

```nix
# nix-darwin
environment.systemPackages = [ inputs.fordnx.packages.aarch64-darwin.claude-desktop ];
# or Home Manager
home.packages = [ inputs.fordnx.packages.aarch64-darwin.claude-desktop ];
```

## Integrity

Upstream's release feed (`RELEASES.json`, what the app's own updater reads)
publishes no checksum, so the pinned zip is checked through the bundle's own
Apple code signature, without macOS (`verify/codesign-check.py`, with
`rcodesign` and `openssl`):

- every Mach-O in the bundle (the app, its helpers, frameworks and tools)
  carries a valid signature by a Developer ID Application certificate of
  Anthropic's team `Q6L2SF6YDW` that chains to Apple's root CA;
- `Info.plist` and the seal (`_CodeSignature/CodeResources`) match the hashes
  in the app's signed code directory, and every file the seal lists matches,
  `Resources/app.asar` (the app's code) included; nested bundles and tools
  match the cdhash the seal records;
- no file sits outside the seal, except those Apple's rules omit and the
  stapled notarization ticket.

The macOS install check runs this on the installed bundle and
`checks.<linux>.claude-desktop-codesign` on the pinned download, so an
update that fails it never reaches a Mac. Updates pass through a pull
request.

## Updates and telemetry

Claude Desktop updates itself with Squirrel.Mac, and its Code tab also
downloads and updates the Claude Code binary it runs. Its updater can't
replace the read-only store copy or nix-darwin's root-owned, read-only copy in
`/Applications/Nix Apps`, but it still checks for and downloads updates; Home
Manager's writable copy in `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`) it could replace, unless
`homeManagerModules.read-only-apps` keeps it read-only (see the
[top-level README](../../README.md#updates)). Updates belong to this flake
(`nix flake update fordnx`).

Upstream's documented switch is `disableAutoUpdates` in the
`com.anthropic.claudefordesktop` domain
([enterprise configuration](https://support.claude.com/en/articles/12622667-enterprise-configuration-for-claude-desktop)).
It turns off both the app's and the Code tab's automatic updates. The app
reads it only from managed preferences (`/Library/Managed Preferences`),
which macOS fills from a configuration profile, not from `defaults write`.
macOS requires the user to approve a profile, so no module can install it;
the package ships one, `share/claude-desktop/disable-auto-updates.mobileconfig`.
nix-darwin's system profile and its per-user profiles (Home Manager with
`useUserPackages`) link only the paths in `environment.pathsToLink`, so a
nix-darwin configuration adds the folder there first:

```nix
environment.pathsToLink = [ "/share/claude-desktop" ];
```

```sh
# installed with nix-darwin
open /run/current-system/sw/share/claude-desktop/disable-auto-updates.mobileconfig
# installed with nix-darwin's Home Manager module and useUserPackages
open /etc/profiles/per-user/$USER/share/claude-desktop/disable-auto-updates.mobileconfig
# installed with standalone Home Manager (~/.local/state/nix/profile with use-xdg-base-directories)
open ~/.nix-profile/share/claude-desktop/disable-auto-updates.mobileconfig
```

Then approve it in System Settings → General → Device Management (it shows
as unsigned, "Claude Desktop: updates through Nix"). To turn updates back on,
remove the profile there.

As upstream documents, setting any of its policy keys also hides the app's
**Release channel** setting and keeps the app on Stable. The `RELEASES.json`
feed this package follows is the stable one.

Telemetry: Claude Desktop's telemetry switches (`disableNonessentialTelemetry`
and the like) apply only to its third-party-inference mode; for a Claude.ai
account no client-side switch was found, so this package doesn't claim to
turn telemetry off. The account's privacy settings on claude.ai still apply.

## Rechecking on a bump

The feed's layout and URL pattern, the bundle identifier and minimum macOS
version, the signing team, the `disableAutoUpdates` key and where the app
reads managed preferences from, and whether a Claude.ai account gains a
telemetry switch.
