# Llama

The command-line version of [Llama](https://llama.app/) from the llama.cpp
team: the unified `llama` binary (`llama serve`, `llama cli`, `llama download`,
`llama bench`, ...), plus the tools llama.cpp installs next to it
(`llama-server`, `llama-cli`, ...). Linux only (`x86_64-linux`,
`aarch64-linux`); on macOS and Windows llama.app is a desktop app.

```nix
inputs.xr3t.url = "github:xr3t/flakes";
environment.systemPackages = [ inputs.xr3t.packages.${system}.llama ];
```

The overlay also provides `pkgs.xr3t.llama`.

```sh
llama serve    # OpenAI-compatible API and chat UI on http://localhost:9931
```

## How it is built

llama.app's `install.sh` downloads one of several hundred prebuilt binaries,
chosen by probing the CPU and GPU at install time. That doesn't fit a pinned
store path, so this package builds the same release from the llama.cpp source
tag (`v<version>`, which `update.sh` follows) with the same options:

- A CPU backend for each instruction set, chosen at run time, so one build runs
  on any CPU of its architecture and uses the best code on newer ones.
- The Vulkan backend, for GPUs from any vendor. Build without it with
  `.override { vulkanSupport = false; }`. CUDA and ROCm are not built; use
  nixpkgs' `llama-cpp` with `cudaSupport` or `rocmSupport` for those.
- The chat UI that llama.cpp's own releases embed, downloaded as upstream
  built it (`hashes.ui`) rather than rebuilt with npm. Nothing is fetched at
  build time outside the pinned hashes.

The tarball has no git history, so `hashes.json` records the build number and
commit that `llama version` reports; `update.sh` reads them from the
`v<version>-b<build>-<commit>` tag.

Compiling takes minutes, so CI pushes the `x86_64-linux` and `aarch64-linux`
builds to `ret.cachix.org` from `main` (see `SECURITY.md`); with that cache
as a substituter the package is downloaded instead.

## Updates and telemetry

- **Self-update: off.** `llama update` runs llama.app's `install.sh` only in
  binaries built with `LLAMA_INSTALL_BUILD`, which this package doesn't set;
  here it prints that updates are available only when installed from
  llama.app. Update through this flake.
- **Telemetry and update checks:** none in the program. Models are downloaded
  from Hugging Face only when you ask (`llama download`, `-hf`, the chat UI).

Recheck on a bump: `llama update` in `app/llama.cpp`, any new network call at
startup, and that `tools/ui/dist` is still what `scripts/ui-assets.cmake` looks
for first.
