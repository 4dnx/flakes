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
    # Nothing is written while the app runs, and the note asking to close it
    # appears only while a preference is still absent.
    home.activation.whatsappSparkleDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      whatsapp_missing=""
      for key in SUEnableAutomaticChecks SUAutomaticallyUpdate SUSendProfileInfo; do
        if ! /usr/bin/defaults read net.whatsapp.WhatsApp "$key" >/dev/null 2>&1; then
          whatsapp_missing="$whatsapp_missing $key"
        fi
      done
      if [ -n "$whatsapp_missing" ]; then
        if /usr/bin/pgrep -xq WhatsApp; then
          echo "whatsapp: close the app before activating its default update preferences"
        else
          for key in $whatsapp_missing; do
            run /usr/bin/defaults write net.whatsapp.WhatsApp "$key" -bool false
          done
        fi
      fi
    '';
  };
}
