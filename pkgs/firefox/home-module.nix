self:
{
  config,
  lib,
  pkgs,
  ...
}:
# Extends Home Manager's own Firefox module (programs.firefox): this flake's
# Firefox as its package, and on macOS the policies that keep its update
# check and telemetry off. On Linux the package does that itself (README.md);
# on macOS the signed bundle can't hold a policies file, so Home Manager
# writes them to the org.mozilla.firefox defaults, which Firefox reads as
# user policies.
let
  cfg = config.programs.firefox;
in
{
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.firefox;
      policies = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        # Updates come from this flake.
        DisableAppUpdate = true;
        # A default: `programs.firefox.policies.DisableTelemetry = false`
        # turns telemetry back on.
        DisableTelemetry = lib.mkDefault true;
      };
    };
  };
}
