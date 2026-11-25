{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

let
  # Version, channel, commit and hash live in hashes.json so update.sh can
  # rewrite them. Downloads are named after the commit they were built from.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version channel commit;
in
stdenvNoCC.mkDerivation {
  pname = "rex";
  inherit version;

  # Upstream's release archive for Apple Silicon: the rex binary alone (the
  # CLI and the server), with no enclosing directory.
  src = fetchurl {
    url = "https://blob.superlogical.com/download/rex/${channel}/${commit}/rex-darwin-arm64.zip";
    hash = sources.hashes.aarch64-darwin;
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # The binary carries the linker's ad-hoc signature, which Apple Silicon
  # needs to run it: stripping or patching would break it.
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 rex "$out/bin/rex"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/rex" version | tee version.txt
    grep -qF -- "$version" version.txt
    runHook postInstallCheck
  '';

  meta = {
    description = "Rex, Superlogical's multiplexer for all work (the rex CLI and server)";
    homepage = "https://www.superlogical.com/rex/docs";
    license = lib.licenses.unfree;
    mainProgram = "rex";
    # Upstream also builds for Intel Macs; this flake declares only Apple
    # Silicon.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
