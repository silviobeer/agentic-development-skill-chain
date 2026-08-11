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

run_validator() { node "$VALIDATOR" "$CASE/plan" "$CASE"; }

expect_failure() {
  local expected="$1"
  if run_validator >"$CASE/output" 2>&1; then
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
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-valid.json
sed -i 's|npm test -- tests/validator.test.ts|npm test -- tests/validator.test.ts \&\& npx playwright test -g validator|' "$CASE/plan/PROJ-1-wave-1-plan.md"
jq '.waves["1"].ac_commands[0].command="npm test -- tests/validator.test.ts && npx playwright test -g validator"' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "must invoke exactly one test runner; split shell-chained commands"

prepare_case plan-valid.md config-valid.json
jq '.waves["1"].regression_commands[0].command="npm test -- tests && npx playwright test"' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "must invoke exactly one test runner; split shell-chained commands"

prepare_case plan-valid.md config-valid.json
jq '.waves["1"].ac_commands=["npm test -- tests/validator.test.ts"]' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "legacy string entries are unsupported; replace each with {id, task, command, test_files, auth_consuming}"

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
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-protected-e2e-unmapped.json
expect_failure "is absent from wave 1 regression test_files"

prepare_case plan-valid.md config-readiness-float.json
expect_failure "readiness.timeout_seconds must be a positive integer"

prepare_case plan-narrow-command.md config-regression-repeats-ac.json
expect_failure "duplicates an AC command and test_files set"

prepare_case plan-narrow-command.md config-regression-same-file-broader.json
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-valid.json
jq '.auth_budget={"preflight_cmd":"true","exhausted_exit_code":75,"rate_limit_evidence_cmd":"true"} | .waves["1"].ac_commands[0].auth_consuming=true' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "wave_required_reason must explain why hosted auth is needed before CI"

prepare_case plan-valid.md config-valid.json
jq '.phase_commands=[{"label":"hosted browser regression","phase":"nightly","command":"npm run test:e2e","test_files":["e2e/auth.spec.ts"],"auth_consuming":true}]' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "nightly phase command requires workflow_file"

prepare_case plan-valid.md config-valid.json
mkdir -p "$CASE/.github/workflows"
printf 'run: npm run test:e2e\n' >"$CASE/.github/workflows/e2e.yml"
jq '.phase_commands=[{"label":"assembled regression","phase":"quality","command":"npm test","test_files":["tests/validator.test.ts"],"auth_consuming":false},{"label":"hosted browser regression","phase":"nightly","command":"npm run test:e2e","test_files":["e2e/auth.spec.ts"],"auth_consuming":true,"workflow_file":".github/workflows/e2e.yml"}]' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

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
