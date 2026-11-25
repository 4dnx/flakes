# AGENTS.md

Guidance for coding agents working in this repo. `README.md` is the
user-facing doc; keep it, the package table in `pkgs/README.md` and each
package's README in sync with behavior. Remote: `xr3t/flakes`.

`README.md` holds only general information about the flake: what it is, how
to install and use it, its outputs and how updates work in general. Don't
change it for a package, a schedule or a workflow: a package's details go in
`pkgs/<name>/README.md` and its row in `pkgs/README.md`, files and workflows
in `LAYOUT.md`. Change `README.md` only when that general information
changes.

## Layout

See `LAYOUT.md`; keep it in sync when adding a kind of file or workflow.
Packages go under `pkgs/`: one package's files in `pkgs/<name>/`, a family's
shared files in one of its packages. What packages of different families share
goes in a top-level folder named after what it holds, never under `pkgs/`:
signature and install checks in `verify/`, Nix functions in `lib/`, the tools
`update.sh` scripts use in `scripts/`, firewall rules in `firewall/`, modules
that belong to no one package in `modules/`. `ci/` holds the CI and update
machinery the workflows run.

## Running installed commands

Use the active installation through `PATH` or the active user or system
profile when running any installed command. Keep the profile path when it
resolves to a store symlink. Use a specific store path when the task requires
an exact artifact, such as testing a build before activation.

## Adding a package

Use upstream's native application binaries for each declared operating system
and CPU architecture, including Apple Silicon on macOS and the matching Linux
architecture. Do not substitute a web wrapper or an emulated binary when an
upstream native release is missing; leave that system unsupported and say so.

1. `pkgs/<name>/package.nix` (+ `hashes.json` and `update.sh` if it tracks
   upstream releases). `update.sh` sources `scripts/update-lib.sh` and passes
   every upstream version through `check_version`. Where upstream publishes
   checksums (a sums file, `.sha256` files, a manifest), check downloads
   against them (`sums`, or `prefetch URL SHA256`); GitHub release assets are
   checked against GitHub's digest by `prefetch` itself. If the package runs
   as root or acts with the user's access, add it to `REVIEW` in
   `.github/workflows/update.yml`. Give the package an install check that runs
   it (`--version`, or `verify/check-app.py` for a macOS app bundle): building
   is not starting.
2. Set `meta.platforms` to the systems it really supports; that's what filters
   `packages.<system>`. If evaluating it fetches another flake, also list it
   in `fixedPlatforms` in `flake.nix`.
3. Add a row, in alphabetical order, to the package table in `pkgs/README.md`,
   and a `pkgs/<name>/README.md` if it has options. Package-specific notes
   (gotchas, what to recheck on a bump) go in that README or as comments in
   the package's own files, not in this file.
4. `git add` new files; flakes ignore untracked files.

For a macOS profile command that launches an executable inside an app bundle,
use `lib/app-copy-launcher.nix` so it prefers a matching installed copy and
falls back to the packaged bundle. Preserve the launcher’s arguments and
environment. When an app has multiple launch commands, use the same copy
selection policy for each. Keep service entry points and installer-managed
links on the paths their integration requires.

## Modules

Run a package and its service the way upstream's own installer does (recheck
its unit or plist on a bump), with the binary in the store: Nix makes it
declarative, it doesn't change how it behaves. Updates and telemetry go
through Nix instead (next section). Anything else beyond upstream, such as a
sandbox it doesn't ship, is an option that is off by default.

## Updates and telemetry

Turn off every package's self-update, update check and telemetry wherever it
can be done; updates come from this flake. When adding or bumping a package,
look for all three in its docs, its config schema and its binary.

1. Use upstream's documented switch first: a setting, an env var, a flag, or
   an override that upstream offers redistributions.
2. Without one, an undocumented knob will do, but say so in the package README
   and recheck it on every bump: upstream may drop it.
3. Last resort for an update command: a guard wrapper that refuses it.

Update checks and self-updates go through Nix only. A module turns them off
on every activation (or through Nix-managed config), whatever the program's
own config holds, and only the Nix config turns an update check back on, with
a module option (`checkUpdates`). A self-update stays off: it would replace
the store copy, a root daemon could write into the store, and on macOS an
app's updater can replace Home Manager's writable copy of the app
(`targets.darwin.copyApps`, see "Updates" in `README.md`; `read-only-apps`
keeps those copies read-only). Don't call an
app's updater harmless because the store is read-only: say which installs it
can replace. Where an app reads its switch only from managed preferences,
ship a configuration profile (`pkgs/<name>/*.mobileconfig`). Where no
setting holds it (an app that starts its own checks whatever its settings
say), say so in the package README instead of claiming it is off; a rule in
`firewall/` can cut the update host off if the app works without it.

Telemetry is a default the user can set back: the user's Nix config or the
program's own config wins. So apply it only while that config doesn't set it
(a flag or env var added conditionally), or as a module option.

In the package README, say what is off, how, and how to turn it back on. Where
nothing in the package can turn it off (an updater inside a signed app
bundle), say that and how to turn it off in the app.

## Writing docs

Write READMEs, `LAYOUT.md`, `SECURITY.md` and comments in a neutral
documentation style: say what a package, module or script does, instead of
talking to the reader. No "you", "your" or "for you"; name who it concerns
("the user", "the consuming nixpkgs", "the configuration") or use the passive.
Steps may be imperatives ("Install Nix with flakes enabled"). Quoted program
output, such as an error message, stays as the program prints it.

## Checking changes

```sh
# Evaluate everything and build this host's packages; on Linux also lint
# scripts and workflows.
nix flake check --all-systems
nix build .#<name> && ./result/bin/<prog> --version
nix fmt   # nixfmt; checks.formatting fails otherwise
# One check's tool on its own, at the version the checks use.
nix develop -c shellcheck -x pkgs/<name>/update.sh
nix develop -c actionlint .github/workflows/<file>.yml
```

Avoid `--no-build`: its read-only store fails on filtered sources that are
read during evaluation.

A local check builds only the host's own system; CI builds Linux x86_64, Linux
aarch64 and macOS. To try a change in a system config, build that config
against this checkout (`--override-input <input> path:<checkout>`); don't
switch to it unless asked.

## Workflows

Pin actions by commit SHA (with the tag in a comment). Give secrets only to
the step that needs them, never at job level, and default to
`permissions: contents: read`.

The update workflow opens pull requests for the packages in `REVIEW`, which
needs Settings → Actions → General → "Allow GitHub Actions to create and
approve pull requests" on the repository; `check.yml` merges them once every
system passes. GitHub's merge queue isn't available to a repository owned by
a user account, so the `merge` job merges directly, and only a tested head
that contains `main` (`ci/merge-update.sh` rebases one that doesn't and
checks it again). `check.yml` checks a pull request at its head, so update
any other pull request that GitHub reports out of date with `main` and let
its checks pass before merging it. Don't make the `main` branch rule require
status checks: `update.yml` pushes the updates outside `REVIEW` straight to
`main` with `GITHUB_TOKEN`, which such a rule rejects and can't exempt.

## Commits

Commits containing Codex contributions include the trailer
`Co-authored-by: Codex <noreply@openai.com>`.

Short imperative subject lines with no prefix. The update workflow commits as
`Update <name> to vX.Y.Z`.

This repo is public. Commits and files must not carry private data:

- No links to private sessions or chats (such as an agent's session trailer).
  This holds for pull request descriptions, comments and reviews too: a tool
  may append a footer that links the session, so check what was posted and
  edit the link out.
- Author and committer emails are noreply addresses only.
- No hostnames, usernames, IPs, local paths or other details of anyone's
  machines in code, comments, docs or commit messages; use `alice`,
  `example.com` and the like in examples.
- READMEs, notes and comments describe a package for anyone who installs it,
  not how its maintainer uses it. Leave out their setup and habits: which
  features, channels or services they run, the other tools they pair it with,
  what they tested on, and incidents seen on their machines. Write such facts
  as upstream behavior or a general case ("a polling channel", "another VPN",
  "a transient API error"); upstream's own release, bug or issue is fine to
  cite.
