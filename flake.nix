{
  description = "Nix packages by Prompter";

  inputs = {
    # Nixpkgs from FlakeHub: 0.1 is the rolling release of nixos-unstable.
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    nixos-shell = {
      url = "github:Mic92/nixos-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Only the module checks use these three (checks.<linux>.darwin-modules,
    # home-modules, darwin-home-modules), and `determinate` also the
    # nixos-shell guest: the other packages, the overlay and the modules
    # themselves don't, so they are fetched only when those are evaluated. A
    # consumer can point them at its own with `follows` to keep one copy.
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Determinate Nix's nix-darwin, Home Manager and NixOS modules: the module
    # checks evaluate against a system that runs Determinate Nix, and the
    # nixos-shell guest runs it. Its own
    # nixpkgs isn't followed, as upstream recommends: that would miss
    # FlakeHub Cache.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      determinate,
      nixos-shell,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;

      shellVM = lib.nixosSystem {
        modules = [
          nixos-shell.nixosModules.nixos-shell
          # The upstream launcher adjusts virtiofs flags. Darwin uses 9p.
          # Apply its guest defaults and expose nixpkgs' VM runner directly.
          (nixos-shell + "/share/modules/nixos-shell-config.nix")
          # Determinate Nix in the guest, with its telemetry off by default
          # (pkgs/nixos-shell/vm.nix).
          determinate.nixosModules.default
          ./pkgs/nixos-shell/vm.nix
          {
            nixpkgs.hostPlatform = "aarch64-linux";
            virtualisation.host.pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          }
        ];
      };

      # Packages in the shared scope have a pkgs/<name>/package.nix.
      pkgDirs = lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists ./pkgs/${name}/package.nix
      ) (builtins.readDir ./pkgs);
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
        "rex"
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
      # .github/workflows/microsoft-office.yml builds them on request (a
      # `build-office` label or Run workflow) on pull requests
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
      # Silicon) running Determinate Nix, with every nix-darwin module
      # imported and enabled.
      darwinModulesTest = nix-darwin.lib.darwinSystem {
        modules = modulesToTest self.darwinModules ++ [
          determinate.darwinModules.default
          {
            # Determinate Nix manages /etc/nix/nix.conf, not nix-darwin.
            determinateNix.enable = true;
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
      # Home Manager, as on Ubuntu) and darwin-home-modules (macOS), with
      # Determinate Nix's module (Nix comes from Determinate, not Home
      # Manager): every Home Manager module imported, and those for the
      # system enabled.
      homeModulesTest =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.${system};
          modules = modulesToTest self.homeManagerModules ++ [
            determinate.homeManagerModules.default
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
            # The Linux default Home Manager keeps for a stateVersion before
            # 26.05, set so it doesn't warn about the new XDG default.
            (lib.optionalAttrs (!darwinHome system) {
              programs.firefox.configPath = ".mozilla/firefox";
            })
            (lib.optionalAttrs (darwinHome system) {
              programs = {
                kiri.enable = true;
                whatsapp.enable = true;
              };
              targets.darwin.copyApps.readOnly = true;
            })
          ];
        };

      # A configuration's drv path as a check: evaluated, not built.
      evaluated =
        pkgs: name: drv:
        pkgs.writeText name (builtins.unsafeDiscardStringContext drv.drvPath);
    in
    {
      nixosConfigurations.nixos-shell = shellVM;

      packages = eachSystem (
        system:
        lib.filterAttrs (available system) (mkPackagesFor pkgsFor.${system})
        // lib.optionalAttrs (system == "aarch64-darwin") {
          nixos-shell = shellVM.config.system.build.vm;
        }
      );

      overlays.default = import ./overlays { inherit mkPackagesFor; };

      darwinModules = modulesFrom "module.nix" // modulesFrom "darwin-module.nix";
      nixosModules = modulesFrom "module.nix" // modulesFrom "nixos-module.nix";
      # Home Manager modules of the packages, and read-only-apps
      # (modules/read-only-apps.nix), which belongs to no one package.
      homeManagerModules = modulesFrom "home-module.nix" // {
        read-only-apps = import ./modules/read-only-apps.nix;
      };

      # Every package but the rolling and heavy ones, every .nix file
      # formatted with `nix fmt`, and on Linux the scripts and workflows
      # linted and the NixOS, nix-darwin and Home Manager modules evaluated.
      checks = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        removeAttrs self.packages.${system} (rolling ++ heavy ++ [ "nixos-shell" ])
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
                    (lib.fileset.fileFilter (file: file.hasExt "sh") ./ci)
                    (lib.fileset.fileFilter (file: file.hasExt "sh") ./scripts)
                    (lib.fileset.fileFilter (file: file.hasExt "sh") ./pkgs)
                  ];
                };
              }
              ''
                cd "$src"
                find ci scripts pkgs -name '*.sh' -exec shellcheck -x {} +
                actionlint .github/workflows/*.yml
                touch "$out"
              '';
          # firewall/updaters.lsrules, which users subscribe to by URL: valid
          # JSON, and every rule denies a process given by code ID
          # (identifier.<team>/<identifier>), never a path or "any", either
          # everywhere or towards the hosts it lists.
          firewall-rules =
            pkgs.runCommand "firewall-rules"
              {
                nativeBuildInputs = [ pkgs.jq ];
                rules = ./firewall/updaters.lsrules;
              }
              ''
                jq -e '
                  (.name | type == "string") and (.rules | type == "array" and length > 0) and
                  all(.rules[];
                    (.process | test("^identifier\\.[A-Z0-9]{10}/[A-Za-z0-9.-]+$")) and
                    .action == "deny" and
                    (.remote == "any" or (.["remote-hosts"] | type == "array" and length > 0)))
                ' "$rules" >/dev/null || {
                  echo "firewall/updaters.lsrules: not JSON, or a rule that isn't a deny of a code ID" >&2
                  exit 1
                }
                touch "$out"
              '';
          # The Office apps' installer signature check is their own copy, so a
          # change for another package doesn't rebuild them; the part that
          # decides whether a package is trusted must stay the same in both.
          pkg-signature-sync =
            pkgs.runCommand "pkg-signature-sync"
              {
                a = ./verify/pkg-signature-check.py;
                b = ./verify/office-pkg-signature-check.py;
              }
              ''
                region() { sed -n '/^ *# BEGIN shared verification/,/^ *# END shared verification/p' "$1"; }
                region "$a" >a
                region "$b" >b
                if [ "$(grep -c 'shared verification' a)" != 2 ]; then
                  echo "pkg-signature-check.py: no BEGIN/END shared verification markers" >&2
                  exit 1
                fi
                diff -u a b || {
                  echo "verify/pkg-signature-check.py and verify/office-pkg-signature-check.py differ in their shared verification" >&2
                  exit 1
                }
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

      # `nix develop`: the tools `checks` run, from the pinned nixpkgs, to run
      # one of them on its own (shellcheck on a script, actionlint on a
      # workflow) without the whole `nix flake check`.
      devShells = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              self.formatter.${system}
              pkgs.nixfmt
              pkgs.shellcheck
              pkgs.actionlint
              pkgs.jq
              pkgs.python3
            ];
          };
        }
      );
    };
}
