# microsoft-office

Microsoft Word, Excel and PowerPoint for macOS, from Microsoft's signed
installer packages, with a nix-darwin module that installs any selection of
them and the licensing helper they need. The apps are separate packages,
[microsoft-word](../microsoft-word), [microsoft-excel](../microsoft-excel)
and [microsoft-powerpoint](../microsoft-powerpoint), built by
`builder.nix` here; this package is the three together (each app
bundle linked whole), and the directory holds the module.

All four are unfree (this flake's own `packages` allow them; through the
overlay, the consuming nixpkgs config has to allow `microsoft-word`,
`microsoft-excel`, `microsoft-powerpoint` and `microsoft-office`). Each app
is a universal (Apple Silicon and Intel) bundle, installed untouched;
nothing is compiled. Microsoft ships no native Linux build, so Linux is
unsupported. macOS 15 or later, as the installers require.

## nix-darwin module

```nix
{
  imports = [ xr3t.darwinModules.microsoft-office ];
  programs.microsoft-office = {
    word.enable = true;
    excel.enable = true;
    # powerpoint.enable = false;
  };
}
```

| Option | Default | |
|---|---|---|
| `word.enable`, `excel.enable`, `powerpoint.enable` | `false` | Install that app. Nothing is installed unless selected. |
| `word.package`, `excel.package`, `powerpoint.package` | this flake's | The app's package. |
| `licensingHelper` | the `licensing` output of the newest enabled app | The licensing helper to install (below). |
| `diagnosticData` | `"ZeroDiagnosticData"` | Office's diagnostic data level (below). |
| `autoUpdate.howToCheck` | `"Manual"` | Microsoft AutoUpdate's update checks (below). |

The selected apps go into `environment.systemPackages`, which nix-darwin
copies into `/Applications/Nix Apps` (real directories owned by root, not
links into the store). Microsoft's installer puts them in `/Applications`;
nothing in the apps was found to require that, but Microsoft AutoUpdate and
the installer's legacy-helper cleanup look for them there, and the
licensing helper's binary also names them by their `/Applications` paths. Another copy of the same app elsewhere (from
Microsoft's installer or Homebrew) has the same bundle identifier, so
Launch Services may open either: remove it.

### Licensing helper

Office signs in and checks its license through a root LaunchDaemon,
`com.microsoft.office.licensingV3.helper`, shared by every Office app
(Word, Excel, PowerPoint, Outlook, OneNote). Whenever at least one app is
enabled, the module's activation script puts it in place as the installer's
licensing component does:

- checks the new helper's code signature against the requirement the
  installer uses (`anchor apple generic and certificate leaf[subject.OU] =
  "UBF8T346G9" and identifier "com.microsoft.office.licensingV3.helper"`),
  and installs nothing if it fails;
- keeps an installed, validly signed helper that is newer (as reported by
  `--version-of`), as the installer does;
- otherwise unloads the job (`launchctl bootout`), copies the helper to
  `/Library/PrivilegedHelperTools/com.microsoft.office.licensingV3.helper`
  (0755) and upstream's plist, unchanged, to
  `/Library/LaunchDaemons/com.microsoft.office.licensingV3.helper.plist`
  (0644), both regular files owned by `root:wheel`, then
  `launchctl enable` and `launchctl bootstrap system`;
- waits for `--probe` to answer, as the installer does, and warns if it
  doesn't.

A failure is reported and doesn't stop the rest of the activation. The
helper starts on demand (its XPC service), not at boot.

When the module is imported with every app disabled, activation removes the
helper and its plist again, but only if they are still the files this
module copied there (their sha256 is recorded in
`/var/db/xr3t-microsoft-office-licensing`): a helper that Microsoft's
installer (Outlook, OneNote) put there, before or since, is left alone. Removing the
module's import altogether leaves the helper installed; remove it by hand:

```sh
sudo launchctl bootout system/com.microsoft.office.licensingV3.helper
sudo rm /Library/PrivilegedHelperTools/com.microsoft.office.licensingV3.helper \
  /Library/LaunchDaemons/com.microsoft.office.licensingV3.helper.plist \
  /var/db/xr3t-microsoft-office-licensing
```

An older helper, `com.microsoft.office.licensingV2.helper`, left by an
earlier Office install, is left alone: Microsoft's installers retire it only
once every Office app in `/Applications` has a current package receipt,
which apps installed through Nix don't have.

### Switching from the Homebrew casks

Upstream behavior to keep in mind: uninstalling Homebrew's `microsoft-word`
(and the other Office casks) unloads both licensing helpers
(`com.microsoft.office.licensingV2.helper`, `...V3.helper`), which every
Office app shares, and forgets their receipts; `brew uninstall --zap` also
removes `~/Library/Application Support/Microsoft`, which every Office app
shares, and the app's containers (`~/Library/Containers/com.microsoft.Word*`
and so on). Uninstall the casks without `--zap` to keep documents' recent
lists, settings and sign-in state. nix-darwin's `homebrew` activation runs
before this module's, so removing the casks and enabling the module in the
same switch ends with the helper installed; a `brew uninstall` run later
unloads it again (the next activation puts it back).

## Updates and telemetry

- **Self-update: off.** Microsoft AutoUpdate (MAU), the updater the
  installers bring as a separate component, is not installed (Homebrew's
  casks deselect it too), and nor is its root helper and launch agent; the
  apps are not registered with it. Updates come from this flake
  (`nix flake update xr3t`).
- **Update checks: `autoUpdate.howToCheck = "Manual"`.** Should another
  Microsoft product install MAU, this keeps it from checking and installing
  updates on its own: Microsoft's documented `HowToCheck` in
  `com.microsoft.autoupdate2`
  ([MAU preferences](https://learn.microsoft.com/microsoft-365-apps/mac/mau-preferences)).
  MAU's preferences are global: this applies to every Microsoft app that
  MAU updates on the machine.
- **Telemetry: `diagnosticData = "ZeroDiagnosticData"`.** No diagnostic data
  ("Neither"): Microsoft's documented `DiagnosticDataTypePreference` in
  `com.microsoft.office`, which every Office app reads
  ([privacy preferences](https://learn.microsoft.com/microsoft-365-apps/privacy/mac-privacy-preferences)).
  Connected experiences (co-authoring, online templates, Copilot) are
  features rather than telemetry and are left as they are; Microsoft
  documents their switches on the same page. Crash reports go through
  Microsoft Error Reporting (inside each app bundle), which the module
  doesn't configure.

Both are written to `/Library/Preferences/<domain>`, the domain for every
user, on activation while an app is enabled. A value a user sets (in the
app's or MAU's settings, or with `defaults write <domain> <key>`) wins over
it. To turn either back on from the configuration, set it to another value
(`"BasicDiagnosticData"`, `"FullDiagnosticData"`; `"AutomaticCheck"`,
`"AutomaticDownload"`), or to `null` to stop writing it; `null` leaves the
value already written, which `sudo defaults delete /Library/Preferences/<domain> <key>`
removes so Office's own default applies.

## What the installer does

Inspected for 16.115.1 (Word); Excel and PowerPoint carry the same three
components. The `Distribution` (macOS 15 or later, arm64 and x86_64) has
three choices:

| Choice | Component | Installs | Scripts |
|---|---|---|---|
| `com.microsoft.word` (always on) | `Microsoft_Word.pkg` (`com.microsoft.package.Microsoft_Word.app`) | `Microsoft Word.app` in `/Applications` (~2.8 GB, ~51,000 files) | preinstall: quits a running Word. postinstall: registers the app with MAU (`Applications` in the console user's `com.microsoft.autoupdate2`, `ApplicationsSystem` in `/Library/Preferences/com.microsoft.autoupdate2`); runs the licensing reconciliation in "app" mode (only with a working V3 helper: may retire the V2 helper, see above); starts `chain_app`, which waits for Installer to quit and runs `gktool scan` on the app (a Gatekeeper pre-scan that makes the first launch faster). |
| `com.microsoft.autoupdate` (optional) | `Office16_all_autoupdate.pkg` (MAU 4.85) | `Microsoft AutoUpdate.app` in `/Library/Application Support/Microsoft/MAU2.0` | Quits MAU, fixes the permissions of `/Library/Application Support/Microsoft`, installs MAU's root helper (`com.microsoft.autoupdate.helper`) and launch agent (`com.microsoft.update.agent`), opens MAU. |
| `com.microsoft.licensing` (hidden, always on) | `Office16_all_licensing.pkg` (`com.microsoft.pkg.licensing.v3`) | The helper and its plist, staged in `/Library/Application Support/Microsoft` | postinstall ("component" mode): what the module reproduces, above; also registers the helper with MAU (`OLIC02`, hidden). |

What the packages and module do with each: the app component is extracted
into the store (`out`); the licensing component into the `licensing` output,
already at its final paths, which the module installs as described above;
MAU is left out. Left out of the app component's scripts: quitting a running
app, registering with MAU (not installed), the V2 reconciliation (needs receipts) and `gktool scan` (an
optimization; Gatekeeper scans the app at its first launch instead).

## Packages and updates

Each app's `update.sh` (`update-lib.sh` here) follows
Microsoft's download link (`go.microsoft.com/fwlink/?linkid=525134` for
Word, `525135` Excel, `525136` PowerPoint), which redirects to the current
installer on Microsoft's CDN, and takes its build once MAU's own manifest
for the app (`0409MSWD2019-chk.xml`, `0409XCEL2019-chk.xml`,
`0409PPT32019-chk.xml`) offers the same one. Microsoft publishes no checksum
of the installers (the signed catalogs beside the manifests list only the
MAU update packages, and the release history page lists none), so the
download is pinned by its hash, after `verify/pkg-signature-check.py` has
checked the package's signature on Linux or macOS: its table of contents
signed (RSA and CMS) by Microsoft's Developer ID Installer certificate
(team `UBF8T346G9`) chaining to Apple's root CA, and every file in it
matching the checksum recorded there. The version comes from the signed
`Distribution`. The build checks the signature again before extracting
anything, and the install check (`verify/check-app.py`) the app's version,
build and arm64 slice, and the helper's build. Updates go through a pull
request (`REVIEW` in `update.yml`): the helper runs as root.

The apps are left out of `checks` (`heavy` in `flake.nix`): each downloads
~1.4 GB and takes ~3 GB built. `.github/workflows/microsoft-office.yml` builds those
whose derivation a pull request changes; `update.yml` builds each bump
before proposing it, and deletes it from the store again so its cache stays
small.

On a bump, recheck: the components and their scripts (`xar -tf`, then
`Scripts` with `gzip -dc | cpio -i`), in particular the licensing
component's postinstall, which the module reproduces; that the licensing
helper's build still equals the app's (the install check fails otherwise);
and the documented preferences.
