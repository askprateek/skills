#!/usr/bin/env bash
# Fence + stop ONE worker's dispatch regardless of state (cancel an active worker,
# or force-settle a stuck one). Use worker-release.sh for the normal settled path.
# usage: worker-stop.sh <dispatch_id>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'worker-stop.sh <dispatch_id>'
DID="$1"; need dispatch_id "$DID"
preflight

STATE="$(orca_json orchestration worker-stop --dispatch "$DID" | jget '.result.state // "stopped"')"
say "stopped $DID (state=$STATE)"
