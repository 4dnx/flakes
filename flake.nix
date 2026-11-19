{
  description = "Nix packages by Prompter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Only the module checks use these two (checks.<linux>.darwin-modules,
    # home-modules, darwin-home-modules): the packages, the overlay and the
    # modules themselves don't, so they are fetched only when checks are
    # evaluated. A consumer can point them at its own with `follows` to keep
    # one copy.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;

      # Every directory under pkgs/ is a package: pkgs/<name>/package.nix.
      pkgDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./pkgs);
      packageNames = builtins.attrNames pkgDirs;

      # Unfree packages this flake's own `packages` allow. Overlay users allow
      # them in their own nixpkgs config.
      allowedUnfree = [
        "claude-code"
        "claude-desktop"
        "cloudflare-warp"
        "cloudflare-warp-headless"
        "firefox"
        "firefox-unwrapped"
        "google-chrome"
        "google-drive"
        "littlesnitch"
        "microsoft-excel"
        "microsoft-office"
        "microsoft-powerpoint"
        "microsoft-word"
        "whatsapp"
      ];

      pkgsFor = eachSystem (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfree;
        }
      );

      # All packages built against `pkgs`, in one scope so they can depend on
      # each other by argument name.
      mkPackagesFor =
        pkgs:
        let
          scope = lib.makeScope pkgs.newScope (
            self: lib.genAttrs packageNames (name: self.callPackage ./pkgs/${name}/package.nix { })
          );
        in
        lib.genAttrs packageNames (name: scope.${name});

      # Packages whose evaluation fetches another flake (Hermes). Their
      # platforms are given here, matching their meta.platforms, so listing
      # packages.<system> or using any module never fetches Hermes on other
      # systems.
      fixedPlatforms = {
        hermes-agent = [ "x86_64-linux" ];
      };

      # Only expose packages that build on the given system.
      available =
        system: name: pkg:
        if fixedPlatforms ? ${name} then
          builtins.elem system fixedPlatforms.${name}
        else
          lib.meta.availableOn pkgsFor.${system}.stdenv.hostPlatform pkg && !(pkg.meta.broken or false);

      # Service modules, by file name in pkgs/<name>/: module.nix is exported for
      # both nix-darwin and NixOS, darwin-module.nix / nixos-module.nix for one,
      # home-module.nix for Home Manager.
      modulesFrom =
        file:
        lib.genAttrs (builtins.filter (name: builtins.pathExists ./pkgs/${name}/${file}) packageNames) (
          name: import ./pkgs/${name}/${file} self
        );
      # Rolling builds: upstream replaces the file behind their URL with every
      # build, so a pin fails its hash until the next update. Left out of
      # checks; update.yml builds them when it bumps them.
      rolling = [
        "ghostty-tip"
      ];
      # Heavy builds: each Office app downloads a ~1.4 GB installer and takes
      # ~3 GB built. Left out of checks, so check.yml's macOS job and
      # update.yml's store cache stay small;
      # .github/workflows/microsoft-office.yml builds them on pull requests
      # that change them, and update.yml when it bumps them.
      heavy = [
        "microsoft-excel"
        "microsoft-office"
        "microsoft-powerpoint"
        "microsoft-word"
      ];

      # The modules of one kind, but those that fetch another flake when
      # evaluated (hermes-agent: upstream's modules).
      modulesToTest =
        modules: builtins.attrValues (removeAttrs modules (builtins.attrNames fixedPlatforms));
      darwinHome = system: lib.hasSuffix "-darwin" system;

      # Used by checks.<linux>.nixos-modules: a NixOS system with every NixOS
      # module imported and enabled.
      nixosModulesTest =
        system:
        nixpkgs.lib.nixosSystem {
          modules = modulesToTest self.nixosModules ++ [
            {
              nixpkgs.hostPlatform = system;
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
              };
              system.stateVersion = "25.11";
              users.users.alice.isNormalUser = true;
              programs.herdr.enable = true;
              services = {
                "1mcp" = {
                  enable = true;
                  user = "alice";
                  settings.mcpServers = { };
                };
                cloudflare-warp.enable = true;
                littlesnitch.enable = true;
                rayfish.enable = true;
                # nixpkgs' module, running this flake's package and its unit.
                tailscale = {
                  enable = true;
                  package = self.packages.${system}.tailscale;
                };
              };
            }
          ];
        };

      # Used by checks.<linux>.darwin-modules: a nix-darwin system (Apple
      # Silicon) with every nix-darwin module imported and enabled.
      darwinModulesTest = nix-darwin.lib.darwinSystem {
        modules = modulesToTest self.darwinModules ++ [
          {
            nixpkgs.hostPlatform = "aarch64-darwin";
            system.stateVersion = 6;
            system.primaryUser = "alice";
            programs = {
              google-drive.enable = true;
              herdr.enable = true;
              # PowerPoint left off, so the selection is exercised too.
              microsoft-office = {
                word.enable = true;
                excel.enable = true;
              };
            };
            services = {
              cloudflare-warp.enable = true;
              rayfish.enable = true;
              santa.enable = true;
            };
          }
        ];
      };

      # Used by checks.<linux>.home-modules (this Linux system: a standalone
      # Home Manager, as on Ubuntu) and darwin-home-modules (macOS): every
      # Home Manager module imported, and those for the system enabled.
      homeModulesTest =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.${system};
          modules = modulesToTest self.homeManagerModules ++ [
            {
              home = {
                username = "alice";
                homeDirectory = if darwinHome system then "/Users/alice" else "/home/alice";
                stateVersion = "25.11";
              };
              programs = {
                codex.enable = true;
                # Home Manager's own module, which homeManagerModules.firefox
                # extends.
                firefox.enable = true;
                helium.enable = true;
                muxin.enable = true;
                zed-editor.enable = true;
              };
              services.nullclaw.enable = true;
            }
            (lib.optionalAttrs (darwinHome system) {
              programs = {
                kiri.enable = true;
                whatsapp.enable = true;
              };
            })
          ];
        };

      # A configuration's drv path as a check: evaluated, not built.
      evaluated =
        pkgs: name: drv:
        pkgs.writeText name (builtins.unsafeDiscardStringContext drv.drvPath);
    in
    {
      packages = eachSystem (
        system: lib.filterAttrs (available system) (mkPackagesFor pkgsFor.${system})
      );

      overlays.default = import ./overlays { inherit mkPackagesFor; };

      darwinModules = modulesFrom "module.nix" // modulesFrom "darwin-module.nix";
      nixosModules = modulesFrom "module.nix" // modulesFrom "nixos-module.nix";
      homeManagerModules = modulesFrom "home-module.nix";

      # Every package but the rolling and heavy ones, every .nix file
      # formatted with `nix fmt`, and on Linux the scripts and workflows
      # linted and the NixOS, nix-darwin and Home Manager modules evaluated.
      checks = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        removeAttrs self.packages.${system} (rolling ++ heavy)
        // {
          warp-launchd-syntax =
            let
              variants = [
                { }
                { excludeRayfish = true; }
                { excludeHosts = [ "example.com" ]; }
                {
                  excludeRayfish = true;
                  excludeHosts = [ "example.com" ];
                }
              ];
              scripts = map (
                settings:
                let
                  test = darwinModulesTest.extendModules {
                    modules = [ { services.cloudflare-warp = settings; } ];
                  };
                  command = lib.last test.config.launchd.daemons.cloudflare-warp.serviceConfig.ProgramArguments;
                in
                pkgs.writeText "warp-launchd-script" (builtins.unsafeDiscardStringContext command)
              ) variants;
            in
            pkgs.runCommand "warp-launchd-syntax" { nativeBuildInputs = [ pkgs.bash ]; } ''
              ${lib.concatMapStringsSep "\n" (script: "bash --posix -n ${script}") scripts}
              touch "$out"
            '';
          warp-exclusions =
            pkgs.runCommand "warp-exclusions"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.python3
                  pkgs.coreutils
                  pkgs.gawk
                  pkgs.gnugrep
                ];
              }
              ''
                mkdir work
                export WARP_TEST_TMPDIR="$PWD/work"
                python3 ${./pkgs/cloudflare-warp/tests.py} ${./pkgs/cloudflare-warp/apply-exclusions.sh}
                touch "$out"
              '';
          formatting = pkgs.runCommand "formatting" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            find ${self} -name '*.nix' -exec nixfmt --check {} +
            touch "$out"
          '';
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          kiri-shell-profiles = import ./pkgs/kiri/tests.nix {
            inherit self home-manager pkgs;
          };
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
          # The Apple code signatures of macOS downloads (passthru.codesign),
          # checked on Linux too, so an update is checked before it reaches a
          # Mac, macOS-only packages included; on macOS each package's install
          # check does it. Packages that fetch another flake when evaluated
          # are skipped.
          lib.concatMapAttrs (
            name: pkg: lib.optionalAttrs (pkg ? codesign) { "${name}-codesign" = pkg.codesign; }
          ) (removeAttrs (mkPackagesFor pkgs) (builtins.attrNames fixedPlatforms))
        )
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # shellcheck over every shell script, and actionlint (which runs
          # shellcheck on the `run` scripts too) over the workflows. Its
          # source is only those files, so other changes don't rebuild it.
          lint =
            pkgs.runCommand "lint"
              {
                nativeBuildInputs = [
                  pkgs.actionlint
                  pkgs.shellcheck
                ];
                src = lib.fileset.toSource {
                  root = ./.;
                  fileset = lib.fileset.unions [
                    ./.github/workflows
                    (lib.fileset.fileFilter (file: file.hasExt "sh") ./lib)
                    (lib.fileset.fileFilter (file: file.hasExt "sh") ./pkgs)
                  ];
                };
              }
              ''
                cd "$src"
                find lib pkgs -name '*.sh' -exec shellcheck -x {} +
                actionlint .github/workflows/*.yml
                touch "$out"
              '';
          # The modules evaluated in a NixOS system, a nix-darwin system and
          # Home Manager on Linux and macOS (not built): each drv path is its
          # check's only content. The macOS ones are evaluated here, so CI
          # checks them on every change without a macOS runner.
          nixos-modules =
            evaluated pkgs "nixos-modules"
              (nixosModulesTest system).config.system.build.toplevel;
          darwin-modules = evaluated pkgs "darwin-modules" darwinModulesTest.config.system.build.toplevel;
          home-modules = evaluated pkgs "home-modules" (homeModulesTest system).activationPackage;
          darwin-home-modules =
            evaluated pkgs "darwin-home-modules"
              (homeModulesTest "aarch64-darwin").activationPackage;
        }
      );

      # nixfmt over the whole tree: plain `nix fmt` needs no path.
      formatter = eachSystem (system: pkgsFor.${system}.nixfmt-tree);
    };
}
