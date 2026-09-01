#!/usr/bin/env bash
# Checker poll: wait for a TUI worker to settle (tui-idle, bounded), read the
# tail, and classify its sentinel. Read-only. Targets a TUI (omp) terminal ONLY
# — tui-idle never settles for a plain shell.
# usage: poll.sh <handle> [timeout_ms=90000] [tail_lines=40]
# emits: CLASS (DONE|NEEDS-INPUT|BLOCKER|AMBIGUOUS) and SENTINEL when present
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'poll.sh <handle> [timeout_ms] [tail_lines]'
HANDLE="$1"; TO="${2:-90000}"; LINES="${3:-40}"
need handle "$HANDLE"
preflight

"$ORCA" terminal wait --terminal "$HANDLE" --for tui-idle --timeout-ms "$TO" --json >/dev/null 2>&1 \
  || warn "tui-idle wait timed out (worker may still be busy)"

J="$(orca_json terminal read --terminal "$HANDLE")"
TAIL="$(printf '%s' "$J" | jq -r '.result.terminal.tail[]? | if type=="string" then . else (.text // tostring) end' | tail -n "$LINES")"

CLASS=AMBIGUOUS; SENT=""
if   SENT="$(printf '%s\n' "$TAIL" | grep -m1 'WORKER DONE:')"; then CLASS=DONE
elif SENT="$(printf '%s\n' "$TAIL" | grep -m1 'NEEDS-INPUT:')"; then CLASS=NEEDS-INPUT
elif SENT="$(printf '%s\n' "$TAIL" | grep -m1 'BLOCKER:')";     then CLASS=BLOCKER
fi

emit CLASS "$CLASS"
[ -n "$SENT" ] && emit SENTINEL "$SENT"
say "---- tail ($HANDLE) ----"
printf '%s\n' "$TAIL" >&2
