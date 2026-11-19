#!/usr/bin/env bash
# Bump hashes.json to the current Microsoft Excel installer; see
# pkgs/microsoft-office/update-lib.sh.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../scripts/update-lib.sh
. ../../scripts/update-lib.sh
# shellcheck source-path=SCRIPTDIR source=../microsoft-office/update-lib.sh
. ../microsoft-office/update-lib.sh

office_update microsoft-excel 525135 XCEL2019 com.microsoft.Excel
