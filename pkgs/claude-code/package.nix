{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  patchelf,
  zstd,
}:

let
  # Version and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenv.hostPlatform) system isLinux;

  # Upstream's platform names in the release manifest.
  platform =
    {
      aarch64-darwin = "darwin-arm64";
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    }
    .${system} or (throw "claude-code: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  # Upstream's native release, what claude.ai/install.sh installs: one
  # Bun-compiled binary, zstd-compressed. Nothing is compiled. update.sh checks
  # the hash against upstream's GPG-signed manifest.
  src = fetchurl {
    url = "https://downloads.claude.ai/claude-code-releases/${version}/${platform}/claude.zst";
    hash = hashes.${system};
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    zstd
  ]
  ++ lib.optional isLinux patchelf;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Ship upstream's binary as it is: signed on macOS, and stripping would cut
  # off the program Bun appends to it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/claude-code"
    zstd -dq "$src" -o "$out/libexec/claude-code/claude"
    chmod 755 "$out/libexec/claude-code/claude"
  ''
  + lib.optionalString isLinux ''
    # Linked against glibc only; point it at Nix's loader. Adding a RUNPATH
    # (for the ALSA and libsecret it dlopens) makes it crash, so don't.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/libexec/claude-code/claude"
  ''
  + ''
    # Updates come through this flake. DISABLE_UPDATES is upstream's switch
    # for redistributions: no background update, and `claude update` and
    # `claude install` refuse. It would also stop plugin auto-updates, which
    # upstream otherwise does, so FORCE_AUTOUPDATE_PLUGINS keeps those as
    # upstream has them. Telemetry and error reports are off unless the
    # environment, or an `env` block in Claude Code's settings, sets them
    # (to an empty value, which turns them back on). Installation checks would
    # warn that the binary isn't in ~/.local/bin.
    makeWrapper "$out/libexec/claude-code/claude" "$out/bin/claude" \
      --set DISABLE_UPDATES 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set-default DISABLE_TELEMETRY 1 \
      --set-default DISABLE_ERROR_REPORTING 1 \
      --set-default DISABLE_INSTALLATION_CHECKS 1
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    test "$("$out/bin/claude" --version)" = "$version (Claude Code)"
    runHook postInstallCheck
  '';

  meta = {
    description = "Claude Code, Anthropic's agentic coding tool for the terminal (upstream's native release)";
    homepage = "https://code.claude.com";
    changelog = "https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
