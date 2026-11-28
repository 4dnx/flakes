# Modules

Modules that belong to no one package. Each package's own modules live in
`pkgs/<name>/` and are described in that package's README.

## read-only-apps

`homeManagerModules.read-only-apps` keeps Home Manager's copies of macOS apps
out of reach of the apps' own updaters.

On macOS an app's updater replaces its bundle in place, so where the bundle
lives decides whether it can. The Nix store is read-only, and nix-darwin
copies the apps in `environment.systemPackages` into `/Applications/Nix Apps`
as read-only directories owned by root. Home Manager copies the apps in
`home.packages` into `~/Applications/Home Manager Apps`
(`targets.darwin.copyApps`, on by default from `home.stateVersion` 25.11) as
writable directories owned by the user: an updater can replace such a copy,
and the next activation copies the pinned version back.

The module keeps those copies read-only, for every app Home Manager copies,
from this flake or not:

```nix
imports = [ xr3t.homeManagerModules.read-only-apps ];
targets.darwin.copyApps.readOnly = true;
```

Each activation makes `~/Applications/Home Manager Apps` and everything in it
writable before Home Manager's App Management check and copy, which write
into the bundles, and read-only (`chmod -R a-w`) after the copy. An updater
running as the user then can't replace a copy, write into it or stage a new
one beside it without first changing its permissions back. Sparkle and
Google's updater may ask for an administrator's password instead; given it,
they can replace the copy as root. The unlock also runs while the option is
false, so turning it off leaves no copy that Home Manager can't replace.
With the module dropped from the imports, nothing unlocks the folder, so make
it writable before switching:

```sh
chmod -R u+w ~/Applications/Home\ Manager\ Apps
```

The `whatsapp` module keeps only its own copy read-only the same way. App
updaters can also be cut off the network with the Little Snitch rule group in
[firewall/](../firewall/README.md).
