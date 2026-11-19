{
  lib,
  python3,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  sources = lib.importJSON ./hashes.json;
in
stdenvNoCC.mkDerivation {
  pname = "telegram";
  inherit (sources) version;

  src = fetchurl {
    inherit (sources) url;
    name = "telegram-${sources.version}-${sources.build}.zip";
    hash = sources.hashes."Telegram.app.zip";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Keep the upstream signed bundle intact, including nested frameworks.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R "Telegram.app" "$out/Applications/"
    cat > "$out/bin/telegram" <<SH
    #!/bin/sh
    exec "$out/Applications/Telegram.app/Contents/MacOS/Telegram" "\$@"
    SH
    chmod +x "$out/bin/telegram"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../build-support/check-app.py} "$out/Applications/Telegram.app" \
      "$version" "${sources.build}" arm64
    runHook postInstallCheck
  '';

  meta = {
    description = "Telegram native macOS messenger from the official prebuilt app bundle";
    homepage = "https://macos.telegram.org/";
    license = lib.licenses.gpl2Only;
    mainProgram = "telegram";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
