# Shared builder for the Microsoft Office apps (pkgs/microsoft-excel,
# pkgs/microsoft-powerpoint, pkgs/microsoft-word): one app from Microsoft's
# signed installer package, installed untouched.
#
# The installer holds three component packages (see README.md here): the app, Microsoft AutoUpdate (left out:
# updates come from Nix) and the licensing helper shared by every Office app.
# `out` gets the app as $out/Applications/<app>.app; `licensing` gets the
# helper and its LaunchDaemon plist under the paths the installer gives them
# ($licensing/Library/PrivilegedHelperTools/..., .../LaunchDaemons/...),
# which the microsoft-office nix-darwin module copies into place. Nothing is
# compiled or patched. It lives here rather than in lib/ because only the
# Office apps use it; pkgs/microsoft-office is a package of its own (the
# three apps together), so this file is not one.
{
  lib,
  stdenvNoCC,
  fetchurl,
  cpio,
  gzip,
  openssl,
  python3,
}:
{
  pname,
  # The bundle's name, without .app.
  app,
  bundleId,
  # The installer's component package that holds the app.
  component,
  # hashes.json: version (CFBundleShortVersionString), build
  # (CFBundleVersion), url, hashes.installer.
  sources,
  description,
}:
let
  inherit (sources) version build url;
  # Microsoft's Apple Developer team: it signs the installer, the apps and
  # the licensing helper.
  team = "UBF8T346G9";
  helper = "com.microsoft.office.licensingV3.helper";
  # Checks the installer's signature and every file in it before anything
  # is read from it (pkg-signature-check.py here).
  pkgCheck = ''${python3.interpreter} -I ${./pkg-signature-check.py} ${../../lib/apple-root-ca.pem} ${team} "$src"'';
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  outputs = [
    "out"
    "licensing"
  ];

  src = fetchurl {
    inherit url;
    hash = sources.hashes.installer;
  };

  nativeBuildInputs = [
    cpio
    gzip
    openssl
  ];

  # Only the two components are extracted, straight from the checked
  # archive, so the ~1.4 GB installer isn't copied first.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Stripping or patching would break the bundle's code signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    versions="$(${pkgCheck} --bundle ${bundleId})"
    if [ "$versions" != "${version} ${build}" ]; then
      echo "installer is $versions, hashes.json says ${version} ${build}" >&2
      exit 1
    fi

    mkdir -p "$out/Applications"
    ${pkgCheck} --cat ${component}/Payload | gzip -dc | (cd "$out/Applications" && cpio -id --quiet)

    # The helper's component installs into /Library/Application Support/
    # Microsoft, from where its postinstall script moves the two files to
    # these paths.
    mkdir -p licensing
    ${pkgCheck} --cat Office16_all_licensing.pkg/Payload | gzip -dc | (cd licensing && cpio -id --quiet)
    staged="licensing/Library/Application Support/Microsoft"
    install -Dm0755 "$staged/${helper}" "$licensing/Library/PrivilegedHelperTools/${helper}"
    install -Dm0644 "$staged/${helper}.plist" "$licensing/Library/LaunchDaemons/${helper}.plist"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${../../lib/check-app.py} "$out/Applications/${app}.app" \
      "$version" "${build}" arm64
    # The helper is the one from this release: its embedded Info.plist
    # carries the same build.
    grep -qF "<string>${build}</string>" "$licensing/Library/PrivilegedHelperTools/${helper}"
    grep -qF "<string>/Library/PrivilegedHelperTools/${helper}</string>" \
      "$licensing/Library/LaunchDaemons/${helper}.plist"
    runHook postInstallCheck
  '';

  passthru = {
    inherit build team;
    appName = "${app}.app";
  };

  meta = {
    inherit description;
    homepage = "https://www.microsoft.com/microsoft-365";
    changelog = "https://learn.microsoft.com/officeupdates/release-notes-office-for-mac";
    license = lib.licenses.unfree;
    # Universal binary. Microsoft ships no Linux build.
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
