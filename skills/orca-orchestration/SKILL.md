---
name: orca-orchestration
description: Orchestrate multiple AI agents in parallel through Orca using a non-blocking, role-assigned workflow (Main, Admin, Worker, Checker). Use for multi-worker or multi-file coding tasks, parallel implementation waves, isolated worktrees, or when the user mentions Orca or multi-agent orchestration.
---

# Orca Orchestration (non-blocking, role-assigned)

Spawn multi-worker implementations, parallel waves, isolated branches, or
coordinate OMP agents through Orca. For plain ownership handoff of a
worktree to another agent, use the orca CLI directly; this skill is for
supervised multi-agent orchestration.

Strict role hierarchy with disciplined non-blocking coordination;
primitives: Run/Task/Dispatch. Non-blocking SOP: Main/Admin never run `check --wait`.
Admin detects completion via background sonic Checkers reading worker sentinels,
reconciles bus with non-blocking `check` (no `--wait`).

---

## Assign a role before doing anything

Exactly ONE role per agent. Identify yours, read this root + your role file.
Never act outside assigned role.

| You are assigned | Read | One-line mandate |
|---|---|---|
| **Main** | `skill://orca-orchestration/roles/main.md` | User-facing; owns scope/product/model; launches Admin; **never blocks, never edits source**. |
| **Admin** | `skill://orca-orchestration/roles/admin.md` | Orchestrator; spins worktrees (single/parallel), places workers, spawns Checkers, integrates; **never `check --wait`, never edits source**. |
| **Worker** | `skill://orca-orchestration/roles/worker.md` | One bounded slice; **EXECUTOR** (edits own/shared worktree, pushes branch) or **INVESTIGATOR** (read-only shared tab, no branch); both bus-bound — report via sentinel + `worker_done`. |
| **Checker** | `skill://orca-orchestration/roles/checker.md` | Read-only background sonic subagent; polls ONE worker, classifies sentinel, reports once to Admin, self-terminates. |

Admin assigns each worker deterministic label/role (e.g. `Foundation`, `W-ui`,
`Docs`, `Review-1`) before mutating, state in prompt, worktree name, terminal
title.

---

## Hierarchy

Main → Admin → Workers → (Checkers observe) → Admin → Main. No layer skips.

- **Main** — user-facing. Never `check --wait`, never `sleep`s, never polls. Waits only on user.
- **Admin** — the orchestrator. Persistent OMP agent in split terminal on main worktree (no dedicated worktree). Binds Run, creates Tasks, spins worktrees, launches workers, spawns one Checker per active worker, reconciles bus non-blockingly, integrates, reports milestones to Main.
- **Worker** — one omp agent, one bounded slice, no subagents; bus-bound (own Task + Dispatch). **EXECUTOR**: own worktree+branch or tab on shared worktree with peer (disjoint files); commits + pushes branch. **INVESTIGATOR**: read-only tab in shared `Review`/`Research` worktree, no branch pushed, never spawns workers. Both report via sentinel + `worker_done`.
- **Checker** — background sonic subagent owned by Admin, one per active worker. Read-only: never edits, decides, or orchestrates.

---

## Model

Three durable Orca objects underpin everything:

- **Run** — namespace + coordinator inbox. Bound once per feature by Admin.
- **Task** — one work item; `--deps` form a DAG.
- **Dispatch** — one attempt of one Task on one terminal; lifecycle authority (`worker_done`, `ask`) lives on Dispatch.

Orca does NOT auto-schedule or infer file conflicts — Admin chooses placement and concurrency.

---

## Preconditions

- `orca status --json` → runtime `state: ready`; Orchestration experimental feature enabled.
- `orca` on PATH (`orca-ide` on Linux). All agent calls use `--json`.
- Copy `term_<uuid>` handles, worktree ids from `--json` — never construct by hand.
- Main captures its own handle first: `orca terminal list --worktree active --json`.

---

## Scripts live next to this file

`scripts/` ships in this same skill directory, alongside `SKILL.md`. Resolve
`<skill-root>` to wherever this skill is installed and call scripts as
`<skill-root>/scripts/<name>.sh` — NEVER assume a fixed path such as
`~/.omp/agent/skills/` or any other absolute install location. Run
`scripts/help.sh` first: it prints every wrapper's params + emits, extracted
live from each script's header.

---

## Execution mechanics — Admin branch owns

Concrete `orca` commands, the `scripts/` wrapper catalog + `help.sh` front door, worker-launch recipes (default + pinned-model), Run/Task-DAG binding, bus reconciliation, recovery, wave execution, shared-file ownership, delivery quirks, and teardown live in **roles/admin.md** — single source of truth, run only by the Admin branch. Workers/Checkers receive their one script (`worker-done.sh` / `poll.sh`) via the launch-preamble footer, not this catalog.

---

## Completion contract — sentinels

Worker ends turn with exactly ONE sentinel line, and (when launch preamble is
live) also emits native `worker_done`:

- `WORKER DONE: <task-id> — <summary>` — slice complete; typecheck + touched tests pass; committed + pushed.
- `NEEDS-INPUT: <task-id> — <question>` — blocked on decision; worker idles.
- `BLOCKER: <task-id> — <what broke>` — hard failure needing Admin/Main.

Never encode failure prose-only. Checker reads sentinel; native `worker_done` is
redundant bus signal Admin drains with non-blocking `check`.

---

## Never poll for a peer — the two-channel deadlock

A blocking poll loop for a peer's reply can never succeed, because **there are
two independent channels**:

| Channel | Written by | Read by |
|---|---|---|
| **Bus** | `orchestration send` / `worker_done` | `orchestration check` |
| **Pane text** | `send.sh` / `terminal send --text` | the agent's own input queue |

An agent that blocks inside a `sleep`-loop calling `orchestration check` sees
only the bus. If the answer instead arrives as pane text — already queued and
unreachable by `check`, which keeps returning `count: 0` — the loop can spin
indefinitely while the answer sits unread, and the blocking call itself
prevents the queued text from ever being processed. Both sides end up waiting
on each other while holding the answer.

Rules that follow:

- **Idle is a turn boundary, not a wait state.** With nothing to do, END THE TURN.
  Inbound text wakes the agent. Blocking to "stay available" makes it unavailable.
- **Never `sleep`-loop and never `check --wait`** — for Main *or* Admin.
  Background observation is a sonic Checker subagent's job, never an inline loop.
- **Never read a peer's pane to infer its state.** Ask, then end the turn.
- **Match the channel to the reader.** A bus consumer cannot see pane text and a
  pane agent does not poll the bus. State which channel a reply must use.
- **Diagnose a frozen peer by reading the wedged command**, not by resending.
  The cancelled command box names the exact loop and its timeout.

---

## Hard rules

- **Roles are fixed**: act only within assigned role; Admin labels every worker before mutating.
- **Main never blocks** (`check --wait`/`sleep`/poll) — waits only on user.
- **Admin never runs `check --wait`** in this variant — uses sonic Checkers + non-blocking `check`.
- **Main worktree stays on `main`**: Admin NEVER `git checkout` or `git switch -c` in main worktree. Create integration branch via `git branch <name> <base>` (HEAD unchanged) or use dedicated integration worktree.
- **Workers push only their own branch**: Each worker pushes ONLY its own worktree branch. Admin performs `--no-ff` merge into integration branch; workers never push integration branch.
- **Worker completion is dual-signal**: Worker emits BOTH sentinel line (DONE/NEEDS-INPUT/BLOCKER) AND exact native `orca orchestration send --type worker_done --outcome succeeded|failed ...` command (not paraphrased). Sentinel is prose; `worker_done` is authoritative bus signal.
- Main and Admin never edit source files; Admin fixes via fix Tasks.
- Every worker reports to Admin via sentinel (+ `worker_done`) — never directly to Main.
- Model gate before launching Admin or any wave; never silently substitute models.
- One worktree per slice by default; multiple agents per worktree only when file-disjoint on shared branch.
- Never merge to main without explicit user approval (draft PR + review first).
- Never remove worktree before commits pushed + integrated.
- Always copy full worktree/terminal/dispatch ids from `--json`; never construct by hand.
- Never edit Orca internal state files.

---

Known runtime quirks (split/bind/rename/read/send edge cases) and
verification-gate lessons (re-deriving PASS/FAIL, negative controls, defect
attribution): `skill://orca-orchestration/references/runtime-quirks.md`.
