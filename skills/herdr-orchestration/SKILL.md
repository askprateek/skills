---
name: herdr-orchestration
description: "Orchestrate multiple AI agents in parallel through herdr. Use for multi-worker or multi-file coding tasks, parallel implementation waves, isolated worktrees, or when the user mentions herdr or multi-agent orchestration."
---

# Standard Herdr Orchestration

This root file holds what every role shares: the hierarchy, the scripts, the
herdr CLI reference, the sentinel vocabulary, and the hard rules. Read it first,
then read your role file:

| You are | Also read |
|---|---|
| **Main** (user-facing) | `skill://herdr-orchestration/roles/main.md` |
| **Admin** (orchestrator) | `skill://herdr-orchestration/roles/admin.md` |
| **Worker** (implementation / review) | prompt from Admin; source is `skill://herdr-orchestration/roles/worker.md` |

## Hierarchy

Main → Admin → Workers → Admin → Main. No layer skips.

- **Main** — user-facing; routes instructions to Admin. Full role: `roles/main.md`.
- **Admin** — orchestrator on the main branch, no worktree; dispatches workers, reports to Main. Full role: `roles/admin.md`.
- **Implementation worker** — one worktree/branch/pane; reports to Admin. Full role: `roles/worker.md`.
- **Review worker** — read-only, no worktree; reports to Admin. Full role: `roles/worker.md`.
- **Checker** — one per active worker, owned by Admin; observes only, reports to Admin.

## Scripts (prefer these over raw herdr)

Skill-local wrappers live in `scripts/` next to this file. Each fails loud
(clear message + nonzero exit, never silent empty output) and prints a
machine-parseable last line. Call by the skill's own absolute path so any
agent can use them even without loading this skill — resolve `<skill-root>`
to wherever this skill is installed (e.g. `skills/herdr-orchestration` in a
checkout, or a managed-skills install path) and set:

```bash
S=<skill-root>/scripts
```

| Script | Purpose | Usage |
|---|---|---|
| `herdr-worker` | create worktree + launch worker OMP | `herdr-worker <branch> <base> <label> <model> <repo>` |
| `herdr-launch` | launch OMP in a pane (Admin / non-worktree) | `herdr-launch <model> <cwd> [--beside <pane>] [--label <text>]` |
| `herdr-say` | submit a prompt to a running OMP | `herdr-say <pane> <prompt...>` |
| `herdr-await` | block until a pane is idle, then read it (Admin→downstream only) | `herdr-await <pane> <lines> <timeout_s>` |
| `herdr-watch` | read an agent pane's recent output | `herdr-watch <pane> <lines>` |
| `herdr-panes` | list panes as a table | `herdr-panes [tab_id\|workspace_id]` |

`herdr-worker` and `herdr-launch` print `PANE=… …` as their last line — capture
the pane id from it. The raw CLI reference (`skill://herdr-orchestration/references/cli.md`) is the fallback for the long tail.

`herdr-worker` and `herdr-launch` place the agent under the **project's own
workspace** (worker: `pane move` into it, auto-closing the throwaway per-worktree
workspace; launch: `tab create --workspace` derived from the cwd) and title its
tab with the `label` — so agents appear named alongside the project, never
stranded in the orchestration workspace. Always pass a meaningful label.

**No `agent start` needed:** herdr detects the OMP agent from pane content, so
launching `omp --model X` via `herdr pane run <pane_id> "omp --model <model>"`
INTO an existing pane (the `worktree create` root, `tab create` root, or a
fresh `pane split`) is fully tracked and observable via `herdr agent read`.
`agent start` only bundles pane-create + launch + an optional `--name` — and
`agent start --tab` adds an unwanted second pane beside the root. The
`herdr-launch` / `herdr-worker` scripts already do this correctly; prefer them
over raw `agent start`.

Raw herdr CLI fallback reference: `skill://herdr-orchestration/references/cli.md`

## Sentinels

Workers signal state to Admin with one of three sentinels; Admin and checkers
classify on these exact strings:

- `WORKER <ID> DONE: <sha>` — slice complete at the given commit.
- `NEEDS-INPUT <ID> — <question>` — a decision is required.
- `BLOCKER <ID> — <what>` — progress is blocked.

## Hard rules
- Admin never edits source files.
- Workers report to Admin only — never to Main.
- **Main never blocks on Admin or workers.** Main dispatches and returns to
  idle; Admin wakes it by writing into Main's pane. Only the user blocks Main.
- Admin never blocks waiting for workers — use checkers or `herdr-await`.
- `herdr worktree create` forks herdr's active project, not the shell cwd — so
  the repo is a REQUIRED positional (`herdr-worker <branch> <base> <label>
  <model> <repo>`, `herdr-launch <model> <cwd> …`). No default: a missing repo
  errors instead of forking the wrong project.
- Never merge to main without explicit user approval.
- Never commit scratch artifacts.
- Never reuse a delivered integration branch.
- Never treat worker `completed` status as verification — require sentinel,
  push evidence, integration, and tests.
- Never edit herdr internal state or `~/.omp/agent/extensions/herdr-omp-agent-state.ts`.
