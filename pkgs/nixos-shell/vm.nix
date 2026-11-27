{ lib, pkgs, ... }:
let
  # Determinate Nix's documented opt-out of all its telemetry, crash reports
  # included (docs.determinate.systems/guides/telemetry). A default: the
  # configuration can set it back.
  telemetry.DETSYS_IDS_TELEMETRY = lib.mkDefault "disabled";
in
{
  networking.hostName = "nixos-shell";

  # The guest's own user, logged in on the console instead of root. UID 501
  # is the first account's on a Mac: through the 9p shares (security_model
  # none), the guest sees the host's owners, so files the Mac user owns in
  # the shared folder are nixos's, and nixos can write them.
  # NixOS keeps isNormalUser for UIDs from 1000, so nixos is declared a
  # system user and given what isNormalUser would: home, shell, group.
  users.users.nixos = {
    isSystemUser = true;
    uid = 501;
    group = "users";
    home = "/home/nixos";
    createHome = true;
    useDefaultShell = true;
    extraGroups = [ "wheel" ];
    # No password, as root had: the console logs in automatically.
    initialHashedPassword = "";
  };
  # nixos-shell's module logs root in; this replaces it.
  services.getty.autologinUser = lib.mkForce "nixos";
  # Root's work through sudo, without a password, as on root's console.
  security.sudo.wheelNeedsPassword = false;
  # nixos may use Nix as root may (extra substituters, builds), beside root,
  # which NixOS trusts already: it can become root through sudo anyway.
  nix.settings.trusted-users = [ "nixos" ];
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
