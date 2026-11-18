{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  openssl,
  python3,
  rcodesign,
}:

let
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version;

  # Upstream's macOS release as its own updater installs it: Kiri.app, signed
  # and notarized, in a tar.gz whose SHA-256 the release feed publishes
  # (update.sh checks it). The .dmg on runkiri.com holds the same app.
  src = fetchurl {
    inherit (sources) url;
    hash = sources.hashes."Kiri.app.tar.gz";
  };

  # The Developer ID team of Kiri's maintainer, who signs its release tags.
  teamId = "Z44N5GDT9Q";
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../lib/codesign-check.py} ${../../lib/apple-root-ca.pem} ${teamId} ${app}
  '';

  # The archive was made on a Mac: it holds AppleDouble files (._*) for
  # extended attributes, which only a Mac's tar folds back in. They aren't
  # part of the app and would fall outside its seal.
  unpack = ''
    tar -xzf ${src} --exclude='._*'
  '';
in
stdenvNoCC.mkDerivation {
  pname = "kiri";
  inherit version src;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Keep the signed bundle intact.
  dontFixup = true;

  # Kiri.app sets itself up when it opens, as upstream intends (`kiri setup`):
  # its LaunchAgent and ~/.kiri/bin links name the binary's resolved path, and
  # a newly opened copy replaces those of the one before, so after an update
  # open the app once. bin/kiri is a link into the bundle, so the CLI finds
  # its app.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cd "$out/Applications"
  ''
  + unpack
  + ''
    ln -s "$out/Applications/Kiri.app/Contents/MacOS/kiri" "$out/bin/kiri"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    openssl
    rcodesign
  ];
  # Doesn't start Kiri: its daemon runs a VM, and the CLI's own commands talk
  # to it.
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../lib/check-app.py} "$out/Applications/Kiri.app" \
      "$version" "$version" arm64
  ''
  + codesignCheck "$out/Applications/Kiri.app"
  + ''
    runHook postInstallCheck
  '';

  # The seal checked on any system: checks.<linux> runs it, so an update is
  # checked before it reaches a Mac.
  passthru.codesign =
    runCommand "kiri-codesign-${version}"
      {
        nativeBuildInputs = [
          openssl
          rcodesign
        ];
      }
      (
        unpack
        + codesignCheck "Kiri.app"
        + ''
          touch "$out"
        ''
      );

  meta = {
    description = "Kiri, a small container runtime with the docker CLI, Compose and buildx (upstream's signed app bundle)";
    homepage = "https://runkiri.com";
    changelog = "https://github.com/libracoder/kiri/releases/tag/v${version}";
    # The app; its guest Linux kernel is GPL-2.0-only, with a source offer.
    license = with lib.licenses; [
      asl20
      gpl2Only
    ];
    mainProgram = "kiri";
    # Upstream also ships an Intel app; this flake declares only Apple Silicon.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
