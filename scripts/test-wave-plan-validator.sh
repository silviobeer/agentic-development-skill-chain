#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$ROOT/scripts/fixtures/wave-plan-validator"
VALIDATOR="$ROOT/codex/skills/4_writing-plans/scripts/validate-wave-plan.mjs"
CASE="$(mktemp -d)"
trap 'rm -rf "$CASE"' EXIT

prepare_case() {
  local plan_fixture="$1"
  local config_fixture="$2"
  rm -rf "$CASE/plan"
  mkdir -p "$CASE/plan"
  cp "$FIXTURES/$plan_fixture" "$CASE/plan/PROJ-1-wave-1-plan.md"
  cp "$FIXTURES/$config_fixture" "$CASE/plan/wave-gate-config.json"
}

expect_failure() {
  local expected="$1"
  if node "$VALIDATOR" "$CASE/plan" >"$CASE/output" 2>&1; then
    echo "expected validator failure containing: $expected" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$CASE/output" >/dev/null; then
    echo "validator failed for the wrong reason; expected: $expected" >&2
    cat "$CASE/output" >&2
    exit 1
  fi
}

prepare_case plan-valid.md config-valid.json
node "$VALIDATOR" "$CASE/plan" | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-valid.json
jq 'del(.sonar_cmd)' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "sonar_cmd must be a non-empty top-level string"

prepare_case plan-valid.md config-config-extra-test.json
expect_failure "test_files differ"

prepare_case plan-valid.md config-command-drift.json
expect_failure "command differs"

prepare_case plan-valid.md config-duplicate-ac.json
expect_failure "more than one configured command"

prepare_case plan-duplicate-fulfills.md config-valid.json
expect_failure "must be fulfilled by exactly one task (found 2)"

prepare_case plan-undeclared-fulfills.md config-valid.json
expect_failure "Fulfills references undeclared AC"

prepare_case plan-extra-gate-command.md config-valid.json
expect_failure "Gate command PROJ-1-PRD-1-US-1-AC-99 is absent from Fulfills"

prepare_case plan-missing-gate-command.md config-valid.json
expect_failure "missing Gate command for PROJ-1-PRD-1-US-1-AC-1"

prepare_case plan-extra-test.md config-valid.json
expect_failure "test_files differ"

prepare_case plan-valid.md config-missing-regression.json
expect_failure "broad regression suite"

prepare_case plan-valid.md config-missing-auth-budget.json
expect_failure "require config.auth_budget"

prepare_case plan-valid.md config-protected-without-auth.json
expect_failure "protected routes require auth_state or authenticated_e2e_test_files"

prepare_case plan-valid.md config-protected-e2e-valid.json
node "$VALIDATOR" "$CASE/plan" | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-protected-e2e-unmapped.json
expect_failure "is absent from wave 1 regression test_files"

prepare_case plan-valid.md config-readiness-float.json
expect_failure "readiness.timeout_seconds must be a positive integer"

prepare_case plan-narrow-command.md config-regression-repeats-ac.json
expect_failure "duplicates an AC command and test_files set"

prepare_case plan-narrow-command.md config-regression-same-file-broader.json
node "$VALIDATOR" "$CASE/plan" | grep -F "1 wave(s), 1 AC(s)" >/dev/null

for copy in \
  "$ROOT/claude/skills/4_writing-plans/scripts/validate-wave-plan.mjs" \
  "$ROOT/codex/skills/4a_checkpoint/scripts/validate-wave-plan.mjs" \
  "$ROOT/claude/skills/4a_checkpoint/scripts/validate-wave-plan.mjs" \
  "$ROOT/codex/skills/4b_setup/scripts/validate-wave-plan.mjs" \
  "$ROOT/claude/skills/4b_setup/scripts/validate-wave-plan.mjs"
do
  cmp "$VALIDATOR" "$copy"
done

echo "wave-plan validator tests passed"
