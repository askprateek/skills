# Orca runtime quirks and verification-gate lessons

Detail supporting `skill://orca-orchestration` — read on demand, not part of
the core loop.

## Local runtime quirks — Orca 1.4.185

Each of these has cost a real incident on first contact. Check here before
retrying a failed mutation.

- **`orca terminal split` reports failure but still splits.** Returns `{"ok":false,"error":{"code":"runtime_error","message":"Timed out waiting for split pane handle"}}` after ~10s, then creates the pane ~10s later. `admin-launch.sh` therefore dies at `jget` with an empty handle. A blind retry produces a **second** pane. Recovery: `orca terminal list --worktree active --json`, read each untitled pane to find the live `── π` prompt, adopt one, `orca terminal close --terminal <orphan>` the rest. Adopt-then-close, never retry-then-hope.
- **`worker-start` fails `consumer_fenced` until the coordinator terminal is bound to the Run.** Bind with `run-use` from the Admin terminal first, then `worker-start`. Workers already launched are **adopted** by the bind, not respawned — do not tear them down and relaunch.
- **omp overwrites a pane title back to `Pi`.** `orca terminal rename` does not stick on an omp pane, so panes are identified by handle, not title. Do not rely on a rename for later lookup.
- **`worker_done` fails "Dispatch capability is missing" on adopted panes.** A pane adopted by `run-use` (rather than launched by `worker-start`) has no Dispatch, so the native signal is unavailable — the sentinel line is the only completion signal. Reconcile such workers by reading the sentinel, not by waiting on the bus.
- **`orca terminal read` rejects `--lines`.** The flag is `--limit`. A read-only observer given the wrong flag reports a false "cannot read pane".
- **A truncated `term_<8hex>` handle is silently accepted by `terminal send` and never delivered.** `terminal read` rejects the short form loudly with `terminal_handle_stale`, but `send` returns `{"ok":true}` and **drops the payload**. `send.sh` reports success, so the sender believes the message landed. Always pass the full `term_<uuid>` copied from `terminal list --json`. This class of bug has cost lost verdict relays and idle minutes: the recipient sits waiting for messages that were reported as delivered.
- **A wedged pane needs raw ESC, not `--interrupt`.** `orca terminal send --interrupt` does not reliably break an in-flight omp tool call; `--text $'\x1b'` sent twice does, yielding `[Command cancelled]` and a live prompt. Verify recovery by reading the pane for the `π >` prompt before sending the next directive.

## Verification gate — held by the requester, never the implementer

The agent that gates is never the agent that built. Gate the **actual commit**,
in a **dedicated PR worktree** (`pr_checkout`), never in the integration worktree.

**Re-derive a known PASS before judging anything.** Point the gate harness at an
already-verified commit first. Every known harness bug has surfaced as a
*false FAIL against known-good code*, not as a real defect — treat a first
FAIL as a harness suspect until re-derivation rules that out.

- **A GATE FAIL must be re-derived against harness semantics before it is
  reported.** Read what the assertion actually compares. Real cases have
  traced to the harness comparing against a truncated report field, or
  coercing an array to `"a,b,c"`.
- **Embed a negative control whenever the harness was just patched** — assert one
  string that must NOT exist, in the same run. If the control passes, the patch
  manufactures false passes and the run is void.
- **Case-sensitive DOM text assertions are unsafe.** CSS `text-transform:
  uppercase` changes `innerText`, not the source. Check the component.
- **A stacked PR may be gated before retarget** if its three-dot diff is provably
  parent-only and the stack head carries the full surface.
- **Distinguish environment limits from defects.** Headless has no compositor, so
  canvas/`requestAnimationFrame` visuals read blank and screenshots time out —
  file the blind spot, never a defect.
- **Separate a plan defect from a worker error.** A worker that followed a wrong
  ruling exactly gets a PASS and a new ticket, never a fix round.
- **Log your own measurement errors in the verdict.** An unlogged bad probe gets
  re-chased by the next agent as a real defect.
