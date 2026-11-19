{ lib, callPackage }:

# Microsoft PowerPoint for macOS from Microsoft's signed installer; see
# pkgs/microsoft-office/builder.nix and README.md there.
callPackage ../microsoft-office/builder.nix { } {
  pname = "microsoft-powerpoint";
  app = "Microsoft PowerPoint";
  bundleId = "com.microsoft.Powerpoint";
  component = "Microsoft_PowerPoint.pkg";
  sources = lib.importJSON ./hashes.json;
  description = "Microsoft PowerPoint presentation app for macOS (upstream Microsoft PowerPoint.app, unfree)";
}
