{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  openssl,
  shaderc,
  spirv-headers,
  vulkan-headers,
  vulkan-loader,
  vulkanSupport ? true,
}:

let
  # Versions and hashes live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources)
    version
    build
    commit
    hashes
    ;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "llama";
  inherit version;

  src = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "v${version}";
    hash = hashes.src;
  };

  # The chat UI llama.cpp's own releases embed. Upstream's build downloads it
  # when it finds no ui/apps/chat/dist (tools/ui/dist before v1.1.0), which
  # the sandbox forbids; npm is not needed.
  ui = fetchurl {
    url = "https://huggingface.co/buckets/ggml-org/llama-ui/resolve/b${build}/dist.tar.gz";
    hash = hashes.ui;
  };

  postPatch = ''
    mkdir ui/apps/chat/dist
    tar -xzf ${finalAttrs.ui} -C ui/apps/chat/dist
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ]
  # glslc compiles the shaders.
  ++ lib.optionals vulkanSupport [ shaderc ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals vulkanSupport [
    spirv-headers
    vulkan-headers
    vulkan-loader
  ];

  cmakeFlags = [
    # -march=native would tie the build to the builder's CPU.
    (lib.cmakeBool "GGML_NATIVE" false)
    # One CPU backend per instruction set, picked at run time, as the
    # binaries from llama.app do.
    (lib.cmakeBool "GGML_CPU_ALL_VARIANTS" true)
    (lib.cmakeBool "GGML_BACKEND_DL" true)
    (lib.cmakeFeature "GGML_BACKEND_DIR" "${placeholder "out"}/bin")
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "GGML_VULKAN" vulkanSupport)
    (lib.cmakeBool "LLAMA_OPENSSL" true)
    (lib.cmakeBool "LLAMA_BUILD_APP" true)
    (lib.cmakeBool "LLAMA_BUILD_TESTS" false)
    (lib.cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    (lib.cmakeBool "LLAMA_BUILD_IS_DEV" false)
    # The release tarball has no git history to read these from.
    (lib.cmakeFeature "LLAMA_BUILD_NUMBER" build)
    (lib.cmakeFeature "LLAMA_BUILD_COMMIT" commit)
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/llama" version 2>&1 | grep -F "${version} (build ${build}, commit ${commit})"
    runHook postInstallCheck
  '';

  meta = {
    description = "Llama: run open models locally, from the llama.cpp team (command-line version)";
    homepage = "https://llama.app/";
    license = lib.licenses.mit;
    mainProgram = "llama";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
