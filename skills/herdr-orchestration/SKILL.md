---
name: herdr-orchestration
description: "Standard operating procedure for orchestrating OMP agents through herdr: hierarchy (Main/Admin/Workers/Checkers), model gate, worktree topology, checker pattern, shared-file ownership, wave execution, delivery gate, and hard rules."
---

# Standard Herdr Orchestration

Use for multi-worker implementation, parallel waves, isolated branches, or any
request to orchestrate OMP agents through herdr.

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

- **Main** — user-facing agent. Stays responsive. Owns scope and product
  decisions. Routes all implementation instructions to Admin. Never executes
  code or edits source files unless user explicitly asks.
- **Admin** — persistent orchestrator in a pane on the main branch (no
  worktree). Plans waves, launches workers, runs checkers, merges into the
  integration branch, verifies, updates GitHub, cleans worktrees, reports
  milestones to Main. Never edits source files.
- **Implementation worker** — one worktree, branch, pane, bounded task slice.
  Works solo; no subagents.
- **Review worker** — read-only, no new worktree. Posts findings; no
  repository edits.
- **Checker** — one `checker` agent per active worker, owned by Admin. Observes
  only; never decides or edits.

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
the pane id from it. The raw CLI reference below is the fallback for the long tail.

`herdr-worker` and `herdr-launch` place the agent under the **project's own
workspace** (worker: `pane move` into it, auto-closing the throwaway per-worktree
workspace; launch: `tab create --workspace` derived from the cwd) and title its
tab with the `label` — so agents appear named alongside the project, never
stranded in the orchestration workspace. Always pass a meaningful label.

**No `agent start` needed:** herdr detects the OMP agent from pane content, so a
plain pane (`worktree create` root, `tab create` root, or `pane split`) plus
`pane run "omp --model X"` is fully tracked and observable via `herdr agent
read`. `agent start` only bundles pane-create + launch + an optional `--name`;
the scripts use the uniform pane-run path everywhere.

## Herdr CLI reference

Ground the exact command surface before issuing herdr commands — do not guess
flags. `herdr <group> --help` is authoritative when unsure.

- **JSON is the default output** of every herdr command. `--json` is NOT a
  universal flag: it is accepted only by `herdr worktree *` and
  `herdr agent explain`. Passing `--json` to `pane`/`tab`/`agent list|get|read`
  fails with `unknown option` and empty stdout. Parse the default JSON; never
  append `--json` to those groups.
- **Empty stdout + nonzero exit is a bad flag/subcommand, not a race.** Never
  retry-loop with sleeps — re-check `herdr <group> --help` and fix the command.
- **Observe a pane:** `herdr pane read <pane_id> --source recent-unwrapped --lines N`
  (or `herdr agent read <target> --source recent-unwrapped`). Plain text on
  success; JSON `{code,message}` + nonzero on error. Never jq the success output.
- **List panes:** `herdr pane list [--workspace ID]`. There is no `--tab`
  filter — list all and filter on `.tab_id` client-side.
- **Inspect a tab:** `herdr tab get <tab_id>`. There is no `tab show`.
- **Status snapshot / block:** `herdr agent get <target>`; block until state
  with `herdr agent wait <target> --status idle|working|blocked --timeout MS`.
- **Launch an OMP agent:** get a pane, then `herdr pane run <pane_id> "omp --model <model>"`. herdr tracks it from pane content — `agent start` is optional. Prefer the `herdr-launch` / `herdr-worker` scripts.
- **Submit a prompt to a running OMP:** `herdr pane run <pane_id> "<prompt>"`
  (types text + Enter) for a SINGLE-LINE prompt. `pane run` would submit a
  MULTI-LINE prompt at its first newline; for those, `herdr pane send-text
  <pane> "<block>"` (bracketed paste — inserts without submitting) then
  `herdr pane send-keys <pane> ENTER` once submits the whole block. `herdr-say`
  auto-selects the right path by detecting newlines — prefer it over raw calls.
  `herdr agent send` writes literal text WITHOUT Enter — never use it to submit.
- **No leftover shell panes:** launch omp INTO an existing pane (the `tab create`
  / `worktree create` root pane, or a fresh `pane split`) with
  `herdr pane run <pane> "omp ..."`. Do not `agent start --tab`, which adds a
  second pane beside the root. `herdr-launch` / `herdr-worker` already do this.

## Sentinels

Workers signal state to Admin with one of three sentinels; Admin and checkers
classify on these exact strings:

- `WORKER <ID> DONE: <sha>` — slice complete at the given commit.
- `NEEDS-INPUT <ID> — <question>` — a decision is required.
- `BLOCKER <ID> — <what>` — progress is blocked.

Never treat a worker's `completed` process status as a sentinel — require the
sentinel plus push evidence, integration, and passing tests.

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
