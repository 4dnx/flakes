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
      defaultText = lib.literalExpression "f0dnx.packages.\${pkgs.stdenv.hostPlatform.system}.whatsapp";
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
    # writable by the user, so the copy is read-only between activations. It
    # is unlocked while the module is disabled too, so that copyApps can
    # remove it.
    (import ../../lib/read-only-app-copies.nix {
      inherit config lib;
      name = "whatsappCopy";
      paths = [ "WhatsApp.app" ];
      lock = cfg.enable;
    })
  ];
}
