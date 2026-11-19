#!/usr/bin/env bash
# Bump hashes.json to the current Microsoft PowerPoint installer; see
# pkgs/microsoft-office/update-lib.sh.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source-path=SCRIPTDIR source=../build-support/update-lib.sh
. ../build-support/update-lib.sh
# shellcheck source-path=SCRIPTDIR source=../microsoft-office/update-lib.sh
. ../microsoft-office/update-lib.sh

office_update microsoft-powerpoint 525136 PPT32019 com.microsoft.Powerpoint
