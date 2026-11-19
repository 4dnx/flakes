self:
{
  config,
  lib,
  pkgs,
  ...
}:
# Extend Home Manager's existing Zed module; its userSettings remain available.
{
  programs.zed-editor.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.zed;
  programs.zed-editor.userSettings = lib.mkIf config.programs.zed-editor.enable {
    auto_update = lib.mkDefault false;
    telemetry = {
      diagnostics = lib.mkDefault false;
      metrics = lib.mkDefault false;
    };
  };
}
