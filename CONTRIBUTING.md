# Contributing a skill

1. **Branch.** Create a branch off `main`, e.g. `git checkout -b skill/my-new-skill`.
2. **Add the skill.** Create `skills/<name>/SKILL.md` with valid frontmatter (`name`, `description`) — see [docs/writing-skills.md](docs/writing-skills.md) for the full format. `<name>` must exactly match the directory name and use lowercase letters, digits, and hyphens only.
   You can scaffold the file for you:
   ```bash
   scripts/new-skill.sh my-new-skill
   ```
3. **Validate.** Run the linter locally before opening a PR:
   ```bash
   scripts/validate.sh
   ```
   This checks every `skills/*/SKILL.md` for a well-formed frontmatter block with non-empty `name`/`description`, and that `name` matches its folder. Fix any reported errors — CI runs the same script and will fail the build otherwise.
4. **Update the catalog.** Add a row for your skill to the table in [README.md](README.md).
5. **Open a PR.** Describe what the skill does and why it's useful. Keep the PR scoped to one skill (or a focused set of related changes).

## Guidelines

- Keep `SKILL.md` bodies under 5000 tokens. Move deep detail into a `references/` subdirectory next to the skill.
- No new runtime dependencies — skills should work with the tools already available to the agent.
- Prefer clear, single-purpose skills over broad, do-everything ones.
