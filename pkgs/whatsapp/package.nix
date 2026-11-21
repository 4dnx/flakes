{
  lib,
  python3,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  sources = lib.importJSON ./hashes.json;
  # Forces Sparkle's update check and automatic installation off in the app's
  # domain. WhatsApp sets both back on itself, and only managed preferences,
  # which macOS fills from a configuration profile, take precedence; installing
  # one needs the user's approval, so it ships here for them to open (see
  # README.md).
  profile = ./disable-auto-updates.mobileconfig;
in
stdenvNoCC.mkDerivation {
  pname = "whatsapp";
  inherit (sources) version;

  src = fetchurl {
    inherit (sources) url;
    name = "whatsapp-${sources.version}-${sources.build}.zip";
    hash = sources.hashes."WhatsApp.app.zip";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Keep the upstream signed bundle intact, including nested frameworks.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin" "$out/share/whatsapp"
    cp -R "WhatsApp.app" "$out/Applications/"
    cat > "$out/bin/whatsapp" <<SH
    #!/bin/sh
    exec "$out/Applications/WhatsApp.app/Contents/MacOS/WhatsApp" "\$@"
    SH
    chmod +x "$out/bin/whatsapp"
    cp ${profile} "$out/share/whatsapp/disable-auto-updates.mobileconfig"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../verify/check-app.py} "$out/Applications/WhatsApp.app" \
      "$version" "${sources.build}" arm64
    runHook postInstallCheck
  '';

  meta = {
    description = "WhatsApp native macOS messenger from the official prebuilt app bundle";
    homepage = "https://www.whatsapp.com/";
    license = lib.licenses.unfree;
    mainProgram = "whatsapp";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
