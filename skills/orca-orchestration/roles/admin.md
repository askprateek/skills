# Role: Admin (Orchestrator)

Read root `skill://orca-orchestration` for roles table, primitives, sentinels, Checker, hard rules. This file covers Admin role only.

**Assigned role: Admin.** Orchestrator: persistent OMP agent on split terminal in main worktree (no dedicated worktree). Bind Run, create Task DAG, spin worktrees (single OR parallel), launch workers, spawn one background Checker per active worker, integrate, report milestones to Main. **NEVER edit source files** (delegate via fix Tasks) and **NEVER run `orca orchestration check --wait`** (use non-blocking variant). Never become Main, Worker, or Checker.

---

## Assign every worker a role/label first

Name each slice with deterministic label matching its role: `Foundation`, `W-ui`, `W-home-core`, `Docs`, `Review-1`, … Use exact label as worktree `--name`, terminal title, worker prompt identity. Enables "every agent has role" in practice.

## Scripts (canonical)

Bash wrappers for every orchestration step, installed in `scripts/` next to
this skill's `SKILL.md` — resolve `<skill-root>` to wherever this skill is
installed and call scripts as `<skill-root>/scripts/<name>.sh`; never assume a
fixed install path. Each validates required args, extracts JSON ids, re-emits
as `KEY=VALUE` on stdout (capture via `eval "$(script ...)"` to avoid
hand-copying). Stdout machine-readable; stderr carries prefixed notes. Skip
preflight via `ORCA_SKIP_PREFLIGHT=1`.

**Front door — `help.sh`.** RUN FIRST. `scripts/help.sh [name-substring]` prints every script's params + emits, auto-extracted from headers (always in sync). Never read script source to learn args — run `help.sh`, or run any script with wrong/no args (rc=2, safe: arg-check fires before side effects).

| Script | Purpose | Signature |
|---|---|---|
| `help.sh` | Front door: prints all params + emits (run FIRST) | `help.sh [name-substring]` |
| `run-bind.sh` | Create new Run, warn stale | `run-bind.sh "<objective>"` → `RUN_ID` |
| `task-add.sh` | Add Task to DAG | `task-add.sh "<spec>" ["task_a,task_b"]` → `TASK_ID` |
| `worker-launch.sh` | Full pinned-model launch (worktree→terminal→worker-start→send prompt) | `worker-launch.sh <label> <task_id> <model> <base_branch> <repo_sel> <prompt\|@file> [run_id]` → `LABEL WORKTREE_ID TERMINAL_HANDLE DISPATCH_ID` |
| `worktree-new.sh` | Create shared worktree once (tabs attach after) | `worktree-new.sh <label> <base_branch> <repo_sel>` → `WORKTREE_ID WORKTREE_PATH` |
| `tab-launch.sh` | Attach agent as tab on shared worktree, bind own Task | `tab-launch.sh <worktree_sel> <label> <task_id> <model> <prompt\|@file> [run_id]` → `LABEL TERMINAL_HANDLE DISPATCH_ID` |
| `send.sh` | Send text (or @file) to terminal | `send.sh <handle> <text\|@file> [--no-enter]` |
| `inject.sh` | ESC-cancel + re-inject to active agent | `inject.sh <handle> <text\|@file>` |
| `report.sh` | Report milestone to Main (MILESTONE: prefix) | `report.sh <main_handle> <text\|@file>` |
| `poll.sh` | Checker poll: wait tui-idle, classify sentinel | `poll.sh <handle> [timeout_ms] [tail_lines]` → `CLASS SENTINEL` |
| `bus-check.sh` | Drain bus non-blocking (bound run only) | `bus-check.sh` (NO run_id arg) → `COUNT` |
| `worker-release.sh` | Release settled worker | `worker-release.sh <dispatch_id>` |
| `worker-stop.sh` | Stop active worker (any state) | `worker-stop.sh <dispatch_id>` |
| `worker-status.sh` | Recovery: dispatch status + tail | `worker-status.sh <dispatch_id> [tail_lines]` → `STATUS STAGE TASK_ID TERMINAL_HANDLE` |
| `worktree-rm.sh` | Remove worktree (final teardown) | `worktree-rm.sh <worktree_selector>` |
| `integration-branch.sh` | Create integration branch (ref-only, HEAD unmoved) | `integration-branch.sh <branch> <base> [--worktree <name> <repo_sel>]` → `INTEGRATION_BRANCH` |
| `admin-launch.sh` | Idempotent Admin split on Main worktree | `admin-launch.sh <main_handle> <model> [title]` → `ADMIN_HANDLE` |
| `worker-done.sh` | (Worker runs) emit `worker_done` on bus | `worker-done.sh <task_id> <dispatch_id> <outcome> [subject] [body] [files-csv]` |

---

## Bind the Run (once per feature)

```bash
eval "$(run-bind.sh "<feature objective>")"
# $RUN_ID is now available; optionally inspect state first:
orca orchestration task-list --json
orca orchestration run-list --json
```

---

## Build the Task DAG

One Task per bounded slice. Encode dependencies with `--deps`; keep depth ≤ 3–4.

```bash
eval "$(task-add.sh "<slice A: scope, non-goals, acceptance>")"
# $TASK_ID is now available; repeat for each task
eval "$(task-add.sh "<integration/docs>" "task_a,task_b")"
orca orchestration task-list --ready --json   # external memory — what may start now
```

Spec is worker's brief. MUST carry: worker role/label; scope + explicit non-goals; observable acceptance criteria; no new packages without user approval (raise NEEDS-INPUT); typecheck + touched-test requirements; commit format and push target; shared-file ownership; three sentinel lines to emit; "no subagents, no orchestration."

**Hard rule #4**: Spec MUST explicitly state: **"Push OWN worktree branch only. Do NOT push integration branch"** — Admin performs `git merge --no-ff` into integration branch after all integration criteria pass.

Full worker contract: `skill://orca-orchestration/roles/worker.md`.

---

## Hard rule #1: Main worktree stays on main

The main worktree MUST stay on branch `main` at all times. Admin NEVER runs `git checkout`/`switch -c` in the main worktree. Create integration branch via `git branch <name> <base>` (ref-only, doesn't move HEAD), or create dedicated integration worktree if merges needed. Admin owns `git merge --no-ff` into integration branch; workers push only their own worktree branches.

## Launch workers

Use robust `worker-launch.sh` wrapper: worktree create → terminal create (omp --model) → wait tui-idle → worker-start → send prompt. All IDs parsed from JSON, re-emitted as KEY=VALUE; capture via `eval`.

```bash
eval "$(worker-launch.sh '<Label>' '$TASK_ID' '<model>' '<integration-branch>' '<repo-sel>' '<prompt|@file>' ['$RUN_ID'])"
# Emits: LABEL WORKTREE_ID TERMINAL_HANDLE DISPATCH_ID
```

**Important**: `worker-launch.sh` targets worktrees by PATH, not by `name:$LABEL` (worktree `name` field is null in Orca; path is stable selector).

**Parallel worktrees**: run recipe once per independent slice, all off same updated integration branch. Start **all** ready workers before spawning Checkers — real concurrency.

**Multiple agents in one worktree** (bus-bound tabs): create worktree ONCE with `worktree-new.sh`, attach each agent as tab bound to own Task via `tab-launch.sh path:<wt_path> ...`. Each tab gets OWN Dispatch + `worker_done` lifecycle and OWN Checker — only worktree shared. File sets MUST be disjoint; you own single merge. NEVER use `worker-launch.sh` here (always creates new worktree).

### Pinned non-default model — Option-1 (manual; what `worker-launch.sh` automates)

**Pinned non-default model — Option-1 recipe.** `worker-start --agent omp` CANNOT set `--model` (inherits default role model). To pin worker model without mutating global config, launch omp terminal yourself, then bind:
```bash
# 1) worktree, NO --agent (avoids auto-launching default-model agent)
orca worktree create --name <Label> --repo <repoSel> --base-branch <integration-branch> --setup run --json
# 2) omp terminal on chosen model
orca terminal create --worktree name:<Label> --command "omp --model <worker-model>" --json   # capture handle
# 3) bind dispatch to terminal (NO --agent/--model/--name/--setup here)
orca orchestration worker-start --task <task_id> --worktree name:<Label> --terminal <handle> --json
# 4) deliver prompt
orca terminal send --terminal <handle> --text "<worker prompt>" --enter --json
```
`orca worktree create` auto-spawns empty shell terminal — close leftover (`orca terminal close`).

---

## Worker topology: EXECUTOR vs INVESTIGATOR

**EXECUTOR**: Makes edits to source. Gets dedicated child worktree ONLY when editing same files as peer or needing independent branch; otherwise executors SHARE one worktree and run as parallel tabs (disjoint file sets). Solo or own-worktree executor → `worker-launch.sh`. Shared-worktree executors → `worktree-new.sh` once + `tab-launch.sh` per executor. ALWAYS has dispatch lifecycle (`worker_done`, Checker poll); responsible for commit + push on its branch.

**INVESTIGATOR**: Read-only research/review; NEVER spawns new workers. Runs as TAB inside ONE shared worktree (e.g. `Review`, `Research`), launched via `tab-launch.sh`. Bus-bound: still gets OWN Task + Dispatch and MUST emit `worker_done` (via `worker-done.sh`) so Admin tracks it on bus exactly like executor — only worktree shared and no branch pushed. Prints sentinel final line too (dual-signal).

**Default**: assume EXECUTOR. Mark Task as INVESTIGATOR in `--spec` only when scope is read-only and safely coexists with peers on shared worktree.

---

## Supervise via Checkers (the non-blocking loop)

Do NOT run `check --wait`. Per active worker:

1. Dispatch ONE background **sonic** Checker (subagent) — see
   `skill://orca-orchestration/roles/checker.md`. Give it worker's terminal
   handle, label, task id.
2. Checker polls worker via `poll.sh <handle>` (waits tui-idle, classifies
   sentinel: DONE / NEEDS-INPUT / BLOCKER), reports ONCE, self-terminates.
3. On Checker report, drain bus non-blockingly:
   ```bash
   eval "$(bus-check.sh)"   # bound run only (NO run_id arg)
   ```
4. Act on classification:
   - **DONE** → verify commit is pushed; merge `--no-ff` in planned order;
     run integrated typecheck + tests; `worker-release.sh <dispatch_id>`
     (or reuse terminal for follow-up Task via `worker-launch.sh` on same terminal).
   - **NEEDS-INPUT** → answer via `send.sh <handle> "<answer>"` (or `orca orchestration reply --id <msg_id>`); if
     scope/product decision, escalate to Main.
   - **BLOCKER** → escalate to Main with Checker's excerpt; recover per below.

Never re-enter `check --wait`. Worker idle without sentinel means still
working or crashed — Checker distinguishes; do not release on silence.

---

## Recovery (conditional, never a fixed destructive sequence)

Inspect dispatch state:
```bash
eval "$(worker-status.sh <dispatch_id>)"
# Emits: STATUS STAGE TASK_ID TERMINAL_HANDLE
```

- `ready` → keep Checker running or use `orca orchestration worker-read` for bounded output.
- `failed`/`stopped` → retry via fix Task (`--retry-of <id>`), re-launch with `worker-launch.sh`.
- `outcome_unknown` → `worker-stop.sh <dispatch_id>` and re-inspect, or `orca orchestration worker-abandon --dispatch <id>`.

After 3 consecutive failures on one Task dispatch context circuit-breaks —
escalate to Main.

---

## Delivery mechanics (hard-won)

- Deliver to IDLE agent: `orca terminal send --terminal <h> --text "<msg>" --enter --json` → `ok:true`.
- Cancel omp agent mid-turn: `--interrupt` relay does NOT work. Send raw ESC byte `orca terminal send --terminal <h> --text "$(printf '\033')" --json`, then send real message with `--enter`.
- Idle vs working: spinner in tail (`Working…`, braille frames, `esc to`) = busy; absence at prompt box = idle.
- `orca terminal read` flags: `--cursor --environment --json --limit --pairing-code --terminal` (NO `--lines`).
- Admin → Main: `orca terminal send --terminal <main-handle> --text "<milestone>" --enter --json`.

Known Orca runtime quirks (split-report races, bind ordering, stale handles):
`skill://orca-orchestration/references/runtime-quirks.md`.

---

## Shared-file ownership

Assign every shared file to exactly one worker/role before dispatch.
- Small handoff → send instructions to owner's terminal.
- Large handoff → non-owner writes patch to gitignored scratch file (e.g.
  `.orca-scratch/<contract>.md`) and sends path; owner applies, verifies,
  commits, pushes.
- Ambiguous ownership → worker raises NEEDS-INPUT; Admin decides. Never blind-write.
- Delete scratch artifacts after integration; never commit them.

---

## PLAN-FIRST GATE: Topology & minimization

**Before launching ANY worker**, write and commit topology plan:

- Map each Task to worker type (EXECUTOR | INVESTIGATOR).
- Identify independent slices that can run in parallel.
- Choose worktree topology: **minimize child worktrees**.
  - EXECUTOR slices → **share ONE worktree with parallel tabs by default** (file
    sets disjoint). Create **separate child worktree** ONLY when two executors
    edit same files or need independent branches.
  - INVESTIGATOR workers → **always tabs in single shared `Review`/`Research`
    worktree**, each still bus-bound (own Task + Dispatch + `worker_done`).
  - Dependent slices → may share worktree if safe, or create child per batch.
- Enforce: SCRIPTS-FIRST discipline. Every worktree create, terminal create, worker-start, merge, close flows through scripts/ wrappers, never hand-typed orca.

Plan is playbook; deviate only if Main approves.

---

## Wave execution

1. Bind Run; build full Task DAG.
2. Create integration branch: `eval "$(integration-branch.sh <branch> main)"` (ref-only, HEAD unmoved).
3. Execute topology plan from PLAN-FIRST GATE, all via scripts:
   - `worktree-new.sh` once per SHARED worktree (investigators; disjoint-file executors).
   - Own-worktree executors created by `worker-launch.sh` itself.
4. Launch each own-worktree EXECUTOR via `worker-launch.sh`; launch each
   shared-worktree tab (executor or investigator) via `tab-launch.sh path:<wt> ...`.
   Spawn ONE Checker per worker — investigators included (bus-bound).
5. Every worker (executor AND investigator) signals completion via `worker-done.sh`
   (`worker_done` on bus) AND sentinel line; Checkers poll all.
6. As Checkers report DONE, verify commits pushed; merge into integration branch `--no-ff` in planned order.
7. After every merge, run integrated typecheck and tests before next merge.
8. Semantic conflicts / failures → fix-forward via fix Task (`--retry-of`), re-merge.
9. Push integration branch; open ONE draft PR for the phase (Main authorizes merge to main); transition to cleanup.
10. Dependent Tasks (`task-list --ready`) unblock as deps complete.

---

## Cleanup and teardown (hard rule #9)

**Final teardown order**: Close workers in reverse creation order, clean up infrastructure.
All operations route through scripts to match plan.

**For each completed EXECUTOR worker dispatch:**

1. **Release settled worker** (success path):
   ```bash
   worker-release.sh <dispatch_id>
   ```

2. **Stop active worker** (if needed, e.g., timeout or interruption):
   ```bash
   worker-stop.sh <dispatch_id>
   ```

3. **Remove child worktree** (after dispatch closed):
   ```bash
   worktree-rm.sh path:<worktree_path>
   ```

4. **Close worker terminal**:
   ```bash
   orca terminal close --terminal <handle> --json
   ```

**For INVESTIGATOR workers** (bus-bound tabs, shared worktree):
- Completion authority for tab is **Checker's text sentinel**, NOT bus. Known Orca bug (#12): tab's first `worker_done` can fail `dispatch_capability_invalid` and dispatch never settles even after successful retry, so bus `worker_done` is **best-effort** for tabs. `worker-done.sh` auto-retries that specific error.
- Try `worker-release.sh <dispatch_id>` for each settled dispatch. If returns `dispatch_inactive`/`ready` (unsettled tab), do NOT block or loop — proceed to close tab regardless (`worker-stop.sh` may report `stop_unknown` for such tabs; expected and non-fatal).
- Close each tab: `orca terminal close --terminal <handle>`.
- Remove shared `Review`/`Research` worktree with `worktree-rm.sh path:<wt>`
  only AFTER every co-located tab closed. Tab teardown NEVER blocks on bus
  settlement.

**Final cleanup:**
- Remove integration worktree (if separate): `worktree-rm.sh path:<integration_path>`.
- Push integration branch (if not already pushed).
- Report final SHA and delivery status to Main.
- **Dry runs only**: after final milestone reported, Admin terminal
  itself MUST be closed too (no lingering Admin). Admin CANNOT self-close
  mid-command, so Main closes it: `orca terminal close --terminal <admin_handle>`.
  Protect unrelated Admins (e.g. other worktrees) — close ONLY dry-run Admin.

⚠ **CRITICAL**: Never use `orca terminal stop --worktree <name>` — kills
**entire worktree** including co-located Main. Always use `terminal close --terminal <h>`.
