{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  glibc,
  libgcc,
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-darwin" = "ray-macos-aarch64";
    "aarch64-linux" = "ray-linux-aarch64";
    "x86_64-linux" = "ray-linux-x86_64";
  };

  system = stdenvNoCC.hostPlatform.system;
  isLinux = stdenvNoCC.hostPlatform.isLinux;
  asset = assets.${system} or (throw "Rayfish has no prebuilt release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "rayfish";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rayfish/rayfish/releases/download/v${version}/${asset}";
    hash = hashes.${system};
  };

  dontUnpack = true;
  dontFixup = !isLinux;

  nativeBuildInputs = lib.optional isLinux autoPatchelfHook;
  buildInputs = lib.optionals isLinux [
    glibc
    libgcc
  ];
  runtimeDependencies = lib.optionals isLinux [ libgcc ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/libexec/rayfish/ray"
    install -Dm755 ${./ray-guard.sh} "$out/bin/ray"
    substituteInPlace "$out/bin/ray" \
      --replace-fail '@REAL@' "$out/libexec/rayfish/ray"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/libexec/rayfish/ray" --version | grep -q "^ray $version "
    # The guard refuses these before the real binary runs, so they touch
    # nothing here. Its own message is checked, not just the exit status: the
    # real binary fails here too, without network. Recheck upstream's aliases
    # (`ray --help`) on a bump.
    for cmd in update upgrade "update --force" install uninstall "auto-update on" \
      "config set auto-update on"; do
      # shellcheck disable=SC2086 # one command per word list
      if "$out/bin/ray" $cmd 2>err || ! grep -q '^rayfish: ' err; then
        echo "ray $cmd was not refused by the guard" >&2
        exit 1
      fi
    done
    runHook postInstallCheck
  '';

  meta = {
    description = "P2P mesh VPN powered by iroh";
    homepage = "https://rayfish.xyz";
    license = lib.licenses.mpl20;
    mainProgram = "ray";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames hashes;
  };
}
