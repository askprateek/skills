#!/usr/bin/env bash
# Release the terminal of ONE settled worker (cleanup after DONE + integrated).
# usage: worker-release.sh <dispatch_id>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'worker-release.sh <dispatch_id>'
DID="$1"; need dispatch_id "$DID"
preflight

orca_json orchestration worker-release --dispatch "$DID" >/dev/null
say "released $DID"
