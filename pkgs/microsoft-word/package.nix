{ lib, callPackage }:

# Microsoft Word for macOS from Microsoft's signed installer; see
# lib/microsoft-office.nix and pkgs/microsoft-office/README.md.
callPackage ../../lib/microsoft-office.nix { } {
  pname = "microsoft-word";
  app = "Microsoft Word";
  bundleId = "com.microsoft.Word";
  component = "Microsoft_Word.pkg";
  sources = lib.importJSON ./hashes.json;
  description = "Microsoft Word word processor for macOS (upstream Microsoft Word.app, unfree)";
}
