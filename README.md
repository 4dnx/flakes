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

## Packages

The packages, what each brings and which systems it runs on are listed in
[pkgs/README.md](pkgs/README.md); each package's own README has its usage and
options.

## Usage

The flake targets three setups: **nix-darwin** on Apple Silicon Macs,
**NixOS**, and **Ubuntu** (or another Linux distribution) with Nix and,
optionally, standalone Home Manager. Packages that don't run on a system are
left out of `packages.<system>`; the package table and each package's README
say which systems it supports.

Add it as an input. Its `nix-darwin` and `home-manager` inputs are only used
by its own checks (they are never fetched otherwise); point them at yours
with `follows` if you have them, so your lock file holds one copy:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  xr3t = {
    url = "github:xr3t/flakes";
    inputs.nixpkgs.follows = "nixpkgs";
    # inputs.nix-darwin.follows = "nix-darwin";
    # inputs.home-manager.follows = "home-manager";
  };
};
```

Take packages straight from the flake (built against its pinned nixpkgs,
with its unfree packages allowed), or build them against your own nixpkgs
through the overlay, as `pkgs.xr3t.<name>`; unfree ones then need your
nixpkgs config to allow them (`nixpkgs.config.allowUnfreePredicate`).

### nix-darwin

```nix
darwinConfigurations.example = nix-darwin.lib.darwinSystem {
  modules = [
    xr3t.darwinModules.rayfish
    {
      nixpkgs.hostPlatform = "aarch64-darwin";
      environment.systemPackages = [ xr3t.packages.aarch64-darwin.ghostty ];
      services.rayfish.enable = true;
    }
  ];
};
```

`darwinModules` hold the system services (launchd daemons). macOS apps such as
`kiri` and `whatsapp` have Home Manager modules (`homeManagerModules`), for
nix-darwin's Home Manager module or a standalone Home Manager.

### NixOS

```nix
nixosConfigurations.example = nixpkgs.lib.nixosSystem {
  modules = [
    xr3t.nixosModules.rayfish
    (
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ xr3t.overlays.default ];
        environment.systemPackages = [ pkgs.xr3t.codex ];
        services.rayfish.enable = true;
      }
    )
  ];
};
```

`nixosModules` hold the system services (systemd units). The NixOS service
for `tailscale` is nixpkgs' own `services.tailscale`; set its `package` to
this flake's.

### Ubuntu and other Linux distributions

Install Nix with flakes enabled, then either add packages to your profile:

```bash
nix profile add github:xr3t/flakes#codex
```

or use standalone Home Manager, with this flake's `homeManagerModules`:

```nix
homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    xr3t.homeManagerModules.helium
    {
      home = {
        username = "alice";
        homeDirectory = "/home/alice";
        stateVersion = "25.11";
        packages = [ xr3t.packages.x86_64-linux.codex ];
      };
      targets.genericLinux.enable = true;
      programs.helium.enable = true;
    }
  ];
};
```

What is different from NixOS:

- `nixosModules` don't apply: nothing sets up the system services (`rayfish`,
  `cloudflare-warp`, `littlesnitch`, `1mcp`, `tailscale`) for you. The
  binaries run, but a system unit has to come from elsewhere, such as
  upstream's own package or installer. User services from Home Manager
  modules (`services.nullclaw`) run under the systemd user manager as on
  NixOS.
- Programs from Nix don't see the distribution's OpenGL and Vulkan drivers.
  With `targets.genericLinux.enable`, Home Manager links Nix's drivers into
  `/run/opengl-driver`; run the `sudo` command it prints when it activates
  (see Home Manager's manual, "GPU on non-NixOS systems"). This matters to
  the GUI apps and to `llama`'s Vulkan backend.
- Ubuntu 23.10 and later restrict unprivileged user namespaces through
  AppArmor, which sandboxes from the Nix store rely on (there are no setuid
  helpers in it): see [helium](pkgs/helium/README.md#ubuntu) and
  [claude-code](pkgs/claude-code) for the profile each needs.

Or run a package without installing it:
`nix run github:xr3t/flakes#codex -- --version`.

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.xr3t.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: for packages that have a
  `module.nix` (both), `darwin-module.nix` or `nixos-module.nix` (one only)
- `homeManagerModules.<name>`: for packages that have a `home-module.nix`
- `checks.<system>.<name>`: builds every package but the rolling
  `ghostty-tip`; `checks.<system>.formatting`
  checks that every `.nix` file is formatted; on Linux,
  `nixos-modules`, `darwin-modules`, `home-modules` and `darwin-home-modules`
  check that the NixOS, nix-darwin and Home Manager (Linux, macOS) modules
  evaluate with every one of them enabled
- `formatter`: `nixfmt`

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

CI builds every Linux check. On macOS it evaluates the package checks and builds
those whose derivations changed since a successful ancestor Check on the PR base
branch or `main` (including checks of merged PRs). Without a usable baseline, or when check scripts or the Check
workflow change, it builds all macOS package checks. Its store cache follows the
macOS package derivations, so Linux-only updates do not replace it.

## Updates

Packages follow upstream automatically: a workflow checks for new releases
twice a day and commits them to `main`, and the pinned nixpkgs is bumped
weekly. Pick them up with `nix flake update xr3t`. Updates of root daemons,
network filters and agents, and of nixpkgs, go through a pull request that is
merged once it builds on every system; see [SECURITY.md](SECURITY.md) for what is checked.

## References

This flake grew out of three projects:

- [nixpkgs](https://github.com/NixOS/nixpkgs/tree/master/pkgs): its package
  tree, one directory per package with a `package.nix` (`pkgs/by-name`),
  `meta.platforms` and an update script beside it, which `pkgs/` here follows.
- [Homebrew](https://brew.sh): its formulae and casks, which install
  upstream's own app bundles and binaries; this flake installs them
  declaratively through Nix instead, with their self-update turned off.
- [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix): Nix
  packages for AI coding agents and their tools. `lib/codesign-check.py`
  builds on its `codesignCheckHook`, which checks macOS code signatures
  without macOS.

## License

Each packaged program keeps its own license, set by its authors. All product
names, logos and trademarks belong to their respective owners and creators.
This repository is not affiliated with or endorsed by them.
