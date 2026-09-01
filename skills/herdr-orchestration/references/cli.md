# Herdr CLI reference

Read with root `skill://herdr-orchestration` for the hierarchy, scripts, and
hard rules this reference supports. Ground the exact command surface before
issuing herdr commands — do not guess flags. `herdr <group> --help` is
authoritative when unsure.

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
- **Launch an OMP agent:** get a pane, then `herdr pane run <pane_id> "omp --model <model>"`. See root skill for why `agent start` is unnecessary; prefer the `herdr-launch` / `herdr-worker` scripts.
- **Submit a prompt to a running OMP:** `herdr pane run <pane_id> "<prompt>"`
  (types text + Enter) for a SINGLE-LINE prompt. `pane run` would submit a
  MULTI-LINE prompt at its first newline; for those, `herdr pane send-text
  <pane> "<block>"` (bracketed paste — inserts without submitting) then
  `herdr pane send-keys <pane> ENTER` once submits the whole block. `herdr-say`
  auto-selects the right path by detecting newlines — prefer it over raw calls.
  `herdr agent send` writes literal text WITHOUT Enter — never use it to submit.
