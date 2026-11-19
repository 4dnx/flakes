#!/usr/bin/env bash
# Bump hashes.json to the current Microsoft Word installer; see
# pkgs/microsoft-office/update-lib.sh.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../helpers/update-lib.sh
. ../../helpers/update-lib.sh
# shellcheck source-path=SCRIPTDIR source=../microsoft-office/update-lib.sh
. ../microsoft-office/update-lib.sh

office_update microsoft-word 525134 MSWD2019 com.microsoft.Word
