#!/usr/bin/env bash
# Recovery/inspection for ONE worker: dispatch status/stage + a bounded tail of
# its recent output. Read-only.
# usage: worker-status.sh <dispatch_id> [tail_lines=30]
# emits: STATUS STAGE TASK_ID TERMINAL_HANDLE
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'worker-status.sh <dispatch_id> [tail_lines]'
DID="$1"; LINES="${2:-30}"; need dispatch_id "$DID"
preflight

J="$(orca_json orchestration worker-show --dispatch "$DID")"
emit STATUS          "$(jopt "$J" '.result.dispatch.status')"
emit STAGE           "$(jopt "$J" '.result.worker.stage')"
emit TASK_ID         "$(jopt "$J" '.result.dispatch.task_id')"
emit TERMINAL_HANDLE "$(jopt "$J" '.result.terminal.handle')"

say "---- recent output (limit $LINES) ----"
"$ORCA" orchestration worker-read --dispatch "$DID" --limit "$LINES" --json 2>/dev/null \
  | jq -r '(.result.rows[]?.text) // (.result.lines[]?) // (.result.terminal.tail[]?) // empty' 2>/dev/null >&2 \
  || warn "worker-read returned no rows"
