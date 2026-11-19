{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  runCommand,
  wrapFirefox,
  undmg,
  openssl,
  python3,
  rcodesign,
  # Linux: what nixpkgs' firefox-bin-unwrapped links the release against.
  wrapGAppsHook3,
  autoPatchelfHook,
  # Firefox relocates itself from a fixed offset ("relrhack"): patchelf must
  # leave the old sections in place (--no-clobber-old-sections).
  patchelfUnstable,
  adwaita-icon-theme,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libva,
  libxtst,
  pciutils,
  pipewire,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenvNoCC.hostPlatform) system;
  hash = hashes.${system} or (throw "firefox: unsupported system ${system}");
  # Mozilla's release directory for each system; en-US builds. Other
  # languages install as language packs from within Firefox.
  base = "https://archive.mozilla.org/pub/firefox/releases/${version}";

  meta = {
    description = "Mozilla Firefox web browser, latest release (Mozilla's own build)";
    homepage = "https://www.firefox.com/";
    changelog = "https://www.firefox.com/en-US/firefox/${version}/releasenotes/";
    # The binaries come under the Firefox Terms of Use, as nixpkgs'
    # firefox-bin: not free, but redistributable (the code is MPL-2.0).
    license = lib.licenses.mkLicense {
      shortName = "firefox";
      fullName = "Firefox Terms of Use";
      url = "https://www.mozilla.org/about/legal/terms/firefox/";
      free = false;
      redistributable = true;
    };
    mainProgram = "firefox";
    # The macOS dmg is universal; this flake declares only Apple Silicon.
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  # Mozilla's Apple Developer team, which signs Firefox.app.
  team = "43AQ936H96";
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../helpers/codesign-check.py} ${../../helpers/apple-root-ca.pem} ${team} ${app}
  '';
  dmg = fetchurl {
    url = "${base}/mac/en-US/Firefox%20${version}.dmg";
    name = "firefox-${version}.dmg";
    hash = hashes.aarch64-darwin;
  };

  # The macOS bundle's seal, checked on any system: checks.<linux> runs it,
  # so an update is checked before it reaches a Mac. On every system's
  # package, as the flake's checks look for it there.
  passthru = {
    inherit team;
    codesign =
      runCommand "firefox-codesign-${version}"
        {
          nativeBuildInputs = [
            openssl
            rcodesign
            undmg
          ];
        }
        (
          ''
            undmg ${dmg}
          ''
          + codesignCheck "Firefox.app"
          + ''
            touch "$out"
          ''
        );
  };

  # Mozilla's signed, notarized Firefox.app, untouched. Nothing is compiled.
  # nixpkgs' wrapFirefox would write into the bundle and break its
  # signature, so on macOS there is none: policies come from the
  # org.mozilla.firefox defaults instead (README.md).
  darwin = stdenvNoCC.mkDerivation {
    pname = "firefox";
    inherit version;
    src = dmg;

    nativeBuildInputs = [ undmg ];
    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    # Stripping or patching would break the bundle's code signature.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -R Firefox.app "$out/Applications/"
      # Exec by full path so Firefox finds its libraries inside the bundle.
      cat > "$out/bin/firefox" <<SH
      #!/bin/sh
      exec "$out/Applications/Firefox.app/Contents/MacOS/firefox" "\$@"
      SH
      chmod +x "$out/bin/firefox"
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      openssl
      rcodesign
    ];
    installCheckPhase = ''
      runHook preInstallCheck
      ${python3.interpreter} ${../../helpers/check-app.py} "$out/Applications/Firefox.app" "$version" "" arm64
      "$out/bin/firefox" --version | grep -F "Mozilla Firefox $version"
    ''
    + codesignCheck ''"$out/Applications/Firefox.app"''
    + ''
      runHook postInstallCheck
    '';

    inherit passthru meta;
  };

  # Mozilla's Linux tarball, linked against the store's libraries as
  # nixpkgs' firefox-bin-unwrapped does; wrapFirefox (below) runs it.
  unwrapped = stdenv.mkDerivation {
    pname = "firefox-unwrapped";
    inherit version;

    src = fetchurl {
      url = "${base}/${
        {
          x86_64-linux = "linux-x86_64";
          aarch64-linux = "linux-aarch64";
        }
        .${system}
      }/en-US/firefox-${version}.tar.xz";
      inherit hash;
    };

    nativeBuildInputs = [
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ];
    buildInputs = [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libxtst
    ];
    runtimeDependencies = [
      curl
      pciutils
      libva.out
    ];
    appendRunpaths = [ "${pipewire}/lib" ];
    patchelfFlags = [ "--no-clobber-old-sections" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/firefox-${version}" "$out/bin"
      cp -r * "$out/lib/firefox-${version}"
      ln -s "$out/lib/firefox-${version}/firefox" "$out/bin/firefox"
      runHook postInstall
    '';

    # What wrapFirefox reads from the browser it wraps.
    passthru = {
      applicationName = "Firefox";
      binaryName = "firefox";
      libName = "firefox-${version}";
      withFFmpeg = true;
      withGSSAPI = true;
      inherit gtk3;
    };

    meta = meta // {
      platforms = lib.platforms.linux;
    };
  };

  # nixpkgs' wrapper, as for its firefox-bin: the libraries Firefox loads at
  # run time, the desktop entry, policies.json and the autoconfig prefs.
  # NixOS' and Home Manager's `programs.firefox` take it as their `package`
  # and add their own policies and prefs through its `override`.
  linux =
    (wrapFirefox unwrapped {
      pname = "firefox";
      # Mozilla's build reads native messaging hosts from ~/.mozilla only,
      # without nixpkgs' MOZ_SYSTEM_DIR patch; the wrapper links them there.
      hasMozSystemDirPatch = false;
      # Updates come from this flake. Mozilla's documented policy; the
      # wrapper's is-packaged-app marker turns the update check off too.
      extraPolicies.DisableAppUpdate = true;
      # Telemetry off by default: default values (defaultPref), so the
      # user's choice in Settings → Privacy & Security → Firefox Data
      # Collection and Use, or in user.js, wins.
      extraPrefs = ''
        defaultPref("datareporting.healthreport.uploadEnabled", false);
        defaultPref("datareporting.usage.uploadEnabled", false);
        defaultPref("app.shield.optoutstudies.enabled", false);
      '';
    }).overrideAttrs
      (old: {
        doInstallCheck = true;
        installCheckPhase = ''
          runHook preInstallCheck
          "$out/bin/firefox" --version | grep -F "Mozilla Firefox ${version}"
          runHook postInstallCheck
        '';
        passthru = old.passthru // passthru;
        meta = old.meta // meta;
      });
in
if stdenvNoCC.hostPlatform.isDarwin then darwin else linux
