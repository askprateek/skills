#!/usr/bin/env bash
# Scaffold a new skill at skills/<name>/SKILL.md from a frontmatter template.
#
# Usage: scripts/new-skill.sh <skill-name>

set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  echo "Usage: $0 <skill-name>" >&2
  echo "  <skill-name> must be lowercase letters, digits, and hyphens only." >&2
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

name="$1"

case "$name" in
  '')
    echo "Error: skill name must not be empty." >&2
    usage
    exit 1
    ;;
esac

if ! printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "Error: '$name' is not a valid skill name." >&2
  echo "Skill names must be lowercase letters, digits, and hyphens only (e.g. 'my-skill')." >&2
  exit 1
fi

skill_dir="$root_dir/skills/$name"
skill_file="$skill_dir/SKILL.md"

if [ -e "$skill_file" ]; then
  echo "Error: $skill_file already exists. Refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$skill_dir"

cat > "$skill_file" <<EOF
---
name: $name
description: TODO — one clear sentence describing when and why to use this skill.
---

# $(printf '%s' "$name" | sed 's/-/ /g')

TODO: describe what this skill does and how the agent should carry it out.
EOF

echo "Created $skill_file"
echo "Next steps:"
echo "  1. Edit the description and body in $skill_file"
echo "  2. Run scripts/validate.sh"
echo "  3. Add a row to the catalog table in README.md"
