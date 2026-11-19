{ lib, callPackage }:

# Microsoft Word for macOS from Microsoft's signed installer; see
# pkgs/microsoft-office/builder.nix and README.md there.
callPackage ../microsoft-office/builder.nix { } {
  pname = "microsoft-word";
  app = "Microsoft Word";
  bundleId = "com.microsoft.Word";
  component = "Microsoft_Word.pkg";
  sources = lib.importJSON ./hashes.json;
  description = "Microsoft Word word processor for macOS (upstream Microsoft Word.app, unfree)";
}
