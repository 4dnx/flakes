# NixOS shell

`nixos-shell` boots this flake's ARM64 NixOS guest in a headless QEMU VM on
Apple Silicon. The terminal attaches to the guest's root console. The guest
includes Nix with flakes enabled, `jq` and `ripgrep` and uses QEMU user networking for outbound access.

Configure the public `nan` Cachix cache, then run a revision whose Cache workflow
has built, published and booted the VM:

```sh
nix run --builders "" --max-jobs 0 'github:4dnx/flakes/<commit-sha>#nixos-shell'
```

The launcher allocates 1 GiB of guest RAM, two vCPUs and a 4 GiB virtual disk.
Run from the same directory to reuse the guest's `nixos-shell.qcow2` disk.
The guest's home and writable Nix store overlay live on that disk. The
host's home and Nix profile are excluded from shares. The host Nix store is
mounted read-only, and QEMU also provides its standard exchange directory.
Enter `poweroff` at the guest console to return to macOS.

The launcher uses the guest defaults from Mic92's nixos-shell module and the
NixOS QEMU runner for macOS. The Cache workflow builds the guest on ARM Linux,
then builds the macOS launcher using the published guest. VPN credentials can
be provisioned inside the running guest and kept on its disk, outside the
flake and binary cache.
