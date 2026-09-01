# askprateek/skills — Battle-Tested Agent Skills

[![skills.sh](https://skills.sh/badge/askprateek/skills)](https://skills.sh/askprateek/skills)

My personal collection of [Agent Skills](https://agentskills.io) — workflows I build and use daily, released as install-ready skills for AI coding agents. New skills land regularly: multi-agent orchestration, automation loops, and more. Works with Claude Code, Codex, Cursor, and 70+ agents via one npx skills command.

## Install

Install every skill in this repo, or a single one, with the `skills` CLI:

```bash
npx skills add askprateek/skills
```

Install a single skill:

```bash
npx skills add askprateek/skills/<skill-name>
```

## Skills

### herdr-orchestration

Orchestrate multiple AI agents in parallel through herdr for multi-worker or multi-file coding tasks, parallel implementation waves, and isolated worktrees.

**What you get:** the full Main → Admin → Worker → Checker hierarchy, skill-local `herdr-*` wrapper scripts for worktree/pane orchestration, the three-sentinel vocabulary workers use to report status, and the hard rules that keep multi-agent runs safe (no merges to main without approval, no blocking waits, checker-verified completion).

```bash
npx skills add askprateek/skills/herdr-orchestration
```

[Full docs →](skills/herdr-orchestration/SKILL.md)

### orca-orchestration

Orchestrate multiple AI agents in parallel through Orca for multi-worker or multi-file coding tasks, parallel implementation waves, and isolated worktrees.

**What you get:** the full Main → Admin → Worker → Checker hierarchy built on Orca's Run/Task/Dispatch primitives, skill-local `scripts/` wrappers for worktree/terminal orchestration, the dual sentinel + native `worker_done` signal workers use to report status, and the hard rules that keep multi-agent runs safe (non-blocking completion via background Checkers, no `check --wait`, no merges to main without approval).

```bash
npx skills add askprateek/skills/orca-orchestration
```

[Full docs →](skills/orca-orchestration/SKILL.md)

## Repo layout

```
skills/<name>/SKILL.md   # one skill per directory, discovered by the installer
docs/                     # authoring docs for contributors
scripts/                  # validation and scaffolding tooling
articles/                 # long-form writeups, see articles/README.md
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a skill, and [docs/writing-skills.md](docs/writing-skills.md) for how to author a `SKILL.md`.

## License

[MIT](LICENSE)
