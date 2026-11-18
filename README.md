# Flakes

Desktop apps, command-line tools and services for **nix-darwin**, **NixOS**
and **Linux with Nix**, packaged from each project's own official releases.
A declarative take on Homebrew's casks and formulae: packages are listed in a
Nix configuration, and every machine gets the same versions. By `Prompter`.

- **Upstream's own builds.** Most packages are the vendor's signed bundles
  and binaries, installed unchanged and native on Apple Silicon and Linux:
  no web wrappers, no emulation. The few built from source here say so.
- **Checked downloads.** Every download is pinned by hash and, where the
  vendor publishes more, checked against it: signed release manifests,
  checksum lists, and for some macOS apps their whole Apple code signature.
- **Updates through Nix.** New upstream releases arrive here twice a day;
  apps' own self-updaters are turned off wherever they can be, so updating is
  `nix flake update xr3t`.
- **Telemetry off by default** wherever that doesn't break a feature; each
  package's README says what is off, how to turn it back on, and what
  couldn't be turned off.

> [!WARNING]
> **DYOR (Do Your Own Research).** These packages are written largely with AI
> agents and provided as-is, without warranty. Pinned hashes only prove a
> download is unchanged, not that the program is safe. Read the package
> definition and the upstream project before installing, especially anything
> that runs as a system service or with root privileges. See
> [SECURITY.md](SECURITY.md) for what the checks cover, and to report a
> vulnerability.

## Packages

Among them: Claude Code and Claude Desktop, Codex, OpenCode and other coding
agents; Ghostty, Google Chrome and Helium; WhatsApp and Telegram; UTM and
Kiri; Tailscale, Cloudflare WARP and Little Snitch. The full list, with what
each package brings and the systems it runs on, is in
**[pkgs/README.md](pkgs/README.md)**; each package's own README covers its
options and notes.

## Usage

The flake targets three setups: **nix-darwin** on Apple Silicon Macs,
**NixOS**, and **Ubuntu** (or another Linux distribution) with Nix and,
optionally, standalone Home Manager. Packages that don't run on a system are
left out of `packages.<system>`; the package table and each package's README
say which systems it supports.

Add it as an input. Its `nix-darwin` and `home-manager` inputs are used only
by its own checks and are never fetched otherwise; pointing them at existing
inputs with `follows` keeps a single copy of each in the lock file:

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

Packages come straight from the flake (built against its pinned nixpkgs,
with its unfree packages allowed) or from the overlay, as `pkgs.xr3t.<name>`,
built against the configuration's own nixpkgs; unfree ones then need that
nixpkgs' config to allow them (`nixpkgs.config.allowUnfreePredicate`).

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

Install Nix with flakes enabled, then either add packages to a profile:

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

A package also runs without being installed:
`nix run github:xr3t/flakes#codex -- --version`.

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.xr3t.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: system services (launchd
  daemons, systemd units), for the packages that have one
- `homeManagerModules.<name>`: per-user settings and services, for the
  packages that have them
- `checks.<system>`: the flake's own tests: every package built, every
  `.nix` file formatted, and the modules evaluated
- `formatter`: `nixfmt`

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

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
