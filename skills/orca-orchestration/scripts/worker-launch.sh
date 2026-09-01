#!/usr/bin/env bash
# Launch ONE pinned-model supervised worker in its OWN new child worktree.
# Composition: worktree-new.sh (create worktree) + tab-launch.sh (terminal ->
# wait tui-idle -> worker-start --terminal -> deliver prompt). Single source of
# truth for the tab recipe lives in tab-launch.sh.
# Every id is parsed from JSON and re-emitted; nothing is hand-copied.
# For workers that SHARE a worktree, call worktree-new.sh once then tab-launch.sh
# per worker instead of this wrapper.
# usage: worker-launch.sh <label> <task_id> <model> <base_branch> <repo_sel> <prompt|@file> [run_id]
# emits: LABEL WORKTREE_ID TERMINAL_HANDLE DISPATCH_ID
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

[ $# -ge 6 ] || usage 'worker-launch.sh <label> <task_id> <model> <base_branch> <repo_sel> <prompt|@file> [run_id]'
LABEL="$1"; TASK_ID="$2"; MODEL="$3"; BASE="$4"; REPO="$5"; PROMPT_RAW="$6"; RUN_ID="${7:-}"
need label "$LABEL"; need task_id "$TASK_ID"; need model "$MODEL"
need base_branch "$BASE"; need repo_sel "$REPO"; need prompt "$PROMPT_RAW"
preflight

# 1) Create the worktree (preflight already done; skip the inner one).
eval "$(ORCA_SKIP_PREFLIGHT=1 "$DIR/worktree-new.sh" "$LABEL" "$BASE" "$REPO")"
# Orca worktree "name" is null; a fresh worktree is addressable only by id/path.
# Target the terminal AND worker-start at THIS worktree, else worker-start fails
# terminal_worktree_mismatch (terminal lands in the repo's default worktree).
WTSEL="path:$WORKTREE_PATH"

# 2) Attach the worker tab (pass prompt raw; tab-launch resolves @file once).
eval "$(ORCA_SKIP_PREFLIGHT=1 "$DIR/tab-launch.sh" "$WTSEL" "$LABEL" "$TASK_ID" "$MODEL" "$PROMPT_RAW" "$RUN_ID")"

emit LABEL "$LABEL"
emit WORKTREE_ID "$WORKTREE_ID"
emit TERMINAL_HANDLE "$TERMINAL_HANDLE"
emit DISPATCH_ID "$DISPATCH_ID"
say "[$LABEL] launched (dispatch $DISPATCH_ID)."
