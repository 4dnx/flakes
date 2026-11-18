{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  unzip,
  openssl,
  python3,
  rcodesign,
}:

let
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version;

  # Upstream's macOS release, what claude.com/download serves and the app's
  # own updater installs: a signed, notarized universal zip with Claude.app at
  # its root. Upstream publishes no checksum for it; the bundle's Developer ID
  # seal is checked instead (below).
  src = fetchurl {
    inherit (sources) url;
    name = "claude-desktop-${version}.zip";
    hash = sources.hashes."Claude.zip";
  };

  # Anthropic's Apple Developer ID team, which signs the bundle.
  teamId = "Q6L2SF6YDW";
  # The whole bundle: every Mach-O signed by that team, and every file
  # matching the seal, app.asar (the app's code) included.
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../lib/codesign-check.py} ${../../lib/apple-root-ca.pem} ${teamId} ${app}
  '';

  # Upstream's documented switch for installs whose versions something else
  # manages: `disableAutoUpdates` in the com.anthropic.claudefordesktop
  # domain. The app reads it only from managed preferences, which macOS fills
  # from a configuration profile; installing one needs the user's approval,
  # so it ships here for them to open (see README.md).
  profile = ./disable-auto-updates.mobileconfig;
in
stdenvNoCC.mkDerivation {
  pname = "claude-desktop";
  inherit version src;

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Keep the signed bundle intact, nested frameworks and helpers included.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin" "$out/share/claude-desktop"
    cp -R Claude.app "$out/Applications/"
    cat > "$out/bin/claude-desktop" <<SH
    #!/bin/sh
    exec "$out/Applications/Claude.app/Contents/MacOS/Claude" "\$@"
    SH
    chmod +x "$out/bin/claude-desktop"
    cp ${profile} "$out/share/claude-desktop/disable-auto-updates.mobileconfig"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    openssl
    rcodesign
  ];
  # Doesn't start the app: Electron needs a window server, and upstream's
  # bundle runs unchanged.
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../lib/check-app.py} "$out/Applications/Claude.app" \
      "$version" "$version" arm64
  ''
  + codesignCheck "$out/Applications/Claude.app"
  + ''
    runHook postInstallCheck
  '';

  # The seal checked on any system: checks.<linux> runs it, so an update is
  # checked before it reaches a Mac.
  passthru.codesign =
    runCommand "claude-desktop-codesign-${version}"
      {
        nativeBuildInputs = [
          openssl
          rcodesign
          unzip
        ];
      }
      (
        ''
          unzip -q ${src}
        ''
        + codesignCheck "Claude.app"
        + ''
          touch "$out"
        ''
      );

  meta = {
    description = "Claude Desktop, Anthropic's app for Claude, Claude Code and Cowork (upstream's signed app bundle)";
    homepage = "https://claude.com/download";
    license = lib.licenses.unfree;
    mainProgram = "claude-desktop";
    # Upstream's zip is universal; this flake declares only Apple Silicon.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
