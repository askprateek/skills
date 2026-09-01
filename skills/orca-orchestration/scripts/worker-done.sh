#!/usr/bin/env bash
# Complete a dispatched task via worker_done (settled or forced outcome).
# Wraps: orca orchestration send --type worker_done --subject <s> --body <b>
#   --task-id <t> --dispatch-id <d> --outcome <outcome> [--files-modified <csv>]
# usage: worker-done.sh <task_id> <dispatch_id> <outcome> [subject] [body] [files-csv]
# outcome MUST be: succeeded | failed
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 3 ] || usage 'worker-done.sh <task_id> <dispatch_id> <outcome> [subject] [body] [files-csv]'
TASK_ID="$1"; DISPATCH_ID="$2"; OUTCOME="$3"
SUBJECT="${4:-task completed}"
BODY="${5:-}"
FILES_CSV="${6:-}"

need task_id "$TASK_ID"
need dispatch_id "$DISPATCH_ID"
need outcome "$OUTCOME"

case "$OUTCOME" in
  succeeded|failed) ;;
  *) die "outcome must be 'succeeded' or 'failed', got: $OUTCOME" ;;
esac

preflight

# Build orca command
SEND_ARGS=(orchestration send --type worker_done)
SEND_ARGS+=(--subject "$SUBJECT")
[ -n "$BODY" ] && SEND_ARGS+=(--body "$BODY")
SEND_ARGS+=(--task-id "$TASK_ID")
SEND_ARGS+=(--dispatch-id "$DISPATCH_ID")
SEND_ARGS+=(--outcome "$OUTCOME")
[ -n "$FILES_CSV" ] && SEND_ARGS+=(--files-modified "$FILES_CSV")

# Orca has a boot race: a tab dispatch's worker_done capability may not be
# registered yet on the FIRST attempt, returning `dispatch_capability_invalid`
# ("capability missing"). When that happens the dispatch never settles even if a
# later attempt succeeds in-terminal. Retry ONLY that specific error, bounded.
ATTEMPTS="${WORKER_DONE_RETRIES:-6}"
DELAY="${WORKER_DONE_DELAY:-2}"
LAST=""
for _n in $(seq 1 "$ATTEMPTS"); do
  OUT="$("$ORCA" "${SEND_ARGS[@]}" --json 2>&1)" && RC=0 || RC=$?
  LAST="$OUT"
  OK="$(printf '%s' "$OUT" | jq -r '.ok // empty' 2>/dev/null)"
  if [ "$RC" = 0 ] && [ "$OK" = "true" ]; then
    say "worker_done: task=$TASK_ID dispatch=$DISPATCH_ID outcome=$OUTCOME (attempt $_n)"
    exit 0
  fi
  if printf '%s' "$OUT" | grep -qiE 'dispatch_capability_invalid|capability missing'; then
    warn "worker_done attempt $_n: dispatch_capability_invalid (Orca boot race); retry in ${DELAY}s"
    sleep "$DELAY"
    continue
  fi
  die "worker_done failed (attempt $_n): $OUT"
done
die "worker_done exhausted $ATTEMPTS attempts on dispatch_capability_invalid; dispatch likely will NOT settle (rely on text sentinel + close tab): $LAST"
