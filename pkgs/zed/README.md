# zed

[Zed](https://zed.dev/), from the official stable prebuilt releases. Systems:
`aarch64-darwin`, `x86_64-linux` and `aarch64-linux`. No Zed source compilation
or CPU emulation.

- macOS: the official Apple Silicon DMG, installed as the unchanged signed
  `$out/Applications/Zed.app`. `bin/zed` invokes the bundle's official CLI.
  Neither Mach-O executable nor app resources are patched or stripped.
- Linux: the official architecture-specific tarball, with its `zed.app`
  layout and bundled libraries preserved under `$out/libexec/zed`. ELF
  loaders and library paths are adjusted for Nix. The launcher and desktop
  entry use `bin/zed`; Vulkan and window-system libraries come from nixpkgs.

```nix
home.packages = [ inputs.xr3t.packages.${pkgs.stdenv.hostPlatform.system}.zed ];
```

## Settings, updates and telemetry

The Home Manager module extends Home Manager's existing `programs.zed-editor`
options. It selects this flake's package and defaults automatic update
checks, diagnostic submissions and usage metrics to off, for GUI launches
as well as terminal launches:

```nix
imports = [ inputs.xr3t.homeManagerModules.zed ];
programs.zed-editor.enable = true;
```

The defaults are the documented Zed settings `auto_update = false`,
`telemetry.diagnostics = false` and `telemetry.metrics = false`, written to
Zed's `settings.json` through Home Manager. Explicit values in
`programs.zed-editor.userSettings` override them, including `true` to
re-enable checks or telemetry. The module manages that settings file through
Home Manager's normal Zed configuration options; it does not patch the app.

The launcher sets upstream's `ZED_UPDATE_EXPLANATION` package-manager switch.
It prevents updater polling and manual self-update through that launch path,
and explains that updates come through Nix. On macOS, launching `Zed.app`
directly bypasses the launcher environment: the Home Manager settings also
turn off automatic checks for that case. Without the module, the same
settings can be set in Zed's settings file. The store bundle is read-only.

`update.sh` follows GitHub's latest stable release and checks all three
asset downloads against their GitHub SHA-256 digests. New versions go
through update PRs and CI, then are selected with `nix flake update xr3t`
and a configuration rebuild. Updates never replace the app's signed files
in place.

## Checks and maintenance

CI runs the CLI version check on every system. macOS additionally checks
the bundle version, executable and native ARM64 Mach-O slice. Linux checks
the editor's `--help` path to load its libraries and verifies its ELF CPU
architecture. These headless checks do not test rendering or GPU drivers.

On every bump, recheck the release asset names, bundled `bin/zed` and
`libexec/zed-editor` layout, settings keys and `ZED_UPDATE_EXPLANATION` in
upstream's `crates/auto_update/src/auto_update.rs`. The macOS app bundle must
remain untouched to preserve its official code signature.
