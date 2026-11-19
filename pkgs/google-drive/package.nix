{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  _7zz,
  cpio,
  pbzx,
  openssl,
  python3,
  rcodesign,
}:

let
  # Version, URL and hash live in hashes.json so update.sh can rewrite them.
  # The URL carries an id from Google's update server that can't be derived
  # from the version, so it is pinned too. `version` is the release as
  # Google's update server names it (134.0.1.0); the bundle says 134.0
  # (CFBundleShortVersionString) and 134.0.1 (CFBundleVersion), which
  # update.sh reads from the app's Info.plist and the install check checks.
  sources = lib.importJSON ./hashes.json;
  inherit (sources)
    version
    shortVersion
    build
    url
    ;

  # Google's signed, notarized universal dmg. It is APFS, which undmg can't
  # read: 7-Zip takes the APFS partition out of the dmg, and apfs-cat.py the
  # installer out of the partition.
  src = fetchurl {
    inherit url;
    hash = sources.hashes."GoogleDrive.dmg";
  };

  # Google's Apple Developer team: it signs the installer and the app.
  team = "EQHXZ8M8AV";
  python = python3.withPackages (p: [ p.dissect-apfs ]);
  # Takes GoogleDrive.pkg out of the dmg into the current directory.
  extractInstaller = ''
    7zz x -tdmg -y -bd ${src} >/dev/null
    apfs=(*.apfs)
    [ ''${#apfs[@]} = 1 ] || { echo "google-drive: expected one APFS partition, found: ''${apfs[*]}" >&2; exit 1; }
    ${python.interpreter} -I ${./apfs-cat.py} "''${apfs[0]}" /GoogleDrive.pkg GoogleDrive.pkg
    rm -- *.apfs
  '';
  # Checks the installer's signature and every file in it before anything
  # is read from it (pkg-signature-check.py, this package's own copy of the
  # Office apps' pkgs/microsoft-office/pkg-signature-check.py, so neither
  # rebuilds with the other).
  pkgCheck = "${python3.interpreter} -I ${./pkg-signature-check.py} ${../../lib/apple-root-ca.pem} ${team} GoogleDrive.pkg";
  # The whole bundle: every Mach-O signed by Google's team, every file
  # matching the seal.
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../lib/codesign-check.py} ${../../lib/apple-root-ca.pem} ${team} ${app}
  '';
in
stdenvNoCC.mkDerivation {
  pname = "google-drive";
  inherit version src;

  nativeBuildInputs = [
    _7zz
    cpio
    openssl
    pbzx
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  # The installer holds four components: Google Drive for Apple Silicon and
  # for Intel, Google's updater (left out: updates come from Nix) and
  # shortcuts to the Docs, Sheets and Slides web apps (scripts, left out).
  # Only the Apple Silicon app is installed, untouched. Its postinstall
  # script makes Contents/MacOS/mount_helper setuid root, which the Nix store
  # can't hold; the nix-darwin module does that on its copy in /Applications.
  installPhase = ''
    runHook preInstall
    ${extractInstaller}
    mkdir -p "$out/Applications"
    ${pkgCheck} --cat GoogleDrive_arm64.pkg/Payload | pbzx - | (cd "$out/Applications" && cpio -id --quiet)
    rm GoogleDrive.pkg
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    openssl
    rcodesign
  ];
  # Doesn't start the app: it needs a window server and a Google account.
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../lib/check-app.py} "$out/Applications/Google Drive.app" \
      "${shortVersion}" "${build}" arm64
  ''
  + codesignCheck ''"$out/Applications/Google Drive.app"''
  + ''
    runHook postInstallCheck
  '';

  passthru = {
    inherit team;
    # The seal checked on any system: checks.<linux> runs it, so an update
    # is checked before it reaches a Mac.
    codesign =
      runCommand "google-drive-codesign-${version}"
        {
          nativeBuildInputs = [
            _7zz
            cpio
            openssl
            pbzx
            rcodesign
          ];
        }
        (
          extractInstaller
          + ''
            ${pkgCheck} --cat GoogleDrive_arm64.pkg/Payload | pbzx - | cpio -id --quiet
          ''
          + codesignCheck ''"Google Drive.app"''
          + ''
            touch "$out"
          ''
        );
  };

  meta = {
    description = "Google Drive for desktop, Google's file sync app for macOS (upstream's signed app bundle)";
    homepage = "https://www.google.com/drive/download/";
    changelog = "https://support.google.com/a/answer/7577057";
    license = lib.licenses.unfree;
    # The installer is universal; this flake declares only Apple Silicon.
    # Google ships no Linux build. macOS 13 or later.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
