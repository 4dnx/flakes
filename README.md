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

```nix
{
  inputs.xr3t.url = "github:xr3t/flakes";
  inputs.xr3t.inputs.nixpkgs.follows = "nixpkgs";

  # Either take packages straight from the flake (pinned nixpkgs) ...
  environment.systemPackages = [ inputs.xr3t.packages.${system}.rayfish ];

  # ... or build them against your own nixpkgs through the overlay.
  nixpkgs.overlays = [ inputs.xr3t.overlays.default ];
  environment.systemPackages = [ pkgs.xr3t.rayfish ];

  # Packages with a service module:
  modules = [ inputs.xr3t.darwinModules.rayfish ];  # or nixosModules
}
```

Or run one without installing: `nix run github:xr3t/flakes#rayfish -- --version`.

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.xr3t.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: for packages that have a
  `module.nix` (both), `darwin-module.nix` or `nixos-module.nix` (one only)
- `homeManagerModules.<name>`: for packages that have a `home-module.nix`
- `checks.<system>.<name>`: builds every package but the rolling
  `ghostty-tip`; `checks.<system>.formatting`
  checks that every `.nix` file is formatted, `checks.<linux>.nixos-modules`
  that the NixOS modules evaluate
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
