# Flakes

Nix packages by `Prompter`.

> [!WARNING]
> **DYOR (Do Your Own Research).** These packages are written largely with AI
> agents and provided as-is, without warranty. Upstream binaries are fetched
> from their official release pages and pinned by hash, but that only proves
> the download is unchanged, not that the program is safe. Read the package
> definition and the upstream project before installing, especially anything
> that runs as a system service or with root privileges.
>
> See [SECURITY.md](SECURITY.md) for what the pins and checks cover, and to
> report a vulnerability.

## Usage

The flake targets three setups: **nix-darwin** on Apple Silicon Macs,
**NixOS**, and **Ubuntu** (or another Linux distribution) with Nix and,
optionally, standalone Home Manager. Packages that don't run on a system are
left out of `packages.<system>`; the [package table](pkgs/README.md) and each
package's README say which systems it supports.

Try Codex without installing it in a profile:

```sh
nix run github:xr3t/flakes#codex -- --version
```

Add it as an input. Its nixpkgs, nix-darwin and Home Manager come from
FlakeHub. Its `nix-darwin`, `home-manager` and `determinate` inputs are used
only by its own checks, which evaluate the modules on a system running
Determinate Nix, and `determinate` also by the `nixos-shell` guest; they are
never fetched otherwise. Pointing them at existing
inputs with `follows` keeps a single copy of each in the lock file:

```nix
inputs = {
  nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
  flakes = {
    url = "github:xr3t/flakes";
    inputs.nixpkgs.follows = "nixpkgs";
    # inputs.nix-darwin.follows = "nix-darwin";
    # inputs.home-manager.follows = "home-manager";
    # inputs.determinate.follows = "determinate";
  };
};
```

Packages come straight from the flake (built against its pinned nixpkgs,
with its unfree packages allowed) or from the overlay, as `pkgs.flakes.<name>`,
built against the configuration's own nixpkgs; unfree ones then need that
nixpkgs' config to allow them (`nixpkgs.config.allowUnfreePredicate`).

### nix-darwin

The modules are checked on a nix-darwin system running
[Determinate Nix](https://docs.determinate.systems), with Determinate's
nix-darwin module (`determinate.url =
"https://flakehub.com/f/DeterminateSystems/determinate/3"`), which leaves
`/etc/nix/nix.conf` to Determinate Nix:

```nix
darwinConfigurations.example = nix-darwin.lib.darwinSystem {
  modules = [
    determinate.darwinModules.default
    flakes.darwinModules.rayfish
    {
      determinateNix.enable = true;
      nixpkgs.hostPlatform = "aarch64-darwin";
      environment.systemPackages = [ flakes.packages.aarch64-darwin.ghostty ];
      services.rayfish.enable = true;
    }
  ];
};
```

`darwinModules` hold the system services (launchd daemons),
`microsoft-office`, which installs the selected Office apps with the root
licensing helper they share, `google-drive`, which installs Google Drive into
`/Applications` with its setuid mount helper, and `santa`, which installs
Santa into `/Applications` for its system extension. Other macOS apps such as
`firefox`, `kiri` and `whatsapp` have Home Manager modules
(`homeManagerModules`), for nix-darwin's Home Manager module or a standalone
Home Manager.

### NixOS

```nix
nixosConfigurations.example = nixpkgs.lib.nixosSystem {
  modules = [
    flakes.nixosModules.rayfish
    (
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ flakes.overlays.default ];
        environment.systemPackages = [ pkgs.flakes.codex ];
        services.rayfish.enable = true;
      }
    )
  ];
};
```

`nixosModules` hold the system services (systemd units). The NixOS service
for `tailscale` is nixpkgs' own `services.tailscale`; set its `package` to
this flake's.

The [Cloudflare WARP module](pkgs/cloudflare-warp) also provides opt-in
`services.cloudflare-warp.excludeRayfish` and `excludeHosts` for consumer WARP
split-tunnel exclusions.

### Ubuntu and other Linux distributions

Install Nix with flakes enabled (Determinate Nix, as the checks assume, or
another Nix), then either add packages to a profile:

```bash
nix profile add github:xr3t/flakes#codex
```

or use standalone Home Manager, with this flake's `homeManagerModules`:

```nix
homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    # With Determinate Nix: Nix comes from Determinate, not Home Manager.
    determinate.homeManagerModules.default
    flakes.homeManagerModules.helium
    {
      home = {
        username = "alice";
        homeDirectory = "/home/alice";
        stateVersion = "25.11";
        packages = [ flakes.packages.x86_64-linux.codex ];
      };
      targets.genericLinux.enable = true;
      programs.helium.enable = true;
    }
  ];
};
```

Differences from NixOS:

- `nixosModules` don't apply, so the system services (`rayfish`,
  `cloudflare-warp`, `littlesnitch`, `1mcp`, `tailscale`) aren't set up. Their
  binaries run, but the system units have to come from elsewhere, such as
  upstream's own package or installer. User services from Home Manager
  modules (`services.nullclaw`) run under the systemd user manager as on
  NixOS.
- Programs from Nix don't see the distribution's OpenGL and Vulkan drivers.
  With `targets.genericLinux.enable`, Home Manager links Nix's drivers into
  `/run/opengl-driver` once the `sudo` command it prints on activation has
  run (see Home Manager's manual, "GPU on non-NixOS systems"). The GUI apps
  and `llama`'s Vulkan backend need this.
- Ubuntu 23.10 and later restrict unprivileged user namespaces through
  AppArmor, which sandboxes from the Nix store rely on (there are no setuid
  helpers in it): see [helium](pkgs/helium/README.md#ubuntu) and
  [claude-code](pkgs/claude-code) for the profile each needs.

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.flakes.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: system services (launchd
  daemons, systemd units), for the packages that have one
- `homeManagerModules.<name>`: per-user settings and services, for the
  packages that have them, and `read-only-apps`, which keeps Home Manager's
  copies of macOS apps read-only (see "Updates")
- `checks.<system>`: the flake's own tests: every package built (but the
  rolling `ghostty-tip`, the heavy Office apps and `nixos-shell`, which their
  own workflows build), every `.nix` file formatted, and the modules evaluated
- `formatter`: `nixfmt`
- `devShells.<system>.default`: the tools the checks run (nixfmt,
  shellcheck, actionlint, jq, Python), for working on this flake with
  `nix develop`

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

## Updates

Packages follow upstream automatically: a scheduled workflow checks for new
releases and commits them to `main`, and the pinned nixpkgs is bumped weekly.
Pick them up with `nix flake update flakes`. Updates of root daemons, network
filters and agents, and of nixpkgs, go through a pull request that is merged
once it builds on every system; see [SECURITY.md](SECURITY.md) for what is
checked.

Self-updates, update checks and telemetry are turned off wherever the program
allows it. Each package's README says what is off, how, and how to turn it
back on.

On macOS an app's own updater can replace a writable copy of its bundle. The
Nix store and nix-darwin's copies in `/Applications/Nix Apps` are read-only;
Home Manager's copies in `~/Applications/Home Manager Apps` are writable,
unless `homeManagerModules.read-only-apps` keeps them read-only:

```nix
imports = [ flakes.homeManagerModules.read-only-apps ];
targets.darwin.copyApps.readOnly = true;
```

Before dropping the module from the imports, make the folder writable again:

```sh
chmod -R u+w ~/Applications/Home\ Manager\ Apps
```

[firewall/](firewall/README.md) holds a Little Snitch rule group that cuts app
updaters off the network.

## References

This flake grew out of three projects:

- [nixpkgs](https://github.com/NixOS/nixpkgs/tree/master/pkgs): its package
  tree, one directory per package with a `package.nix` (`pkgs/by-name`),
  `meta.platforms` and an update script beside it, which `pkgs/` here follows.
- [Homebrew](https://brew.sh): its formulae and casks, which install
  upstream's own app bundles and binaries; this flake installs them
  declaratively through Nix instead, with their self-update turned off.
- [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix): Nix
  packages for AI coding agents and their tools. `verify/codesign-check.py`
  builds on its `codesignCheckHook`, which checks macOS code signatures
  without macOS.

## License

Each packaged program keeps its own license, set by its authors. All product
names, logos and trademarks belong to their respective owners and creators.
This repository is not affiliated with or endorsed by them.
