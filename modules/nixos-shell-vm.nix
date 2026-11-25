{ pkgs, ... }:
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    jq
    ripgrep
  ];
}
