{ mkPackagesFor }:
# Builds pkgs/ against the consumer's nixpkgs and puts it under `pkgs.f0dnx`.
# The flake's own `packages` use this repo's pinned nixpkgs instead.
final: _prev: {
  f0dnx = mkPackagesFor final;
}
