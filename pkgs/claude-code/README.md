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

The wrapper sets these, all documented in
[upstream's environment variables](https://code.claude.com/docs/en/env-vars):

| Variable | Effect | Turn back on |
|---|---|---|
| `DISABLE_UPDATES=1` | No background update; `claude update` and `claude install` refuse ("disabled by your administrator"), so no second copy lands in `~/.local`. Always set. | Update the flake input. |
| `FORCE_AUTOUPDATE_PLUGINS=1` | `DISABLE_UPDATES` would also stop plugin auto-updates; this keeps them on, as upstream has them. | Set it to an empty value. |
| `DISABLE_TELEMETRY=1` | No usage metrics. Like upstream's own switch, this also turns off feature-flag fetching, so Remote Control and other flag-gated features are unavailable. | Set it to an empty value. |
| `DISABLE_ERROR_REPORTING=1` | No error reports. | Set it to an empty value. |
| `DISABLE_INSTALLATION_CHECKS=1` | No warning that `claude` isn't in `~/.local/bin`. | Set it to an empty value. |

Except for `DISABLE_UPDATES`, each one is only a default: a value already in
the environment wins, and so does one in the `env` block of
`~/.claude/settings.json`, which Claude Code applies over its environment.
An empty value (`""`) undoes any of them. Don't use `0` for the two
telemetry variables: upstream counts any non-empty value as opting out.

## Notes

- On Linux, the binary loads ALSA (voice input) and libsecret (keyring) at
  run time from the library path. Most distributions have them; NixOS doesn't
  put them in one, and adding them to the binary's RUNPATH with patchelf makes
  it crash, so those two features may be missing there.
- The Linux sandbox needs `bubblewrap` and `socat` on `PATH`, as upstream
  documents; install them alongside.
- On a bump, recheck the manifest layout (`claude.zst` per platform), the
  `--version` format the install check expects, and the variables above.
