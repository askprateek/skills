#!/usr/bin/env bash
# Create the integration branch WITHOUT moving the current worktree's HEAD.
# Invariant: the main worktree MUST stay on `main`; Admin never runs
# `git checkout`/`switch -c` in it. `git branch <name> <base>` only writes a ref.
# Do all merges in a dedicated integration worktree (see --worktree), never here.
#
# usage: integration-branch.sh <integration_branch> <base_branch> [--worktree <name> <repo_sel>]
# emits: INTEGRATION_BRANCH  (+ INTEGRATION_WORKTREE_ID when --worktree given)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 2 ] || usage 'integration-branch.sh <integration_branch> <base_branch> [--worktree <name> <repo_sel>]'
IB="$1"; BASE="$2"; shift 2
need integration_branch "$IB"; need base_branch "$BASE"

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
HEAD_BEFORE="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"

# ref-only creation: never checks out, never moves HEAD.
if git show-ref --verify --quiet "refs/heads/$IB"; then
  warn "branch $IB already exists — leaving it as-is"
else
  git branch "$IB" "$BASE"
  say "created branch $IB off $BASE (HEAD not moved)"
fi

HEAD_AFTER="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"
[ "$HEAD_BEFORE" = "$HEAD_AFTER" ] || die "GUARD FAILED: worktree HEAD moved ($HEAD_BEFORE -> $HEAD_AFTER)"
emit INTEGRATION_BRANCH "$IB"

# optional dedicated integration worktree so merges never touch this worktree.
if [ "${1:-}" = "--worktree" ]; then
  WT_NAME="${2:-}"; REPO="${3:-}"
  need worktree_name "$WT_NAME"; need repo_sel "$REPO"
  preflight
  J="$(orca_json worktree create --name "$WT_NAME" --repo "$REPO" --base-branch "$IB")"
  WID="$(jget "$J" '.result.worktree.id // .result.worktreeId // .result.worktree.worktreeId' worktreeId)"
  emit INTEGRATION_WORKTREE_ID "$WID"
  say "integration worktree '$WT_NAME' ready on $IB"
fi

say "main worktree HEAD unchanged ($HEAD_AFTER)."
