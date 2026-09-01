#!/usr/bin/env bash
# Send text (or @file contents) to a live terminal. Appends Enter by default so
# the message is actually submitted (omitting Enter is a common footgun).
# usage: send.sh <handle> <text|@file> [--no-enter]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 2 ] || usage 'send.sh <handle> <text|@file> [--no-enter]'
HANDLE="$1"; TXT_RAW="$2"; ENTER="${3:-}"
need handle "$HANDLE"; need text "$TXT_RAW"
TXT="$(argtext "$TXT_RAW")"
preflight

# A short/stale handle is accepted by the runtime and then dropped on the floor,
# so resolve to the full uuid BEFORE sending or the message is silently lost.
FULL="$(resolve_handle "$HANDLE")"

ARGS=(terminal send --terminal "$FULL" --text "$TXT")
[ "$ENTER" != "--no-enter" ] && ARGS+=(--enter)
orca_json "${ARGS[@]}" >/dev/null
say "sent to $FULL (${#TXT} chars${ENTER:+, $ENTER})"
