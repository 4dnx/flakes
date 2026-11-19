{ lib, callPackage }:

# Microsoft Excel for macOS from Microsoft's signed installer; see
# pkgs/microsoft-office/builder.nix and README.md there.
callPackage ../microsoft-office/builder.nix { } {
  pname = "microsoft-excel";
  app = "Microsoft Excel";
  bundleId = "com.microsoft.Excel";
  component = "Microsoft_Excel.pkg";
  sources = lib.importJSON ./hashes.json;
  description = "Microsoft Excel spreadsheet app for macOS (upstream Microsoft Excel.app, unfree)";
}
