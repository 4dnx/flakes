self:
{
  config,
  lib,
  pkgs,
  ...
}:

# Google Drive for desktop, installed into /Applications as Google's
# installer does; see README.md here.
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  cfg = config.programs.google-drive;

  app = "/Applications/Google Drive.app";
  seal = "${app}/Contents/_CodeSignature/CodeResources";
  # The store path of the copy this module put in /Applications and the
  # sha256 of its seal, so a copy Google's updater or installer put there
  # since is replaced on the next activation, and one this module didn't
  # install is never removed.
  marker = "/var/db/xr3t-google-drive";
  settings = "/Library/Preferences/com.google.drivefs.settings";
  sealHash = ''"$(/usr/bin/shasum -a 256 < ${lib.escapeShellArg seal} | /usr/bin/cut -d' ' -f1)"'';
  # The copy is this module's and unchanged since it put it there.
  ours = ''[ -f ${marker} ] && [ -f ${lib.escapeShellArg seal} ] && [ "$(/usr/bin/sed -n 2p ${marker})" = ${sealHash} ]'';
in
{
  options.programs.google-drive = {
    enable = mkEnableOption "Google Drive for desktop";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.google-drive;
      defaultText = literalExpression "xr3t.packages.\${pkgs.stdenv.hostPlatform.system}.google-drive";
      description = "Google Drive package to install.";
    };
    automaticErrorReporting = mkOption {
      type = types.nullOr types.bool;
      default = false;
      example = true;
      description = ''
        Whether Google Drive sends error reports to Google:
        `AutomaticErrorReporting` in `com.google.drivefs.settings`, a key the
        app reads but Google doesn't document. Written to
        `/Library/Preferences`, Google's host-wide settings, which a user's
        own settings override. `null` writes nothing and leaves a value
        written earlier in place.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      system.activationScripts.postActivation.text = ''
        # Google Drive, as Google's installer puts it in place.
        google_drive_install() {
          local src=${lib.escapeShellArg "${cfg.package}/Applications/Google Drive.app"}
          local app=${lib.escapeShellArg app}
          if [ "$(/usr/bin/sed -n 1p ${marker} 2>/dev/null)" = "$src" ] && ${ours}; then
            return 0
          fi
          echo "installing Google Drive..." >&2
          /bin/rm -rf "$app.nix-new"
          /usr/bin/ditto "$src" "$app.nix-new" &&
            /usr/sbin/chown -R root:wheel "$app.nix-new" &&
            /bin/chmod -R u+w,go-w "$app.nix-new" &&
            # The installer's postinstall script makes the mount helper
            # setuid root.
            /bin/chmod u+s "$app.nix-new/Contents/MacOS/mount_helper" || return 1
          /bin/rm -rf "$app" && /bin/mv "$app.nix-new" "$app" || return 1
          printf '%s\n%s\n' "$src" ${sealHash} > ${marker} || return 1
          # As the postinstall script does: refresh Quick Look, and ask a
          # running Google Drive to restart into the new copy.
          /usr/bin/qlmanage -r >/dev/null 2>&1 || true
          /usr/bin/pkill -USR1 -nx 'Google Drive' || true
        }
        google_drive_install || echo "google-drive: installing ${app} failed" >&2

        ${lib.optionalString (cfg.automaticErrorReporting != null) ''
          if [ "$(/usr/bin/defaults read ${settings} AutomaticErrorReporting 2>/dev/null)" != ${
            if cfg.automaticErrorReporting then "1" else "0"
          } ]; then
            /usr/bin/defaults write ${settings} AutomaticErrorReporting -bool ${lib.boolToString cfg.automaticErrorReporting}
          fi
        ''}
      '';
    })

    # Disabled: remove the copy this module installed, if it is still the
    # one it installed.
    (mkIf (!cfg.enable) {
      system.activationScripts.postActivation.text = ''
        if [ -f ${marker} ]; then
          if ${ours}; then
            echo "removing Google Drive..." >&2
            /bin/rm -rf ${lib.escapeShellArg app}
          fi
          /bin/rm -f ${marker}
        fi
      '';
    })
  ];
}
