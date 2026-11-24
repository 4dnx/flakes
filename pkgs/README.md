# Packages

Every package in this flake, what it brings and the systems it runs on. Each
name links to the package's own README, with its options, what it turns off
(self-update, telemetry) and how to turn that back on. For installing them,
see [the top-level README](../README.md).

See [macOS app launchers](../README.md#macos-app-launchers) for how profile commands select an app bundle.

| Package | Description |
|---|---|
| [1mcp](1mcp) | Unified MCP runtime that aggregates MCP servers behind one endpoint, with a NixOS service module |
| [anoa](anoa) | Anoa headless browser (CDP, a command per action for agents) from upstream's prebuilt releases: its signed, notarized `anoa.app` on macOS (the seal checked), its Linux bundle run unpatched in an FHS environment; Apple Silicon macOS and Linux, no compilation |
| [bend](bend) | Bend parallel functional language (runs `.bend` files directly or builds native binaries) from upstream's prebuilt release, with clang on Linux; update check off, no self-update; Apple Silicon macOS and Linux, no compilation |
| [claude-code](claude-code) | Claude Code from upstream's native release (`latest` channel, unfree), checked against its GPG-signed manifest; self-update and error reports off, usage metrics on so flag-gated features such as Remote Control work; Apple Silicon macOS and Linux, no compilation |
| [claude-desktop](claude-desktop) | Claude Desktop for macOS from upstream's signed app bundle (unfree), its whole code-signature seal checked, with a configuration profile that turns its self-update off; Apple Silicon, no compilation |
| [cloudflare-warp](cloudflare-warp) | Cloudflare WARP client (`warp-cli`, the `warp-svc` daemon and tray app, or the macOS app) from upstream's deb and installer (unfree), with a nix-darwin/NixOS service module that keeps its update check off and offers an opt-in Rayfish overlay exclusion; Apple Silicon macOS and Linux, no compilation |
| [codex](codex) | OpenAI Codex CLI from upstream's prebuilt npm release; Apple Silicon macOS and Linux, no compilation |
| [cua-driver](cua-driver) | Desktop control driver for Hermes' computer_use; telemetry and update check off by default; Linux only, no compilation |
| [firefox](firefox) | Mozilla Firefox's latest release from Mozilla's builds (unfree terms): the signed macOS app, and on Linux the release tarball run through nixpkgs' `wrapFirefox`, its update check and telemetry off by default; a Home Manager module extends `programs.firefox`; Apple Silicon macOS and Linux, no compilation |
| [ghostty](ghostty) | Ghostty terminal's latest release from upstream's Ghostty.dmg; macOS only, no compilation |
| [ghostty-tip](ghostty) | Ghostty's rolling tip build from main, bumped daily |
| [google-chrome](google-chrome) | Google Chrome's latest Stable release from Google's signed dmg (unfree); macOS only, no compilation |
| [google-drive](google-drive) | Google Drive for desktop from Google's signed installer (unfree), its signature and the app's seal checked, with a nix-darwin module that installs it into `/Applications` as the installer does, without Google's updater, and turns error reports off; Apple Silicon macOS only, no compilation |
| [helium](helium) | Helium browser (Chromium-based, private by default) from upstream's signed, notarized dmg on macOS and its binary tarball on Linux, with a Home Manager module that keeps its update check off; Apple Silicon macOS and Linux, no compilation |
| [herdr](herdr) | Herdr desktop app, herdr-core (`hc`) and the `herdr` CLI from upstream's prebuilt releases, with a nix-darwin/NixOS module that routes its updates through Nix; Apple Silicon macOS and Linux, no compilation |
| [hermes-agent](hermes-agent) | Hermes Agent pinned to upstream's latest stable release tag (`minimal` + telegram, mcp), with upstream's NixOS and Home Manager modules; x86_64 Linux only |
| [kiri](kiri) | Kiri container runtime (a Docker Desktop alternative with its own `docker`, Compose and buildx) from upstream's signed app bundle, its whole code-signature seal checked, with a Home Manager module that turns its update check off; Apple Silicon, no compilation |
| [lite-xl](lite-xl) | Lite XL editor from upstream's addons release (language plugins, colour schemes) as Lite XL.app, Apple Silicon only |
| [littlesnitch](littlesnitch) | Little Snitch for Linux network monitor (unfree freeware binary), with a NixOS service module |
| [llama](llama) | Llama (llama.app) command line from the llama.cpp team: local models with an OpenAI-compatible API and chat UI; built from source with Vulkan, self-update off; Linux only |
| [microsoft-excel](microsoft-excel) | Microsoft Excel from Microsoft's signed installer (unfree), its signature checked; installed with its licensing helper by the [microsoft-office](microsoft-office) nix-darwin module; macOS only, no compilation |
| [microsoft-office](microsoft-office) | Microsoft Word, Excel and PowerPoint together, with a nix-darwin module that installs any selection of them and the licensing helper they share, keeps Microsoft AutoUpdate out and turns diagnostic data and update checks off; macOS only, no compilation |
| [microsoft-powerpoint](microsoft-powerpoint) | Microsoft PowerPoint from Microsoft's signed installer (unfree), its signature checked; installed with its licensing helper by the [microsoft-office](microsoft-office) nix-darwin module; macOS only, no compilation |
| [microsoft-word](microsoft-word) | Microsoft Word from Microsoft's signed installer (unfree), its signature checked; installed with its licensing helper by the [microsoft-office](microsoft-office) nix-darwin module; macOS only, no compilation |
| [muxin](muxin) | One desktop app for many machines and their AI agents (sessions, desktops, logs, files) over ssh, with its CLI and MCP server, from upstream's prebuilt release; Apple Silicon macOS and Linux, no compilation |
| [nh](nh) | Nix CLI helper from prebuilt upstream binaries, without Rust compilation |
| [nodejs-24-lts](nodejs-24-lts) | Official prebuilt Node.js 24 LTS with independently pinned npm latest; no source compilation |
| [nullclaw](nullclaw) | Small, fully autonomous AI assistant in one static Zig binary, with a Home Manager module that runs it as upstream's user service |
| [nullclaw-chat-ui](nullclaw-chat-ui) | NullClaw's web chat UI as static files, to serve from any web server |
| [opencode](opencode) | OpenCode 2 AI coding agent from upstream's prebuilt npm release, kept on Nix (no self-update); Apple Silicon macOS and Linux, no compilation |
| [pi](pi) | Pi coding agent from published npm packages with Node.js 24 LTS; local assembly, no Pi source compilation |
| [rayfish](rayfish) | P2P mesh VPN (iroh), with a nix-darwin/NixOS service module |
| [santa](santa) | Santa, North Pole Security's binary and file access authorization system, from upstream's signed installer package, the app's seal checked, with a nix-darwin module that installs it into `/Applications` as the installer does; no update check or telemetry upstream; Apple Silicon macOS only, no compilation |
| [tailscale](tailscale) | Tailscale CLI and node agent (`tailscale`, `tailscaled`, no GUI) from upstream's static build, for NixOS' `services.tailscale`; log upload off by default, no self-update; Linux only, no compilation |
| [telegram](telegram) | Native Telegram for macOS from its official app bundle (not Telegram Desktop); Apple Silicon, no compilation |
| [utm](utm) | UTM virtual machine host for macOS from the upstream release dmg, no compilation |
| [whatsapp](whatsapp) | Native WhatsApp for macOS from its official app bundle (unfree), with a Home Manager module that keeps Home Manager's copy read-only; its built-in updater checks on every launch whatever its settings say (see its README); Apple Silicon, no compilation |
| [zed](zed) | Zed editor from official native releases; Apple Silicon macOS and Linux x86_64/ARM64, with a Home Manager module for update and telemetry defaults; no compilation |
