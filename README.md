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

The [Cloudflare WARP module](pkgs/cloudflare-warp) also provides opt-in
`services.cloudflare-warp.excludeRayfish` and `excludeHosts` for consumer WARP
split-tunnel exclusions.

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

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.xr3t.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: system services (launchd
  daemons, systemd units), for the packages that have one
- `homeManagerModules.<name>`: per-user settings and services, for the
  packages that have them, and `read-only-apps`, which keeps Home Manager's
  copies of macOS apps read-only (see "Updates")
- `checks.<system>`: the flake's own tests: every package built (but the
  rolling `ghostty-tip` and the heavy Office apps, which their own workflows
  build), every `.nix` file formatted, and the modules evaluated
- `formatter`: `nixfmt`
- `devShells.<system>.default`: the tools the checks run (nixfmt,
  shellcheck, actionlint, jq, Python), for working on this flake with
  `nix develop`

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

## Updates

Packages follow upstream automatically: a workflow checks for new releases
twice a day and commits them to `main`, and the pinned nixpkgs is bumped
weekly. Pick them up with `nix flake update xr3t`. Updates of root daemons,
network filters and agents, and of nixpkgs, go through a pull request that is
merged once it builds on every system; see [SECURITY.md](SECURITY.md) for what is checked.

On macOS an app's own updater replaces its bundle in place, so where the
bundle lives decides whether it can. The Nix store is read-only, and
nix-darwin copies the apps in `environment.systemPackages` into
`/Applications/Nix Apps` as read-only directories owned by root. Home Manager
copies the apps in `home.packages` into `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`, on by default from `home.stateVersion` 25.11) as
writable directories owned by the user: an updater can replace such a copy,
and the next activation copies the pinned version back. The package READMEs
name each app's updater and what turns it off; where nothing does, the
nix-darwin copy is out of reach of an updater that runs as the user.

`homeManagerModules.read-only-apps` keeps Home Manager's copies read-only
instead, for every app Home Manager copies, from this flake or not:

```nix
imports = [ xr3t.homeManagerModules.read-only-apps ];
targets.darwin.copyApps.readOnly = true;
```

Each activation makes `~/Applications/Home Manager Apps` and everything in it
writable before Home Manager's App Management check and copy, which write
into the bundles, and read-only (`chmod -R a-w`) after the copy. An updater
running as the user then can't replace a copy, write into it or stage a new
one beside it without first changing its permissions back. Sparkle and
Google's updater may ask for an administrator's password instead; given it,
they can replace the copy as root. The unlock also runs while the option is
false, so turning it off leaves no copy that Home Manager can't replace;
with the module dropped from the imports, nothing unlocks the folder, so
make it writable before switching:

```sh
chmod -R u+w ~/Applications/Home\ Manager\ Apps
```

The `whatsapp` module keeps only its own copy read-only the same way.

App updaters can also be cut off the network with Little Snitch:
[firewall/](firewall/README.md) holds a rule group to subscribe to, matched by
code signature, which leaves Nix's own downloads alone. It denies the updaters
that run as processes of their own (Google's GoogleUpdater and Keystone,
Microsoft AutoUpdate) everywhere, and Telegram and Ghostty their update hosts.

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

## macOS app launchers

Profile commands for anoa, Claude Desktop, Firefox, Ghostty, Chrome, Helium,
Herdr Desktop, Telegram, UTM, WhatsApp, and Zed look for an app copy in
Home Manager’s app directory and then in nix-darwin’s app directory. A copy
must match the packaged executable, Info.plist, and code resources seal.
The launcher uses the store bundle when no copy matches.
