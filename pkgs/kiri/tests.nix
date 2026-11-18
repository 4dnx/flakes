{
  self,
  home-manager,
  pkgs,
}:
let
  inherit (pkgs) lib;
  marker = "# Added by Kiri: its docker and kiri commands (kiri setup --uninstall removes this)";
  mkHome =
    extra:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        self.homeManagerModules.kiri
        {
          home.username = "alice";
          home.homeDirectory = "/Users/alice";
          home.stateVersion = "25.11";
          programs.kiri.enable = true;
        }
        extra
      ];
    };
  managed =
    (mkHome {
      programs.zsh.enable = true;
      programs.zsh.dotDir = "/Users/alice/.config/zsh";
      programs.bash.enable = true;
      programs.fish.enable = true;
    }).config;
  defaults =
    (mkHome {
      programs.zsh.enable = true;
      programs.zsh.dotDir = "/Users/alice";
    }).config;
  disabled =
    (mkHome {
      programs.kiri.enable = lib.mkForce false;
      programs.bash.enable = true;
    }).config;
  custom =
    (mkHome {
      programs.bash.enable = true;
      home.file.".bash_profile".source = lib.mkForce (
        pkgs.writeText "custom-bash-profile" "export CUSTOM_LOGIN=preserved\n"
      );
    }).config;
  profiles =
    map (name: managed.home.file.${name}.source) [
      ".config/zsh/.zprofile"
      ".config/zsh/.zshrc"
      ".bash_profile"
      ".profile"
      ".bashrc"
    ]
    ++ [
      defaults.home.file."./.zprofile".source
      defaults.home.file."./.zshrc".source
      managed.xdg.configFile."fish/conf.d/kiri.fish".source
    ];
  pathSnippet = pkgs.writeText "kiri-path-test" managed.programs.zsh.profileExtra;
in
assert !(disabled.xdg.configFile ? "fish/conf.d/kiri.fish");
pkgs.runCommand "kiri-shell-profiles" { } ''
  for profile in ${lib.escapeShellArgs (map toString profiles)}; do
    # Upstream skips writing only when this exact marker is present.
    grep -Fq ${lib.escapeShellArg marker} "$profile"
  done
  # Retain Home Manager's bash login behavior when adding the marker.
  grep -Fq '. ~/.profile' ${managed.home.file.".bash_profile".source}
  grep -Fq '. ~/.bashrc' ${managed.home.file.".bash_profile".source}
  # Preserve a consumer's custom source as well.
  grep -Fq 'export CUSTOM_LOGIN=preserved' ${custom.home.file.".bash_profile".source}
  grep -Fq ${lib.escapeShellArg marker} ${custom.home.file.".bash_profile".source}
  # Disabled Kiri must leave bash's profile unchanged.
  if grep -Fq ${lib.escapeShellArg marker} ${disabled.home.file.".bash_profile".source}; then
    exit 1
  fi
  # The PATH entry must append, preserve earlier commands, and be idempotent.
  HOME=/Users/alice PATH=/example/bin ${pkgs.bash}/bin/bash -c '
    . "$1"
    . "$1"
    test "$PATH" = "/example/bin:/Users/alice/.kiri/bin"
  ' bash ${pathSnippet}
  touch "$out"
''
