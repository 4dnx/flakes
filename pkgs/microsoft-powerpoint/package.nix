{ lib, callPackage }:

# Microsoft PowerPoint for macOS from Microsoft's signed installer; see
# lib/microsoft-office.nix and pkgs/microsoft-office/README.md.
callPackage ../../lib/microsoft-office.nix { } {
  pname = "microsoft-powerpoint";
  app = "Microsoft PowerPoint";
  bundleId = "com.microsoft.Powerpoint";
  component = "Microsoft_PowerPoint.pkg";
  sources = lib.importJSON ./hashes.json;
  description = "Microsoft PowerPoint presentation app for macOS (upstream Microsoft PowerPoint.app, unfree)";
}
