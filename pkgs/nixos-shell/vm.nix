{ lib, pkgs, ... }:
let
  # Determinate Nix's documented opt-out of all its telemetry, crash reports
  # included (docs.determinate.systems/guides/telemetry). A default: the
  # configuration can set it back.
  telemetry.DETSYS_IDS_TELEMETRY = lib.mkDefault "disabled";
in
{
  networking.hostName = "nixos-shell";
  networking.firewall.enable = true;
  system.stateVersion = "26.05";

  nixos-shell.mounts = {
    mountHome = false;
    mountNixProfile = false;
  };

  virtualisation = {
    cores = 2;
    memorySize = 1024;
    diskSize = 4096;
    qemu.enableSharedMemory = false;
    writableStoreUseTmpfs = false;
  };

  # Determinate Nix comes from determinate.nixosModules.default (flake.nix),
  # which runs the daemon through Determinate Nixd.
  systemd.services.nix-daemon.environment = telemetry;
  environment.variables = telemetry;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    jq
    ripgrep
  ];
}
