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

| Package | Description |
|---|---|
| [1mcp](pkgs/1mcp) | Unified MCP runtime that aggregates MCP servers behind one endpoint, with a NixOS service module |
| [anoa](pkgs/anoa) | Anoa headless browser (CDP, a command per action for agents) from upstream's Linux bundle, run unpatched in an FHS environment; Linux only, no compilation |
| [bend](pkgs/bend) | Bend parallel functional language (runs `.bend` files directly or builds native binaries) from upstream's prebuilt release, with clang on Linux; update check off, no self-update; Apple Silicon macOS and Linux, no compilation |
| [claude-desktop](pkgs/claude-desktop) | Claude Desktop for macOS from upstream's signed app bundle (unfree), its whole code-signature seal checked, with a configuration profile that turns its self-update off; Apple Silicon, no compilation |
| [cloudflare-warp](pkgs/cloudflare-warp) | Cloudflare WARP client (`warp-cli`, the `warp-svc` daemon and tray app, or the macOS app) from upstream's deb and installer (unfree), with a nix-darwin/NixOS service module that keeps its update check off; Apple Silicon macOS and Linux, no compilation |
| [claude-code](pkgs/claude-code) | Claude Code from upstream's native release (`latest` channel, unfree), checked against its GPG-signed manifest; self-update and error reports off, usage metrics on so flag-gated features such as Remote Control work; Apple Silicon macOS and Linux, no compilation |
| [codex](pkgs/codex) | OpenAI Codex CLI from upstream's prebuilt npm release; Apple Silicon macOS and Linux, no compilation |
| [cua-driver](pkgs/cua-driver) | Desktop control driver for Hermes' computer_use; telemetry and update check off by default; Linux only, no compilation |
| [muxin](pkgs/muxin) | One desktop app for all your machines and their AI agents (sessions, desktops, logs, files) over ssh, with its CLI and MCP server, from upstream's prebuilt release; Apple Silicon macOS and Linux, no compilation |
| [nh](pkgs/nh) | Nix CLI helper from prebuilt upstream binaries, without Rust compilation |
| [llama](pkgs/llama) | Llama (llama.app) command line from the llama.cpp team: local models with an OpenAI-compatible API and chat UI; built from source with Vulkan, self-update off; Linux only |
| [pi](pkgs/pi) | Pi coding agent from published npm packages with Node.js 24 LTS; local assembly, no Pi source compilation |
| [nodejs-24-lts](pkgs/nodejs-24-lts) | Official prebuilt Node.js 24 LTS with independently pinned npm latest; no source compilation |
| [ghostty](pkgs/ghostty) | Ghostty terminal's latest release from upstream's Ghostty.dmg; macOS only, no compilation |
| [ghostty-tip](pkgs/ghostty) | Ghostty's rolling tip build from main, bumped daily |
| [google-chrome](pkgs/google-chrome) | Google Chrome's latest Stable release from Google's signed dmg (unfree); macOS only, no compilation |
| [herdr](pkgs/herdr) | Herdr desktop app, herdr-core (`hc`) and the `herdr` CLI from upstream's prebuilt releases, with a nix-darwin/NixOS module that routes its updates through Nix; Apple Silicon macOS and Linux, no compilation |
| [helium](pkgs/helium) | Helium browser (Chromium-based, private by default) from upstream's signed, notarized dmg on macOS and its binary tarball on Linux, with a Home Manager module that keeps its update check off; Apple Silicon macOS and Linux, no compilation |
| [hermes-agent](pkgs/hermes-agent) | Hermes Agent pinned to upstream's latest stable release tag (`minimal` + telegram, mcp), with upstream's NixOS and Home Manager modules; x86_64 Linux only |
| [kiri](pkgs/kiri) | Kiri container runtime (a Docker Desktop alternative with its own `docker`, Compose and buildx) from upstream's signed app bundle, its whole code-signature seal checked, with a Home Manager module that turns its update check off; Apple Silicon, no compilation |
| [littlesnitch](pkgs/littlesnitch) | Little Snitch for Linux network monitor (unfree freeware binary), with a NixOS service module |
| [lite-xl](pkgs/lite-xl) | Lite XL editor from upstream's addons release (language plugins, colour schemes) as Lite XL.app, Apple Silicon only |
| [nullclaw](pkgs/nullclaw) | Small, fully autonomous AI assistant in one static Zig binary, with a Home Manager module that runs it as upstream's user service |
| [nullclaw-chat-ui](pkgs/nullclaw-chat-ui) | NullClaw's web chat UI as static files, to serve from any web server |
| [opencode](pkgs/opencode) | OpenCode 2 AI coding agent from upstream's prebuilt npm release, kept on Nix (no self-update); Apple Silicon macOS and Linux, no compilation |
| [rayfish](pkgs/rayfish) | P2P mesh VPN (iroh), with a nix-darwin/NixOS service module |
| [tailscale](pkgs/tailscale) | Tailscale CLI and node agent (`tailscale`, `tailscaled`, no GUI) from upstream's static build, for NixOS' `services.tailscale`; log upload off by default, no self-update; Linux only, no compilation |
| [telegram](pkgs/telegram) | Native Telegram for macOS from its official app bundle (not Telegram Desktop); Apple Silicon, no compilation |
| [whatsapp](pkgs/whatsapp) | Native WhatsApp for macOS from its official app bundle (unfree), with a Home Manager module for update defaults; Apple Silicon, no compilation |
| [utm](pkgs/utm) | UTM virtual machine host for macOS from the upstream release dmg, no compilation |

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

## License

Each packaged program keeps its own license, set by its authors. All product
names, logos and trademarks belong to their respective owners and creators.
This repository is not affiliated with or endorsed by them.
