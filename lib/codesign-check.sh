#!/usr/bin/env bash
# Checks the Apple code signature of macOS binaries without macOS: each file
# (every slice of a universal one) must carry a valid signature whose signer is
# a Developer ID Application certificate of team TEAM_ID chaining to Apple's
# root CA (lib/apple-root-ca.pem). Needs rcodesign and openssl.
#   codesign-check.sh APPLE_ROOT_CA TEAM_ID FILE...
# After numtide/llm-agents.nix's codesignCheckHook.
set -euo pipefail

root_ca=$1 team=$2
shift 2
[[ $team =~ ^[A-Z0-9]{10}$ ]] || { echo "codesign-check: bad team ID '$team'" >&2; exit 1; }

magic() { head -c 4 "$1" | od -An -tx1 | tr -d ' \n'; }

# check_slice FILE [--universal-index N]
check_slice() {
  local file=$1 dir subject
  shift
  dir="$(mktemp -d)"
  rcodesign extract "$@" cms-pem "$file" >"$dir/cms.pem"
  rcodesign extract "$@" code-directory-raw "$file" >"$dir/cd.bin"
  # Apple marks its Developer ID extension critical, which openssl rejects
  # unless told to ignore it. The certificate's validity period isn't
  # checked: a pinned download has to keep building after it expires.
  openssl cms -verify -binary -inform PEM -in "$dir/cms.pem" -content "$dir/cd.bin" \
    -CAfile "$root_ca" -purpose any -ignore_critical -no_check_time \
    -out /dev/null -signer "$dir/signer.pem" 2>"$dir/err" ||
    { cat "$dir/err" >&2; echo "codesign-check: $file: signature doesn't chain to Apple's root CA" >&2; exit 1; }
  subject="$(openssl x509 -in "$dir/signer.pem" -noout -subject -nameopt RFC2253)"
  rm -rf "$dir"
  if [[ $subject != *"CN=Developer ID Application:"* || $subject != *"OU=$team,"* ]]; then
    echo "codesign-check: $file is signed by '$subject', expected team $team" >&2
    exit 1
  fi
}

for file in "$@"; do
  # verify checks the code directory hashes against the file, every slice of
  # a universal binary included.
  rcodesign verify "$file" >/dev/null
  case "$(magic "$file")" in
    cffaedfe | feedfacf) check_slice "$file" ;;
    cafebabe | bebafeca)
      count=$((16#$(head -c 8 "$file" | tail -c 4 | od -An -tx1 | tr -d ' \n')))
      for ((i = 0; i < count; i++)); do check_slice "$file" --universal-index "$i"; done
      ;;
    *) echo "codesign-check: $file is not a Mach-O executable" >&2; exit 1 ;;
  esac
  echo "codesign-check: $file: Developer ID, team $team"
done
