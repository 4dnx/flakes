# microsoft-powerpoint

Microsoft PowerPoint for macOS from Microsoft's signed installer package
(`go.microsoft.com/fwlink/?linkid=525136`), installed untouched as
`$out/Applications/Microsoft PowerPoint.app` (universal: Apple Silicon and Intel). The
`licensing` output holds the Office licensing helper from the same
installer, which Office needs to activate. Nothing is compiled. Unfree:
this flake's own `packages` allow it; through the overlay, the consuming
nixpkgs config has to allow `microsoft-powerpoint`. macOS 15 or later; Microsoft
ships no native Linux build.

Installing the package alone (`environment.systemPackages`, `home.packages`)
gives the app without the licensing helper, which has to run as a root
LaunchDaemon: use the nix-darwin module in
[microsoft-office](../microsoft-office), with
`programs.microsoft-office.powerpoint.enable = true`. That README also covers what
Microsoft's installer does, how its signature is checked and what to
recheck on a bump.

## Updates and telemetry

- Self-update: Microsoft AutoUpdate, which the installer brings as a
  separate component, is not installed; updates come from this flake
  (`nix flake update fordnx`). `update.sh` takes the build Microsoft's
  download link and MAU's manifest (`0409PPT32019-chk.xml`) agree on.
- Update checks and telemetry: the module's `autoUpdate.howToCheck`
  (default `"Manual"`) and `diagnosticData` (default
  `"ZeroDiagnosticData"`) set Microsoft's documented preferences, which a
  user's own setting overrides; see [microsoft-office](../microsoft-office#updates-and-telemetry).
