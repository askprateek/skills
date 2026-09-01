#!/usr/bin/env bash
# Validate every skills/*/SKILL.md file:
#   - has a well-formed YAML frontmatter block (--- ... ---)
#   - frontmatter has non-empty `name` and `description` keys
#   - `name` matches the containing directory name
#
# Exits 0 with a summary on success, nonzero with per-file errors otherwise.

set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
skills_dir="$root_dir/skills"

errors=0
checked=0

fail() {
  # $1: file, $2: message
  echo "FAIL: $1: $2" >&2
  errors=$((errors + 1))
}

if [ ! -d "$skills_dir" ]; then
  echo "No skills/ directory found at $skills_dir" >&2
  exit 1
fi

for skill_dir in "$skills_dir"/*/; do
  [ -d "$skill_dir" ] || continue

  dir_name="$(basename "$skill_dir")"
  file="${skill_dir}SKILL.md"
  checked=$((checked + 1))

  if [ ! -f "$file" ]; then
    fail "$skill_dir" "missing SKILL.md"
    continue
  fi

  first_line="$(sed -n '1p' "$file")"
  if [ "$first_line" != "---" ]; then
    fail "$file" "does not start with a '---' frontmatter delimiter"
    continue
  fi

  # Line number of the closing '---' (first occurrence after line 1).
  close_line="$(awk 'NR>1 && $0=="---"{print NR; exit}' "$file")"
  if [ -z "$close_line" ]; then
    fail "$file" "missing closing '---' for frontmatter block"
    continue
  fi

  frontmatter="$(sed -n "2,$((close_line - 1))p" "$file")"

  name_value="$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -n1)"
  desc_value="$(printf '%s\n' "$frontmatter" | sed -n 's/^description:[[:space:]]*//p' | head -n1)"

  # Strip surrounding quotes, if any.
  name_value="$(printf '%s' "$name_value" | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//')"
  desc_value="$(printf '%s' "$desc_value" | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//')"

  if [ -z "$name_value" ]; then
    fail "$file" "frontmatter 'name' key is missing or empty"
    continue
  fi

  if [ -z "$desc_value" ]; then
    fail "$file" "frontmatter 'description' key is missing or empty"
    continue
  fi

  if [ "$name_value" != "$dir_name" ]; then
    fail "$file" "frontmatter name '$name_value' does not match directory name '$dir_name'"
    continue
  fi
done

if [ "$errors" -gt 0 ]; then
  echo "" >&2
  echo "$errors error(s) across $checked skill(s)." >&2
  exit 1
fi

echo "OK: $checked skill(s) validated, no errors."
