#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_SKILLS=(
  0_chain-guide
  1_brainstorming
  1b_visual-companion
  2_requirements-engineer
  1c_frontend-design
  1d_ui-mockup
  1e_concept-sync
  2b_handoff-package
  2c_review-reconcile
  3_architecture
  4_writing-plans
  5_executing
  6_qa
  7_documentation
)
OPTIONAL_SKILLS=(
  refactor-dreamer
  sonar-cli
)
EXPECTED=("${CORE_SKILLS[@]}" "${OPTIONAL_SKILLS[@]}")

fail() {
  echo "validate: $*" >&2
  exit 1
}

check_skill_set() {
  local platform="$1"
  local dir="$ROOT/$platform/skills"

  [ -d "$dir" ] || fail "missing $dir"

  local count
  count="$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  [ "$count" = "${#EXPECTED[@]}" ] || fail "$platform has $count skill folders, expected ${#EXPECTED[@]}"

  for skill in "${EXPECTED[@]}"; do
    local file="$dir/$skill/SKILL.md"
    [ -f "$file" ] || fail "missing $file"
    head -n 1 "$file" | grep -qx -- "---" || fail "$file missing YAML frontmatter opener"
    grep -q '^name: ' "$file" || fail "$file missing name frontmatter"
    grep -q '^description: ' "$file" || fail "$file missing description frontmatter"
  done
}

check_skill_set codex
check_skill_set claude

[ -f "$ROOT/CLAUDE.md" ] || fail "missing CLAUDE.md"
grep -q 'AGENTS.md' "$ROOT/CLAUDE.md" || fail "CLAUDE.md must point to AGENTS.md"

if grep -R -n 'CLAUDE\.md Candidates\|CLAUDE-PROJ' "$ROOT/codex" "$ROOT/claude" "$ROOT/docs" >/tmp/skill-chain-stale.txt; then
  cat /tmp/skill-chain-stale.txt >&2
  fail "stale CLAUDE.md candidate convention found"
fi

if find "$ROOT/claude/skills" "$ROOT/codex/skills" -maxdepth 1 -type d -name autonomous-execution | grep -q .; then
  fail "autonomous-execution must not be included"
fi

echo "validate: ok"
