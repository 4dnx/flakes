self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.kiri;
  # Kiri 0.2.1 skips profiles containing this exact upstream marker.
  profileMark = "# Added by Kiri: its docker and kiri commands (kiri setup --uninstall removes this)";
  shellPath = ''
    ${profileMark}
    case ":$PATH:" in *":$HOME/.kiri/bin:"*) ;; *) export PATH="$PATH:$HOME/.kiri/bin" ;; esac
  '';
in
{
  options.home.file = lib.mkOption {
    # Bash's managed .bash_profile has no extra-content option. Append to
    # its resolved source, retaining Home Manager's and the user's content.
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }: {
          options.source = lib.mkOption {
            apply =
              source:
              if cfg.enable && config.programs.bash.enable && name == ".bash_profile" then
                pkgs.runCommand "kiri-bash-profile" { } ''
                  cat ${lib.escapeShellArg (toString source)} > "$out"
                  printf '\n' >> "$out"
                  cat ${pkgs.writeText "kiri-shell-path" shellPath} >> "$out"
                ''
              else
                source;
          };
        }
      )
    );
  };
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
    # First launch writes shell profiles before opening the window. Seed the
    # marker and PATH in managed profiles so setup leaves store files alone.
    programs.zsh = lib.mkIf config.programs.zsh.enable {
      profileExtra = lib.mkAfter shellPath;
      initContent = lib.mkAfter shellPath;
    };
    programs.bash = lib.mkIf config.programs.bash.enable {
      profileExtra = lib.mkAfter shellPath;
      initExtra = lib.mkAfter shellPath;
    };
    xdg.configFile."fish/conf.d/kiri.fish" = lib.mkIf config.programs.fish.enable {
      text = ''
        ${profileMark}
        fish_add_path --append $HOME/.kiri/bin
      '';
    };
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
