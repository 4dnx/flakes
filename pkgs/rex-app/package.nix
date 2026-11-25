{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  _7zz,
  openssl,
  python3,
  rcodesign,
}:

let
  # Version, bundle version, build, URL and hash live in hashes.json so
  # update.sh can rewrite them. `version` is the bundle version and the build
  # (0.1.0-2116): every build so far is 0.1.0.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version bundleVersion build;

  # The key Sparkle checks updates with (the app's SUPublicEDKey). update.sh
  # checks each dmg against it, and the install check that the app still
  # names it.
  sparkleKey = lib.trim (builtins.readFile ./sparkle-ed25519.pub);

  # Upstream's dmg from its preview appcast, the one the app updates from. The
  # file name holds the build, so the URL serves one build only.
  src = fetchurl {
    inherit (sources) url;
    hash = sources.hashes."Rex.dmg";
  };

  # Superlogical's Apple Developer team, which signs Rex.app, its server and
  # its helpers.
  team = "AG92C3PT77";
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../verify/codesign-check.py} ${../../verify/apple-root-ca.pem} ${team} ${app}
  '';
  # The dmg's volume, extracted into the current directory: Rex.app is at
  # Rex/Rex.app. 7-Zip leaves out the volume's /Applications link.
  extract = ''
    7zz x -y -bso0 -bsp0 -snld ${src} 'Rex/Rex.app/*'
  '';
in
stdenvNoCC.mkDerivation {
  pname = "rex-app";
  inherit version src;

  nativeBuildInputs = [ _7zz ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    ${extract}
    mkdir -p "$out/Applications"
    mv Rex/Rex.app "$out/Applications/"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    openssl
    rcodesign
  ];
  # Doesn't open the app: it starts its own server and checks for updates.
  installCheckPhase = ''
    runHook preInstallCheck
    app="$out/Applications/Rex.app"
    ${python3.interpreter} ${../../verify/check-app.py} "$app" "${bundleVersion}" "${build}" arm64
    ${python3.interpreter} ${../../verify/check-app.py} "$app/Contents/Helpers/Rex Server.rex" "${bundleVersion}" "${build}" arm64
    ${python3.interpreter} -I -c '
    import plistlib, sys
    info = plistlib.load(open(sys.argv[1] + "/Contents/Info.plist", "rb"))
    if info.get("SUPublicEDKey") != sys.argv[2]:
        sys.exit("Rex.app: SUPublicEDKey is not the key in sparkle-ed25519.pub")
    ' "$app" "${sparkleKey}"
  ''
  + codesignCheck ''"$app"''
  + ''
    runHook postInstallCheck
  '';

  passthru = {
    inherit build team;
    # The seal checked on any system: checks.<linux> runs it, so an update
    # is checked before it reaches a Mac.
    codesign =
      runCommand "rex-app-codesign-${version}"
        {
          nativeBuildInputs = [
            _7zz
            openssl
            rcodesign
          ];
        }
        (
          extract
          + codesignCheck "Rex/Rex.app"
          + ''
            touch "$out"
          ''
        );
  };

  meta = {
    description = "Rex for Mac, Superlogical's multiplexer app (upstream's signed app bundle, preview channel)";
    homepage = "https://www.superlogical.com/rex/docs";
    license = lib.licenses.unfree;
    # The bundle is universal; this flake declares only Apple Silicon.
    # macOS 15 or later.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
