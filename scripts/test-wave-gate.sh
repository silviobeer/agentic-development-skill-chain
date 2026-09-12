#!/usr/bin/env bash
# Deterministic end-to-end controls for both platform wave-gate variants.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() { set +e; "$@" >"$GATE_OUT" 2>&1; local rc=$?; set -e; [[ "$rc" -ne 0 ]] || fail "$LABEL: expected failure"; }
expect_rc() { local expected="$1"; shift; set +e; "$@" >"$GATE_OUT" 2>&1; local rc=$?; set -e; [[ "$rc" -eq "$expected" ]] || fail "$LABEL: got rc=$rc, expected $expected"; }

case_dir() {
  local name="$1"
  CASE="$TMP/$PLATFORM-$name"; LABEL="$PLATFORM/$name"; CASE_LOG="$TMP/$PLATFORM-$name-counter"; GATE_OUT="$TMP/$PLATFORM-$name.out"
  mkdir -p "$CASE/specs/PROJ-1-test/3-4_plan" "$CASE/specs/PROJ-1-test/5_progress" "$CASE/bin" "$CASE/scripts"
  printf '# Progress\n' >"$CASE/specs/PROJ-1-test/5_progress/PROJ-1-progress.md"
  printf '%s\n' '#!/usr/bin/env bash' '[[ -z "${CR_CALL_LOG:-}" ]] || printf "called\n" >>"$CR_CALL_LOG"' '[[ -z "${CR_FIXTURE:-}" ]] || command cat "$CR_FIXTURE"' 'exit "${CR_RC:-0}"' >"$CASE/bin/coderabbit"
  printf '%s\n' '#!/usr/bin/env bash' \
    '[[ -z "${BROWSER_CALL_LOG:-}" ]] || printf "called\n" >>"$BROWSER_CALL_LOG"' \
    'while [[ "${1:-}" == --* ]]; do case "$1" in --session) SESSION="$2"; shift 2;; --state) [[ -f "$2" ]] || exit 9; shift 2;; *) shift;; esac; done' \
    'STATE="${BROWSER_STATE_DIR:?}/${SESSION:-default}"; cmd="${1:-}"; shift || true' \
    '[[ "$cmd" != "${BROWSER_STALL_COMMAND:-}" ]] || sleep 3' \
    'case "$cmd" in open) printf "%s\n" "${BROWSER_FINAL_URL:-$1}" >"$STATE";; get) [[ "${1:-}" == url ]] && command cat "$STATE";; snapshot) printf "%s\n" "${BROWSER_TEXT:-Welcome}";; errors) exit 0;; close) rm -f "$STATE";; *) exit 2;; esac' >"$CASE/bin/agent-browser"
  printf '%s\n' '#!/usr/bin/env bash' '[[ "${CURL_ALWAYS_READY:-1}" == 1 || -f "${READY_FILE:-/nonexistent}" ]]' >"$CASE/bin/curl"
  printf '%s\n' '#!/usr/bin/env bash' \
    '[[ "${1:-}" == with-shared-lock ]] || exit 64' \
    'shift; [[ "${1:-}" == -- ]] || exit 64; shift' \
    '[[ -z "${WORKTREE_LOCK_LOG:-}" ]] || printf "locked\n" >>"$WORKTREE_LOCK_LOG"' \
    'exec "$@"' >"$CASE/scripts/worktree.sh"
  chmod +x "$CASE/bin/coderabbit" "$CASE/bin/agent-browser" "$CASE/bin/curl" "$CASE/scripts/worktree.sh"
  printf '.scannerwork/\n' >"$CASE/.gitignore"
  git -C "$CASE" init -q
  git -C "$CASE" config user.email test@example.invalid
  git -C "$CASE" config user.name test
  mkdir -p "$TMP/$PLATFORM-browser"; BROWSER_STATE_DIR="$TMP/$PLATFORM-browser"; export BROWSER_STATE_DIR CASE_LOG
}

default_config() {
  printf '%s' '{"build_cmd":"true","sonar_cmd":"mkdir -p .scannerwork && date +%s > .scannerwork/report-task.txt","timeouts":{"ac_seconds":5,"build_seconds":5,"coderabbit_seconds":5,"browser_seconds":5,"sonar_seconds":5},"waves":{"1":{"advisory_severities":[],"ac_commands":[{"id":"AC-1","task":"T-1","command":"printf '\''Running 1 test\\n1 passed\\n'\''; printf x >> \"$CASE_LOG\"","test_files":["tests/ac.test.ts"],"auth_consuming":false}],"regression_commands":[{"label":"broad","command":"printf '\''Running 2 tests\\n2 passed\\n'\''","test_files":["tests/regression.test.ts"],"auth_consuming":false,"require_non_empty_selection":true}]}}}'
}

write_config() { printf '%s\n' "$1" >"$CASE/specs/PROJ-1-test/3-4_plan/wave-gate-config.json"; }
commit_case() { git -C "$CASE" add .; git -C "$CASE" commit -qm fixture; git -C "$CASE" tag -f wave-1-start-PROJ-1 >/dev/null; }
run_gate() { (cd "$CASE" && PATH="$CASE/bin:$PATH" bash "$GATE" 1 1 test); }
ac_only_gate() { (cd "$CASE" && PATH="$CASE/bin:$PATH" bash "$GATE" --ac-only 1 1 test); }
status_gate() { (cd "$CASE" && PATH="$CASE/bin:$PATH" bash "$GATE" --status 1 1 test); }
auth_control_gate() { (cd "$CASE" && PATH="$CASE/bin:$PATH" bash "$GATE" --auth-budget-negative-control 1 1 test); }

run_suite() {
  GATE="$1"; PLATFORM="$2"

  case_dir wrapped-lock-timeout
  write_config "$(default_config | jq '.waves["1"].ac_commands[0].command="echo SKILLCHAIN_LOCK_TIMEOUT pid=123 waited_seconds=1 path=/test-lock >&2; exit 1"')"; commit_case
  expect_rc 73 ac_only_gate
  jq -e '.ralph_status=="infrastructure_failed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: lock contention counted as failed AC"
  case_dir lock-wait-is-not-timeout
  write_config "$(default_config | jq '.waves["1"].ac_commands[0].command="echo SKILLCHAIN_LOCK_WAIT pid=123 >&2; echo SKILLCHAIN_LOCK_ACQUIRED pid=123 >&2; exit 1"')"; commit_case
  expect_rc 1 ac_only_gate
  jq -e '.commands[0].status=="failed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: earlier contention concealed a test failure"

  case_dir external-dependency
  mkdir -p "$CASE/tests"
  printf '// retained acceptance test\n' >"$CASE/tests/ac.test.ts"
  config=$(default_config | jq '.waves["1"].ac_commands[0].external_dependency={reason:"specialist sign-off of revision abc",decided_by:"product owner",decided_at:"2026-09-08T10:00:00Z",check_command:"exit 76"} | .waves["1"].ac_commands += [(.waves["1"].ac_commands[0] | .id="AC-2" | del(.external_dependency))]')
  write_config "$config"; commit_case
  expect_rc 76 ac_only_gate
  jq -e '.ralph_status=="blocked_external" and .commands[0].status=="blocked_external" and .commands[1].status=="passed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: missing blocked/independent evidence"
  [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: blocked test ran or independent AC was skipped"
  expect_rc 76 run_gate
  ! grep -q 'Gate — PASSED' "$CASE/specs/PROJ-1-test/5_progress/PROJ-1-progress.md" || fail "$LABEL: blocked wave certified"
  (cd "$CASE" && bash "$ROOT/$PLATFORM/skills/4b_setup/scripts/state.sh" init 1 test >/dev/null)
  (cd "$CASE" && node "$ROOT/$PLATFORM/skills/8_delivery/scripts/render-pr-body.mjs" 1 test) >"$TMP/$PLATFORM-pr-body"
  (cd "$CASE" && node "$ROOT/runner/render-report.mjs" stop 1 test --reason "external prerequisite") >/dev/null
  (cd "$CASE" && node "$ROOT/runner/render-report.mjs" morning) >/dev/null
  for report in "$TMP/$PLATFORM-pr-body" "$CASE/specs/PROJ-1-test/5_progress/stop-report.md" "$CASE"/specs/morning-report-*.md; do
    grep -q 'specialist sign-off of revision abc' "$report" || fail "$LABEL: prerequisite missing from $report"
    grep -q 'product owner at 2026-09-08T10:00:00Z' "$report" || fail "$LABEL: decision metadata missing from $report"
  done
  write_config "$(printf '%s' "$config" | jq '.waves["1"].ac_commands[0].external_dependency.check_command="true"')"; commit_case
  ac_only_gate >"$GATE_OUT" 2>&1 || fail "$LABEL: readiness did not restore original test"
  jq -e 'all(.commands[]; .status=="passed")' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: stale blocked status"
  write_config "$(printf '%s' "$config" | jq '.waves["1"].ac_commands[0].external_dependency.check_command="exit 2"')"; commit_case
  expect_rc 74 ac_only_gate

  case_dir selection-preflight
  config=$(default_config | jq '.waves["1"].regression_commands[0].selection_check_cmd="printf '\''Running 0 tests\\n'\''"')
  write_config "$config"; commit_case
  expect_fail ac_only_gate
  [[ ! -e "$CASE_LOG" ]] || fail "$LABEL: expensive AC ran before empty selection detected"
  grep -q '0/6' "$GATE_OUT" || fail "$LABEL: missing early diagnostic"
  write_config "$(printf '%s' "$config" | jq '.waves["1"].regression_commands[0].selection_check_cmd="exit 2"')"; commit_case
  expect_fail ac_only_gate
  grep -q 'scenario selection preflight failed for broad rc=2 (log:' "$GATE_OUT" || fail "$LABEL: checker failure diagnostic lost"
  [[ ! -e "$CASE_LOG" ]] || fail "$LABEL: AC ran after discovery error"
  write_config "$(printf '%s' "$config" | jq '.waves["1"].regression_commands[0].selection_check_cmd="printf '\''Running 2 tests\\n'\''"')"; commit_case
  ac_only_gate >"$GATE_OUT" 2>&1 || fail "$LABEL: positive selection rejected"

  case_dir test-size-warning
  mkdir -p "$CASE/tests"
  awk 'BEGIN {for (i=0; i<801; i++) print "// test fixture"}' >"$CASE/tests/ac.test.ts"
  write_config "$(default_config)"; commit_case
  ac_only_gate >"$GATE_OUT" 2>&1 || fail "$LABEL: size warning blocked gate"
  grep -q '801 lines (>800)' "$GATE_OUT" || fail "$LABEL: oversized file was silent"

  case_dir parallel-build-review
  PARALLEL_DIR="$TMP/$PLATFORM-parallel-markers"; export PARALLEL_DIR
  mkdir -p "$PARALLEL_DIR"
  cat >"$CASE/build.sh" <<'EOF'
#!/usr/bin/env bash
touch "$PARALLEL_DIR/build-started"
for ((i=0; i<100; i++)); do
  if [[ -f "$PARALLEL_DIR/review-started" ]]; then echo build-output; exit 0; fi
  sleep .02
done
echo 'review did not overlap build' >&2
exit 9
EOF
  cat >"$CASE/bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
touch "$PARALLEL_DIR/review-started"
[[ -f "$PARALLEL_DIR/build-started" ]] || sleep .1
[[ -f "$PARALLEL_DIR/build-started" ]] || exit 9
echo review-diagnostic >&2
EOF
  write_config "$(default_config | jq '.build_cmd="bash build.sh"')"; commit_case
  run_gate >"$GATE_OUT" 2>&1 || { cat "$GATE_OUT"; fail "$LABEL: build/review did not overlap"; }
  grep -q build-output "$CASE/specs/PROJ-1-test/5_progress/build-wave-1-attempt-1.log" || fail "$LABEL: build output not retained"
  grep -q review-diagnostic "$CASE/specs/PROJ-1-test/5_progress/coderabbit-wave-1-attempt-1.stderr.log" || fail "$LABEL: review stderr not separate"
  unset PARALLEL_DIR

  case_dir final-wave-build-reuse
  printf 'out/\n' >>"$CASE/.gitignore"
  config=$(default_config | jq '.build_cmd="mkdir -p out; echo output > out/build" | .build_artifacts=["out"]')
  write_config "$config"; commit_case; run_gate >"$GATE_OUT" 2>&1
  (cd "$CASE" && PATH="$CASE/bin:$PATH" node "$ROOT/$PLATFORM/skills/5_executing/scripts/quality-evidence.mjs" 1 test run build) >"$GATE_OUT" 2>&1
  grep -q 'reused build' "$GATE_OUT" || fail "$LABEL: PROJ gate did not reuse valid wave build"

  for failure in build-failure review-failure build-timeout review-timeout; do
    case_dir "parallel-$failure"
    PARALLEL_DIR="$TMP/$PLATFORM-$failure-markers"; export PARALLEL_DIR
    BROWSER_CALL_LOG="$PARALLEL_DIR/browser"; export BROWSER_CALL_LOG
    mkdir -p "$PARALLEL_DIR"
    build='sleep .1; touch "$PARALLEL_DIR/build-done"'
    review='sleep .1; touch "$PARALLEL_DIR/review-done"'
    case "$failure" in
      build-failure) build='exit 7' ;;
      review-failure) review='exit 8' ;;
      build-timeout) build='sleep 20' ;;
      review-timeout) review='sleep 20' ;;
    esac
    printf '#!/usr/bin/env bash\n%s\n' "$review" >"$CASE/bin/coderabbit"
    config=$(default_config | jq --arg build "$build" '.build_cmd=$build | .timeouts.build_seconds=1 | .timeouts.coderabbit_seconds=1 | .waves["1"].frontend_routes=["/"]')
    write_config "$config"; commit_case; expect_fail run_gate
    [[ -e "$BROWSER_CALL_LOG" ]] || fail "$LABEL: smoke did not run before build/review"
    ! grep -q "Gate — PASSED" "$CASE/specs/PROJ-1-test/5_progress/PROJ-1-progress.md" || fail "$LABEL: wave certified after parallel failure"
    case "$failure" in
      build-*) [[ -f "$PARALLEL_DIR/review-done" ]] || fail "$LABEL: review was not collected"; grep -q 'build .*\(exit 7\|timed out\)' "$GATE_OUT" || fail "$LABEL: build failure lost" ;;
      review-*) [[ -f "$PARALLEL_DIR/build-done" ]] || fail "$LABEL: build was not collected"; grep -q 'CodeRabbit .*\(rc=8\|timed out\)' "$GATE_OUT" || fail "$LABEL: review failure lost" ;;
    esac
    unset PARALLEL_DIR BROWSER_CALL_LOG
  done

  case_dir parallel-interrupt
  PARALLEL_DIR="$TMP/$PLATFORM-interrupt-markers"; export PARALLEL_DIR
  mkdir -p "$PARALLEL_DIR"
  cat >"$CASE/bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
sleep 30 & echo $! >"$PARALLEL_DIR/review-child"
wait
EOF
  write_config "$(default_config | jq '.build_cmd="sleep 30 & echo $! >\"$PARALLEL_DIR/build-child\"; wait"')"; commit_case
  (cd "$CASE" && exec env PATH="$CASE/bin:$PATH" bash "$GATE" 1 1 test) >"$GATE_OUT" 2>&1 & gate_pid=$!
  for ((i=0; i<100; i++)); do
    [[ ! -s "$PARALLEL_DIR/build-child" || ! -s "$PARALLEL_DIR/review-child" ]] || break
    sleep .05
  done
  kill -TERM "$gate_pid" 2>/dev/null || true
  interrupt_rc=0; wait "$gate_pid" || interrupt_rc=$?
  [[ "$interrupt_rc" -eq 143 ]] || fail "$LABEL: interruption exit status lost ($interrupt_rc)"
  for child in build-child review-child; do
    [[ -s "$PARALLEL_DIR/$child" ]] || fail "$LABEL: both commands did not start"
    child_pid=$(cat "$PARALLEL_DIR/$child")
    if ps -p "$child_pid" -o stat= | grep -q '^[[:space:]]*[^Z[:space:]]'; then fail "$LABEL: command descendant $child_pid survived interruption"; fi
  done
  unset PARALLEL_DIR

  case_dir ac-only-cache-handoff
  REST_LOG="$TMP/$PLATFORM-ac-only-rest" CR_CALL_LOG="$TMP/$PLATFORM-ac-only-coderabbit" BROWSER_CALL_LOG="$TMP/$PLATFORM-ac-only-browser"
  export REST_LOG CR_CALL_LOG BROWSER_CALL_LOG
  config=$(default_config | jq '
    .auth_budget={"preflight_cmd":"true","exhausted_exit_code":75}
    | .waves["1"].ac_commands[0].auth_consuming=true
    | .waves["1"].regression_commands[0].command="printf R >> \"$REST_LOG\"; printf \"Running 2 tests\\n2 passed\\n\""
    | .build_cmd="printf B >> \"$REST_LOG\""
    | .frontend={"dev_url":"http://app.test","dev_cmd":"true","readiness":{"path":"/ready","timeout_seconds":2,"interval_seconds":1},"routes":[{"wave":1,"path":"/","expected_url":"/","expected_text":"Welcome","protected":false}]}
  ')
  write_config "$config"; commit_case
  ac_only_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: AC-only did not execute the AC exactly once"
  [[ ! -e "$REST_LOG" && ! -e "$CR_CALL_LOG" && ! -e "$BROWSER_CALL_LOG" ]] || fail "$LABEL: AC-only executed a later gate phase"
  jq -e --arg head "$(git -C "$CASE" rev-parse HEAD)" '.ralph_status=="complete" and (.commands[0] | .id=="AC-1" and .verified_head==$head and .status=="passed")' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: AC-only did not persist canonical current-HEAD evidence"
  run_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: full gate repeated the same-HEAD auth-consuming AC"
  [[ $(cat "$REST_LOG") == RB ]] || fail "$LABEL: full gate did not execute regression and build after AC-only"
  [[ -s "$CR_CALL_LOG" && -s "$BROWSER_CALL_LOG" ]] || fail "$LABEL: full gate did not execute CodeRabbit and browser after AC-only"
  unset REST_LOG CR_CALL_LOG BROWSER_CALL_LOG

  case_dir identical-ac-command
  config=$(default_config | jq '.waves["1"].ac_commands += [(.waves["1"].ac_commands[0] | .id="AC-2" | .task="T-2")]')
  write_config "$config"; commit_case; ac_only_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: identical AC command executed twice"
  jq -e '(.commands | length)==2 and all(.commands[]; .status=="passed" and .selected==1) and .commands[0].log==.commands[1].log' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: reused command lost per-AC evidence"

  for failure in 'exit 2' 'true' 'sleep 10'; do
    case_dir "shared-failure-${failure// /-}"
    config=$(default_config | jq --arg failure "$failure" '.timeouts.ac_seconds=1 | .waves["1"].ac_commands[0].command=("printf x >> \"$CASE_LOG\"; " + $failure) | .waves["1"].ac_commands += [(.waves["1"].ac_commands[0] | .id="AC-2")]')
    write_config "$config"; commit_case
    expect_fail ac_only_gate
    [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: shared failing command repeated in one pass"
    jq -e '(.commands|length)==2 and .commands[0].log==.commands[1].log' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: missing per-AC failure evidence"
    expect_fail ac_only_gate
    [[ $(wc -c <"$CASE_LOG") -eq 2 ]] || fail "$LABEL: failure incorrectly reused across passes"
  done

  case_dir regression-reuse
  REST_LOG="$TMP/$PLATFORM-regression-reuse-rest"; export REST_LOG
  config=$(default_config | jq '.waves["1"].regression_commands[0] += {reuse_passed:true,command:"printf R >> \"$REST_LOG\"; printf \"Running 2 tests\\n2 passed\\n\""}')
  write_config "$config"; commit_case; run_gate >/dev/null; run_gate >/dev/null
  [[ $(cat "$REST_LOG") == R ]] || fail "$LABEL: deterministic regression repeated"
  jq '.regressions[0].config_hash="stale"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >"$CASE/ralph.tmp"
  mv "$CASE/ralph.tmp" "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json"
  run_gate >/dev/null
  [[ $(cat "$REST_LOG") == RR ]] || fail "$LABEL: stale configuration reused regression evidence"
  git -C "$CASE" commit --allow-empty -qm changed-head
  run_gate >/dev/null
  [[ $(cat "$REST_LOG") == RRR ]] || fail "$LABEL: new HEAD reused regression evidence"
  unset REST_LOG

  case_dir ac-context-mismatch
  config=$(default_config | jq '.auth_budget={preflight_cmd:"true"} | .waves["1"].ac_commands += [(.waves["1"].ac_commands[0] | .id="AC-2" | .test_files=["tests/other.ts"]), (.waves["1"].ac_commands[0] | .id="AC-3" | .auth_consuming=true)]')
  write_config "$config"; commit_case; ac_only_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 3 ]] || fail "$LABEL: AC command reused across different files/auth context"

  case_dir regression-reuse-auth-rejected
  config=$(default_config | jq '.waves["1"].regression_commands[0] += {reuse_passed:true,auth_consuming:true}')
  write_config "$config"; commit_case; expect_fail run_gate
  grep -q 'reuse_passed requires a non-auth deterministic command' "$GATE_OUT" || fail "$LABEL: auth regression reuse was accepted"

  case_dir ac-only-collects-failures
  config=$(default_config | jq '.waves["1"].ac_commands=[
    {"id":"AC-1","task":"T-1","command":"printf a >> \"$CASE_LOG\"; printf \"Running 1 test\\n\"; exit 2","test_files":["tests/a.ts"],"auth_consuming":false},
    {"id":"AC-2","task":"T-2","command":"printf b >> \"$CASE_LOG\"; printf \"Running 1 test\\n\"; exit 3","test_files":["tests/b.ts"],"auth_consuming":false}
  ]')
  write_config "$config"; commit_case; expect_fail ac_only_gate
  [[ $(cat "$CASE_LOG") == ab ]] || fail "$LABEL: AC-only did not execute both ordinary failing ACs"
  jq -e '.ralph_status=="failed" and (.commands | length)==2 and all(.commands[]; .status=="failed")' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: AC-only did not retain both ordinary failure records"

  case_dir full-gate-fails-fast
  write_config "$config"; commit_case; expect_fail run_gate
  [[ $(cat "$CASE_LOG") == a ]] || fail "$LABEL: full gate no longer fails fast on its first ordinary AC failure"

  case_dir cache
  write_config "$(default_config)"; commit_case
  run_gate >/dev/null; run_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: unchanged AC cache was not reused"
  jq -e '.commands[0] | (.id=="AC-1" and (.command|contains("CASE_LOG")))' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: structured AC evidence missing"
  jq -e --arg head "$(git -C "$CASE" rev-parse HEAD)" '.commands[0] | .verified_head==$head and .selected==1 and .failed_empty_selection==false' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: verified_head/selection missing"

  case_dir command-mismatch
  write_config "$(default_config)"; commit_case
  head=$(git -C "$CASE" rev-parse HEAD)
  printf '%s\n' "{\"version\":2,\"wave\":\"1\",\"ralph_status\":\"complete\",\"commands\":[{\"index\":0,\"id\":\"AC-1\",\"command\":\"old command\",\"verified_head\":\"$head\",\"status\":\"passed\",\"rc\":0,\"selected\":1}]}" >"$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json"
  run_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 1 ]] || fail "$LABEL: same-HEAD stale command was reused by index"

  # A type-confused selected count must not satisfy the cache predicate.
  jq '.commands[0].selected="1"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >"$CASE/ralph.tmp"
  mv "$CASE/ralph.tmp" "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json"
  run_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 2 ]] || fail "$LABEL: string selected count was accepted as cache evidence"

  # A changed command at a new commit cannot reuse the old index result.
  jq '.waves["1"].ac_commands[0].command += "; printf y >> \"$CASE_LOG\""' "$CASE/specs/PROJ-1-test/3-4_plan/wave-gate-config.json" >"$CASE/config.tmp"
  mv "$CASE/config.tmp" "$CASE/specs/PROJ-1-test/3-4_plan/wave-gate-config.json"
  git -C "$CASE" add specs/PROJ-1-test/3-4_plan/wave-gate-config.json; git -C "$CASE" commit -qm changed-command
  run_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 4 ]] || fail "$LABEL: changed command was skipped"

  # An identical command at a different committed HEAD must also rerun.
  git -C "$CASE" commit --allow-empty -qm changed-head
  run_gate >/dev/null
  [[ $(wc -c <"$CASE_LOG") -eq 6 ]] || fail "$LABEL: new HEAD reused stale AC evidence"

  case_dir dirty
  write_config "$(default_config)"; commit_case; mkdir -p "$CASE/src"; printf dirty >"$CASE/src/uncommitted.ts"
  expect_fail run_gate; grep -q 'commit them before certification' "$GATE_OUT" || fail "$LABEL: dirty-tree failure was unclear"

  case_dir head-changed-by-build
  config=$(default_config | jq '.build_cmd="git commit --allow-empty -m slipped-head >/dev/null"')
  write_config "$config"; commit_case; expect_fail run_gate
  grep -q 'HEAD changed during gate verification' "$GATE_OUT" || fail "$LABEL: gate certified a commit created during build"

  case_dir sonar-not-run-by-wave-gate
  SONAR_CWD_LOG="$TMP/$PLATFORM-sonar-cwd"; export SONAR_CWD_LOG
  config=$(default_config | jq 'del(.sonar_cmd) | del(.timeouts.sonar_seconds)')
  write_config "$config"; commit_case; run_gate >/dev/null
  [[ ! -e "$SONAR_CWD_LOG" ]] || fail "$LABEL: wave gate must not run any sonar_cmd — that is PROJ-end only"
  unset SONAR_CWD_LOG

  case_dir regression-empty
  config=$(default_config | jq '.waves["1"].regression_commands[0].command="printf '\''Running 0 tests\\n'\''"')
  write_config "$config"; commit_case; expect_fail run_gate
  jq -e '.regressions[0].failed_empty_selection==true and .regressions[0].selected==0' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: empty regression selection was not evidenced"

  case_dir ac-empty
  config=$(default_config | jq '.waves["1"].ac_commands[0].command="printf '\''Running 0 tests\\n'\''"')
  write_config "$config"; commit_case; expect_fail run_gate
  jq -e '.commands[0].failed_empty_selection==true and .commands[0].selected==0' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: empty AC selection was not evidenced"

  case_dir loose-rate-limit
  config=$(default_config | jq '.waves["1"].ac_commands[0].command="printf '\''a test is rate limited server-side\\n'\''; exit 1"')
  write_config "$config"; commit_case; expect_fail run_gate
  jq -e '.commands[0].attempts==1 and .commands[0].status=="failed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: loose rate-limit text was retried"

  case_dir provider-rate-limit
  RETRY_FILE="$TMP/$PLATFORM-retry"; export RETRY_FILE
  config=$(default_config | jq '.rate_limit_backoff_seconds=0 | .waves["1"].ac_commands[0].command="if [[ ! -f \"$RETRY_FILE\" ]]; then touch \"$RETRY_FILE\"; printf over_request_rate_limit; exit 1; fi; printf '\''Running 1 test\\n1 passed\\n'\''"')
  write_config "$config"; commit_case; run_gate >/dev/null
  jq -e '.commands[0].attempts==2 and .commands[0].status=="passed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: exact provider rate limit did not retry once"
  unset RETRY_FILE

  # Browser output can hide the provider 429 in a separate server log. The
  # configured evidence command must make that failure pause and retry too.
  case_dir browser-provider-rate-limit
  RETRY_FILE="$TMP/$PLATFORM-browser-retry"; RATE_LIMIT_EVIDENCE_FILE="$TMP/$PLATFORM-server.log"; export RETRY_FILE RATE_LIMIT_EVIDENCE_FILE
  printf "status: 429, message: 'Request rate limit reached', type: 'signup'\n" >"$RATE_LIMIT_EVIDENCE_FILE"
  config=$(default_config | jq '.rate_limit_backoff_seconds=1 | .auth_budget={"preflight_cmd":"true","exhausted_exit_code":75,"rate_limit_evidence_cmd":"grep '\''Request rate limit reached'\'' \"$RATE_LIMIT_EVIDENCE_FILE\""} | .waves["1"].ac_commands[0].auth_consuming=true | .waves["1"].ac_commands[0].command="if [[ ! -f \"$RETRY_FILE\" ]]; then touch \"$RETRY_FILE\"; printf '\''unexpected value http://127.0.0.1:3000/anmelden\\n'\''; exit 1; fi; printf '\''Running 1 test\\n1 passed\\n'\''"')
  gate_output="$TMP/$PLATFORM-browser-gate-output"
  write_config "$config"; commit_case; started=$(date +%s); run_gate >"$gate_output"; elapsed=$(( $(date +%s) - started ))
  jq -e '.commands[0].attempts==2 and .commands[0].status=="passed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: browser failure with provider evidence did not retry once"
  grep -q 'provider rate limit evidenced; pausing' "$gate_output" || fail "$LABEL: browser rate-limit pause was not observable"
  [[ "$elapsed" -ge 1 ]] || fail "$LABEL: browser rate-limit retry did not actually pause"
  [[ -s "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1-ac-1-attempt-1-rate-limit-evidence.log" ]] || fail "$LABEL: browser rate-limit evidence was not retained"
  grep -q 'Request rate limit reached' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1-ac-1-attempt-1-rate-limit-evidence.log" || fail "$LABEL: retained rate-limit log lacks provider evidence"
  unset RETRY_FILE RATE_LIMIT_EVIDENCE_FILE

  case_dir stall
  config=$(default_config | jq '.timeouts.ac_seconds=1 | .waves["1"].ac_commands[0].command="sleep 2"')
  write_config "$config"; commit_case; expect_fail run_gate
  jq -e '.commands[0].status=="stalled" and .commands[0].rc==124' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: stalled AC was not red"

  case_dir stale-status
  write_config "$(default_config)"; commit_case
  printf '{"ralph_status":"running","commands":[]}\n' >"$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json"
  printf '%s\n' "$$" >"$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.pid"
  printf '%s\n' "$(( $(date +%s) - 10 ))" >"$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.heartbeat"
  expect_fail status_gate
  [[ -f "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.pid" ]] || fail "$LABEL: status check removed another Ralph process PID"

  case_dir auth-budget
  config=$(default_config | jq '.auth_budget={"preflight_cmd":"printf AUTH_BUDGET_EXHAUSTED; exit 75","exhausted_exit_code":75} | .waves["1"].ac_commands[0].auth_consuming=true')
  write_config "$config"; commit_case; WORKTREE_LOCK_LOG="$TMP/$PLATFORM-auth-lock"; export WORKTREE_LOCK_LOG
  expect_rc 75 run_gate; [[ -s "$WORKTREE_LOCK_LOG" ]] || fail "$LABEL: auth command did not use shared lock"
  grep -q 'INFRASTRUCTURE FAILED' "$GATE_OUT" || fail "$LABEL: auth exhaustion reported as a test failure"
  jq -e '.ralph_status=="infrastructure_failed" and .infrastructure_failure.exit_code==75 and (.infrastructure_failure.message|contains("auth budget exhausted"))' \
    "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: auth exhaustion infrastructure status was not persisted"
  unset WORKTREE_LOCK_LOG

  case_dir auth-hook-env
  config=$(default_config | jq '.auth_budget={"preflight_cmd":"test \"$WAVE\" = 1 && test -f \"$WAVE_GATE_CONFIG\" && test -f \"$RALPH_STATE\"","exhausted_exit_code":75} | .waves["1"].ac_commands[0].auth_consuming=true')
  write_config "$config"; commit_case; WORKTREE_LOCK_LOG="$TMP/$PLATFORM-auth-env-lock"; export WORKTREE_LOCK_LOG
  run_gate >/dev/null; [[ -s "$WORKTREE_LOCK_LOG" ]] || fail "$LABEL: successful auth hook did not use shared lock"
  unset WORKTREE_LOCK_LOG

  case_dir auth-negative-control
  config=$(default_config | jq '.auth_budget={"preflight_cmd":"if [[ \"${SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL:-0}\" == 1 ]]; then printf AUTH_BUDGET_EXHAUSTED; exit 75; fi","exhausted_exit_code":75,"rate_limit_evidence_cmd":"if [[ \"${SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL:-0}\" == 1 ]]; then printf '\''simulated provider rate-limit evidence\\n'\''; exit 0; fi; exit 1"} | .waves["1"].ac_commands[0].auth_consuming=true')
  write_config "$config"; commit_case; WORKTREE_LOCK_LOG="$TMP/$PLATFORM-auth-control-lock"; export WORKTREE_LOCK_LOG
  expect_rc 75 auth_control_gate
  grep -q 'auth budget negative control observed' "$GATE_OUT" || fail "$LABEL: auth negative control did not report the expected infrastructure failure"
  jq -e '.ralph_status=="infrastructure_failed" and .infrastructure_failure.exit_code==75' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "$LABEL: auth negative control did not persist infra_fail"
  [[ $(wc -l <"$WORKTREE_LOCK_LOG") -eq 2 ]] || fail "$LABEL: both configured auth hooks were not exercised under the shared lock"
  grep -q 'AUTH_BUDGET_EXHAUSTED' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1-auth-preflight-negative-control.log" || fail "$LABEL: configured preflight negative evidence was not retained"
  grep -q 'simulated provider rate-limit evidence' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1-rate-limit-evidence-negative-control.log" || fail "$LABEL: configured rate-limit negative evidence was not retained"
  unset WORKTREE_LOCK_LOG

  case_dir auth-negative-control-inactive
  config=$(default_config | jq '.auth_budget={"preflight_cmd":"true","exhausted_exit_code":75} | .waves["1"].ac_commands[0].auth_consuming=true')
  write_config "$config"; commit_case
  expect_rc 73 auth_control_gate
  grep -q 'preflight_cmd report exhaustion' "$GATE_OUT" || fail "$LABEL: inactive auth negative-control branch was not rejected clearly"

  case_dir legacy-ac
  config=$(default_config | jq '.waves["1"].ac_commands=["printf '\''Running 1 test\\n1 passed\\n'\''"]')
  write_config "$config"; commit_case; expect_fail run_gate
  grep -Fq 'legacy string entries are unsupported; replace each with {id, task, command, test_files, auth_consuming}' "$GATE_OUT" || fail "$LABEL: legacy AC did not stop with migration guidance"

  case_dir auth-pacing
  AUTH_TIMES="$TMP/$PLATFORM-auth-times"; export AUTH_TIMES
  config=$(default_config | jq '.auth_budget={"preflight_cmd":"true","exhausted_exit_code":75} | .waves["1"].auth_pacing_seconds=1 | .waves["1"].ac_commands=[{"id":"AC-1","task":"T-1","command":"date +%s%3N >> \"$AUTH_TIMES\"; printf '\''Running 1 test\\n1 passed\\n'\''","test_files":["tests/a.ts"],"auth_consuming":true},{"id":"AC-2","task":"T-2","command":"date +%s%3N >> \"$AUTH_TIMES\"; printf '\''Running 1 test\\n1 passed\\n'\''","test_files":["tests/b.ts"],"auth_consuming":true}]')
  write_config "$config"; commit_case; run_gate >/dev/null
  mapfile -t auth_times <"$AUTH_TIMES"; [[ $((auth_times[1]-auth_times[0])) -ge 1000 ]] || fail "$LABEL: auth-consuming commands were not paced"
  unset AUTH_TIMES

  case_dir coderabbit-archive
  config=$(default_config | jq '.waves["1"].advisory_severities=["high","low"]')
  write_config "$config"; commit_case
  CR_FIXTURE="$TMP/$PLATFORM-coderabbit.jsonl"; export CR_FIXTURE
  printf '%s\n' \
    '{"type":"status","message":"reviewing"}' \
    '{"type":"finding","severity":"minor","fileName":"src/a.ts","codegenInstructions":"**🤖 Prompt for AI Agents:** Verify each finding against the latest code and only fix it if needed. Fix A"}' \
    '{"type":"finding","severity":"major","fileName":"src/a.ts","codegenInstructions":"Fix B"}' >"$CR_FIXTURE"
  run_gate >/dev/null; run_gate >/dev/null
  for attempt in 1 2; do
    [[ -s "$CASE/specs/PROJ-1-test/5_progress/coderabbit-wave-1-attempt-${attempt}.jsonl" ]] || fail "$LABEL: raw attempt ${attempt} missing"
    [[ $(wc -l <"$CASE/specs/PROJ-1-test/5_progress/coderabbit-wave-1-attempt-${attempt}-normalized.jsonl") -eq 2 ]] || fail "$LABEL: normalized attempt ${attempt} count wrong"
  done
  jq -e -s '.[0].file=="src/a.ts" and .[0].severity=="low" and .[0].category==null and (.[0].summary|startswith("Fix A"))' "$CASE/specs/PROJ-1-test/5_progress/coderabbit-wave-1-attempt-1-normalized.jsonl" >/dev/null || fail "$LABEL: CodeRabbit schema/prefix normalization wrong"
  unset CR_FIXTURE

  case_dir coderabbit-command-failure
  write_config "$(default_config)"; commit_case; CR_RC=1; export CR_RC
  expect_fail run_gate; [[ -f "$CASE/specs/PROJ-1-test/5_progress/coderabbit-wave-1-attempt-1.jsonl" && -f "$CASE/specs/PROJ-1-test/5_progress/coderabbit-wave-1-attempt-1-normalized.jsonl" ]] || fail "$LABEL: failed CodeRabbit attempt was not archived"
  unset CR_RC

  case_dir standalone-blocking
  write_config "$(default_config)"; commit_case
  CR_FIXTURE="$TMP/$PLATFORM-coderabbit-blocking.jsonl"; export CR_FIXTURE
  printf '%s\n' '{"type":"finding","severity":"major","fileName":"src/a.ts","codegenInstructions":"blocking defect"}' >"$CR_FIXTURE"
  expect_fail run_gate; grep -q 'blocking finding' "$GATE_OUT" || fail "$LABEL: standalone current major did not block"
  unset CR_FIXTURE

  case_dir coderabbit-invalid
  write_config "$(default_config)"; commit_case
  CR_FIXTURE="$TMP/$PLATFORM-coderabbit-invalid.jsonl"; export CR_FIXTURE
  printf '%s\n' '{"type":"finding","severity":"major","fileName":"src/a.ts"}' >"$CR_FIXTURE"
  expect_fail run_gate; grep -q 'invalid finding records' "$GATE_OUT" || fail "$LABEL: invalid CodeRabbit record was not rejected"
  unset CR_FIXTURE

  case_dir coderabbit-invalid-optional-fields
  write_config "$(default_config)"; commit_case
  CR_FIXTURE="$TMP/$PLATFORM-coderabbit-invalid-optional.jsonl"; export CR_FIXTURE
  printf '%s\n' '{"type":"finding","severity":"major","category":{"name":"bug"},"fileName":"src/a.ts","line":1.5,"anchor":["symbol"],"codegenInstructions":"typed defect"}' >"$CR_FIXTURE"
  expect_fail run_gate; grep -q 'invalid finding records' "$GATE_OUT" || fail "$LABEL: malformed optional CodeRabbit fields were accepted"
  unset CR_FIXTURE

  case_dir coderabbit-blank-summary
  write_config "$(default_config)"; commit_case
  CR_FIXTURE="$TMP/$PLATFORM-coderabbit-blank-summary.jsonl"; export CR_FIXTURE
  printf '%s\n' '{"type":"finding","severity":"major","fileName":"src/a.ts","codegenInstructions":"   "}' >"$CR_FIXTURE"
  expect_fail run_gate; grep -q 'invalid finding records' "$GATE_OUT" || fail "$LABEL: whitespace-only CodeRabbit summary was accepted"
  unset CR_FIXTURE

  case_dir ledger-cumulative
  write_config "$(default_config)"; cp "$ROOT/$PLATFORM/skills/6_qa/scripts/ledger.mjs" "$CASE/scripts/ledger.mjs"; commit_case
  printf '%s\n' '{"source":"review","severity":"high","summary":"earlier blocker","file":"src/old.ts"}' | (cd "$CASE" && node scripts/ledger.mjs add 1 test) >/dev/null
  expect_fail run_gate; grep -q 'cumulative/current open blocking' "$GATE_OUT" || fail "$LABEL: earlier ledger blocker did not block a zero-finding review"

  case_dir ledger-deferred
  config=$(default_config); write_config "$config"; cp "$ROOT/$PLATFORM/skills/6_qa/scripts/ledger.mjs" "$CASE/scripts/ledger.mjs"; commit_case
  printf '%s\n' '{"source":"coderabbit","severity":"major","summary":"same defect","file":"src/a.ts"}' | (cd "$CASE" && node scripts/ledger.mjs add 1 test) >/dev/null
  id=$(jq -r '.findings[0].id' "$CASE/specs/PROJ-1-test/findings.json"); (cd "$CASE" && node scripts/ledger.mjs set-status 1 test "$id" deferred) >/dev/null
  CR_FIXTURE="$TMP/$PLATFORM-coderabbit-deferred.jsonl"; export CR_FIXTURE
  printf '%s\n' '{"type":"finding","severity":"major","fileName":"src/a.ts","codegenInstructions":"same defect"}' >"$CR_FIXTURE"
  run_gate >/dev/null || fail "$LABEL: deferred re-report incorrectly blocked"
  [[ $(jq -r '.findings[0].status' "$CASE/specs/PROJ-1-test/findings.json") == deferred ]] || fail "$LABEL: deferred finding was reopened"
  unset CR_FIXTURE

  case_dir redirect
  config=$(default_config | jq '.frontend={"dev_url":"http://app.test","dev_cmd":"true","readiness":{"path":"/ready","timeout_seconds":2,"interval_seconds":1},"routes":[{"wave":1,"path":"/account","expected_url":"/account","expected_text":"Account","protected":false}]}')
  write_config "$config"; commit_case; BROWSER_FINAL_URL='http://app.test/login'; BROWSER_TEXT=Account; export BROWSER_FINAL_URL BROWSER_TEXT
  expect_fail run_gate; grep -q 'redirected/resolved' "$GATE_OUT" || fail "$LABEL: login redirect passed smoke"
  [[ ! -e "$BROWSER_STATE_DIR/skillchain-wave-1-route-0" ]] || fail "$LABEL: browser session leaked after failed smoke"
  unset BROWSER_FINAL_URL BROWSER_TEXT

  case_dir auth-state
  printf '{}\n' >"$CASE/auth.json"
  config=$(default_config | jq '.frontend={"dev_url":"http://app.test","dev_cmd":"true","readiness":{"path":"/ready","timeout_seconds":2,"interval_seconds":1},"routes":[{"wave":1,"path":"/account","expected_url":"/account","expected_text":"Account","protected":true,"auth_state":"auth.json"}]}')
  write_config "$config"; commit_case; BROWSER_TEXT=Account; export BROWSER_TEXT; run_gate >/dev/null; unset BROWSER_TEXT

  case_dir authenticated-e2e
  config=$(default_config | jq '.waves["1"].regression_commands[0].test_files=["tests/e2e/account.spec.ts"] | .frontend={"dev_url":"http://app.test","dev_cmd":"true","readiness":{"path":"/ready","timeout_seconds":2,"interval_seconds":1},"routes":[{"wave":1,"path":"/account","expected_url":"/account","expected_text":"Account","protected":true,"authenticated_e2e_test_files":["tests/e2e/account.spec.ts"]}]}')
  write_config "$config"; commit_case; BROWSER_FINAL_URL='http://app.test/login'; export BROWSER_FINAL_URL
  run_gate >/dev/null; unset BROWSER_FINAL_URL

  case_dir authenticated-ac-e2e
  config=$(default_config | jq '.waves["1"].ac_commands[0].test_files=["tests/e2e/account.spec.ts"] | .frontend={"dev_url":"http://app.test","routes":[{"wave":1,"path":"/account","expected_url":"/account","expected_text":"Account","protected":true,"authenticated_e2e_test_files":["tests/e2e/account.spec.ts"]}]}')
  write_config "$config"; commit_case; BROWSER_CALL_LOG="$TMP/$PLATFORM-ac-coverage-browser"; export BROWSER_CALL_LOG
  run_gate >/dev/null
  [[ ! -e "$BROWSER_CALL_LOG" ]] || fail "$LABEL: equivalent authenticated AC evidence still ran smoke"
  unset BROWSER_CALL_LOG

  case_dir browser-snapshot-timeout
  config=$(default_config | jq '.timeouts.browser_seconds=1 | .frontend={"dev_url":"http://app.test","routes":[{"wave":1,"path":"/","expected_text":"Welcome","protected":false}]}')
  write_config "$config"; commit_case; BROWSER_STALL_COMMAND=snapshot; export BROWSER_STALL_COMMAND
  expect_fail run_gate
  grep -q 'snapshot failed or timed out' "$GATE_OUT" || fail "$LABEL: stalled snapshot was not bounded"
  [[ ! -e "$BROWSER_STATE_DIR/skillchain-wave-1-route-0" ]] || fail "$LABEL: browser session leaked after timeout"
  unset BROWSER_STALL_COMMAND

  case_dir protected-without-auth-coverage
  config=$(default_config | jq '.frontend={"dev_url":"http://app.test","dev_cmd":"true","readiness":{"path":"/ready","timeout_seconds":2,"interval_seconds":1},"routes":[{"wave":1,"path":"/account","expected_url":"/account","expected_text":"Account","protected":true}]}')
  write_config "$config"; commit_case; expect_fail run_gate
  grep -q 'lacks auth_state or authenticated E2E coverage' "$GATE_OUT" || fail "$LABEL: protected route without auth evidence was accepted"

  case_dir dev-server
  DEV_PID_FILE="$TMP/$PLATFORM-dev-pid"; READY_FILE="$TMP/$PLATFORM-ready"; export DEV_PID_FILE READY_FILE; CURL_ALWAYS_READY=0; export CURL_ALWAYS_READY
  config=$(default_config | jq '.frontend={"dev_url":"http://app.test","dev_cmd":"echo $$ > \"$DEV_PID_FILE\"; touch \"$READY_FILE\"; sleep 30","readiness":{"path":"/ready","timeout_seconds":3,"interval_seconds":1},"routes":[{"wave":1,"path":"/","expected_url":"/","expected_text":"Welcome","protected":false}]}')
  write_config "$config"; commit_case; run_gate >/dev/null
  [[ -f "$READY_FILE" && -s "$DEV_PID_FILE" ]] || fail "$LABEL: gate did not start configured dev server"
  pid=$(cat "$DEV_PID_FILE"); ! kill -0 "$pid" 2>/dev/null || fail "$LABEL: gate did not stop its dev server"
  unset DEV_PID_FILE READY_FILE CURL_ALWAYS_READY
}

# Both platform suites use platform-prefixed paths under $TMP, so they run concurrently.
run_suite "$ROOT/codex/skills/5_executing/scripts/wave-gate.sh" codex & codex_pid=$!
run_suite "$ROOT/claude/skills/5_executing/scripts/wave-gate.sh" claude & claude_pid=$!
rc=0; wait "$codex_pid" || rc=1; wait "$claude_pid" || rc=1
[[ "$rc" -eq 0 ]] || exit 1

echo 'wave-gate behavior tests (codex + claude): PASS'
