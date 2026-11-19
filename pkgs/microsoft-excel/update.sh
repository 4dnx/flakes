#!/usr/bin/env bash
# Bump hashes.json to the current Microsoft Excel installer; see
# lib/microsoft-office-update.sh.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh
# shellcheck source-path=SCRIPTDIR source=../../lib/microsoft-office-update.sh
. ../../lib/microsoft-office-update.sh

office_update microsoft-excel 525135 XCEL2019 com.microsoft.Excel
