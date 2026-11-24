{
  lib,
  python3,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

let
  # Version and hash live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  # version is upstream's release (5.0.9-2 for a re-release), appVersion the
  # app's own (5.0.9); update.sh writes both.
  inherit (sources) version hashes;
  appVersion = sources.appVersion or version;
in
stdenvNoCC.mkDerivation {
  pname = "utm";
  inherit version;

  # Upstream's signed, notarized universal UTM.app; nothing is compiled.
  src = fetchurl {
    url = "https://github.com/utmapp/UTM/releases/download/v${version}/UTM.dmg";
    hash = hashes."UTM.dmg";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R UTM.app "$out/Applications/"
    ${import ../../lib/app-copy-launcher.nix {
      bundle = "UTM.app";
      executable = "Contents/MacOS/UTM";
      launcher = "$out/bin/UTM";
    }}
    ${import ../../lib/app-copy-launcher.nix {
      bundle = "UTM.app";
      executable = "Contents/MacOS/utmctl";
      launcher = "$out/bin/utmctl";
    }}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../verify/check-app.py} "$out/Applications/UTM.app" "${appVersion}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Virtual machine host for macOS based on QEMU and Virtualization.framework (upstream UTM.app)";
    homepage = "https://mac.getutm.app/";
    changelog = "https://github.com/utmapp/UTM/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "utmctl";
    # Universal binary; macOS 12 or later.
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
