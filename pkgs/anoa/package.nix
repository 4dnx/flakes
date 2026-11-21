{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  buildFHSEnv,
  openssl,
  python3,
  rcodesign,
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-darwin" = "macos-universal";
    "aarch64-linux" = "linux-aarch64";
    "x86_64-linux" = "linux-x86_64";
  };

  system = stdenvNoCC.hostPlatform.system;
  srcFor =
    system:
    fetchurl {
      url = "https://github.com/porcupine-md/anoa-browser/releases/download/v${version}/anoa-${
        assets.${system} or (throw "anoa has no prebuilt release for ${system}")
      }.tar.gz";
      hash = hashes.${system};
    };
  src = srcFor system;

  meta = {
    description = "Headless browser with full CDP support and a command per action for agents, from upstream's prebuilt release";
    homepage = "https://github.com/porcupine-md/anoa-browser";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "anoa";
    platforms = builtins.attrNames hashes;
  };

  # The portable bundle as released: one binary with Qt 6 and QtWebEngine
  # (Chromium) in lib/, and anoa.sh, which sets Qt's paths and puts its own
  # GL, X11, libstdc++ and NSS copies (lib/hostfirst) on the library path for
  # whichever of them the host lacks. Left as released and run in an FHS
  # environment below, so anoa.sh's host-library logic works unchanged.
  bundle = stdenvNoCC.mkDerivation {
    pname = "anoa-bundle";
    inherit version meta;

    inherit src;

    sourceRoot = "anoa";
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      cp -r . $out
      runHook postInstall
    '';
  };

  # Upstream's universal anoa.app, signed with its Developer ID and
  # notarized, untouched; the command is its main executable. Nothing is
  # compiled.
  team = "TVFQAT4MZP";
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../verify/codesign-check.py} ${../../verify/apple-root-ca.pem} ${team} ${app}
  '';
  # The macOS bundle's seal, checked on any system: checks.<linux> runs it,
  # so an update is checked before it reaches a Mac.
  passthru = {
    inherit team;
    codesign =
      runCommand "anoa-codesign-${version}"
        {
          nativeBuildInputs = [
            openssl
            rcodesign
          ];
        }
        (
          ''
            tar xzf ${srcFor "aarch64-darwin"} anoa.app
          ''
          + codesignCheck "anoa.app"
          + ''
            touch "$out"
          ''
        );
  };

  darwin = stdenvNoCC.mkDerivation {
    pname = "anoa";
    inherit version src;

    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    # Stripping or patching would break the bundle's code signature.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -R anoa.app "$out/Applications/"
      # Upstream's Homebrew cask links the executable; a launcher instead, to
      # run it from the installed copy of anoa.app. It execs the bundle's
      # executable by its real path, where it finds its frameworks.
      ${import ../../lib/app-copy-launcher.nix {
        bundle = "anoa.app";
        executable = "Contents/MacOS/anoa";
        launcher = "$out/bin/anoa";
      }}
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      openssl
      rcodesign
    ];
    # The bundle carries no version; `--version` runs on Qt's offscreen
    # platform, without a window server.
    installCheckPhase = ''
      runHook preInstallCheck
      ${python3.interpreter} ${../../verify/check-app.py} "$out/Applications/anoa.app" "" "" arm64
      "$out/bin/anoa" --version | grep -Fx "anoa ${version}"
    ''
    + codesignCheck ''"$out/Applications/anoa.app"''
    + ''
      runHook postInstallCheck
    '';

    inherit passthru meta;
  };

  # Linux: a glibc FHS environment for the unpatched binaries, like the
  # Ubuntu upstream builds on.
  linux = buildFHSEnv {
    pname = "anoa";
    inherit version passthru meta;

    # Libraries the bundle expects from the host and does not ship: Chromium
    # aborts at startup (SIGTRAP) without libudev, and Qt's TLS backend
    # dlopen()s libssl.so.3. NSS too: anoa.sh only takes its own copy when
    # ldconfig does not list the host's, and that copy then fails to load
    # libsoftokn3, so every HTTPS page aborts the browser.
    targetPkgs = pkgs: [
      pkgs.udev
      pkgs.openssl
      pkgs.nss
      pkgs.nspr
    ];

    runScript = "${bundle}/anoa.sh";
  };
in
if stdenvNoCC.hostPlatform.isDarwin then darwin else linux
