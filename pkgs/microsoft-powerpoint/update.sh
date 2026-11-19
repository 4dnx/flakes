#!/usr/bin/env bash
# Bump hashes.json to the current Microsoft PowerPoint installer; see
# lib/microsoft-office-update.sh.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../../lib/update.sh
. ../../lib/update.sh
# shellcheck source-path=SCRIPTDIR source=../../lib/microsoft-office-update.sh
. ../../lib/microsoft-office-update.sh

office_update microsoft-powerpoint 525136 PPT32019 com.microsoft.Powerpoint
