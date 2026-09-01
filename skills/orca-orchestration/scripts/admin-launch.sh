#!/usr/bin/env bash
# Idempotent single-split Admin launch in Main worktree.
# CRITICAL: Captures terminal split stdout FIRST, then parses handle to avoid
# piping mutating command into jq (duplicate side-effects if jq errors).
# Renames terminal to title.
# usage: admin-launch.sh <main_handle> <admin_model> [title]
# emits: ADMIN_HANDLE
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 2 ] || usage 'admin-launch.sh <main_handle> <admin_model> [title]'
MAIN_HANDLE="$1"; ADMIN_MODEL="$2"; TITLE="${3:-Admin}"
need main_handle "$MAIN_HANDLE"
need admin_model "$ADMIN_MODEL"
preflight

say "splitting terminal $MAIN_HANDLE for Admin ..."
OUT="$("$ORCA" terminal split --terminal "$MAIN_HANDLE" --direction vertical --command "omp --model $ADMIN_MODEL" --json 2>&1)"
ADMIN_HANDLE="$(jget "$OUT" '.result.split.handle // .result.handle' adminHandle)"

say "renaming Admin terminal to '$TITLE' ..."
orca_json terminal rename --terminal "$ADMIN_HANDLE" --title "$TITLE" >/dev/null

# Wait for omp to actually accept input. A bare `terminal wait --for tui-idle`
# fires DURING boot (shell/MCP init) before the agent prompt exists, so a prompt
# sent then is silently dropped. Poll for the omp prompt banner instead.
say "waiting for omp prompt banner (readiness) ..."
READY=0
for _i in $(seq 1 40); do
  T="$("$ORCA" terminal read --terminal "$ADMIN_HANDLE" --json 2>/dev/null \
        | jq -r '.result.terminal.tail // .result.content // .result | if type=="array" then .[] else . end' 2>/dev/null)"
  if printf '%s' "$T" | grep -q '── π'; then READY=1; break; fi
  sleep 3
done
[ "$READY" = 1 ] || die "Admin omp did not reach prompt readiness on $ADMIN_HANDLE (banner never appeared)"

emit ADMIN_HANDLE "$ADMIN_HANDLE"
say "Admin launched + ready on $ADMIN_HANDLE"
