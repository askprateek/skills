#!/usr/bin/env bash
# Create ONE child worktree off a base branch. No terminal, no worker.
# Use before launching tabs that SHARE a worktree (investigators, or executors
# whose file sets are disjoint). For the common own-worktree case use
# worker-launch.sh (which calls this internally).
# usage: worktree-new.sh <label> <base_branch> <repo_sel>
# emits: WORKTREE_ID WORKTREE_PATH
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 3 ] || usage 'worktree-new.sh <label> <base_branch> <repo_sel>'
LABEL="$1"; BASE="$2"; REPO="$3"
need label "$LABEL"; need base_branch "$BASE"; need repo_sel "$REPO"
preflight

say "[$LABEL] worktree create on $BASE ..."
WT_JSON="$(orca_json worktree create --name "$LABEL" --repo "$REPO" --base-branch "$BASE")"
WORKTREE_ID="$(jget "$WT_JSON" '.result.worktree.id // .result.worktreeId // .result.worktree.worktreeId' worktreeId)"
WT_PATH="$(jget "$WT_JSON" '.result.worktree.path // .result.path' worktreePath)"

emit WORKTREE_ID "$WORKTREE_ID"
emit WORKTREE_PATH "$WT_PATH"
say "[$LABEL] worktree $WORKTREE_ID at $WT_PATH"
