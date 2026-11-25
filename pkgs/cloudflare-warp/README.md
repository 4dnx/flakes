# cloudflare-warp

A Nix package and service module for the
[Cloudflare WARP client](https://one.one.one.one/) (the Cloudflare One Client,
formerly 1.1.1.1 with WARP): `warp-cli`, the `warp-svc` daemon and the tray
app on Linux, `Cloudflare WARP.app` and its daemon on macOS. One `module.nix`
covers both nix-darwin (launchd) and NixOS (systemd).

The package installs upstream's prebuilt client and compiles nothing. The
pinned release (`version` in `hashes.json`) is for:

| System | Upstream file | Checked against |
|---|---|---|
| `x86_64-linux` | the `.deb` for Ubuntu noble, from Cloudflare's download service (the file in the `pkg.cloudflareclient.com` apt repository) | the sha256 that apt index lists |
| `aarch64-linux` | the same, for arm64 | the same |
| `aarch64-darwin` | `Cloudflare_WARP_<version>.pkg` (macOS 14 or later) | nothing: Cloudflare lists no checksum for it, so it is pinned by the hash of the download |

On Linux the binaries are patched with `autoPatchelfHook` to run on NixOS and
any other distribution. On macOS the signed app bundle is copied out of the
installer's payload untouched (`dontFixup`: patching would break its code
signature and the system extension inside it) into `$out/Applications`, with
`warp-cli`, `warp-dex` and `warp-diag` in `$out/bin`.

## License: unfree

The client is proprietary. This flake's own `packages` allow it. Through the
overlay, the consuming nixpkgs has to allow it:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "cloudflare-warp" ];
```

## Usage

```nix
{
  inputs.f0dnx.url = "github:4dnx/flakes";
  inputs.f0dnx.inputs.nixpkgs.follows = "nixpkgs";

  # nix-darwin
  darwinConfigurations.<host> = nix-darwin.lib.darwinSystem {
    modules = [
      inputs.f0dnx.darwinModules.cloudflare-warp
      { services.cloudflare-warp.enable = true; }
    ];
  };

  # NixOS
  nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
    modules = [
      inputs.f0dnx.nixosModules.cloudflare-warp
      { services.cloudflare-warp.enable = true; }
    ];
  };
}
```

Then register and connect with `warp-cli` (`warp-cli registration new`,
`warp-cli connect`; it asks to accept Cloudflare's terms of service).

`darwinModules.cloudflare-warp` and `nixosModules.cloudflare-warp` are the same
module. It detects nix-darwin from the `launchd` option. nixpkgs has its own
`services.cloudflare-warp` module, with other options (`rootDir`, `udpPort`,
`openFirewall`); on NixOS this module replaces it (`disabledModules`), so
importing both is fine but those options are gone.

### Domain exclusions (consumer WARP)

```nix
services.cloudflare-warp = {
  enable = true;
  excludeHosts = [ "example.com" ];
};
```

`excludeHosts` shares the `warp-apply-exclusions` helper and startup behavior
below. Each hostname is added only when absent; other entries are preserved.
Domain exclusions affect all applications reaching the resolved IPs, including
other domains sharing those IPs. Removing a hostname from Nix leaves its client
state in place; remove it with `warp-cli tunnel host remove example.com`.
Zero Trust clients require device-profile policy instead.

### Rayfish coexistence (consumer WARP)

```nix
services.cloudflare-warp = {
  enable = true;
  excludeRayfish = true;
};
services.rayfish.enable = true; # requires the Rayfish module as well
```

`excludeRayfish` installs `warp-apply-exclusions` and attempts to apply the
`200::/7` IPv6 exclusion when the WARP daemon starts or configuration activates.
The helper waits up to 15 seconds for the daemon, preserves existing exclusions,
and adds the range only when missing. An unavailable or unregistered client
produces a warning without failing the daemon or activation. After first
registration, run `warp-apply-exclusions` before connecting. A custom on-demand
start command can invoke it before `warp-cli connect` as well.

Rayfish 0.5.16 uses `200::/7` for its IPv6-only overlay, including DNS at
`200::53`; no `100.64.0.0/10` exclusion is added. The Rayfish module's resolver
integration must remain enabled for `.ray` DNS, and `ray-fix` can restore peer
and resolver routes on macOS if another VPN replaces them. This exclusion
covers overlay destinations, not Rayfish's internet transport by process, and
does not configure Rayfish exit-node coexistence.

The CLI permits local additions only for consumer WARP. Zero Trust clients
need an equivalent IP exclusion in their device profile; this option does not
change a dashboard policy. Disabling the option leaves the persisted exclusion.
Remove it explicitly with `warp-cli tunnel ip remove-range 200::/7`.

Sources: [Rayfish 0.5.16 routing implementation](https://github.com/rayfish/rayfish/blob/v0.5.16/src/tun.rs)
and [Cloudflare Split Tunnels](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/route-traffic/split-tunnels/).
The installed client's `warp-cli tunnel ip add-range --help` documents its
consumer-only restriction.

### Without the tray app (Linux)

The tray app (GTK and WebKitGTK) is most of the closure. For a server, leave it
out; `taskbar.enable` then defaults to `false`:

```nix
{
  services.cloudflare-warp = {
    enable = true;
    package = inputs.f0dnx.packages.${pkgs.stdenv.hostPlatform.system}.cloudflare-warp.override {
      headless = true;
    };
  };
}
```

Through the overlay, allow `cloudflare-warp-headless` as well as
`cloudflare-warp` in `allowUnfreePredicate`.

## Options

| Option | Default | Platform | Description |
|---|---|---|---|
| `services.cloudflare-warp.enable` | `false` | both | Run the WARP daemon and put `warp-cli` on `PATH`. |
| `services.cloudflare-warp.excludeHosts` | `[ ]` | both | Add domain exclusions to consumer WARP, preserving existing entries. |
| `services.cloudflare-warp.excludeRayfish` | `false` | both | Add the Rayfish IPv6 overlay to consumer WARP exclusions; see below. |
| `services.cloudflare-warp.package` | this flake's package | both | Package to run. No overlay needed. |
| `services.cloudflare-warp.settings` | `{ allow_updates = false; }`, plus `allow_managed_deployments = false` on macOS | both | The client's [deployment parameters](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/), written to its `mdm.xml`. Values are booleans, integers or strings. Setting it replaces the defaults; `{ }` writes nothing (see below). |
| `services.cloudflare-warp.taskbar.enable` | `true`, `false` for the headless package | NixOS | Start the tray app with the graphical session, as upstream's deb does. |

`settings` is also how to enroll in a Zero Trust organization declaratively:

```nix
services.cloudflare-warp.settings = {
  allow_updates = false;
  organization = "my-team";
};
```

The module owns the `mdm.xml` it writes and overwrites it on every activation
(`/var/lib/cloudflare-warp/mdm.xml` on NixOS, `/Library/Application
Support/Cloudflare/mdm.xml` on macOS). With `settings = { }` it writes nothing
and leaves an existing file alone, but doesn't remove one it wrote before.
The Linux daemon doesn't pick up an `mdm.xml` that is a link into the store, so
on both systems it is written as a copy.

## Service

- **NixOS:** upstream's own `warp-svc.service` from the package
  (`systemd.packages`; what the deb enables and starts), with `ExecStart`
  pointed into the store, so its capability bounding set and state directories
  follow upstream on every bump. The module adds `lsof` to its `PATH` (the
  daemon's diagnostics use it) and shows it nftables as `/usr/sbin/nft`, which
  it runs by that absolute path. No firewall port is opened: upstream's
  installer doesn't open any. The tray app runs as upstream's
  `warp-taskbar.service` user unit, wanted by `graphical-session.target`, with
  the package bound at `/usr` for it, because it runs `/usr/bin/warp-diag` by
  that path.
- **macOS:** the launchd daemon `com.cloudflare.1dot1dot1dot1.macos.warp.daemon`,
  upstream's plist from the installer's postinstall script (the `CloudflareWARP`
  binary as root, `RunAtLoad`, `KeepAlive`, 32768 open files), except that it
  waits for the Nix store to be mounted at boot. The app starts the tunnel's
  system extension: open `Cloudflare WARP.app` and approve the extension when
  macOS asks. macOS activates a system extension only for an app installed in
  `/Applications`, and whether nix-darwin's copy of the app (under
  `/Applications/Nix Apps`) qualifies is not something this repository checks:
  nothing here starts the daemon or the extension (the install check reads the
  bundle's `Info.plist` and runs nothing).

## Updates and telemetry

Updates come through this flake, so the client's update check is off.

- **Update check: off by default, in the module.** `allow_updates = false` is
  upstream's documented switch for it; the module writes it into `mdm.xml`.
  Without the module, it goes there by hand:
  ```xml
  <dict>
    <key>allow_updates</key>
    <false/>
  </dict>
  ```
  To turn the check back on, set `services.cloudflare-warp.settings = { }` (and
  delete the file the module wrote), or set `allow_updates = true`. A parameter
  in `mdm.xml` wins over the same setting in the Zero Trust dashboard.
- **Versions assigned from the Zero Trust dashboard (macOS):** off by default,
  with `allow_managed_deployments = false`, upstream's documented local kill
  switch (macOS and Windows, client 2026.6.0 or later). It only matters on a
  device enrolled in an organization. Upstream's installer also loads a second
  launchd job, `com.cloudflare.warp.updater` (`warp-updater`, not started at
  load), which installs such versions; the module doesn't load it. The tool
  stays in `Cloudflare WARP.app` and unused.
- **Sparkle (macOS):** the app bundle ships with `SUEnableAutomaticChecks`
  false and no feed URL in its `Info.plist`, so the framework doesn't check on
  its own. Nothing in the signed bundle was changed.
- **Linux:** upstream's packaging leaves updates to apt; the client itself only
  offers them while `allow_updates` is on.
- **Crash reporting: on, and upstream documents no switch for it.** The daemon
  starts a crash-reporting component at launch; `warp-svc`, `warp-cli` and
  `warp-diag` embed a Sentry client, and the tray app ships Sentry's native
  SDK with a crash handler. Nothing here turns it off. Registering and
  connecting contact Cloudflare by design.

## Maintenance

`update.sh` takes the version from the apt index for Ubuntu noble and checks
each Linux download against the sha256 it lists. It waits (and changes
nothing) until the macOS installer the download service serves as the latest
GA release is that same version, so one version covers all three systems.
Cloudflare's [release notes](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/download/)
are the changelog.

On a bump, recheck against the new release:

- the deb's `warp-svc.service` and `warp-taskbar.service` (the module uses them
  as shipped), and the absolute paths the binaries run (`/usr/sbin/nft`,
  `/usr/bin/warp-diag`);
- the macOS installer's `postinstall` script and launchd plists (the module
  mirrors the daemon's), and the app's `Info.plist` Sparkle keys;
- the deployment parameters `allow_updates` and `allow_managed_deployments`,
  and whether upstream added a switch for crash reporting.

`warp-svc` ignores `--version` and starts the daemon, so the install check runs
`warp-cli`, `warp-dex` and `warp-diag` instead.
