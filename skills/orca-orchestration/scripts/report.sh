#!/usr/bin/env bash
# Report a milestone from Admin to Main (semantic wrapper over terminal send).
# Prefixes "MILESTONE: " so Main can filter. Always submits (Enter).
# usage: report.sh <main_handle> <text|@file>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 2 ] || usage 'report.sh <main_handle> <text|@file>'
HANDLE="$1"; TXT_RAW="$2"
need main_handle "$HANDLE"; need text "$TXT_RAW"
TXT="$(argtext "$TXT_RAW")"
preflight

orca_json terminal send --terminal "$HANDLE" --text "MILESTONE: $TXT" --enter >/dev/null
say "reported to Main ($HANDLE)"
