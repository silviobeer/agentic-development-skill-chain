#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_SKILLS=(
  0_chain-guide
  0a_product-vision
  0b_intake
  0c_bootstrap
  1a_clarification
  1_concept
  1b_visual-companion
  2_requirements-engineer
  1c_frontend-design
  1d_prototyping
  1e_concept-sync
  2b_handoff-package
  2c_review-reconcile
  2e_handoff-refinement
  3_architecture
  4_writing-plans
  5_executing
  5b_executing-large-model
  6_qa
  7_documentation
  8_delivery
  cross-review
)
OPTIONAL_SKILLS=(
  bugfixing
  refactor-dreamer
  sonar-cli
  supabase-local-dev
  update-chain
  vibecoder
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

# CP1 + P0 are subskills of executing: instruction files, not discoverable skills
for platform in codex claude; do
  for sub in checkpoint setup; do
    file="$ROOT/$platform/skills/5_executing/subskills/$sub.md"
    [ -f "$file" ] || fail "missing $file"
    head -n 1 "$file" | grep -qx -- "---" && fail "$file must not carry skill frontmatter"
  done
done

[ -f "$ROOT/CLAUDE.md" ] || fail "missing CLAUDE.md"
grep -q 'AGENTS.md' "$ROOT/CLAUDE.md" || fail "CLAUDE.md must point to AGENTS.md"

stale_candidates="$(mktemp)"
if grep -R -n 'CLAUDE\.md Candidates\|CLAUDE-PROJ' "$ROOT/codex" "$ROOT/claude" "$ROOT/docs" >"$stale_candidates"; then
  cat "$stale_candidates" >&2
  rm -f "$stale_candidates"
  fail "stale CLAUDE.md candidate convention found"
fi
rm -f "$stale_candidates"

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
check_identical() {
  local first="$1"; shift
  [ -f "$first" ] || fail "missing $first"
  for other in "$@"; do
    [ -f "$other" ] || fail "missing $other"
    cmp -s "$first" "$other" || fail "helper copies differ: $first vs $other"
  done
}
check_identical "$ROOT/claude/skills/5_executing/scripts/wave-gate.sh" "$ROOT/codex/skills/5_executing/scripts/wave-gate.sh"
check_identical "$ROOT/runner/prompts/p6-controller.md" "$ROOT/claude/skills/5_executing/references/p6-controller.md" "$ROOT/codex/skills/5_executing/references/p6-controller.md"
check_identical "$ROOT/claude/skills/5_executing/references/in-session-driver.md" "$ROOT/codex/skills/5_executing/references/in-session-driver.md"
check_identical "$ROOT/claude/skills/5_executing/scripts/state.sh" "$ROOT/codex/skills/5_executing/scripts/state.sh"
check_identical "$ROOT/claude/skills/5_executing/scripts/env-local.sh" "$ROOT/codex/skills/5_executing/scripts/env-local.sh"
check_identical "$ROOT/claude/skills/5_executing/scripts/compat.sh" "$ROOT/codex/skills/5_executing/scripts/compat.sh"
bash "$ROOT/scripts/check-portability.sh" || fail "GNU-only usage outside compat.sh"
check_identical "$ROOT/claude/skills/5_executing/scripts/worktree.sh" \
  "$ROOT/codex/skills/5_executing/scripts/worktree.sh"
# Removed duplicates and folded scripts must stay gone (a second copy would drift silently).
for dup in 5_executing/scripts/plan.mjs 0b_intake/scripts/curation-caps.sh 7_documentation/scripts/curation-caps.sh 0b_intake/scripts/intake-seal-check.sh 8_delivery/scripts/worktree.sh \
         5_executing/scripts/validate-wave-plan.mjs 5_executing/scripts/compile-context-bundles.mjs \
         8_delivery/scripts/render-pr-body.mjs 8_delivery/scripts/ci-poll.sh 8_delivery/scripts/conflict-probe.sh \
         6_qa/scripts/ledger.mjs 6_qa/scripts/harvest-debt.sh 5_executing/scripts/quality-evidence.mjs 5_executing/scripts/quality-gate-proof.sh; do
  for platform in claude codex; do
    [ ! -e "$ROOT/$platform/skills/$dup" ] || fail "duplicate helper copy must stay deleted: $platform/skills/$dup"
  done
done
while IFS= read -r bugfix_file; do
  bugfix_rel="${bugfix_file#"$ROOT/codex/skills/bugfixing/"}"
  check_identical "$bugfix_file" "$ROOT/claude/skills/bugfixing/$bugfix_rel"
done < <(find "$ROOT/codex/skills/bugfixing" -type f | sort)
# Optional receiving skills share the same contracts and behavior on both providers.
for skill in 2e_handoff-refinement; do
  while IFS= read -r file; do
    relative="${file#"$ROOT/codex/skills/$skill/"}"
    check_identical "$file" "$ROOT/claude/skills/$skill/$relative"
  done < <(find "$ROOT/codex/skills/$skill" -type f | sort)
  diff -qr "$ROOT/codex/skills/$skill" "$ROOT/claude/skills/$skill" >/dev/null || \
    fail "optional receiving skill copies differ: $skill"
done

check_identical "$ROOT/claude/skills/5b_executing-large-model/SKILL.md" \
  "$ROOT/codex/skills/5b_executing-large-model/SKILL.md"
# 5b stays lean: shared rules live in 5_executing/references/, not in 5b
for platform in claude codex; do
  [ "$(wc -l <"$ROOT/$platform/skills/5b_executing-large-model/SKILL.md")" -le 350 ] || \
    fail "5b exceeds 350 lines: move procedure to 5_executing/references/ or drop it (every line is an invariant or a lead-only decision)"
done

# Every 5_executing reference must be cited somewhere (catches orphans); templates
# that scripts copy or read by path are cited by those scripts, so no allow-list.
for platform in claude codex; do
  for ref in "$ROOT/$platform/skills/5_executing/references/"*; do
    name="$(basename "$ref")"
    grep -rqF --exclude="$name" -- "$name" "$ROOT/$platform/skills/5_executing" "$ROOT/$platform/skills/5b_executing-large-model" "$ROOT/runner" || \
      fail "orphan reference, cited by nothing: $platform/skills/5_executing/references/$name"
  done
done
check_identical "$ROOT/claude/skills/update-chain/SKILL.md" \
  "$ROOT/codex/skills/update-chain/SKILL.md"
check_identical "$ROOT/claude/skills/vibecoder/SKILL.md" \
  "$ROOT/codex/skills/vibecoder/SKILL.md"
check_identical "$ROOT/claude/skills/1a_clarification/SKILL.md" \
  "$ROOT/codex/skills/1a_clarification/SKILL.md"
for f in 5_executing/scripts/chain 0_chain-guide/scripts/chain-status.mjs 5_executing/scripts/preflight.sh 5_executing/scripts/sync-framework.mjs 5_executing/templates/decisions.md.tmpl \
         4_writing-plans/scripts/validate-wave-plan.mjs \
         2_requirements-engineer/scripts/validate-prds.mjs 3_architecture/scripts/validate-architecture.mjs \
         5_executing/scripts/compile-context.mjs 5_executing/scripts/story-slice.mjs \
         5_executing/scripts/migration-drift-check.sh \
         5_executing/manifests/roles/micro-fixer.md 5_executing/manifests/roles/implementer.md \
         5_executing/manifests/roles/frontend-implementer.md 5_executing/manifests/roles/backend-implementer.md \
         5_executing/manifests/roles/reviewer.md 5_executing/manifests/roles/explore.md \
         7_documentation/scripts/curation.sh \
         cross-review/scripts/cross-review.sh cross-review/scripts/review-with-claude.sh \
         cross-review/scripts/review-with-codex.sh cross-review/templates/cross-review-prompt.md.tmpl \
         5_executing/templates/agent-md-entry.md.tmpl \
         5_executing/scripts/gen-component-registry.mjs 5_executing/scripts/quality.mjs \
         6_qa/scripts/findings.mjs \
         8_delivery/scripts/delivery.sh 5_executing/scripts/render.mjs \
         5_executing/templates/morning-report.md.tmpl 5_executing/templates/stop-report.md.tmpl \
         8_delivery/templates/pr-body.md.tmpl; do
  check_identical "$ROOT/claude/skills/$f" "$ROOT/codex/skills/$f"
done

check_identical "$ROOT/codex/skills/6_qa/scripts/findings-store.mjs" \
  "$ROOT/claude/skills/6_qa/scripts/findings-store.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/findings-store.mjs" \
  "$ROOT/claude/skills/5_executing/scripts/findings-store.mjs"

# Shared pure readers must match every adjacent import copy.
check_identical "$ROOT/codex/skills/4_writing-plans/scripts/document-parser.mjs" \
  "$ROOT/claude/skills/4_writing-plans/scripts/document-parser.mjs" \
  "$ROOT/codex/skills/2_requirements-engineer/scripts/document-parser.mjs" \
  "$ROOT/claude/skills/2_requirements-engineer/scripts/document-parser.mjs" \
  "$ROOT/codex/skills/3_architecture/scripts/document-parser.mjs" \
  "$ROOT/claude/skills/3_architecture/scripts/document-parser.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/document-parser.mjs" \
  "$ROOT/claude/skills/5_executing/scripts/document-parser.mjs"
check_identical "$ROOT/codex/skills/3_architecture/scripts/architecture-parser.mjs" \
  "$ROOT/claude/skills/3_architecture/scripts/architecture-parser.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/architecture-parser.mjs" \
  "$ROOT/claude/skills/5_executing/scripts/architecture-parser.mjs"

# One input resolver serves installed gates and synchronized project helpers.
resolver="$ROOT/codex/skills/2e_handoff-refinement/scripts/resolve-inputs.mjs"
while IFS= read -r copy; do
  check_identical "$resolver" "$copy"
done < <(find "$ROOT/codex/skills" "$ROOT/claude/skills" -name resolve-inputs.mjs -type f | sort)

check_identical "$ROOT/codex/skills/2e_handoff-refinement/scripts/integration-status.mjs" \
  "$ROOT/claude/skills/2e_handoff-refinement/scripts/integration-status.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/integration-status.mjs" \
  "$ROOT/claude/skills/5_executing/scripts/integration-status.mjs"

check_identical "$ROOT/codex/skills/2e_handoff-refinement/scripts/workspace.mjs" \
  "$ROOT/claude/skills/2e_handoff-refinement/scripts/workspace.mjs"
check_identical "$ROOT/codex/skills/2e_handoff-refinement/scripts/package-tools.mjs" \
  "$ROOT/claude/skills/2e_handoff-refinement/scripts/package-tools.mjs"

# Schemas must parse; every shell script must be syntactically valid;
# every node script must compile.
for schema in "$ROOT/runner/schemas/state.schema.json" "$ROOT/runner/schemas/findings.schema.json" "$ROOT/runner/schemas/context-manifest.schema.json"; do
  jq empty "$schema" 2>/dev/null || fail "schema does not parse: $schema"
done
jq empty "$ROOT/codex/skills/bugfixing/evals/evals.json" 2>/dev/null || \
  fail "bugfixing evals do not parse"
while IFS= read -r sh; do
  bash -n "$sh" || fail "bash syntax error: $sh"
done < <(find "$ROOT/claude/skills" "$ROOT/codex/skills" "$ROOT/runner" "$ROOT/scripts" -name '*.sh' -type f)
if command -v node >/dev/null; then
  while IFS= read -r mjs; do
    node --check "$mjs" 2>/dev/null || fail "node syntax error: $mjs"
  done < <(find "$ROOT/claude/skills" "$ROOT/codex/skills" "$ROOT/runner" "$ROOT/scripts" -name '*.mjs' -type f)
fi

# Syntax-only checks cannot prove gate behavior. These deterministic harnesses
# use temporary repositories/fixtures and never contact external services.
# Each harness owns its own mktemp fixtures, so they run concurrently; the
# slowest one (wave-gate) is the wall clock. Output is replayed in order.
HARNESS_LOGS=$(mktemp -d); trap 'rm -rf "$HARNESS_LOGS"' EXIT
HARNESS_NAMES=(); HARNESS_PIDS=()
harness() { local name="$1"; shift; env SKILLCHAIN_RESOURCE_LOCK_DIR="$HARNESS_LOGS/$name.resources" "$@" >"$HARNESS_LOGS/$name.log" 2>&1 & HARNESS_NAMES+=("$name"); HARNESS_PIDS+=($!); }
harness external-inputs node "$ROOT/scripts/test-external-inputs.mjs"
harness refinement-package node "$ROOT/scripts/test-refinement-package.mjs"
harness delivery-workspace node "$ROOT/scripts/test-delivery-workspace.mjs"
harness document-validators node "$ROOT/scripts/test-document-validators.mjs"
harness wave-plan-validator bash "$ROOT/scripts/test-wave-plan-validator.sh"
harness chain-dispatcher    bash "$ROOT/scripts/test-chain-dispatcher.sh"
harness chain-status        bash "$ROOT/scripts/test-chain-status.sh"
harness chain-refs          node "$ROOT/scripts/check-chain-refs.mjs"
harness chain-refs-test     bash "$ROOT/scripts/test-chain-refs.sh"
harness delivery            bash "$ROOT/scripts/test-delivery.sh"
harness curation            bash "$ROOT/scripts/test-curation.sh"
harness install             bash "$ROOT/scripts/test-install.sh"
harness uninstall           bash "$ROOT/scripts/test-uninstall.sh"
harness check-setup         bash "$ROOT/scripts/test-check-setup.sh"
harness render              bash "$ROOT/scripts/test-render.sh"
harness story-slice         bash "$ROOT/scripts/test-story-slice.sh"
harness context-bundles     bash "$ROOT/scripts/test-compile-context-bundles.sh"
harness runner-context      bash "$ROOT/scripts/test-runner-context-recovery.sh"
harness runner-interruption bash "$ROOT/scripts/test-runner-interruption.sh"
harness unattended-handoff  bash "$ROOT/scripts/test-unattended-handoff.sh"
harness p7-runner-gate      bash "$ROOT/scripts/test-p7-runner-gate.sh"
harness in-session-driver   bash "$ROOT/scripts/test-in-session-driver.sh"
harness sync-framework      node "$ROOT/scripts/test-sync-framework.mjs"
harness stage-findings node "$ROOT/scripts/test-stage-findings.mjs"
harness findings            bash "$ROOT/scripts/test-findings.sh"
harness preflight-biome     bash "$ROOT/scripts/test-preflight-biome.sh"
harness preflight-coderabbit bash "$ROOT/scripts/test-preflight-coderabbit.sh"
harness migration-drift     bash "$ROOT/scripts/test-migration-drift-check.sh"
harness worktree            bash "$ROOT/scripts/test-worktree.sh"
harness shared-lock         bash "$ROOT/scripts/test-shared-lock.sh"
harness resource-run        bash "$ROOT/scripts/test-resource-run.sh"
harness wave-gate           bash "$ROOT/scripts/test-wave-gate.sh"
harness portability         bash "$ROOT/scripts/test-portability.sh"
harness quality             node "$ROOT/scripts/test-quality.mjs"
harness mutation-file-list  node "$ROOT/scripts/test-mutation-file-list.mjs"
harness cross-review        bash "$ROOT/scripts/test-cross-review.sh"
harness cross-review-routing bash "$ROOT/scripts/test-cross-review-routing.sh"
harness review-with-claude  bash "$ROOT/scripts/test-review-with-claude.sh"
harness review-with-codex   bash "$ROOT/scripts/test-review-with-codex.sh"
harness component-registry  node "$ROOT/codex/skills/5_executing/scripts/gen-component-registry.mjs" --selftest
for i in "${!HARNESS_PIDS[@]}"; do
  if ! wait "${HARNESS_PIDS[$i]}"; then
    kill "${HARNESS_PIDS[@]}" 2>/dev/null || true
    cat "$HARNESS_LOGS/${HARNESS_NAMES[$i]}.log" >&2
    fail "harness failed: ${HARNESS_NAMES[$i]}"
  fi
done
for name in "${HARNESS_NAMES[@]}"; do cat "$HARNESS_LOGS/$name.log"; done

echo "validate: ok"
