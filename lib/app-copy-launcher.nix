# installPhase commands for a macOS app package: write `launcher`, a script
# that runs `executable` (a path inside the bundle) of
# $out/Applications/`bundle` from an installed copy of the bundle when the
# copy is this build, else from the store (app-copy-launcher.sh).
{
  bundle,
  executable,
  launcher,
}:
''
  substitute ${./app-copy-launcher.sh} "${launcher}" \
    --subst-var out \
    --subst-var-by bundle '${bundle}' \
    --subst-var-by executable '${executable}'
  chmod +x "${launcher}"
''
