#!/usr/bin/env bash
# Bind a NEW orchestration Run for a feature. Warns about stale pre-existing runs
# (Admin must never reuse a stale run surfaced as "current").
# usage: run-bind.sh "<objective>"
# emits: RUN_ID
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'run-bind.sh "<objective>"'
OBJ="$1"; need objective "$OBJ"
preflight

EXIST="$("$ORCA" orchestration run-list --json 2>/dev/null | jq -r '.result.runs[]?.id // empty' 2>/dev/null || true)"
[ -n "$EXIST" ] && warn "pre-existing run(s) present — binding a NEW run, do NOT reuse stale: $(printf '%s' "$EXIST" | tr '\n' ' ')"

J="$(orca_json orchestration run-create --objective "$OBJ")"
RUN_ID="$(jget "$J" '.result.runId // .result.run.id // .result.id' runId)"
emit RUN_ID "$RUN_ID"
say "bound run $RUN_ID"
