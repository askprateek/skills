#!/usr/bin/env bash
# Drain the orchestration bus NON-BLOCKING. Admin uses this to reconcile; it
# NEVER passes --wait (the blocking variant is forbidden for Admin/Main).
# usage: bus-check.sh [run_id]
# emits: COUNT
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN_ID="${1:-}"
preflight

ARGS=(orchestration check)
[ -n "$RUN_ID" ] && ARGS+=(--run "$RUN_ID")
J="$(orca_json "${ARGS[@]}")"

COUNT="$(jopt "$J" '.result.count')"
emit COUNT "${COUNT:-0}"
printf '%s' "$J" | jq -r '.result.messages[]? | "- from \(.from // "?"): \(.summary // .text // .kind // (.|tojson))"' >&2 || true
say "bus drained (non-blocking)."
