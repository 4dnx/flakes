self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.whatsapp;
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

  config = lib.mkIf cfg.enable {
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
  };
}
