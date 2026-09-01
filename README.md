# skills

[![skills.sh](https://skills.sh/badge/askprateek/skills)](https://skills.sh/askprateek/skills)

A public, MIT-licensed collection of [Agent Skills](https://agentskills.io) — modular, model-invoked capabilities for AI coding agents. This repo follows the open Agent Skills standard and the [vercel-labs/skills](https://github.com/vercel-labs/skills) installer convention: every skill lives at `skills/<name>/SKILL.md`.

## Install

Install every skill in this repo, or a single one, with the `skills` CLI:

```bash
npx skills add askprateek/skills
```

Install a single skill:

```bash
npx skills add askprateek/skills/<skill-name>
```

## Catalog

| Skill | Description |
| --- | --- |
| [`herdr-orchestration`](skills/herdr-orchestration/SKILL.md) | Orchestrate multiple AI agents in parallel through herdr: Main/Admin/Worker/Checker hierarchy, worktree/pane spawning, and parallel implementation waves. |

<!-- Add new rows above this line as skills are added. -->

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
