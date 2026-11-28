self:
{
  config,
  lib,
  pkgs,
  ...
}:

# Santa, installed as its installer package's postinstall script does; see
# README.md here.
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.services.santa;
  app = "/Applications/Santa.app";
  staged = "/var/db/santa/migration";
in
{
  options.services.santa = {
    enable = mkEnableOption "Santa, the binary and file access authorization system for macOS";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.santa;
      defaultText = literalExpression "xr3t.packages.\${pkgs.stdenv.hostPlatform.system}.santa";
      description = "Santa package to install.";
    };
  };

  config = mkIf cfg.enable {
    system.activationScripts.postActivation.text = ''
      # Santa, as its installer package's postinstall script installs it.
      santa_install() {
        local src=${cfg.package}/Applications/Santa.app
        local want=${lib.escapeShellArg cfg.package.build}
        local installed
        installed="$(/usr/bin/defaults read ${app}/Contents/Info.plist CFBundleVersion 2>/dev/null || true)"
        if [ "$installed" = "$want" ]; then
          return 0
        fi
        # Google's Santa running: upstream's package waits for it to be
        # removed; this leaves it to the user.
        if /usr/bin/systemextensionsctl list com.apple.system_extension.endpoint_security 2>/dev/null |
          /usr/bin/grep -qE 'EQHXZ8M8AV.+com\.google\.santa\.daemon.+activated'; then
          echo "santa: Google's Santa is running; uninstall it before installing Santa" >&2
          return 0
        fi
        echo "installing Santa $want..." >&2
        # The newsyslog config is the system extension's to install: it
        # keeps one the admin changed.
        /bin/rm -rf ${staged}
        /bin/mkdir -p ${staged} &&
          /usr/bin/ditto "$src" ${staged}/Santa.app &&
          /usr/sbin/chown -R root:wheel ${staged}/Santa.app &&
          /bin/chmod -R u+w,go-w ${staged}/Santa.app || return 1
        # Removing the installed copy only works while Santa isn't running:
        # its tamper protection keeps it otherwise, and then Santa itself
        # installs the update, if its signature checks out.
        if /bin/rm -rf ${app} 2>/dev/null; then
          /bin/mv ${staged}/Santa.app ${app} &&
            ${app}/Contents/MacOS/Santa --load-system-extension || return 1
        else
          ${app}/Contents/MacOS/santactl install || return 1
        fi
        /bin/rm -rf ${staged}
        /bin/mkdir -p /usr/local/bin
        /bin/ln -sf ${app}/Contents/MacOS/santactl /usr/local/bin/santactl
      }
      santa_install || echo "santa: installing ${app} failed" >&2
    '';
  };
}
