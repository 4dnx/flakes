# rex

[Rex](https://www.superlogical.com/rex/docs), Superlogical's multiplexer for
all work: the `rex` command, which is both the CLI and the Rex server, from
upstream's release archive (unfree). Nothing is compiled.

Systems: `aarch64-darwin` only. Upstream also builds the binary for Intel
Macs, Linux and Windows; this package covers Apple Silicon macOS.

The package holds `bin/rex` as released, its linker signature intact. It
doesn't include Rex for Mac, the app: its downloads are available only to
beta testers who log in with Discord, and no public release lists them.

Rex is in testing. Until upstream publishes a stable release, the package
follows the preview channel, as upstream's install script does.

```nix
{ environment.systemPackages = [ inputs.f0dnx.packages.aarch64-darwin.rex ]; }
```

The package doesn't install Rex's terminal type (`xterm-rex`) or its ssh
fallback, which upstream's own Nix flake adds from files outside the release
archive; `rex terminfo setup` installs both for the account. See
[upstream's docs](https://www.superlogical.com/rex/docs/linux/installation.md#the-ssh-fallback).

## Updates and telemetry

Upstream's [privacy page](https://www.superlogical.com/rex/docs/reference/privacy.md)
lists every connection Rex makes: the `rex` command has no update check,
self-update or telemetry, and connects only to the servers it is given
and, when turned on, Tailscale.
Nothing in this package turns anything off. Updates come from this flake
(`nix flake update f0dnx`).

Rex for Mac, the app this package doesn't include, checks for updates with
Sparkle at launch and once a day, and upstream says that check can't be
turned off; whether it downloads and installs them on its own is set in
Settings > General > App Version (the info button beside Update Channel).

`update.sh` reads the newest release from upstream's release API
(`https://blob.superlogical.com/api/releases/rex/<channel>`), stable first,
then preview, and checks the archive against the sha256 the API lists. The
binary has no Developer ID signature to check. Updates pass through a pull
request: Rex runs shells and agents with the user's access.

## Maintenance

On a bump, check that the release still lists `rex-darwin-arm64.zip` with
the `rex` binary alone at its top level, and what upstream's
[Nix flake](https://pkgs.superlogical.com/rex/nix/preview.tar.gz) installs
on macOS beside `bin/rex`.
