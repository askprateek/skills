#!/usr/bin/env bash
# Mid-turn injection: ESC-cancel the agent's current turn, then deliver a new
# message. Use when a worker must be steered before it finishes. Do NOT use
# `terminal send --interrupt` for this (it is not an ESC/cancel).
# usage: inject.sh <handle> <text|@file>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 2 ] || usage 'inject.sh <handle> <text|@file>'
HANDLE="$1"; TXT_RAW="$2"
need handle "$HANDLE"; need text "$TXT_RAW"
TXT="$(argtext "$TXT_RAW")"
preflight

orca_json terminal send --terminal "$HANDLE" --text $'\033' >/dev/null   # ESC
sleep 1
orca_json terminal send --terminal "$HANDLE" --text "$TXT" --enter >/dev/null
say "injected into $HANDLE after ESC-cancel"
