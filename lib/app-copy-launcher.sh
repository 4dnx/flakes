#!/bin/sh
# Runs @executable@ of @bundle@ from an installed copy of the bundle when the
# copy is this build, else from the store. A bundle started from the store is
# registered with LaunchServices at its store path, so every version would
# stay in Finder's Open With next to the copy. The copies looked for are
# Home Manager's (targets.darwin.copyApps, default folder) and nix-darwin's.
# A copy counts only when its executable, Info.plist and CodeResources are
# byte for byte the store's: an older copy, or one an updater replaced, runs
# nothing.
store='@out@/Applications/@bundle@'
for dir in "${HOME-}/Applications/Home Manager Apps" '/Applications/Nix Apps'; do
  copy="$dir/@bundle@"
  if [ -x "$copy/@executable@" ] &&
    /usr/bin/cmp -s "$store/@executable@" "$copy/@executable@" &&
    /usr/bin/cmp -s "$store/Contents/Info.plist" "$copy/Contents/Info.plist" &&
    /usr/bin/cmp -s "$store/Contents/_CodeSignature/CodeResources" "$copy/Contents/_CodeSignature/CodeResources"; then
    exec "$copy/@executable@" "$@"
  fi
done
exec "$store/@executable@" "$@"
