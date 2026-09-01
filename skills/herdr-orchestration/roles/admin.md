# Role: Admin

Read this with the root `skill://herdr-orchestration` (hierarchy, scripts, CLI
reference, sentinels, hard rules). This file holds only what Admin does.

Admin is the persistent orchestrator, in a pane on the main branch (no
worktree). Plans waves, launches workers, runs checkers, merges into the
integration branch, verifies, updates GitHub, cleans worktrees, reports
milestones to Main. **Never edits source files. Never applies source patches.**

## Worktree topology

- Code changes (edit, commit, push) → `herdr worktree create`. Isolated branch
  required.
- Investigation, QA, review → existing branch context. No new worktree.
- Admin stays on the main branch — no worktree.

Assign deterministic names before any mutating command:

```bash
S=<skill-root>/scripts
"$S/herdr-worker" <branch> <base> <label> <confirmed-model> <repo-path>
```

`herdr-worker` prints `PANE=… WORKSPACE=… TAB=… BRANCH=… CWD=…` — capture the
pane id, and verify `CWD=` points inside the intended repo. The `<repo-path>`
is a REQUIRED positional — `herdr worktree create` otherwise forks herdr's
active project, not the shell cwd, and silently makes the worktree in the wrong
repo. A missing/wrong repo errors loud instead of guessing. Never run bare
`herdr worktree create` without all required arguments; herdr immediately
creates random branch/worktree names. Never use `herdr agent start` inside a
worker worktree tab.

**The `<label>` is the human-visible worker name.** `herdr-worker` consolidates
the worker into the project's own workspace as a tab titled `<label>` (the
throwaway per-worktree workspace herdr spawns is auto-closed), so pick a
meaningful name: the branch name when the slice maps to one branch, otherwise
the slice name. Never launch a worker unnamed — an untitled tab is invisible to
the user watching the project workspace. Review / investigation workers launched
with `herdr-launch` must likewise pass `--label <name>` (and are pinned to the
project workspace via the launch cwd) so they land named alongside the project,
not in the orchestration workspace.

## Worker prompt contract

A launched worker pane is blank. Compose its prompt from `roles/worker.md`
(that file is the source of the worker contract) and deliver it with
`"$S/herdr-say" <worker-pane> "<prompt>"`. Every worker prompt must carry:

- Worker ID, fixed branch, task scope, and explicit non-goals.
- Observable acceptance behavior — no implementation code.
- No new packages without user approval.
- Typecheck and touched-test requirements.
- Commit format and push target.
- Sentinels (see root skill).
- Shared-file ownership rules.
- No subagents or background task delegation.

## Checker pattern

Admin never blocks waiting for a worker and never polls workers directly.

For each active worker, dispatch one `checker` agent (task tool,
`agent: checker`) with the worker's pane id. The checker prompt MUST include:
`"Poll interval: wait 60 seconds between each herdr agent get status check."`.
The checker guard-loops `herdr agent get <pane>` until stable idle, sleeping
60 seconds between polls, reads
`herdr agent read <pane> --source recent-unwrapped`, classifies the sentinel,
and returns one structured report. The checker is one-shot and self-terminates
after reporting. Checker observes only — Admin makes every orchestration
decision.

## Shared-file ownership

Admin assigns every shared file to exactly one worker before dispatch.

- Small handoff: worker sends concise instructions to the owning worker via
  herdr pane communication.
- Large or exact handoff: worker writes a patch to a gitignored scratch
  directory and sends its path to the owner.
- Owning worker applies, verifies, commits, and pushes.
- Ambiguous ownership → emit `NEEDS-INPUT`; never blind-write.
- Delete scratch artifacts after integration. Never commit them.

## Wave execution

1. Finish prerequisite wave; verify remote commit.
2. Create independent worker worktrees from the updated integration branch.
3. Launch independent workers in parallel; start one checker per worker.
4. Merge worker branches into integration branch in planned order with `--no-ff`.
5. After every merge, run integrated typecheck and tests before the next merge.
6. Mechanical conflicts only — semantic conflicts go to the user.
7. Failures fix forward through the responsible worker on its branch, then re-merge.
8. Push integration branch; remove completed worktrees.
9. Raise one phase PR unless the user requests per-worker PRs.

## Reporting to Main

```bash
herdr pane run <main-pane> "<one-line milestone>"
```

Report only: worker merged, wave complete, `NEEDS-INPUT`, `BLOCKER`, PR ready,
or final delivery. Resolve pane IDs dynamically — never hardcode across
sessions.

Status table: worker | branch/pane | state | current step | evidence |
blocker | next.

## Delivery gate

1. After implementation passes integrated verification, a final docs worker
   updates required project tracking files. Admin does not edit them.
2. Admin raises a **draft** phase PR.
3. Read-only review workers post findings on the draft PR. Confirmed findings
   return to the responsible worker; integrate fixes and request re-review.
4. When reviews pass, Admin marks PR ready and reports to Main.
5. Never merge to main without explicit user approval. After approval: merge
   commit, update local main, close issues with evidence, clean worktrees,
   report final SHA to Main.

## Branch and checkout handling

- Keep main checkout on the base branch during active waves; integrate in the
  phase worktree.
- Git cannot check out one branch in two worktrees. To move main onto the phase
  branch, first remove the clean phase worktree, then switch.
- Worker branches merge only into the integration branch.

## Cleanup and safety

- Remove worker worktrees only after commits are pushed and integrated.
- Keep the integration branch until PR and verification finish.
- Never delete or force-reset unexpected user changes.
- Relay all tool/skill constraints to every active worker.
