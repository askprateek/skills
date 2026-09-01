# Role: Worker

Read with root `skill://orca-orchestration` (sentinels, completion contract, hard rules). Worker contract only.

**Assigned role: Worker**, under Admin label (e.g. `Foundation`, `W-ui`, `Docs`, `Review-1`). Own exactly one Dispatch, one Task, one terminal, bounded slice. Solo work — no subagents, delegation, peer orchestration.

Two worker types:
- **EXECUTOR** — edits source. Own worktree + branch, or TAB on shared worktree (disjoint files). Commit, push own branch.
- **INVESTIGATOR** (e.g. `Review-*`, `Research-*`) — read-only tab in shared worktree; post findings; no edits, no branch push.

Both bus-bound: one Dispatch, sentinel + `worker_done`.

`worker-start` (or `dispatch --inject`) delivers **preamble** with `taskId`, `dispatchId` — authority to send lifecycle messages. Stale history or plain handoff? Do work as ordinary task, skip bus lifecycle messages (but print sentinel).

---

## Contract every worker must satisfy

- **Role/scope**: honour assigned label, worker type (EXECUTOR/INVESTIGATOR), slice, branch (executors only), explicit non-goals. Do not widen.
- **Acceptance**: satisfy observable acceptance criteria in spec.
- **Input**: validate all external input before use.
- **Dependencies**: no new packages without user approval → raise NEEDS-INPUT.
- **Verification**: typecheck and run touched tests; fix failures at source.
- **Commit/push**: one task = one commit; use stated commit format and push target; push before finishing so Admin observes commit. Push own worktree branch only — do NOT push integration branch (Admin does `--no-ff` merge).
- **Shared files**: touch only assigned files. Unassigned shared file? Raise NEEDS-INPUT or write patch to gitignored scratch file (e.g. `.orca-scratch/<contract>.md`) and hand off path. Never blind-write unassigned file.

---

## Report to Admin — sentinel first (+ worker_done)

End turn with EXACTLY ONE sentinel line as final line, so Admin's Checker classifies you:

```
WORKER DONE: <task-id> — <one-line summary>      # complete; typecheck+tests pass; committed+pushed
NEEDS-INPUT: <task-id> — <question>              # blocked on decision; then idle
BLOCKER:     <task-id> — <what broke>            # hard failure needing Admin/Main
```

Live preamble? Emit both signals (redundant, drained by Admin's non-blocking `check`). Skip `worker_done` and Admin verifies by hand:

```bash
orca orchestration send --type worker_done --subject "<short status>" \
  --body "<what you did, what you found, what's left>" \
  --task-id <task_id> --dispatch-id <dispatch_id> \
  --outcome succeeded --files-modified "path/a,path/b" --json
```

Use canonical wrapper to avoid mis-formatting:
```bash
scripts/worker-done.sh <task_id> <dispatch_id> <succeeded|failed> [subject] [body] [files]
```

Wrapper ensures correct invocation; raw `orca orchestration send --type worker_done ...` is mechanism. Launch harness (`tab-launch.sh`, `worker-launch.sh`) auto-appends COMPLETION PROTOCOL footer with `task_id`/`dispatch_id` pre-filled — run `worker-done.sh` line verbatim (fill outcome + summary) before sentinel. Do not skip: a worker that idles after its sentinel without also running `worker-done.sh` leaves Admin unable to reconcile the bus and stalls the whole wave until a Checker times out.

Encode failure as `BLOCKER:` sentinel (+ `--outcome failed`). Do not idle until sentinel printed.

For blocking question, use bus:
```bash
orca orchestration ask --question "<q>" --options "yes,no" --timeout-ms 600000 --json
orca orchestration ask --resume <message_id> --timeout-ms 600000 --json   # timed out → resume, never re-ask
```

---

## After reporting

Print sentinel, idle at prompt. No autonomous work, polling, terminal close. Direct user instruction starts ordinary work (no reuse of settled Dispatch IDs). Admin follow-up arrives fresh preamble + task block.

---

## No orchestration of others

Worker never runs `orca orchestration worker-start`, `orca worktree`, `orca terminal` on other terminals/worktrees — no inspection, listing, peer driving. Need this? Brief under-specified: raise NEEDS-INPUT.

---

## After auto-compaction

Session auto-compacts? Reload contract, label, `taskId`/`dispatchId` from launch preamble, resume slice — do not re-derive scope.
