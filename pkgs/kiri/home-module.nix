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
      type = lib.types.nullOr lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.kiri;
      defaultText = lib.literalExpression "flakes.packages.\${pkgs.stdenv.hostPlatform.system}.kiri";
      description = ''
        Kiri package to install. null installs nothing and keeps the shell
        integration and update setting, for a Kiri installed elsewhere, such
        as nix-darwin's `environment.systemPackages`.
      '';
    };
    checkUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let Kiri check its feed for a newer app (when its window opens and
        every 6 hours) and offer to install it. false, the default, sets
        `updateAuto` to false in `~/.kiri/ui.json` on every activation, as
        updates come through Nix, so Settings › "Check for updates
        automatically" stays on only until then. true leaves the setting to
        Kiri, on by upstream's default.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
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
    # Turn Settings › "Check for updates automatically" off on every
    # activation, by its key in the window's settings file, as updates come
    # through Nix; checkUpdates leaves it to the app. Only in a file the app
    # has made: the app takes a missing file for its first start (language
    # and welcome steps).
    home.activation.kiriUpdateCheck = lib.mkIf (!cfg.checkUpdates) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        kiri_ui="$HOME/.kiri/ui.json"
        if [ -f "$kiri_ui" ] &&
          ${lib.getExe pkgs.jq} -e 'type == "object" and .updateAuto != false' "$kiri_ui" >/dev/null 2>&1; then
          kiri_tmp="$(mktemp "$kiri_ui.XXXXXX")"
          ${lib.getExe pkgs.jq} -c '. + {updateAuto: false}' "$kiri_ui" >"$kiri_tmp" &&
            run mv "$kiri_tmp" "$kiri_ui" || rm -f "$kiri_tmp"
        fi
      ''
    );
  };
}
