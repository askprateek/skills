#!/usr/bin/env bash
# orca-orchestration shared library — sourced by every script in this dir.
#
# Contract (every script MUST follow):
#   - `set -euo pipefail` (inherited by sourcing this).
#   - Required args validated up front via need(); missing -> hard error, never a default.
#   - orca is invoked through ORCA (auto-detects orca / orca-ide) with --json.
#   - IDs are parsed from JSON with jq and RE-EMITTED as KEY=VALUE on stdout so the
#     caller captures them by `eval`/`source`, never by hand-copying.
#   - Human notes go to stderr (say/warn/die); machine KEY=VALUE goes to stdout.
#
# Usage in a script:
#   #!/usr/bin/env bash
#   set -euo pipefail
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

set -euo pipefail

# ---- output helpers ---------------------------------------------------------
say()  { printf '%s\n' "$*" >&2; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
emit() { printf '%s=%q\n' "$1" "$2"; }  # KEY=VALUE (value shell-quoted) to stdout; eval/source-safe

# ---- arg / dependency checks ------------------------------------------------
# need <human-name> <value>  — fail if value empty
need() { [ -n "${2:-}" ] || die "missing required argument: $1"; }

# usage <text> — print usage and exit non-zero (call when arg count is wrong)
usage() { printf 'usage: %s\n' "$1" >&2; exit 2; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---- orca binary + preflight ------------------------------------------------
ORCA="${ORCA:-}"
if [ -z "$ORCA" ]; then
  if have orca;        then ORCA=orca
  elif have orca-ide;  then ORCA=orca-ide
  else die "orca CLI not found on PATH (need 'orca' or 'orca-ide')"; fi
fi

have jq || die "jq not found on PATH (required for JSON id extraction)"

# preflight — runtime must be ready before any orchestration mutation.
# Skip with ORCA_SKIP_PREFLIGHT=1 for non-mutating/offline calls.
preflight() {
  [ "${ORCA_SKIP_PREFLIGHT:-0}" = "1" ] && return 0
  local st
  st="$("$ORCA" status --json 2>/dev/null)" || die "orca status failed (runtime unreachable)"
  local state
  state="$(printf '%s' "$st" | jq -r '.result.runtime.state // empty')"
  [ "$state" = "ready" ] || die "orca runtime not ready (state=${state:-unknown})"
}

# ---- json helpers -----------------------------------------------------------
# orca_json <args...> — run orca with --json, verify ok:true, echo the raw JSON.
orca_json() {
  local out
  out="$("$ORCA" "$@" --json 2>&1)" || die "orca $* failed: $out"
  local ok
  ok="$(printf '%s' "$out" | jq -r '.ok // empty' 2>/dev/null || true)"
  [ "$ok" = "true" ] || die "orca $* returned not-ok: $(printf '%s' "$out" | jq -c '.error // .' 2>/dev/null || printf '%s' "$out")"
  printf '%s' "$out"
}

# jget <json> <jq-filter> <human-name> — extract a REQUIRED field or die.
jget() {
  local v
  v="$(printf '%s' "$1" | jq -r "$2 // empty")"
  [ -n "$v" ] || die "could not extract $3 (filter: $2)"
  printf '%s' "$v"
}

# jopt <json> <jq-filter> — extract an optional field (empty if absent, no die).
jopt() { printf '%s' "$1" | jq -r "$2 // empty"; }

# resolve_handle <handle> — expand a possibly-truncated term_<prefix> to the full
# term_<uuid>. MANDATORY before `terminal send`: the runtime ACCEPTS a short
# handle with {"ok":true} and then SILENTLY DISCARDS the payload, so an unresolved
# handle looks like a successful send and loses the message. `terminal read`, by
# contrast, rejects it outright with terminal_handle_stale.
resolve_handle() {
  local h="$1" list matches n
  # already a full term_<8-4-4-4-12> uuid -> use verbatim
  if [[ "$h" =~ ^term_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf '%s' "$h"; return 0
  fi
  list="$("$ORCA" terminal list --json 2>/dev/null)" || die "terminal list failed while resolving handle $h"
  matches="$(printf '%s' "$list" | jq -r --arg h "$h" '.result.terminals[].handle | select(startswith($h))')"
  n="$(printf '%s' "$matches" | grep -c . || true)"
  [ "$n" = "1" ] || die "handle $h resolved to $n terminals (need exactly 1)${matches:+: $(printf '%s' "$matches" | tr '\n' ' ')}"
  printf '%s' "$matches"
}

# ---- misc -------------------------------------------------------------------
# read text arg that may be a literal or @file reference.
argtext() {
  case "$1" in
    @*) local f="${1#@}"; [ -f "$f" ] || die "text file not found: $f"; cat "$f" ;;
    *)  printf '%s' "$1" ;;
  esac
}
