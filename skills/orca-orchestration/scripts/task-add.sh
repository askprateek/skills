#!/usr/bin/env bash
# Create ONE task in the DAG, optionally with dependencies (comma-separated ids
# converted to the JSON array orca expects).
# usage: task-add.sh "<spec>" ["task_a,task_b"]
# emits: TASK_ID
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'task-add.sh "<spec>" ["task_a,task_b"]'
SPEC="$1"; DEPS="${2:-}"; need spec "$SPEC"
preflight

ARGS=(orchestration task-create --spec "$SPEC")
if [ -n "$DEPS" ]; then
  DEPS_JSON="$(printf '%s' "$DEPS" | jq -Rc 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))')"
  [ "$DEPS_JSON" = "[]" ] && die "no valid dependency ids parsed from: $DEPS"
  ARGS+=(--deps "$DEPS_JSON")
fi

J="$(orca_json "${ARGS[@]}")"
TASK_ID="$(jget "$J" '.result.task.id // .result.taskId // .result.id' taskId)"
emit TASK_ID "$TASK_ID"
say "created task $TASK_ID${DEPS:+ (deps: $DEPS)}"
