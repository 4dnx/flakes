self:
{
  config,
  lib,
  pkgs,
  ...
}:

# Microsoft Word, Excel and PowerPoint, each installed only when selected,
# with the licensing helper they share; see README.md here.
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  cfg = config.programs.microsoft-office;
  system = pkgs.stdenv.hostPlatform.system;

  apps = {
    word = "Microsoft Word";
    excel = "Microsoft Excel";
    powerpoint = "Microsoft PowerPoint";
  };
  enabled = lib.filter (app: cfg.${app}.enable) (builtins.attrNames apps);
  packages = map (app: cfg.${app}.package) enabled;

  # Each Office installer installs the helper it carries unless the one
  # already installed is newer, so the newest of the selected apps' wins.
  build = p: p.build or p.version;
  newest = lib.foldl' (
    a: b: if lib.versionOlder (build a) (build b) then b else a
  ) (lib.head packages) (lib.tail packages);

  label = "com.microsoft.office.licensingV3.helper";
  helper = "/Library/PrivilegedHelperTools/${label}";
  daemon = "/Library/LaunchDaemons/${label}.plist";
  # What the installer requires of the helper before installing it, and of an
  # installed one before trusting it: Microsoft's Developer ID and this
  # identifier.
  requirement = ''anchor apple generic and certificate leaf[subject.OU] = "UBF8T346G9" and identifier "${label}"'';
  # Records the helper and plist this module copied into place (their
  # sha256), so turning every app off removes only those, not a helper that
  # Microsoft's installer (Outlook, OneNote) put there before or since.
  marker = "/var/db/xr3t-microsoft-office-licensing";
  sort = lib.getExe' pkgs.coreutils "sort";

  appOptions = app: name: {
    enable = mkEnableOption name;
    package = mkOption {
      type = types.package;
      default = self.packages.${system}."microsoft-${app}";
      defaultText = literalExpression "fordnx.packages.\${pkgs.stdenv.hostPlatform.system}.microsoft-${app}";
      description = "${name} package to install.";
    };
  };

  # `defaults write` into /Library/Preferences, the domain for every user:
  # a value a user sets (in the app or with `defaults write`) wins over it.
  writePreference =
    domain: key: value:
    lib.optionalString (value != null) ''
      if [ "$(/usr/bin/defaults read /Library/Preferences/${domain} ${key} 2>/dev/null)" != ${lib.escapeShellArg value} ]; then
        /usr/bin/defaults write /Library/Preferences/${domain} ${key} -string ${lib.escapeShellArg value}
      fi
    '';
in
{
  options.programs.microsoft-office = lib.mapAttrs appOptions apps // {
    licensingHelper = mkOption {
      type = types.package;
      default = newest.licensing;
      defaultText = literalExpression "the `licensing` output of the newest enabled app";
      description = ''
        Package holding the Office licensing helper
        (`Library/PrivilegedHelperTools/${label}`) and its LaunchDaemon plist
        (`Library/LaunchDaemons/${label}.plist`). Installed, as regular files
        owned by root, at those paths whenever at least one app is enabled:
        Office activates and checks its license through it. Defaults to the
        one from the newest enabled app, as Microsoft's installers keep the
        newest.
      '';
    };

    diagnosticData = mkOption {
      type = types.nullOr (
        types.enum [
          "ZeroDiagnosticData"
          "BasicDiagnosticData"
          "FullDiagnosticData"
        ]
      );
      default = "ZeroDiagnosticData";
      example = "BasicDiagnosticData";
      description = ''
        Diagnostic data the apps send to Microsoft: Microsoft's documented
        `DiagnosticDataTypePreference` (domain `com.microsoft.office`, shared
        by every Office app). "ZeroDiagnosticData" sends none,
        "BasicDiagnosticData" the required data, "FullDiagnosticData" the
        required and optional data. Written to `/Library/Preferences`, the
        domain for every user, so a value a user sets wins over it. `null`
        writes nothing and leaves a value written earlier in place; Office's
        own default then applies once it is deleted
        (`sudo defaults delete /Library/Preferences/com.microsoft.office DiagnosticDataTypePreference`).
      '';
    };

    autoUpdate.howToCheck = mkOption {
      type = types.nullOr (
        types.enum [
          "Manual"
          "AutomaticCheck"
          "AutomaticDownload"
        ]
      );
      default = "Manual";
      example = "AutomaticDownload";
      description = ''
        How Microsoft AutoUpdate (MAU) checks for updates: its documented
        `HowToCheck` (domain `com.microsoft.autoupdate2`). MAU is not
        installed by this module, since updates come through Nix; this keeps
        it from updating these apps should another Microsoft product install
        it. MAU's preferences are global: they apply to every Microsoft app
        on the machine that MAU updates, not only these. Written to
        `/Library/Preferences` like `diagnosticData`, and `null` behaves the
        same way.
      '';
    };
  };

  config = mkMerge [
    (mkIf (enabled != [ ]) {
      # nix-darwin copies them to /Applications/Nix Apps.
      environment.systemPackages = packages;

      system.activationScripts.postActivation.text = ''
        # Microsoft Office licensing helper, as the installer's licensing
        # component puts it in place.
        microsoft_office_helper() {
          local new_helper=${cfg.licensingHelper}${helper}
          local new_daemon=${cfg.licensingHelper}${daemon}
          local requirement=${lib.escapeShellArg requirement}
          local installed ours attempt
          if ! /usr/bin/codesign --verify --strict --all-architectures -R="$requirement" "$new_helper"; then
            echo "microsoft-office: $new_helper is not Microsoft's licensing helper; left the installed one alone" >&2
            return 0
          fi
          if ! { /usr/bin/cmp -s "$new_helper" ${helper} && /usr/bin/cmp -s "$new_daemon" ${daemon}; }; then
            # A newer helper that Microsoft's installer put there stays, as
            # the installer itself would leave it.
            if [ -f ${helper} ] && [ ! -L ${helper} ] &&
              /usr/bin/codesign --verify --strict --all-architectures -R="$requirement" ${helper} &&
              installed="$("$new_helper" --version-of ${helper})" &&
              ours="$("$new_helper" --version-of "$new_helper")" &&
              [ "$installed" != "$ours" ] &&
              [ "$(printf '%s\n%s\n' "$installed" "$ours" | ${sort} -V | tail -n1)" = "$installed" ]; then
              echo "microsoft-office: keeping the installed licensing helper $installed, newer than $ours" >&2
              return 0
            fi
            echo "setting up the Microsoft Office licensing helper..." >&2
            /bin/launchctl bootout system/${label} 2>/dev/null || true
            /bin/mkdir -p /Library/PrivilegedHelperTools /Library/LaunchDaemons &&
              /usr/bin/install -m 0755 -o root -g wheel "$new_helper" ${helper}.nix-new &&
              /usr/bin/install -m 0644 -o root -g wheel "$new_daemon" ${daemon}.nix-new &&
              /bin/mv -f ${helper}.nix-new ${helper} &&
              /bin/mv -f ${daemon}.nix-new ${daemon} || return 1
            # Only files this module copied: identical ones that were
            # already there stay someone else's.
            /usr/bin/shasum -a 256 ${helper} ${daemon} > ${marker} || return 1
          fi
          if ! /bin/launchctl print system/${label} >/dev/null 2>&1; then
            /bin/launchctl enable system/${label} &&
              /bin/launchctl bootstrap system ${daemon} || return 1
          fi
          for attempt in 1 2 3 4 5; do
            ${helper} --probe && return 0
            [ "$attempt" = 5 ] || sleep 1
          done
          echo "microsoft-office: the licensing helper doesn't answer (${helper} --probe)" >&2
        }
        microsoft_office_helper || echo "microsoft-office: setting up the licensing helper failed" >&2

        # Microsoft Office preferences
        ${writePreference "com.microsoft.office" "DiagnosticDataTypePreference" cfg.diagnosticData}
        ${writePreference "com.microsoft.autoupdate2" "HowToCheck" cfg.autoUpdate.howToCheck}
      '';
    })

    # No app enabled: remove the helper this module installed, if it is
    # still the one it installed.
    (mkIf (enabled == [ ]) {
      system.activationScripts.postActivation.text = ''
        if [ -f ${marker} ]; then
          if /usr/bin/shasum -a 256 --status -c ${marker} 2>/dev/null; then
            echo "removing the Microsoft Office licensing helper..." >&2
            /bin/launchctl bootout system/${label} 2>/dev/null || true
            /bin/rm -f ${helper} ${daemon}
          fi
          /bin/rm -f ${marker}
        fi
      '';
    })
  ];
}
