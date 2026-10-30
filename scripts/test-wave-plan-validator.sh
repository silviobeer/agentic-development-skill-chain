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
  rm -rf "$CASE/plan" "$CASE/2_PRDs"
  mkdir -p "$CASE/plan"
  cp "$FIXTURES/$plan_fixture" "$CASE/plan/PROJ-1-wave-1-plan.md"
  cp "$FIXTURES/$config_fixture" "$CASE/plan/wave-gate-config.json"
}

run_validator() { node "$VALIDATOR" "$CASE/plan" "$CASE"; }

# The dispatcher accepts a plan directory, never a PROJ-number/theme selector.
for provider in codex claude; do
  rc=0
  (cd "$CASE" && bash "$ROOT/$provider/skills/5_executing/scripts/chain" check plan 6 varianten-finden) >"$CASE/output" 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || { echo "$provider: invalid plan selector returned $rc" >&2; exit 1; }
  grep -qF 'specs/PROJ-<X>-<theme>/3-4_plan' "$CASE/output" || { cat "$CASE/output" >&2; exit 1; }
  grep -qF 'not a PROJ number and theme' "$CASE/output" || { cat "$CASE/output" >&2; exit 1; }
done

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

for expression in '.coverage_cmd="npm run coverage"' '.build_artifacts=[]' '.lint_cmd=42' '.complexity_cmd=""' '.arch_rules_cmd=7' '.mutation_cmd=[]' '.sonar_required="false"' '.sonar_required=null' '.sonar_required=1' '.app_root="/abs"' '.app_root="../up"' '.app_root=3' '.worktree_links=[]' '.worktree_links=[{path:"a",target:"../b"}]' '.worktree_links=[{path:"a"}]' '.resources={test_workers:0}' '.resources={max_parallel_commands:0}' '.resources=false' '.resources=null' '.resources={wait_seconds:-1}' '.resources={bogus:1}' '.resources=[]' '.resources={min_available_mb:"1g"}' '.coderabbit=false' '.coderabbit=null' '.coderabbit="off"' '.coderabbit=[]' '.coderabbit={enabled:"false"}' '.coderabbit={enabled:null}' '.coderabbit={enabled:0}' '.coderabbit={enabled:false,bogus:1}'; do
  prepare_case plan-valid.md config-valid.json
  jq "$expression" "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
  mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
  if run_validator >"$CASE/output" 2>&1; then echo "invalid quality config accepted: $expression" >&2; exit 1; fi
done

prepare_case plan-valid.md config-valid.json
jq '.app_root="app" | .worktree_links=[{path:"p/node_modules",target:"app/node_modules"}]' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator >"$CASE/output" 2>&1 || { cat "$CASE/output" >&2; echo "valid app_root/worktree_links rejected" >&2; exit 1; }

jq '.resources={min_available_mb:2048,max_memory_psi_full_avg10:10,wait_seconds:0,test_workers:2,max_parallel_commands:2}' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator >"$CASE/output" 2>&1 || { cat "$CASE/output" >&2; echo "valid resources rejected" >&2; exit 1; }

for coderabbit in '{}' '{"enabled":true}' '{"enabled":false}'; do
  prepare_case plan-valid.md config-valid.json
  jq --argjson cr "$coderabbit" '.coderabbit=$cr' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
  mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
  run_validator >"$CASE/output" 2>&1 || { cat "$CASE/output" >&2; echo "valid coderabbit switch rejected: $coderabbit" >&2; exit 1; }
done

prepare_case plan-valid.md config-valid.json
jq '.coderabbit={enabled:"no"}' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator >"$CASE/output" 2>&1 && { echo "invalid coderabbit switch accepted" >&2; exit 1; }
grep -F "coderabbit must be an object with an optional boolean 'enabled'" "$CASE/output" >/dev/null || { cat "$CASE/output" >&2; echo "coderabbit switch rejected for the wrong reason" >&2; exit 1; }

for required in true false; do
  prepare_case plan-valid.md config-valid.json
  jq --argjson required "$required" '.sonar_required=$required' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
  mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
  run_validator >/dev/null
done

prepare_case plan-valid.md config-valid.json
jq '.complexity_cmd="npm run complexity" | .arch_rules_cmd="npm run arch" | .mutation_cmd="npm run mutate"' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator >/dev/null

prepare_case plan-valid.md config-valid.json
jq '.waves["1"].ac_commands[0].external_dependency={reason:"review of seed revision abc",decided_by:"owner",decided_at:"2026-09-08T10:00:00Z",check_command:"node check-signoff.mjs"} | .waves["1"].regression_commands[0].selection_check_cmd="node scenarios.mjs --list"' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator >/dev/null
cp "$CASE/plan/wave-gate-config.json" "$CASE/dependency-valid.json"
for expression in 'del(.waves["1"].ac_commands[0].external_dependency.reason)' '.waves["1"].ac_commands[0].external_dependency.decided_by=""' '.waves["1"].ac_commands[0].external_dependency.decided_at="yesterday"' '.waves["1"].ac_commands[0].external_dependency=null' '.waves["1"].ac_commands[0].external_dependency.check_command=""'; do
  jq "$expression" "$CASE/dependency-valid.json" >"$CASE/plan/wave-gate-config.json"
  expect_failure external_dependency
done
jq '.waves["1"].regression_commands[0].selection_check_cmd=false' "$CASE/dependency-valid.json" >"$CASE/plan/wave-gate-config.json"
expect_failure selection_check_cmd
jq 'del(.waves["1"].ac_commands[0].command)' "$CASE/dependency-valid.json" >"$CASE/plan/wave-gate-config.json"
expect_failure "command must be a non-empty string"

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
expect_failure "is absent from wave 1 AC/regression test_files"

prepare_case plan-valid.md config-protected-e2e-valid.json
jq '.frontend.routes[0].authenticated_e2e_test_files=["tests/validator.test.ts"]' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-valid.json
jq '.waves["1"].regression_commands[0].reuse_passed=true' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null
jq '.waves["1"].regression_commands[0].reuse_passed="true"' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "reuse_passed must be boolean when present"
jq '.waves["1"].regression_commands[0] |= (.reuse_passed=true | .auth_consuming=true)' "$CASE/plan/wave-gate-config.json" >"$CASE/config.tmp"
mv "$CASE/config.tmp" "$CASE/plan/wave-gate-config.json"
expect_failure "reuse_passed cannot cache auth-consuming commands"

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

# exported parsers: pure functions on plan text
node --input-type=module -e '
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const { parseStoryTable, parseStories } = await import(process.argv[1]);
const read = (name) => readFileSync(`${process.argv[2]}/${name}`, "utf8");

const rows = parseStoryTable(read("stories-valid.md"));
assert.deepEqual(rows, [
  { id: "`PROJ-1-PRD-1-US-1`", scope: "backend", agentType: "backend-implementer", complexity: "sonnet", canStart: "immediately", line: 7 },
  { id: "PROJ-1-PRD-1-US-2", scope: "full-stack", agentType: "`fullstack-implementer`", complexity: "opus (migration)", canStart: "US-1 merged", line: 8 },
]); // raw cells, fenced row ignored
assert.equal(parseStoryTable(read("plan-valid.md")), null);
const legacy = parseStoryTable(read("stories-duplicate.md"));
assert.deepEqual(legacy.map((row) => [row.id, row.agentType, row.line]), [["PROJ-1-PRD-1-US-1", undefined, 7], ["PROJ-1-PRD-1-US-1", undefined, 8]]);

const [one, two] = parseStories(read("stories-valid.md"));
assert.deepEqual([one.id, one.heading, one.line, one.scope, one.agent, one.split], ["PROJ-1-PRD-1-US-1", "PROJ-1-PRD-1-US-1: One", 14, "backend", "backend-implementer", "none"]);
assert.deepEqual(one.acs, [
  { id: "PROJ-1-PRD-1-US-1-AC-1", text: "single line", line: 19 },
  { id: "PROJ-1-PRD-1-US-1-AC-2", text: "first line\n  continues here\n\n  and ends after a gap", line: 20 },
]); // [x] accepted, multi-line kept, fenced AC ignored
assert.deepEqual([two.scope, two.agent, two.split, two.acs.length], ["full-stack", null, "fan-out", 1]);
const plain = parseStories(read("plan-valid.md"));
assert.deepEqual([plain[0].scope, plain[0].agent, plain[0].split], [null, null, null]);
assert.deepEqual(parseStories(read("stories-duplicate.md")).map((story) => [story.id, story.line]), [["PROJ-1-PRD-1-US-1", 10], ["PROJ-1-PRD-1-US-1", 11]]);
' "file://$(dirname "$VALIDATOR")/document-parser.mjs" "$FIXTURES"

# --stories: role per story from the Agent Type column, fail-closed (exit 2 naming story and plan)
stories_fail() { # fixture expected-message
  if node "$VALIDATOR" --stories "$FIXTURES/$1" >"$CASE/output" 2>&1; then echo "--stories accepted $1" >&2; exit 1; fi
  node "$VALIDATOR" --stories "$FIXTURES/$1" >/dev/null 2>&1 || [ $? -eq 2 ] || { echo "--stories $1: exit must be 2" >&2; exit 1; }
  grep -F "$1: PROJ-1-PRD-1-US-" "$CASE/output" | grep -F "$2" >/dev/null || { echo "--stories $1: expected '$2' with story and plan" >&2; cat "$CASE/output" >&2; exit 1; }
}
stories_fail stories-duplicate-row.md "duplicate row in the story table"
stories_fail stories-row-without-section.md "has no story section"
stories_fail stories-section-without-row.md "story section has no row"
stories_fail stories-unsupported-agent.md "unsupported Agent Type"
stories_fail stories-scope-conflict.md "table Scope 'frontend' contradicts"
stories_fail stories-agent-conflict.md "contradicts the section's **Scope:** agent"
stories_fail stories-split-conflict.md "Split: contract contradicts"
stories_fail stories-split-invalid.md "unsupported **Split:**"
stories_fail stories-duplicate.md "duplicate story section"
printf '# PROJ-1 Wave 1\n\nNo stories.\n' >"$CASE/empty.md"
if node "$VALIDATOR" --stories "$CASE/empty.md" >/dev/null 2>&1 || [ $? -ne 2 ]; then echo "--stories accepted a plan without table and stories" >&2; exit 1; fi
node "$VALIDATOR" --stories "$FIXTURES/stories-aliases.md" | jq -e '
  map([.id, .role, .split, (.fallback // false)]) == [
    ["PROJ-1-PRD-1-US-1", "backend-implementer", "none", false],
    ["PROJ-1-PRD-1-US-2", "implementer", "contract", false],
    ["PROJ-1-PRD-1-US-3", "implementer", "none", false],
    ["PROJ-1-PRD-1-US-4", "implementer", "none", false]]
  and .[1].agentType == "full-stack-implementer" and .[0].scope == "backend (test-only)"' >/dev/null \
  || { echo "--stories alias normalization wrong" >&2; exit 1; }
node "$VALIDATOR" --stories "$FIXTURES/stories-legacy.md" | jq -e '
  map([.id, .role, .split, .fallback]) == [["PROJ-1-PRD-1-US-1", "implementer", "none", true], ["PROJ-1-PRD-1-US-2", "implementer", "contract", true]]' >/dev/null \
  || { echo "--stories legacy fallback wrong" >&2; exit 1; }
stories_fail stories-empty-table.md "story section has no row" # Agent Type header, no rows: not legacy
stories_fail stories-short-row.md "unsupported Agent Type '(missing cell)'"
node "$VALIDATOR" --stories "$FIXTURES/stories-legacy-table.md" | jq -e '
  map([.id, .role, .complexity, .canStart, .fallback]) == [
    ["PROJ-1-PRD-1-US-1", "implementer", "sonnet", "immediately", true],
    ["PROJ-1-PRD-1-US-2", "implementer", null, null, true]]' >/dev/null \
  || { echo "--stories legacy table must keep Complexity/Can start when" >&2; exit 1; }
stories_fail stories-ascii-arrow.md "contradicts the section's **Scope:** agent 'frontend-implementer'"
node --input-type=module -e '
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const { parseStories } = await import(process.argv[1]);
const [story] = parseStories(readFileSync(process.argv[2], "utf8"));
assert.deepEqual([story.scope, story.agent], ["full-stack", "frontend-implementer"]); // ASCII arrow splits like →
' "file://$(dirname "$VALIDATOR")/document-parser.mjs" "$FIXTURES/stories-ascii-arrow.md"
node "$VALIDATOR" --stories "$FIXTURES/stories-agent-trailing.md" | jq -e 'map(.role) == ["implementer", "frontend-implementer", "backend-implementer"]' >/dev/null \
  || { echo "--stories: prose after the section agent (or no role token) must not be compared" >&2; exit 1; }
node "$VALIDATOR" --stories "$FIXTURES/stories-valid.md" | jq -e 'map(.role) == ["backend-implementer", "implementer"] and .[1].split == "fan-out"' >/dev/null \
  || { echo "--stories valid fixture wrong" >&2; exit 1; }

# AC wording, plan against ../2_PRDs (byte-exact after the checkbox/ID prefix)
PLAN="$CASE/plan/PROJ-1-wave-1-plan.md"
PRD="$CASE/2_PRDs/PROJ-1-PRD-1-wording.md"
prepare_prd() { prepare_case plan-valid.md config-valid.json; mkdir -p "$CASE/2_PRDs"; cp "$FIXTURES/prd-wording.md" "$PRD"; }
expect_output() { for text in "$@"; do grep -F -- "$text" "$CASE/output" >/dev/null || { echo "missing in output: $text" >&2; cat "$CASE/output" >&2; exit 1; }; done; }

prepare_prd # same wording; PRD checkbox [x] vs plan [ ] is prefix, not wording
run_validator >"$CASE/output" 2>&1
expect_output "1 wave(s), 1 AC(s)"
if grep -F "note:" "$CASE/output" >/dev/null; then echo "2_PRDs present but wording check skipped" >&2; exit 1; fi

prepare_prd # changed wording: ID, both texts, both paths
sed -i 's/AC-1: The plan is validated\./AC-1: The plan is checked./' "$PRD"
expect_failure "PROJ-1-PRD-1-US-1-AC-1: plan wording differs from the PRD"
expect_output "plan $PLAN:6: \"The plan is validated.\"" "PRD  $PRD:13: \"The plan is checked.\""

prepare_prd # AC without PRD entry; the QA section's AC-1 does not count
sed -i '0,/AC-1:/s//AC-3:/' "$PRD"
expect_failure "PROJ-1-PRD-1-US-1-AC-1: no PRD entry (AC-1 under US-1)"
expect_output "PRD  $PRD: (missing)"
rm "$PRD"
expect_failure "no PRD entry, expected one $CASE/2_PRDs/PROJ-1-PRD-1-*.md (titled # PROJ-1-PRD-1 if several), found 0"

prepare_prd # multi-line AC: continuation up to the next heading/bold line, wrapping is wording
sed -i 's/AC-1: The plan is validated\./AC-1: The plan\n  is validated./' "$PLAN" "$PRD"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null
sed -i 's/^- \[x\] AC-1: The plan$/- [x] AC-1: The plan is/; s/^  is validated\.$/  validated./' "$PRD"
expect_failure "plan wording differs"
expect_output '"The plan\n  is validated."' '"The plan is\n  validated."'

continue_ac() { # snippet-file files...: insert the snippet after the AC-1 line
  local snippet="$1"; shift
  sed -i "/AC-1: The plan is validated\.\$/r $snippet" "$@"
}
printf '**Fett** stays part of the AC\n  and so does this line.\n' >"$CASE/bold.txt"
prepare_prd # a bold (non-label) line continues the AC: a change after it is wording
continue_ac "$CASE/bold.txt" "$PLAN" "$PRD"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null
sed -i 's/and so does this line\./and so does that line./' "$PRD"
expect_failure "plan wording differs"
printf '  ```\n  code line\n  ```\n' >"$CASE/indented-fence.txt"
prepare_prd # a fence indented into the list item is AC text
continue_ac "$CASE/indented-fence.txt" "$PLAN" "$PRD"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null
sed -i 's/^  code line$/  other line/' "$PRD"
expect_failure "plan wording differs"
printf '**Smoke Test:** not AC text\n' >"$CASE/label.txt"
printf '```\nnot AC text\n```\n' >"$CASE/fence.txt"
for snippet in label fence; do # a **Label:** line and an unindented fence still end the AC
  prepare_prd
  continue_ac "$CASE/$snippet.txt" "$PRD"
  run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null || { echo "$snippet must end the AC" >&2; exit 1; }
done

prepare_prd # trailing whitespace on the first AC line is not wording
sed -i 's/AC-1: The plan is validated\.$/&  /' "$PLAN"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_prd # PRD file choice: 2c's review-decisions never counts, several candidates resolve by first H1
printf '# PROJ-1-PRD-1 Review Decisions\n\n### US-1: x\n- [ ] AC-1: Other.\n' >"$CASE/2_PRDs/PROJ-1-PRD-1-wording-review-decisions.md"
printf '# Notes\n\n# PROJ-1-PRD-1: not the first H1\n' >"$CASE/2_PRDs/PROJ-1-PRD-1-notes.md"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null
sed 's/^# PROJ-1-PRD-1:/# PROJ-1 PRD-1 —/' "$PRD" >"$CASE/2_PRDs/PROJ-1-PRD-1-copy.md"
expect_failure "no PRD entry, expected one $CASE/2_PRDs/PROJ-1-PRD-1-*.md (titled # PROJ-1-PRD-1 if several), found 2"

prepare_prd # AC IDs with a hyphenated suffix map like the parsers read them
sed -i 's/US-1-AC-1/US-1-AC-1-a/g' "$PLAN" "$CASE/plan/wave-gate-config.json"
expect_failure "PROJ-1-PRD-1-US-1-AC-1-a: no PRD entry (AC-1-a under US-1)"
sed -i 's/AC-1: The plan/AC-1-a: The plan/' "$PRD"
run_validator | grep -F "1 wave(s), 1 AC(s)" >/dev/null

prepare_case plan-valid.md config-valid.json # 2_PRDs as a file: note like a missing directory
touch "$CASE/2_PRDs"
run_validator >"$CASE/output" 2>&1
expect_output "1 wave(s), 1 AC(s)" "note: AC wording not compared against PRDs: $CASE/2_PRDs is not a directory"

prepare_case plan-valid.md config-valid.json # no 2_PRDs/ (legacy): note, exit 0
run_validator >"$CASE/output" 2>&1
expect_output "1 wave(s), 1 AC(s)" "note: AC wording not compared against PRDs: $CASE/2_PRDs is not a directory"

for copy in "$ROOT/claude/skills/4_writing-plans/scripts/validate-wave-plan.mjs"; do
  cmp "$VALIDATOR" "$copy"
done

echo "wave-plan validator tests passed"
