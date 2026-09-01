#!/usr/bin/env bash
# Launch ONE pinned-model worker as a TAB on an EXISTING worktree (no worktree
# create). Use for bus-bound INVESTIGATOR tabs and for EXECUTORs that SHARE one
# worktree. Each tab binds to its OWN Task and gets its OWN Dispatch, so the full
# worker_done lifecycle (Checker poll / bus drain) applies exactly like a solo
# worker -- only the worktree is shared.
# Worktree "name" is null in Orca; pass a path/id selector (e.g. path:<wt_path>).
# Co-located file sets MUST be disjoint; Admin owns the single merge.
# usage: tab-launch.sh <worktree_selector> <label> <task_id> <model> <prompt|@file> [run_id]
# emits: LABEL TERMINAL_HANDLE DISPATCH_ID
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 5 ] || usage 'tab-launch.sh <worktree_selector> <label> <task_id> <model> <prompt|@file> [run_id]'
WTSEL="$1"; LABEL="$2"; TASK_ID="$3"; MODEL="$4"; PROMPT_RAW="$5"; RUN_ID="${6:-}"
need worktree_selector "$WTSEL"; need label "$LABEL"; need task_id "$TASK_ID"
need model "$MODEL"; need prompt "$PROMPT_RAW"
PROMPT="$(argtext "$PROMPT_RAW")"
preflight

say "[$LABEL] terminal create (omp --model $MODEL) on $WTSEL ..."
TERM_JSON="$(orca_json terminal create --worktree "$WTSEL" --title "$LABEL" --command "omp --model $MODEL")"
HANDLE="$(jget "$TERM_JSON" '.result.terminal.handle // .result.handle' terminalHandle)"

say "[$LABEL] waiting for agent (tui-idle, bounded) ..."
"$ORCA" terminal wait --terminal "$HANDLE" --for tui-idle --timeout-ms 120000 --json >/dev/null 2>&1 \
  || warn "[$LABEL] tui-idle wait timed out; proceeding to attach worker"

say "[$LABEL] worker-start on task $TASK_ID ..."
WS_ARGS=(orchestration worker-start --task "$TASK_ID" --terminal "$HANDLE" --worktree "$WTSEL")
[ -n "$RUN_ID" ] && WS_ARGS+=(--run "$RUN_ID")
WS_JSON="$(orca_json "${WS_ARGS[@]}")"
DISPATCH_ID="$(jget "$WS_JSON" '.result.dispatch.id // .result.dispatchId // .result.worker.dispatch_id' dispatchId)"

SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT="$PROMPT

---
MODE: caveman full — every response terse, drop articles/filler, fragments OK, exact technical terms + code/commands unchanged. Off only on 'stop caveman'.

COMPLETION PROTOCOL (MANDATORY, bus-bound worker):
When your work is finished, FIRST run this exact command (fill outcome + summary), THEN print the sentinel line.
  $SD/worker-done.sh $TASK_ID $DISPATCH_ID succeeded \"<one-line subject>\" \"<short body>\" \"<comma,separated,files>\"
On failure, use outcome 'failed'. After the command, print exactly:
  WORKER DONE: $TASK_ID — <one-line summary>
If blocked or needing input, print instead:  NEEDS-INPUT: <question>  or  BLOCKER: <reason>"
say "[$LABEL] delivering prompt (${#PROMPT} chars) ..."
orca_json terminal send --terminal "$HANDLE" --text "$PROMPT" --enter >/dev/null

emit LABEL "$LABEL"
emit TERMINAL_HANDLE "$HANDLE"
emit DISPATCH_ID "$DISPATCH_ID"
say "[$LABEL] launched as tab (dispatch $DISPATCH_ID)."
