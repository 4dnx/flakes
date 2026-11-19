{
  lib,
  buildEnv,
  microsoft-excel,
  microsoft-powerpoint,
  microsoft-word,
}:

# Word, Excel and PowerPoint together, each app bundle linked whole. The
# nix-darwin module here installs any selection of them instead.
buildEnv {
  name = "microsoft-office";
  paths = [
    microsoft-excel
    microsoft-powerpoint
    microsoft-word
  ];
  pathsToLink = [ "/Applications" ];

  meta = {
    description = "Microsoft Word, Excel and PowerPoint for macOS together, with a nix-darwin module that installs any selection of them";
    homepage = "https://www.microsoft.com/microsoft-365";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
