{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  python3,
  _7zz,
  autoPatchelfHook,
  addDriverRunpath,
  makeWrapper,
  glib,
  alsa-lib,
  fontconfig,
  freetype,
  libx11,
  libxkbcommon,
  libglvnd,
  vulkan-loader,
  wayland,
  xdg-utils,
}:
let
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
  inherit (stdenvNoCC.hostPlatform) system isDarwin;
  asset =
    {
      aarch64-darwin = "Zed-aarch64.dmg";
      aarch64-linux = "zed-linux-aarch64.tar.gz";
      x86_64-linux = "zed-linux-x86_64.tar.gz";
    }
    .${system};
  updateMessage = "Zed updates are managed by Nix; update the flake and rebuild the configuration.";
in
stdenvNoCC.mkDerivation {
  pname = "zed";
  inherit version;
  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/${asset}";
    hash = hashes.${system};
  };

  nativeBuildInputs = [ makeWrapper ] ++ (if isDarwin then [ _7zz ] else [ autoPatchelfHook ]);
  buildInputs = lib.optionals (!isDarwin) [
    stdenv.cc.cc.libgcc
    glib
    alsa-lib
  ];
  # GPU, window-system and font libraries are loaded at runtime.
  runtimeDependencies = lib.optionals (!isDarwin) [
    fontconfig
    freetype
    libx11
    libxkbcommon
    libglvnd
    vulkan-loader
    wayland
  ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Preserve the official macOS code signature; patch only Linux ELF files.
  dontFixup = isDarwin;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
  ''
  + (
    if isDarwin then
      ''
        mkdir -p "$out/Applications"
        cp -R "$(find . -maxdepth 2 -type d -name Zed.app -print -quit)" "$out/Applications/"
        makeWrapper "$out/Applications/Zed.app/Contents/MacOS/cli" "$out/bin/zed" \
          --set ZED_UPDATE_EXPLANATION ${lib.escapeShellArg updateMessage}
      ''
    else
      ''
        mkdir -p "$out/libexec" "$out/share"
        cp -R zed.app "$out/libexec/zed"
        cp -R zed.app/share/. "$out/share/"
        makeWrapper "$out/libexec/zed/bin/zed" "$out/bin/zed" \
          --set ZED_UPDATE_EXPLANATION ${lib.escapeShellArg updateMessage} \
          --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
          --prefix XDG_DATA_DIRS : "${addDriverRunpath.driverLink}/share:$out/share"
        substituteInPlace "$out/share/applications/dev.zed.Zed.desktop" \
          --replace-fail 'Exec=zed ' "Exec=$out/bin/zed " \
          --replace-fail 'TryExec=zed' "TryExec=$out/bin/zed"
      ''
  )
  + ''
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/zed" --version | grep -F "Zed ${version} "
  ''
  + (
    if isDarwin then
      ''
        ${python3.interpreter} ${../build-support/check-app.py} "$out/Applications/Zed.app" "$version" "" arm64
        /usr/bin/codesign --verify --deep --strict "$out/Applications/Zed.app"
      ''
    else
      ''
        "$out/libexec/zed/libexec/zed-editor" --help >/dev/null
        ${python3.interpreter} -c 'import struct, sys; h=open(sys.argv[1], "rb").read(20); assert h[:4] == b"\x7fELF"; assert struct.unpack("<H", h[18:20])[0] == int(sys.argv[2])' \
          "$out/libexec/zed/libexec/zed-editor" ${if system == "aarch64-linux" then "183" else "62"}
      ''
  )
  + ''
    runHook postInstallCheck
  '';

  meta = {
    description = "Zed code editor from official native prebuilt releases";
    homepage = "https://zed.dev/";
    changelog = "https://github.com/zed-industries/zed/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "zed";
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
