# Firewall rules

`updaters.lsrules` is a [Little Snitch](https://obdev.at/littlesnitch) rule
group for macOS. It denies the network to the app updaters that run as
processes of their own, so updates come through Nix:

| Updater | Code ID (team/identifier) | Updates |
|---|---|---|
| GoogleUpdater (and its launcher) | `EQHXZ8M8AV/com.google.GoogleUpdater` | Chrome, Google Drive |
| Google Software Update (Keystone) | `EQHXZ8M8AV/com.google.Keystone` | the same, before GoogleUpdater |
| Keystone agent | `EQHXZ8M8AV/com.google.Keystone.Agent` | the same |
| Microsoft AutoUpdate | `UBF8T346G9/com.microsoft.autoupdate2` | Word, Excel, PowerPoint |
| Microsoft Update Assistant | `UBF8T346G9/com.microsoft.autoupdate.fba` | the same, in the background |
| Microsoft AutoUpdate's helper | `UBF8T346G9/com.microsoft.autoupdate.helper` | installs as root |
| `msupdate` | `UBF8T346G9/com.microsoft.autoupdate.cli` | the command line |

The rules match each updater by its code signature (Little Snitch 6's code
IDs), not by its path: GoogleUpdater's path holds its version, and a copy may
sit in `~/Library` or `/Library`. The identifiers come from the signatures of
upstream's own files: GoogleUpdater from the Chrome disk image this flake
pins, Microsoft AutoUpdate from Microsoft's MAU installer (its signature
checked with `verify/pkg-signature-check.py`, team `UBF8T346G9`).

Blocking a process, not a host, leaves Nix's own downloads alone: `nix-daemon`
fetches the apps from the same vendor hosts the updaters use (for example
Google's and Microsoft's download servers), so a host block would break the
builds too. The apps themselves keep their network.

## Use

Subscribe in Little Snitch: Rules window, "+" beside **Rule Groups**, **Remote
Rule Group…**, and the URL
`https://raw.githubusercontent.com/xr3t/flakes/main/firewall/updaters.lsrules`.
Little Snitch then keeps the group up to date. Disable the group to let the
updaters run again.

## What it can't block

Some updaters download inside the app's own process and use a process of
their own only to install: Sparkle without its downloader service (WhatsApp
and Helium don't ship it; Ghostty ships it but doesn't turn it on with
`SUEnableDownloaderService`), Telegram's own updater, Squirrel's ShipIt
(Claude Desktop), Zed's, and Firefox's `updater.app`. Denying those processes
would stop nothing, and denying the app would cut the app off. Their packages
turn the updates off in the app instead, where it can be done; each package's
README says how.

Little Snitch for Linux reads no `.lsrules`, and its blocklists apply to every
process, `nix-daemon` included, so this group is macOS-only. The Linux packages
here have no updater process of their own.
