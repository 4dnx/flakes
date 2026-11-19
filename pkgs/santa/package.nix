{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  cpio,
  gzip,
  xar,
  openssl,
  python3,
  rcodesign,
}:

let
  # Version, build and hash live in hashes.json so update.sh can rewrite
  # them. `build` is the bundle's CFBundleVersion (2026.9.256), which
  # update.sh reads from the installer's Distribution.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version build;

  # Upstream's signed, notarized installer package, as its docs recommend
  # deploying it. Its payload holds Santa.app (installed by the postinstall
  # script from /var/db/santa/migration), the newsyslog config for Santa's
  # log and a launch job that only migrates from Google's Santa (left out).
  src = fetchurl {
    url = "https://github.com/northpolesec/santa/releases/download/${version}/santa-${version}.pkg";
    hash = sources.hashes.aarch64-darwin;
  };

  # North Pole Security's Apple Developer team, which signs Santa.app, its
  # helpers and its system extensions.
  team = "ZMCG7MLDV9";
  codesignCheck = app: ''
    ${python3.interpreter} -I ${../../verify/codesign-check.py} ${../../verify/apple-root-ca.pem} ${team} ${app}
  '';
  # The installer's payload, extracted into the current directory.
  extract = ''
    xar -xf ${src} app.pkg/Payload
    gzip -dc app.pkg/Payload | cpio -id --quiet
  '';
in
stdenvNoCC.mkDerivation {
  pname = "santa";
  inherit version src;

  nativeBuildInputs = [
    cpio
    gzip
    xar
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    ${extract}
    mkdir -p "$out/Applications" "$out/bin" "$out/share/santa"
    mv var/db/santa/migration/Santa.app "$out/Applications/"
    cp private/etc/newsyslog.d/com.northpolesec.santa.newsyslog.conf "$out/share/santa/"
    ln -s "$out/Applications/Santa.app/Contents/MacOS/santactl" "$out/bin/santactl"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    openssl
    rcodesign
  ];
  # Doesn't start Santa: santactl talks to the running daemon, and the
  # system extension needs the user's or an MDM's approval.
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../verify/check-app.py} "$out/Applications/Santa.app" \
      "${version}" "${build}" arm64
  ''
  + codesignCheck ''"$out/Applications/Santa.app"''
  + ''
    runHook postInstallCheck
  '';

  passthru = {
    inherit build team;
    # The seal checked on any system: checks.<linux> runs it, so an update
    # is checked before it reaches a Mac.
    codesign =
      runCommand "santa-codesign-${version}"
        {
          nativeBuildInputs = [
            cpio
            gzip
            openssl
            rcodesign
            xar
          ];
        }
        (
          extract
          + codesignCheck "var/db/santa/migration/Santa.app"
          + ''
            touch "$out"
          ''
        );
  };

  meta = {
    description = "Santa, North Pole Security's binary and file access authorization system for macOS (upstream's signed app bundle)";
    homepage = "https://northpole.dev";
    changelog = "https://github.com/northpolesec/santa/releases/tag/${version}";
    license = lib.licenses.asl20;
    mainProgram = "santactl";
    # The bundle is universal; this flake declares only Apple Silicon.
    # macOS 14 or later.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
