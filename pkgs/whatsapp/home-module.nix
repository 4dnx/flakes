self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.whatsapp;
  # Home Manager's copy of the app (targets.darwin.copyApps, from Home Manager
  # 25.11), which its rsync leaves writable by the user.
  copyApps = config.targets.darwin.copyApps or { enable = false; };
  app = "${config.home.homeDirectory}/${copyApps.directory}/WhatsApp.app";
in
{
  options.programs.whatsapp = {
    enable = lib.mkEnableOption "the native WhatsApp macOS app";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.whatsapp;
      description = "WhatsApp package to install.";
    };
    checkUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let Sparkle check WhatsApp's appcast for a newer release. false, the
        default, sets `SUEnableAutomaticChecks` to false on every activation,
        as updates come through Nix. Automatic installation
        (`SUAutomaticallyUpdate`) is set to false either way. WhatsApp turns
        both back on itself while it runs; the package's configuration
        profile keeps them off in between (see the package README).
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];
      # Forced on every activation, through `defaults import`, which merges
      # these keys into the domain and leaves the app's other preferences
      # alone. The signed app bundle stays untouched. GUI launches read these
      # preferences too.
      targets.darwin.defaults."net.whatsapp.WhatsApp" = {
        SUAutomaticallyUpdate = false;
      }
      // lib.optionalAttrs (!cfg.checkUpdates) { SUEnableAutomaticChecks = false; };
      # Sparkle's system-profile report is telemetry, a default the user can set
      # back: written only while absent.
      home.activation.whatsappSparkleDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ! /usr/bin/defaults read net.whatsapp.WhatsApp SUSendProfileInfo >/dev/null 2>&1; then
          run /usr/bin/defaults write net.whatsapp.WhatsApp SUSendProfileInfo -bool false
        fi
      '';
    })

    # Sparkle replaces the bundle it runs from, and copyApps leaves its copy
    # writable by the user, so the module makes that copy read-only after
    # every copy. It makes it writable again before the next one, as Home
    # Manager's App Management check touches a file in each bundle and its
    # rsync rewrites and deletes files in it: also while the module is
    # disabled, so that rsync can remove the copy.
    (lib.mkIf copyApps.enable {
      home.activation.whatsappUnlockApp =
        lib.hm.dag.entryBetween [ "checkAppManagementPermission" "copyApps" ] [ "writeBoundary" ]
          ''
            if [[ -d ${lib.escapeShellArg app} ]] &&
              ! run /bin/chmod -R u+w ${lib.escapeShellArg app}; then
              warnEcho ${lib.escapeShellArg "Could not make ${app} writable; copying it will fail."}
            fi
          '';
    })
    (lib.mkIf (cfg.enable && copyApps.enable) {
      home.activation.whatsappLockApp = lib.hm.dag.entryAfter [ "copyApps" ] ''
        if [[ -d ${lib.escapeShellArg app} ]]; then
          run /bin/chmod -R a-w ${lib.escapeShellArg app}
        fi
      '';
    })
  ];
}
