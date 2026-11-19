{ lib, callPackage }:

# Microsoft Excel for macOS from Microsoft's signed installer; see
# lib/microsoft-office.nix and pkgs/microsoft-office/README.md.
callPackage ../../lib/microsoft-office.nix { } {
  pname = "microsoft-excel";
  app = "Microsoft Excel";
  bundleId = "com.microsoft.Excel";
  component = "Microsoft_Excel.pkg";
  sources = lib.importJSON ./hashes.json;
  description = "Microsoft Excel spreadsheet app for macOS (upstream Microsoft Excel.app, unfree)";
}
