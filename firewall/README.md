# Firewall rules

`updaters.lsrules` is a [Little Snitch](https://obdev.at/littlesnitch) rule
group for macOS. It denies the network to app updaters, so updates come
through Nix.

The updaters that run as processes of their own lose the network entirely:

| Updater | Code ID (team/identifier) | Updates |
|---|---|---|
| GoogleUpdater (and its launcher) | `EQHXZ8M8AV/com.google.GoogleUpdater` | Chrome, Google Drive |
| Google Software Update (Keystone) | `EQHXZ8M8AV/com.google.Keystone` | the same, before GoogleUpdater |
| Keystone agent | `EQHXZ8M8AV/com.google.Keystone.Agent` | the same |
| Microsoft AutoUpdate | `UBF8T346G9/com.microsoft.autoupdate2` | Word, Excel, PowerPoint |
| Microsoft Update Assistant | `UBF8T346G9/com.microsoft.autoupdate.fba` | the same, in the background |
| Microsoft AutoUpdate's helper | `UBF8T346G9/com.microsoft.autoupdate.helper` | installs as root |
| `msupdate` | `UBF8T346G9/com.microsoft.autoupdate.cli` | the command line |

Apps that update from inside their own process lose only their update hosts,
where those hosts serve nothing else:

| App | Code ID (team/identifier) | Hosts denied |
|---|---|---|
| Telegram | `6N38VWS5BX/ru.keepcoder.Telegram` | `osx.telegram.org` (its `SUFeedURL`, and the downloads) |
| Ghostty | `24VZTF6M5V/com.mitchellh.ghostty` | `release.files.ghostty.org`, `tip.files.ghostty.org` (its stable and tip appcasts) |

Telegram's messages go to its MTProto servers, and the app names no other use
of that host. Ghostty itself needs no network: the programs run in it are
processes of their own, with rules of their own.

The rules match by code signature (Little Snitch 6's code IDs), not by path:
GoogleUpdater's path holds its version, a copy may sit in `~/Library` or
`/Library`, and a Nix store path changes with every release. The identifiers
and hosts come from upstream's own files: GoogleUpdater from the Chrome disk
image this flake pins, Microsoft AutoUpdate from Microsoft's MAU installer
(its signature checked with `verify/pkg-signature-check.py`, team
`UBF8T346G9`), Telegram's and Ghostty's from the pinned app bundles (their
signatures, `Info.plist` and executables).

Blocking a process, not a host for every process, leaves Nix's own downloads
alone: `nix-daemon` fetches the apps from the same vendor hosts the updaters
use, so a system-wide host block would break the builds too.

## Use

Subscribe in Little Snitch: Rules window, "+" beside **Rule Groups**, **Remote
Rule Group…**, and the URL
`https://raw.githubusercontent.com/xr3t/flakes/main/firewall/updaters.lsrules`.
Little Snitch then keeps the group up to date. Disable the group, or one rule
in it, to let an updater run again.

## Left out

These apps update from inside their own process, through a host that also
serves something else, so a rule would cut more than updates:

- Helium: `updates.helium.computer` also serves its component updates.
- Firefox: `aus5.mozilla.org` also serves its media plugins (Widevine,
  OpenH264; `media.gmp-manager.url`). The package turns the update check off
  with Mozilla's `DisableAppUpdate` policy instead.
- WhatsApp: its appcast is on `web.whatsapp.com`.
- Claude Desktop: `downloads.claude.ai` also serves the Claude Code binary the
  app runs, its model catalog and its VM images.
- Zed: `zed.dev` is also its server for sign-in and extensions.

Their packages turn the updates off in the app where it can be done; each
package's README says how.

Little Snitch for Linux reads no `.lsrules`, and its blocklists apply to every
process, `nix-daemon` included, so this group is macOS-only. The Linux packages
here have no updater process of their own.
