# anoa

On macOS, `anoa` runs the app's copy in Home Manager's, then nix-darwin's app
folder when its executable, `Info.plist` and code-signature seal match the
package's, and falls back to the store bundle.

[Anoa](https://github.com/porcupine-md/anoa-browser), a headless browser with
full CDP support and a command per action for agents, from upstream's prebuilt
releases (MIT). Nothing is compiled.

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

- macOS: upstream's universal `anoa.app`, signed with its Developer ID and
  notarized, untouched in `$out/Applications`, with a `bin/anoa` launcher.
- Linux: upstream's portable bundle (Qt 6 and QtWebEngine), unpatched, run
  through its own `anoa.sh` in an FHS environment that adds the libraries the
  bundle expects from the host (udev, OpenSSL, NSS).

```nix
{ environment.systemPackages = [ inputs.flakes.packages.${system}.anoa ]; }
```

## Updates

Updates come from this flake (`nix flake update flakes`); this package turns
nothing off. `update.sh` follows upstream's latest GitHub release and checks
each archive against GitHub's digest. The install check runs `anoa --version`
and, on macOS, checks `anoa.app`'s whole Developer ID seal (team
`TVFQAT4MZP`), which `checks.<linux>.anoa-codesign` also checks before an
update lands.
