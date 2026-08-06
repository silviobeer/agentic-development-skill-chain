#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_SKILLS=(
  0_chain-guide
  0a_product-vision
  0b_intake
  1_brainstorming
  1b_visual-companion
  2_requirements-engineer
  1c_frontend-design
  1d_ui-mockup
  1e_concept-sync
  2b_handoff-package
  2c_review-reconcile
  3_architecture
  3a_cross-review
  4_writing-plans
  4a_checkpoint
  4b_setup
  5_executing
  6_qa
  7_documentation
  8_delivery
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

stale_refs="$(mktemp)"
if grep -R -n 'autonomous-execution' "$ROOT/codex" "$ROOT/claude" "$ROOT/docs" "$ROOT/README.md" >"$stale_refs"; then
  cat "$stale_refs" >&2
  rm -f "$stale_refs"
  fail "stale autonomous-execution reference found"
fi
rm -f "$stale_refs"

# Framework helpers must stay byte-identical across all their copies
# (wave-gate.sh legitimately diverges per platform and is excluded).
check_identical() {
  local first="$1"; shift
  [ -f "$first" ] || fail "missing $first"
  for other in "$@"; do
    [ -f "$other" ] || fail "missing $other"
    cmp -s "$first" "$other" || fail "helper copies differ: $first vs $other"
  done
}
check_identical "$ROOT/claude/skills/4b_setup/scripts/state.sh" \
  "$ROOT/codex/skills/4b_setup/scripts/state.sh" \
  "$ROOT/claude/skills/4a_checkpoint/scripts/state.sh" \
  "$ROOT/codex/skills/4a_checkpoint/scripts/state.sh"
check_identical "$ROOT/claude/skills/7_documentation/scripts/curation-caps.sh" \
  "$ROOT/codex/skills/7_documentation/scripts/curation-caps.sh" \
  "$ROOT/claude/skills/0b_intake/scripts/curation-caps.sh" \
  "$ROOT/codex/skills/0b_intake/scripts/curation-caps.sh"
for f in 4b_setup/scripts/preflight.sh 4a_checkpoint/templates/decisions.md.tmpl \
         4b_setup/scripts/ponytail-check.sh 4b_setup/scripts/compile-context-bundles.mjs \
         4b_setup/scripts/context-injector.mjs \
         4b_setup/manifests/roles/micro-fixer.md 4b_setup/manifests/roles/implementer.md \
         4b_setup/manifests/roles/frontend-implementer.md 4b_setup/manifests/roles/backend-implementer.md \
         4b_setup/manifests/roles/reviewer.md 4b_setup/manifests/roles/explore.md \
         0b_intake/scripts/intake-seal-check.sh \
         3a_cross-review/scripts/cross-review.sh 3a_cross-review/scripts/review-with-claude.sh \
         3a_cross-review/scripts/review-with-codex.sh 3a_cross-review/templates/cross-review-prompt.md.tmpl \
         5_executing/templates/agent-md-entry.md.tmpl \
         5_executing/scripts/gen-component-registry.mjs \
         6_qa/scripts/ledger.mjs 6_qa/scripts/harvest-debt.sh \
         8_delivery/scripts/conflict-probe.sh 8_delivery/scripts/render-pr-body.mjs \
         8_delivery/scripts/ci-poll.sh 8_delivery/templates/pr-body.md.tmpl; do
  check_identical "$ROOT/claude/skills/$f" "$ROOT/codex/skills/$f"
done

# Schemas must parse; every shell script must be syntactically valid;
# every node script must compile.
for schema in "$ROOT/runner/schemas/state.schema.json" "$ROOT/runner/schemas/findings.schema.json" "$ROOT/runner/schemas/context-manifest.schema.json"; do
  jq empty "$schema" 2>/dev/null || fail "schema does not parse: $schema"
done
while IFS= read -r sh; do
  bash -n "$sh" || fail "bash syntax error: $sh"
done < <(find "$ROOT/claude/skills" "$ROOT/codex/skills" "$ROOT/runner" "$ROOT/scripts" -name '*.sh' -type f)
if command -v node >/dev/null; then
  while IFS= read -r mjs; do
    node --check "$mjs" 2>/dev/null || fail "node syntax error: $mjs"
  done < <(find "$ROOT/claude/skills" "$ROOT/codex/skills" "$ROOT/runner" -name '*.mjs' -type f)
fi

echo "validate: ok"
