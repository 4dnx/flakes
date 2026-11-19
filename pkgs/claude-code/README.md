# claude-code

[Claude Code](https://code.claude.com) from upstream's native release, the
binary `claude.ai/install.sh` installs, on its `latest` channel. Unfree:
overlay users must allow `claude-code` in their nixpkgs configuration.
Nothing is compiled.

```nix
home.packages = [ inputs.xr3t.packages.${system}.claude-code ];
```

`libexec/claude-code/claude` is upstream's single Bun-compiled binary. On
macOS it is untouched (`dontFixup`). On Linux it needs only glibc, so its
interpreter is pointed at Nix's loader; stripping is off, since that would cut
off the program Bun appends. `bin/claude` is a wrapper.

Systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`.

## Updates and telemetry

`update.sh` follows `downloads.claude.ai/claude-code-releases/latest`. It
checks the release's `manifest.zst.json` against its detached GPG signature
and upstream's release key (`release-key.asc`, fingerprint
`31DD DE24 DDFA B679 F42D 7BD2 BAA9 29FF 1A7E CACE`, as
[upstream's setup page](https://code.claude.com/docs/en/setup) lists it), then
each platform's download against the manifest's SHA-256. Updates pass
through a pull request.

The macOS binary's Apple code signature is checked too, without macOS
(`helpers/codesign-check.py`, with `rcodesign` and `openssl`): it must be intact
and signed with a Developer ID Application certificate of Anthropic's team
`Q6L2SF6YDW` that chains to Apple's root CA. The macOS install check runs it
on the installed binary, and `checks.<linux>.claude-code-codesign` on the
pinned download, so an update that fails it never reaches a Mac.

The wrapper sets these, all documented in
[upstream's environment variables](https://code.claude.com/docs/en/env-vars):

| Variable | Effect | Turn back on |
|---|---|---|
| `DISABLE_UPDATES=1` | No background update; `claude update` and `claude install` refuse ("disabled by your administrator"), so no second copy lands in `~/.local`. Always set. | Update the flake input. |
| `FORCE_AUTOUPDATE_PLUGINS=1` | `DISABLE_UPDATES` would also stop plugin auto-updates; this keeps them on, as upstream has them. | Set it to an empty value. |
| `DISABLE_ERROR_REPORTING=1` | No error reports. | Set it to an empty value. |
| `DISABLE_INSTALLATION_CHECKS=1` | No warning that `claude` isn't in `~/.local/bin`. | Set it to an empty value. |

Except for `DISABLE_UPDATES`, each one is only a default: a value already in
the environment wins, and so does one in the `env` block of
`~/.claude/settings.json`, which Claude Code applies over its environment.
An empty value (`""`) undoes any of them. Don't use `0` for
`DISABLE_ERROR_REPORTING`: upstream counts any non-empty value as opting out.

Usage metrics stay on, unlike other packages here: upstream ties its feature
flags to them, so `DISABLE_TELEMETRY` (or `DO_NOT_TRACK`) also turns off
[the features that need them](https://code.claude.com/docs/en/env-vars#features-that-need-feature-flag-fetching):
Remote Control, syncing the skills and plugins enabled for the claude.ai
account, `claude import`, the advisor tool, MCP tasks, Code Mode, artifact
comments and others. To turn metrics off anyway, at that cost:

```nix
inputs.xr3t.packages.${system}.claude-code.override { disableTelemetry = true; }
```

or `DISABLE_TELEMETRY=1` in the environment.

## Linux

- **Voice input.** Its addon, embedded in the binary (`audio-capture.node`),
  links `libasound.so.2`. Nix's loader doesn't search a distribution's
  library directories, and a RUNPATH makes the Bun binary crash, so the
  wrapper appends `lib/claude-code`, a directory holding only Nix's
  `libasound.so.2`, to `LD_LIBRARY_PATH`. Commands Claude Code runs inherit
  that variable, so they find Nix's ALSA library before their own RUNPATH; a
  `LD_LIBRARY_PATH` already set comes first. Nix's ALSA reads `/etc/asound.conf`
  and `~/.asoundrc`; on a distribution whose sound server reaches ALSA through
  a plugin configured elsewhere, check that voice input records.
- **Sandbox.** `bubblewrap` and `socat` from Nix are appended to `PATH`.
  Claude Code runs the first `bwrap` on `PATH`, so a distribution's own
  `/usr/bin/bwrap` still wins. Ubuntu 24.04 and later restrict unprivileged
  user namespaces through AppArmor: give the `bwrap` Claude Code runs a
  profile, as [upstream's sandbox guide](https://code.claude.com/docs/en/sandboxing#add-an-apparmor-profile-for-bubblewrap)
  shows, or install the distribution's `bubblewrap`. The optional seccomp
  filter (`@anthropic-ai/sandbox-runtime` on npm) isn't included.
- **Keyring.** The Bun runtime can load libsecret, but Claude Code doesn't
  use it: on Linux it keeps its login in `~/.claude/.credentials.json`.

## Rechecking on a bump

The manifest layout (`claude.zst` per platform), the `--version` format the
install check expects, the signing team ID, the variables above, and the libraries the embedded
addons link (`patchelf --print-needed` on the shared objects inside the
binary).
