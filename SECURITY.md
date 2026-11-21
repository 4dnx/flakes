# Security

This is a personal flake, maintained on a best-effort basis. It repackages
other people's software. Read this before relying on it, especially for the
packages that run as system services.

## Reporting a vulnerability

Report it privately through GitHub: **Security → Report a vulnerability** on
this repository. Don't open a public issue for it.

Report here:

- the Nix code, modules and scripts in this repository (`flake.nix`,
  `pkgs/*/package.nix`, `*module.nix`, `update.sh`, `verify/`, `lib/`, `scripts/`,
  `ci/`);
- the workflows in `.github/workflows/`;
- a pinned hash or URL that downloads something other than upstream's
  official release.

A vulnerability in a packaged program goes to its upstream project, linked
from each package's `meta.homepage`. Tell us too if this flake makes it worse,
for example by exposing it in a module.

Expect an answer within a week or so. Only the latest commit on `main` gets
fixes; there are no release branches.

## Trust model

- **Prebuilt upstream binaries.** Almost every package installs upstream's
  official release as published (GitHub releases, npm, vendor download
  servers). Nothing is audited here.
- **Hashes pin, they don't vouch.** `hashes.json` proves a download is the one
  that was fetched when the update ran, not that it is safe. Where upstream
  publishes more, `update.sh` checks it as well: Node's `SHASUMS256.txt` must
  carry a signature by a Node release key, and Claude Code's release manifest
  one by the release key kept in `pkgs/claude-code`; downloads must match the checksums
  upstream lists beside them (checksum files, package indexes, update
  manifests, Google's update server for Chrome and Google Drive, Firefox's
  `SHA256SUMS` once its signature by Mozilla's release key checks out); GitHub release assets must match the
  digest GitHub recorded at upload; and npm packages are pinned by the registry's integrity hash. Every upstream version goes through `check_version`
  (`scripts/update-lib.sh`) before it reaches a URL, `hashes.json` or a commit
  message. Claude Code's macOS binary and Claude Desktop's whole app bundle
  must also carry intact Developer ID signatures of Anthropic's team chaining
  to Apple's root CA, Claude Desktop's seal covering every file in the bundle
  (`verify/codesign-check.py`); this is checked on Linux before an update lands
  and in the macOS install check. Microsoft publishes no checksum of its
  Office installers; their signature is checked instead, before an update
  lands and again in every build: the package's table of contents signed by
  Microsoft's Developer ID Installer certificate chaining to Apple's root
  CA, and every file in it matching the checksum recorded there
  (`verify/office-pkg-signature-check.py`). The app bundles inside are not checked on
  Linux (a ~1.4 GB download each). Google Drive's installer is checked the
  same way (Google's team), and the app inside, like Firefox's, Anoa's and Santa's macOS apps,
  must carry an intact Developer ID seal of its vendor's team, on Linux
  before an update lands and in the macOS install check.
- **Rolling builds.** `ghostty-tip` follows upstream builds that are
  replaced in place. Its pin only downloads until the next build.
- **Updates.** New releases are committed to `main` automatically once
  `nix flake check` passes, without review, except for the packages in
  `REVIEW` (root daemons, network filters, agents), whose updates go through
  a pull request that CI merges, also without review, once it builds on Linux
  x86_64, Linux aarch64 and macOS. The packages in `ON_REQUEST` (the Office
  apps, a ~1.4 GB download each) update only when a run names them. The pinned nixpkgs, which every package's
  libraries and tools come from, is bumped weekly the same way, with the
  nix-darwin and Home Manager inputs; those two only evaluate the modules in
  `checks` and are in no package or module. See
  [LAYOUT.md](LAYOUT.md) for how the workflow runs.
- **macOS checks.** CI evaluates macOS package derivations (on a Linux
  runner: evaluating builds nothing) and rebuilds, on macOS, those
  that differ from a successful ancestor Check of the PR base branch or `main`
  (a push or dispatch run: a `pull_request` run built a merge commit, not
  the head it reports).
  Unchanged derivations reuse that baseline's validation. Missing baselines
  and changes to check machinery (`check.yml` and `ci/`) trigger all macOS
  package checks; a change to a helper in `verify/`, `lib/` or `scripts/` changes the
  derivations of the packages that read it, so their checks run. Linux
  continues to run the full flake checks, including formatting. The heavy
  Office apps are not in the checks: `microsoft-office.yml` builds those a
  pull request changes when it is labeled `build-office` (or on Run
  workflow), and the update workflow builds each bump before it lands. A
  pull request that changes them without the label merges unbuilt on macOS.
- **Dependencies follow upstream's lock.** A package assembled from
  upstream's own lockfile installs exactly what that lock names, advisories
  included; they close when upstream ships a new lock and the next update
  picks it up. Nothing is patched here.
- **Updates and telemetry go through Nix.** Packages run as upstream ships
  them, except that self-updates, update checks and telemetry are off wherever
  the package allows it: through upstream's own switch where there is one,
  else an undocumented one (which may stop working on a bump), else a guard
  that refuses the update command. Update checks
  and telemetry are only defaults, which the user's own config can set back; each
  package's README says what is off and how. An updater built into a signed
  app bundle can only be turned off in the app.
- **Binary cache.** CI pushes only the closures of `hermes-agent` and `llama`, built from
  `main`, to `ret.cachix.org`; builds of pull requests and `update/<name>` branches
  never reach it. Trusting that cache means trusting this repository's CI.

## CI hardening

- Workflows default to a read-only `GITHUB_TOKEN`; only the update
  workflow's jobs can write, to commit updates and open their pull requests,
  and the check workflow's `merge` job, to merge an `update/<name>` pull
  request it built. No job keeps the token in its checkout: the update
  script pushes through `gh`'s credential helper with the token its step
  gets.
- Secrets and the token reach only the step that uses them (the Cachix push,
  the update script, the merge), never a whole job.
- Every job has a time limit.
- `checks.lint` runs shellcheck over the scripts and actionlint over the
  workflows.
- Actions are pinned by commit SHA and bumped by Dependabot.

## Service modules

The service modules run each daemon the way upstream's own installer does,
with the binary in the store, and add a sandbox only where upstream ships
one. On macOS (launchd) there is none.

- `littlesnitch`: upstream's own unit, with its capability bounding set and
  sandbox.
- `hermes-agent`: upstream's NixOS module, with its own system user and
  hardening.
- `rayfish`: upstream's unit; root, for its TUN device, routes and resolver,
  and no sandbox.
- `cloudflare-warp`: upstream's own `warp-svc.service` on NixOS, with its
  capability bounding set and no other sandbox, and the daemon's launchd job
  on macOS; root, for its tunnel, routes and DNS.
- `microsoft-office` (nix-darwin): Microsoft's licensing helper
  (`com.microsoft.office.licensingV3.helper`), installed as the Office
  installer does, with upstream's plist; a root LaunchDaemon started on
  demand by the apps over XPC, no sandbox. Its code signature is checked
  against Microsoft's team before it is installed.
- `google-drive` (nix-darwin): the app copied into `/Applications` with
  `Contents/MacOS/mount_helper` setuid root, as Google's installer does; no
  daemon. Google's updater is left out.
- `santa` (nix-darwin): Santa.app copied into `/Applications` as its
  installer's postinstall script does; Santa's system extension (root,
  Endpoint Security) then installs and loads its own launch jobs, as
  upstream's app does. Its tamper protection keeps the installed copy; an
  update goes through `santactl install`, which checks it.
- `tailscale`: no module here; the package ships upstream's unit for
  nixpkgs' `services.tailscale`, which runs `tailscaled` as root (for its TUN
  device, routes and firewall rules) with no sandbox.
- `nullclaw` and `1mcp`: no sandbox upstream. `hardening.enable` (off by
  default) adds one: no privilege gain, so no `sudo`; nullclaw can write only
  to its `stateDir` (plus `hardening.readWritePaths`), 1mcp gets a private
  `/tmp` and read-only `/usr`, `/boot` and `/etc`. Turn it on unless the
  agent has to administer the machine.

Agents (`nullclaw`, `hermes-agent`, `codex`, `opencode`, `pi`) run commands a
model chooses. Restrict who can reach them (e.g. nullclaw's `allow_from`) and
what they may do before enabling them, and do it in Nix: an agent can edit a
config file it can write, so put those limits in nullclaw's `settings`
(merged back in on every start) or run Hermes in managed mode
(`nixManagesConfig = true`).

## Secrets

Nothing in the Nix store is secret: it is world-readable. Options such as
`settings` and `environment` end up in the store, so keep tokens and API
keys in the files the modules read at run time (`environmentFile`, Hermes'
`environmentFiles`, nullclaw's `config.json`), ideally managed by sops-nix or
agenix.

This repository is public. Its code, docs and commits carry no private data:
noreply author emails only, and placeholders such as `alice` and
`example.com` in examples.
