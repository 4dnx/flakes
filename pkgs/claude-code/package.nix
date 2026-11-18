{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  patchelf,
  zstd,
  alsa-lib,
  bubblewrap,
  socat,
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

  # Updates come through this flake. DISABLE_UPDATES is upstream's switch for
  # redistributions: no background update, and `claude update` and `claude
  # install` refuse. It would also stop plugin auto-updates, which upstream
  # otherwise does, so FORCE_AUTOUPDATE_PLUGINS keeps those as upstream has
  # them. Telemetry and error reports are off unless the environment, or an
  # `env` block in Claude Code's settings, sets them (to an empty value, which
  # turns them back on). Installation checks would warn that the binary isn't
  # in ~/.local/bin.
  wrapperArgs = [
    "--set"
    "DISABLE_UPDATES"
    "1"
    "--set-default"
    "FORCE_AUTOUPDATE_PLUGINS"
    "1"
    "--set-default"
    "DISABLE_TELEMETRY"
    "1"
    "--set-default"
    "DISABLE_ERROR_REPORTING"
    "1"
    "--set-default"
    "DISABLE_INSTALLATION_CHECKS"
    "1"
  ]
  ++ lib.optionals isLinux [
    # Voice input's libasound.so.2 (see installPhase); appended, so a
    # library path the user sets comes first.
    "--suffix"
    "LD_LIBRARY_PATH"
    ":"
    "${placeholder "out"}/lib/claude-code"
    # The sandbox runs the first bwrap on PATH and relays network traffic
    # through socat. Appended, so a distribution's own bwrap (with the
    # AppArmor profile Ubuntu needs) and the user's tools come first.
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [
      bubblewrap
      socat
    ])
  ];
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
    # Linked against glibc only; point it at Nix's loader. That loader doesn't
    # search a distribution's library directories, and a RUNPATH makes the
    # binary crash, so the one library its embedded voice addon
    # (audio-capture.node) links, libasound.so.2, gets a directory of its own
    # for LD_LIBRARY_PATH: child processes inherit that, so nothing else goes
    # in it.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/libexec/claude-code/claude"
    mkdir -p "$out/lib/claude-code"
    ln -s ${lib.getLib alsa-lib}/lib/libasound.so.2 "$out/lib/claude-code/"
  ''
  + ''
    makeWrapper "$out/libexec/claude-code/claude" "$out/bin/claude" \
      ${lib.escapeShellArgs wrapperArgs}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    test "$("$out/bin/claude" --version)" = "$version (Claude Code)"
  ''
  + lib.optionalString isLinux ''
    test -e "$out/lib/claude-code/libasound.so.2"
  ''
  + ''
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
