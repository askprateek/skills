# Writing a SKILL.md

A skill is a single Markdown file at `skills/<name>/SKILL.md`. The installer (and any Agent Skills-compatible client) discovers skills by scanning `skills/*/SKILL.md`, so the file's location and its frontmatter are load-bearing.

## Frontmatter

Every `SKILL.md` starts with a YAML frontmatter block:

```markdown
---
name: my-skill
description: One clear sentence describing when and why to use this skill.
---
```

- `name` — required. Must exactly match the containing directory name (`skills/my-skill/SKILL.md` → `name: my-skill`). Lowercase letters, digits, and hyphens only.
- `description` — required, non-empty. This is what the model reads to decide *whether* to use the skill, so front-load the trigger conditions ("use when...", "use if the user asks...") rather than just naming the topic.

`scripts/validate.sh` enforces both of these; keep it passing.

## Body

The body is plain Markdown instructing the agent how to carry out the skill. Guidelines:

- **Keep it under ~5000 tokens.** The body is loaded into context whenever the skill is invoked — treat it like a prompt, not a manual.
- **Be procedural.** Prefer concrete steps, commands, and examples over abstract prose.
- **Push deep detail out.** Reference material that's only needed occasionally (full API docs, long option tables, edge-case catalogs) belongs in a `references/` subdirectory next to the skill, e.g. `skills/my-skill/references/api.md`, and should be linked from the body rather than inlined.
- **State scope.** Say explicitly what the skill is for and, if useful, what it's *not* for — this helps the model choose between overlapping skills.

## Example structure

```
skills/my-skill/
  SKILL.md              # frontmatter + procedural body, <5000 tokens
  references/
    api.md               # optional deep-dive material, loaded on demand
    examples.md
```

See [`skills/herdr-orchestration/SKILL.md`](../skills/herdr-orchestration/SKILL.md) for a working example.
