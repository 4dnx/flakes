self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.kiri;
in
{
  options.programs.kiri = {
    enable = lib.mkEnableOption "Kiri, the container runtime";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.kiri;
      description = "Kiri package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    # Turn Settings › "Check for updates automatically" off, by its key in
    # the window's settings file, only while that file doesn't set it: the
    # user's choice wins. Only in a file the app has made: the app takes a
    # missing file for its first start (language and welcome steps).
    home.activation.kiriUpdateCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      kiri_ui="$HOME/.kiri/ui.json"
      if [ -f "$kiri_ui" ] &&
        ${lib.getExe pkgs.jq} -e 'type == "object" and (has("updateAuto") | not)' "$kiri_ui" >/dev/null 2>&1; then
        kiri_tmp="$(mktemp "$kiri_ui.XXXXXX")"
        ${lib.getExe pkgs.jq} -c '. + {updateAuto: false}' "$kiri_ui" >"$kiri_tmp" &&
          run mv "$kiri_tmp" "$kiri_ui" || rm -f "$kiri_tmp"
      fi
    '';
  };
}
