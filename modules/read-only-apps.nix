# targets.darwin.copyApps.readOnly: keeps every app Home Manager copies into
# `~/Applications/Home Manager Apps`, and that folder, read-only, so no app's
# own updater can replace or stage beside its copy. See README.md here.
{ config, lib, ... }:
{
  options.targets.darwin.copyApps.readOnly = lib.mkEnableOption ''
    read-only copies of the apps Home Manager copies (targets.darwin.copyApps)
    and of the folder they are in, made writable only while Home Manager
    copies them, so updates come through Nix only
  '';

  config = import ../lib/read-only-app-copies.nix {
    inherit config lib;
    name = "readOnlyApps";
    paths = [ "" ];
    lock = config.targets.darwin.copyApps.readOnly;
  };
}
