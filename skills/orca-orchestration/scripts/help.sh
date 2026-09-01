#!/usr/bin/env bash
# Front door. FIRST thing to run — lists every orchestration script with its
# params + emitted KEY=VALUE, so you NEVER read script source to learn args.
# Params/emits are auto-extracted from each script's `# usage:` / `# emits:`
# header, so this stays in sync automatically.
# usage: help.sh [name-substring]
# emits: (prints catalog to stdout; no side effects)
set -euo pipefail
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER="${1:-}"

printf '%-22s | %s\n' "SCRIPT" "USAGE  /  EMITS"
printf '%s\n' "-----------------------+--------------------------------------------------------------"
for f in "$SD"/*.sh; do
  base="$(basename "$f")"
  [ "$base" = "lib.sh" ] && continue
  [ "$base" = "help.sh" ] && continue
  [ -n "$FILTER" ] && case "$base" in *"$FILTER"*) ;; *) continue;; esac
  usage="$(sed -n 's/^# usage: *//p' "$f" | head -1)"
  emits="$(sed -n 's/^# emits: *//p' "$f" | head -1)"
  purpose="$(sed -n '2s/^# *//p' "$f")"
  printf '%-22s | %s\n' "$base" "${usage:-<no usage header>}"
  [ -n "$emits" ] && printf '%-22s |   emits: %s\n' "" "$emits"
done
echo
echo "Run any script with wrong/no args to see its usage (rc=2, safe: arg-check fires before side effects)."
