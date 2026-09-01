#!/usr/bin/env bash
# Remove ONE worktree from Orca + git (final teardown after its worker is closed).
# worker-release.sh / worker-stop.sh do NOT delete worktrees; this does.
# usage: worktree-rm.sh <worktree_selector>
#   selector: path:<path> | id:<repo-id>::<path> | branch:<branch> | name:<displayName>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || usage 'worktree-rm.sh <worktree_selector>'
SEL="$1"; need worktree_selector "$SEL"
preflight

orca_json worktree rm --worktree "$SEL" --force >/dev/null
say "removed worktree $SEL"
