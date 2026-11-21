# Keeps apps in Home Manager's copy folder (targets.darwin.copyApps,
# `~/Applications/Home Manager Apps`) read-only. copyApps copies apps
# writable by the user, so an app's own updater can replace its copy until
# the next activation copies the pinned version back.
#
# Returns Home Manager configuration with two activation entries,
# `<name>Unlock` and `<name>Lock`, for `paths`, relative to that folder (""
# for the folder itself and everything in it). While `lock` is true they are
# made read-only (chmod -R a-w) after every copy. They are made writable
# again (chmod -R u+w) before the next one whatever `lock` holds: Home
# Manager's App Management check touches a file in each bundle and its rsync
# rewrites and deletes files in them, and a lock turned off must not leave a
# copy that rsync can't remove.
{
  config,
  lib,
  name,
  paths,
  lock,
}:
let
  copyApps = config.targets.darwin.copyApps;
  folder = "${config.home.homeDirectory}/${copyApps.directory}";
  # A symlinked folder is linkApps' (targets.darwin.linkApps), which
  # copyApps replaces; it is left alone.
  forEach =
    command:
    lib.concatMapStrings (
      path:
      let
        target = lib.escapeShellArg (if path == "" then folder else "${folder}/${path}");
      in
      ''
        if [[ -d ${target} && ! -L ${target} ]]; then
          ${lib.removeSuffix "\n" (command target)}
        fi
      ''
    ) paths;
in
lib.mkIf (copyApps.enable or false) {
  home.activation = {
    "${name}Unlock" =
      lib.hm.dag.entryBetween [ "checkAppManagementPermission" "copyApps" ] [ "writeBoundary" ]
        (
          forEach (target: ''
            run /bin/chmod -R u+w ${target} ||
              warnEcho "Could not make "${target}" writable; copying apps will fail."
          '')
        );
    "${name}Lock" = lib.mkIf lock (
      lib.hm.dag.entryAfter [ "copyApps" ] (
        forEach (target: ''
          run /bin/chmod -R a-w ${target}
        '')
      )
    );
  };
}
