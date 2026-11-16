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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    # Seed Sparkle preferences only when absent. User settings win, and the
    # signed app bundle stays untouched. GUI launches use these defaults too.
    home.activation.whatsappSparkleDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if /usr/bin/pgrep -xq WhatsApp; then
        echo "whatsapp: close the app before activating its default update preferences"
      else
        for key in SUEnableAutomaticChecks SUAutomaticallyUpdate SUSendProfileInfo; do
          if ! /usr/bin/defaults read net.whatsapp.WhatsApp "$key" >/dev/null 2>&1; then
            run /usr/bin/defaults write net.whatsapp.WhatsApp "$key" -bool false
          fi
        done
      fi
    '';
  };
}
