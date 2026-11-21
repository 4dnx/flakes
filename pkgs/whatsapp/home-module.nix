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
  imports = [
    (lib.mkRemovedOptionModule [ "programs" "whatsapp" "checkUpdates" ] ''
      WhatsApp checks for updates on every launch whatever its Sparkle
      preferences say, so no option can turn the check off; see the
      whatsapp package README.
    '')
  ];

  options.programs.whatsapp = {
    enable = lib.mkEnableOption "the native WhatsApp macOS app";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.whatsapp;
      description = "WhatsApp package to install.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];
      # Sparkle's system-profile report is telemetry, a default the user can set
      # back: written only while absent. The update check and automatic
      # installation keys are left alone: WhatsApp sets both itself when it
      # starts (see README.md).
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
