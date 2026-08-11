#!/usr/bin/env bash
# wave-gate.sh — evidence-based Wave Completion Gate (Claude variant)
set -euo pipefail

STATUS_ONLY=false
AUTH_BUDGET_NEGATIVE_CONTROL=false
case "${1:-}" in
  --status) STATUS_ONLY=true; shift ;;
  --auth-budget-negative-control) AUTH_BUDGET_NEGATIVE_CONTROL=true; shift ;;
esac
WAVE="${1:-}"; PROJ="${2:-}"; THEME="${3:-}"
if [[ -z "$WAVE" || -z "$PROJ" || -z "$THEME" ]]; then
  echo "Usage: $0 [--status|--auth-budget-negative-control] <wave-number> <proj-x> <theme>" >&2
  exit 64
fi

BASE="specs/PROJ-${PROJ}-${THEME}"
PROGRESS="${BASE}/5_progress/PROJ-${PROJ}-progress.md"
CFG="${BASE}/3-4_plan/wave-gate-config.json"
RALPH_STATE="${BASE}/5_progress/ralph-wave-${WAVE}.json"
RALPH_PID="${BASE}/5_progress/ralph-wave-${WAVE}.pid"
RALPH_HEARTBEAT="${BASE}/5_progress/ralph-wave-${WAVE}.heartbeat"
WAVE_KEY=".waves[\"${WAVE}\"]"
DEV_PID=""
DEV_PROCESS_GROUP=false
OWNS_RALPH=false

fail() { echo "❌ Wave ${WAVE} Gate FAILED: $1" >&2; exit 1; }
infra_fail() {
  local message="$1" code="${2:-70}" tmp
  if [[ -f "$RALPH_STATE" ]]; then
    tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
    jq --arg message "$message" --argjson code "$code" --arg updated "$(date -Iseconds)" '
      .ralph_status="infrastructure_failed"
      | .infrastructure_failure={message:$message,exit_code:$code,at:$updated}
      | .updated_at=$updated
    ' "$RALPH_STATE" >"$tmp" && mv "$tmp" "$RALPH_STATE" || rm -f "$tmp"
  fi
  echo "🏗️ Wave ${WAVE} Gate INFRASTRUCTURE FAILED: $message" >&2
  exit "$code"
}
step() { echo "→ [$(date +%H:%M:%S)] $1"; }
heartbeat() { date +%s > "$RALPH_HEARTBEAT"; }

cleanup() {
  [[ "$OWNS_RALPH" == false ]] || rm -f "$RALPH_PID"
  if [[ -n "$DEV_PID" ]] && kill -0 "$DEV_PID" 2>/dev/null; then
    if [[ "$DEV_PROCESS_GROUP" == true ]]; then kill -- "-$DEV_PID" 2>/dev/null || true; else kill "$DEV_PID" 2>/dev/null || true; fi
    wait "$DEV_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

run_with_timeout() {
  local secs="$1" label="$2"; shift 2
  local started rc elapsed
  started=$(date +%s)
  set +e
  timeout --foreground "$secs" "$@"
  rc=$?
  set -e
  elapsed=$(( $(date +%s) - started ))
  [[ "$rc" -eq 124 ]] && fail "${label} timed out after ${secs}s (elapsed ${elapsed}s)"
  [[ "$rc" -eq 0 ]] || fail "${label} failed with exit ${rc} (elapsed ${elapsed}s)"
  echo "   ✓ ${label} done in ${elapsed}s"
}

[[ -f "$CFG" ]] || fail "config missing: $CFG"
[[ -f "$PROGRESS" ]] || fail "progress missing: $PROGRESS"
command -v jq >/dev/null || fail "jq not installed"
command -v git >/dev/null || fail "git not installed"
jq -e "$WAVE_KEY" "$CFG" >/dev/null || fail "wave ${WAVE} not configured in $CFG"

AC_TIMEOUT=$(jq -er '.timeouts.ac_seconds' "$CFG") || fail "timeouts.ac_seconds missing"
BUILD_TIMEOUT=$(jq -er '.timeouts.build_seconds' "$CFG") || fail "timeouts.build_seconds missing"
CODERABBIT_TIMEOUT=$(jq -er '.timeouts.coderabbit_seconds' "$CFG") || fail "timeouts.coderabbit_seconds missing"
BROWSER_TIMEOUT=$(jq -er '.timeouts.browser_seconds' "$CFG") || fail "timeouts.browser_seconds missing"
SONAR_TIMEOUT=$(jq -r '.timeouts.sonar_seconds // 120' "$CFG")
SONAR_CMD=$(jq -er '.sonar_cmd | select(type=="string" and test("\\S"))' "$CFG") \
  || fail "sonar_cmd must be a non-empty top-level command"
RALPH_STALL_SECONDS=$(jq -r '.timeouts.ralph_stall_seconds // .timeouts.ac_seconds' "$CFG")
RATE_LIMIT_BACKOFF_SECONDS=$(jq -r "${WAVE_KEY}.rate_limit_backoff_seconds // .rate_limit_backoff_seconds // 330" "$CFG")
AUTH_PACING_SECONDS=$(jq -r "${WAVE_KEY}.auth_pacing_seconds // 0" "$CFG")
for pair in "ac:$AC_TIMEOUT" "build:$BUILD_TIMEOUT" "coderabbit:$CODERABBIT_TIMEOUT" "browser:$BROWSER_TIMEOUT" "sonar:$SONAR_TIMEOUT" "stall:$RALPH_STALL_SECONDS" "backoff:$RATE_LIMIT_BACKOFF_SECONDS" "pacing:$AUTH_PACING_SECONDS"; do
  value="${pair#*:}"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "invalid timeout/pacing ${pair}"
done
for value in "$AC_TIMEOUT" "$BUILD_TIMEOUT" "$CODERABBIT_TIMEOUT" "$BROWSER_TIMEOUT" "$SONAR_TIMEOUT"; do
  [[ "$value" -gt 0 ]] || fail "required timeouts must be greater than zero"
done

AUTH_PREFLIGHT_CMD=$(jq -r '.auth_budget.preflight_cmd // empty' "$CFG")
AUTH_RATE_LIMIT_EVIDENCE_CMD=$(jq -r '.auth_budget.rate_limit_evidence_cmd // empty' "$CFG")
AUTH_EXHAUSTED_RC=$(jq -r '.auth_budget.exhausted_exit_code // 75' "$CFG")
[[ "$AUTH_EXHAUSTED_RC" =~ ^[0-9]+$ && "$AUTH_EXHAUSTED_RC" -gt 0 && "$AUTH_EXHAUSTED_RC" -lt 256 ]] \
  || fail "auth_budget.exhausted_exit_code must be 1..255"

sleep_with_heartbeat() {
  local remaining="$1" chunk
  while [[ "$remaining" -gt 0 ]]; do
    chunk=$((remaining > 30 ? 30 : remaining)); sleep "$chunk"; remaining=$((remaining - chunk)); heartbeat
  done
}

init_ralph_state() {
  [[ -f "$RALPH_STATE" ]] && return
  local tmp started
  started=$(date -Iseconds); tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
  jq -n --arg wave "$WAVE" --arg started "$started" \
    '{version:2,wave:$wave,started_at:$started,updated_at:$started,ralph_status:"running",commands:[],regressions:[]}' >"$tmp"
  mv "$tmp" "$RALPH_STATE"
}

record_ac() {
  local index="$1" id="$2" task="$3" command="$4" tests="$5" attempts="$6" rc="$7" selected="$8" status="$9" log="${10}" verified_head="${11}" tmp
  tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
  jq --argjson index "$index" --arg id "$id" --arg task "$task" --arg command "$command" --argjson tests "$tests" \
    --argjson attempts "$attempts" --argjson rc "$rc" --argjson selected "$selected" --arg status "$status" \
    --arg log "$log" --arg head "$verified_head" --arg updated "$(date -Iseconds)" '
      .updated_at=$updated |
      .commands=((.commands // []) | map(select(.index != $index)) + [{index:$index,id:$id,task:($task | if .=="" then null else . end),command:$command,test_files:$tests,attempts:$attempts,rc:$rc,selected:$selected,failed_empty_selection:($status=="failed_empty_selection"),status:$status,log:$log,verified_head:$head,updated_at:$updated}])
    ' "$RALPH_STATE" >"$tmp" && mv "$tmp" "$RALPH_STATE"
}

record_regression() {
  local label="$1" command="$2" tests="$3" rc="$4" selected="$5" status="$6" log="$7" head="$8" tmp
  tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
  jq --arg label "$label" --arg command "$command" --argjson tests "$tests" --argjson rc "$rc" --argjson selected "$selected" \
    --arg status "$status" --arg log "$log" --arg head "$head" --arg updated "$(date -Iseconds)" '
      .updated_at=$updated |
      .regressions=((.regressions // []) | map(select(.label != $label)) + [{label:$label,command:$command,test_files:$tests,rc:$rc,selected:$selected,failed_empty_selection:($status=="failed_empty_selection"),status:$status,log:$log,verified_head:$head,updated_at:$updated}])
    ' "$RALPH_STATE" >"$tmp" && mv "$tmp" "$RALPH_STATE"
}

selected_count() {
  local log="$1" match
  match=$(grep -Eo 'Running[[:space:]]+[0-9]+[[:space:]]+tests?' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<<"$match" | head -1; return; }
  match=$(grep -Eo 'Tests[[:space:]]+[0-9]+[[:space:]]+passed' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<<"$match" | head -1; return; }
  match=$(grep -Eo '^#[[:space:]]+tests[[:space:]]+[0-9]+' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<<"$match" | tail -1; return; }
  match=$(grep -Eo '(^|[^0-9])[0-9]+[[:space:]]+passed([[:space:]]|$)' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<<"$match" | head -1; return; }
  echo 0
}

provider_rate_limited() {
  grep -Eiq 'over_request_rate_limit|Request[[:space:]]+rate[[:space:]]+limit[[:space:]]+reached|HTTP(/[0-9.]+)?[[:space:]]+429([^0-9]|$)|"status"[[:space:]]*:[[:space:]]*429([^0-9]|$)|status[[:space:]]*=[[:space:]]*429([^0-9]|$)' "$1"
}

is_evidence_path() {
  case "$1" in
    "$PROGRESS"|"$BASE/findings.json"|"$BASE/.findings.lock"|"$BASE/5_progress/ralph-wave-${WAVE}"*|"$BASE/5_progress/coderabbit-wave-${WAVE}-attempt-"*|"$BASE/5_progress/dev-server-wave-${WAVE}.log") return 0 ;;
    *) return 1 ;;
  esac
}

assert_clean_worktree() {
  local line path dirty=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="${line:3}"; path="${path#* -> }"
    is_evidence_path "$path" || dirty+=("$line")
  done < <(git status --porcelain=v1 --untracked-files=all)
  [[ "${#dirty[@]}" -eq 0 ]] || fail "working tree contains non-gate changes; commit them before certification: ${dirty[*]}"
}

assert_verified_head() {
  local current
  current=$(git rev-parse --verify HEAD)
  [[ "$current" == "$VERIFIED_HEAD" ]] || fail "HEAD changed during gate verification (${VERIFIED_HEAD} -> ${current}); rerun all evidence on the new committed HEAD"
}

ralph_status() {
  [[ -f "$RALPH_STATE" ]] || fail "no Ralph state recorded: $RALPH_STATE"
  local pid="" heartbeat_at="" age="unknown" status
  [[ -f "$RALPH_PID" ]] && pid=$(tr -cd '0-9' <"$RALPH_PID")
  [[ -f "$RALPH_HEARTBEAT" ]] && heartbeat_at=$(tr -cd '0-9' <"$RALPH_HEARTBEAT")
  [[ -n "$heartbeat_at" ]] && age=$(( $(date +%s) - heartbeat_at ))
  jq --arg pid "$pid" --arg age "$age" '. + {pid:($pid|if .=="" then null else tonumber end),heartbeat_age_seconds:($age|if .=="unknown" then null else tonumber end)}' "$RALPH_STATE"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    [[ "$age" == unknown || "$age" -le "$RALPH_STALL_SECONDS" ]] || fail "Ralph PID ${pid} is stalled (${age}s)"
    return
  fi
  status=$(jq -r '.ralph_status // "running"' "$RALPH_STATE")
  [[ -z "$pid" && "$status" == complete ]] && return
  fail "Ralph state is ${status} without a live PID; rerun the gate to resume"
}

if [[ "$STATUS_ONLY" == true ]]; then ralph_status; exit 0; fi

# Runs an auth-budget preflight and the test under the shared-project lock.
# Return codes 73/74 and the configured exhausted code are infrastructure, not test failures.
run_test_command() {
  local auth="$1" command="$2" timeout_secs="$3" log="$4" hook_log="$5" rc
  if [[ "$auth" != true ]]; then
    timeout --foreground "$timeout_secs" bash -c "$command" >"$log" 2>&1; rc=$?
    return "$rc"
  fi
  [[ -n "$AUTH_PREFLIGHT_CMD" ]] || infra_fail "auth-consuming command has no auth_budget.preflight_cmd"
  [[ -x scripts/worktree.sh ]] || infra_fail "auth-consuming command requires executable scripts/worktree.sh"
  env WAVE="$WAVE" WAVE_GATE_CONFIG="$CFG" RALPH_STATE="$RALPH_STATE" \
    scripts/worktree.sh with-shared-lock -- bash -c '
      set +e
      bash -c "$1" >"$2" 2>&1
      hook_rc=$?
      set -e
      if grep -q "AUTH_BUDGET_EXHAUSTED" "$2" || [[ "$hook_rc" -eq "$3" ]]; then exit "$3"; fi
      [[ "$hook_rc" -eq 0 ]] || exit 74
      timeout --foreground "$4" bash -c "$5" >"$6" 2>&1
    ' _ "$AUTH_PREFLIGHT_CMD" "$hook_log" "$AUTH_EXHAUSTED_RC" "$timeout_secs" "$command" "$log"
  rc=$?
  return "$rc"
}

run_auth_budget_negative_control() {
  local preflight_log="${BASE}/5_progress/ralph-wave-${WAVE}-auth-preflight-negative-control.log"
  local evidence_log="${BASE}/5_progress/ralph-wave-${WAVE}-rate-limit-evidence-negative-control.log"
  local rc observed="configured preflight exhaustion"
  [[ -n "$AUTH_PREFLIGHT_CMD" ]] || infra_fail "auth budget negative control requires auth_budget.preflight_cmd" 73
  [[ -x scripts/worktree.sh ]] || infra_fail "auth budget negative control requires executable scripts/worktree.sh" 73
  init_ralph_state

  set +e
  env SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1 WAVE="$WAVE" WAVE_GATE_CONFIG="$CFG" RALPH_STATE="$RALPH_STATE" \
    scripts/worktree.sh with-shared-lock -- bash -c "$AUTH_PREFLIGHT_CMD" >"$preflight_log" 2>&1
  rc=$?
  set -e
  if ! grep -q 'AUTH_BUDGET_EXHAUSTED' "$preflight_log" && [[ "$rc" -ne "$AUTH_EXHAUSTED_RC" ]]; then
    infra_fail "auth budget negative control did not make preflight_cmd report exhaustion (rc=${rc})" 73
  fi

  if [[ -n "$AUTH_RATE_LIMIT_EVIDENCE_CMD" ]]; then
    set +e
    env SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1 WAVE="$WAVE" WAVE_GATE_CONFIG="$CFG" RALPH_STATE="$RALPH_STATE" \
      AC_ID="negative-control" AC_LOG="$preflight_log" \
      scripts/worktree.sh with-shared-lock -- bash -c "$AUTH_RATE_LIMIT_EVIDENCE_CMD" >"$evidence_log" 2>&1
    rc=$?
    set -e
    [[ "$rc" -eq 0 ]] || infra_fail "auth budget negative control rate_limit_evidence_cmd failed with exit ${rc}" 74
    grep -q '[^[:space:]]' "$evidence_log" || infra_fail "auth budget negative control rate_limit_evidence_cmd produced no evidence" 74
    observed+=" and rate-limit evidence"
  fi

  infra_fail "auth budget negative control observed ${observed}" "$AUTH_EXHAUSTED_RC"
}

if [[ "$AUTH_BUDGET_NEGATIVE_CONTROL" == true ]]; then run_auth_budget_negative_control; fi

jq -e "${WAVE_KEY}.advisory_severities | type == \"array\"" "$CFG" >/dev/null || fail "advisory_severities missing"
ADVISORY_JSON=$(jq -c "${WAVE_KEY}.advisory_severities | map(ascii_downcase)" "$CFG")
ADVISORY_LABEL=$(jq -r "${WAVE_KEY}.advisory_severities | if length==0 then \"none\" else join(\",\") end" "$CFG")
VERIFIED_HEAD=$(git rev-parse --verify HEAD)
assert_clean_worktree
echo "=== Wave ${WAVE} Completion Gate — current ACs + declared regressions (PROJ-${PROJ}-${THEME}) ==="

step "1/7 Ralph: current AC verification"
AC_COUNT=$(jq -r "${WAVE_KEY}.ac_commands | length" "$CFG")
[[ "$AC_COUNT" -gt 0 ]] || fail "no ac_commands defined"
init_ralph_state
if [[ -f "$RALPH_PID" ]]; then
  previous_pid=$(tr -cd '0-9' <"$RALPH_PID")
  if [[ -n "$previous_pid" ]] && kill -0 "$previous_pid" 2>/dev/null; then ralph_status; fail "Ralph already running"; fi
  rm -f "$RALPH_PID"
fi
printf '%s\n' "$$" >"$RALPH_PID"; OWNS_RALPH=true; heartbeat
LAST_AUTH="${BASE}/5_progress/ralph-wave-${WAVE}.auth-last"

for ((index=0; index<AC_COUNT; index++)); do
  entry=$(jq -c "${WAVE_KEY}.ac_commands[$index]" "$CFG")
  if [[ $(jq -r type <<<"$entry") == string ]]; then
    fail "legacy string entries are unsupported; replace each with {id, task, command, test_files, auth_consuming}"
  else
    command=$(jq -r '.command // empty' <<<"$entry"); id=$(jq -r ".id // \"legacy-$((index+1))\"" <<<"$entry")
    task=$(jq -r '.task // empty' <<<"$entry"); tests=$(jq -c '.test_files // []' <<<"$entry"); auth=$(jq -r '.auth_consuming // false' <<<"$entry")
  fi
  [[ -n "$command" && -n "$id" ]] || fail "AC $((index+1)) has empty id/command"
  [[ "$auth" == true || "$auth" == false ]] || fail "AC ${id} auth_consuming must be boolean"
  if jq -e --arg id "$id" --arg command "$command" --arg head "$VERIFIED_HEAD" \
    '.commands[]? | select(.id==$id and .command==$command and .verified_head==$head and .status=="passed" and .rc==0 and ((.selected|type)=="number") and .selected>0)' "$RALPH_STATE" >/dev/null; then
    assert_verified_head
    echo "   ✓ AC ${id} already green at ${VERIFIED_HEAD}; skipped"
    continue
  fi
  if [[ "$auth" == true && "$AUTH_PACING_SECONDS" -gt 0 && -f "$LAST_AUTH" ]]; then
    last=$(tr -cd '0-9' <"$LAST_AUTH"); wait_for=$((AUTH_PACING_SECONDS - ($(date +%s) - last)))
    [[ "$wait_for" -le 0 ]] || sleep_with_heartbeat "$wait_for"
  fi
  attempts=$(jq -r --arg id "$id" '[.commands[]? | select(.id==$id)][0].attempts // 0' "$RALPH_STATE")
  for retry in 1 2; do
    attempts=$((attempts+1)); log="${BASE}/5_progress/ralph-wave-${WAVE}-ac-$((index+1))-attempt-${attempts}.log"; hook_log="${log%.log}-auth-preflight.log"; rate_limit_log="${log%.log}-rate-limit-evidence.log"
    [[ "$auth" == true ]] && date +%s >"$LAST_AUTH"
    heartbeat; set +e; run_test_command "$auth" "$command" "$AC_TIMEOUT" "$log" "$hook_log"; rc=$?; set -e; selected=$(selected_count "$log"); heartbeat
    [[ "$rc" -eq 73 ]] && infra_fail "shared-resource lock unavailable for AC ${id}" 73
    [[ "$rc" -eq 74 ]] && infra_fail "auth-budget preflight failed for AC ${id} (log: $hook_log)" 74
    if [[ "$auth" == true ]] && { [[ "$rc" -eq "$AUTH_EXHAUSTED_RC" ]] || grep -q 'AUTH_BUDGET_EXHAUSTED' "$log" "$hook_log" 2>/dev/null; }; then infra_fail "auth budget exhausted before/during AC ${id}" "$AUTH_EXHAUSTED_RC"; fi
    if [[ "$rc" -eq 0 && "$selected" -gt 0 ]]; then record_ac "$index" "$id" "$task" "$command" "$tests" "$attempts" 0 "$selected" passed "$log" "$VERIFIED_HEAD"; break; fi
    if [[ "$rc" -eq 0 ]]; then record_ac "$index" "$id" "$task" "$command" "$tests" "$attempts" 0 0 failed_empty_selection "$log" "$VERIFIED_HEAD"; fail "AC ${id} selected 0 tests"; fi
    if [[ "$rc" -eq 124 ]]; then record_ac "$index" "$id" "$task" "$command" "$tests" "$attempts" "$rc" "$selected" stalled "$log" "$VERIFIED_HEAD"; fail "AC ${id} timed out"; fi
    rate_limited=false
    provider_rate_limited "$log" && rate_limited=true
    if [[ "$rate_limited" == false && "$auth" == true && -n "$AUTH_RATE_LIMIT_EVIDENCE_CMD" ]]; then
      set +e
      env WAVE="$WAVE" WAVE_GATE_CONFIG="$CFG" RALPH_STATE="$RALPH_STATE" AC_ID="$id" AC_LOG="$log" \
        timeout --foreground "$AC_TIMEOUT" bash -c "$AUTH_RATE_LIMIT_EVIDENCE_CMD" >"$rate_limit_log" 2>&1
      evidence_rc=$?
      if [[ "$evidence_rc" -eq 0 ]] && ! grep -q '[^[:space:]]' "$rate_limit_log"; then
        evidence_rc=74
        printf 'rate-limit evidence command exited 0 without evidence output\n' >>"$rate_limit_log"
      fi
      printf 'exit_code=%s\n' "$evidence_rc" >>"$rate_limit_log"
      set -e
      case "$evidence_rc" in 0) rate_limited=true ;; 1) ;; *) infra_fail "rate-limit evidence hook failed for AC ${id} rc=${evidence_rc} (log: $rate_limit_log)" "$evidence_rc" ;; esac
    fi
    if [[ "$rate_limited" == true && "$retry" -eq 1 ]]; then echo "   ↻ provider rate limit evidenced; pausing"; record_ac "$index" "$id" "$task" "$command" "$tests" "$attempts" "$rc" "$selected" rate_limited "$log" "$VERIFIED_HEAD"; sleep_with_heartbeat "$RATE_LIMIT_BACKOFF_SECONDS"; continue; fi
    record_ac "$index" "$id" "$task" "$command" "$tests" "$attempts" "$rc" "$selected" failed "$log" "$VERIFIED_HEAD"; fail "AC ${id} failed rc=${rc}, selected=${selected} (log: $log)"
  done
  assert_verified_head
  assert_clean_worktree
done

step "2/7 Declared broad regression suite"
REG_COUNT=$(jq -r "${WAVE_KEY}.regression_commands // [] | length" "$CFG")
[[ "$REG_COUNT" -gt 0 ]] || fail "wave ${WAVE} has no declared broad regression_commands"
for ((index=0; index<REG_COUNT; index++)); do
  entry=$(jq -c "${WAVE_KEY}.regression_commands[$index]" "$CFG")
  label=$(jq -r ".label // \"regression-$((index+1))\"" <<<"$entry"); command=$(jq -r '.command // empty' <<<"$entry")
  tests=$(jq -c '.test_files // []' <<<"$entry"); auth=$(jq -r '.auth_consuming // false' <<<"$entry"); require_selection=$(jq -r '.require_non_empty_selection // false' <<<"$entry")
  [[ -n "$command" ]] || fail "regression ${label} command is empty"
  log="${BASE}/5_progress/ralph-wave-${WAVE}-regression-$((index+1)).log"; hook_log="${log%.log}-auth-preflight.log"
  set +e; run_test_command "$auth" "$command" "$AC_TIMEOUT" "$log" "$hook_log"; rc=$?; set -e; selected=$(selected_count "$log")
  [[ "$rc" -eq 73 ]] && infra_fail "shared-resource lock unavailable for regression ${label}" 73
  [[ "$rc" -eq 74 ]] && infra_fail "auth-budget preflight failed for regression ${label}" 74
  if [[ "$auth" == true ]] && { [[ "$rc" -eq "$AUTH_EXHAUSTED_RC" ]] || grep -q 'AUTH_BUDGET_EXHAUSTED' "$log" "$hook_log" 2>/dev/null; }; then infra_fail "auth budget exhausted before/during regression ${label}" "$AUTH_EXHAUSTED_RC"; fi
  [[ "$rc" -eq 0 ]] || { record_regression "$label" "$command" "$tests" "$rc" "$selected" failed "$log" "$VERIFIED_HEAD"; fail "regression ${label} failed rc=${rc}"; }
  if [[ "$require_selection" == true && "$selected" -le 0 ]]; then record_regression "$label" "$command" "$tests" 0 0 failed_empty_selection "$log" "$VERIFIED_HEAD"; fail "regression ${label} selected 0 tests"; fi
  record_regression "$label" "$command" "$tests" 0 "$selected" passed "$log" "$VERIFIED_HEAD"
  if [[ "$require_selection" == true ]]; then
    echo "   ✓ ${label} (${selected} selected)"
  else
    echo "   ✓ ${label}"
  fi
  assert_verified_head
  assert_clean_worktree
done
rm -f "$RALPH_PID"; OWNS_RALPH=false
tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX"); jq --arg updated "$(date -Iseconds)" '.ralph_status="complete"|.updated_at=$updated' "$RALPH_STATE" >"$tmp" && mv "$tmp" "$RALPH_STATE"

step "3/7 Build"
BUILD_CMD=$(jq -r '.build_cmd // empty' "$CFG"); [[ -n "$BUILD_CMD" ]] || fail "build_cmd missing"
run_with_timeout "$BUILD_TIMEOUT" build bash -c "$BUILD_CMD"; assert_verified_head; assert_clean_worktree

step "4/7 CodeRabbit wave review"
command -v coderabbit >/dev/null || fail "coderabbit not installed"
WAVE_BASE="${WAVE_BASE_SHA:-}"
if [[ -n "$WAVE_BASE" ]]; then git rev-parse --verify "${WAVE_BASE}^{commit}" >/dev/null 2>&1 || fail "invalid WAVE_BASE_SHA"; else WAVE_BASE=$(git rev-parse --verify "wave-${WAVE}-start-PROJ-${PROJ}^{commit}" 2>/dev/null || true); fi
[[ -n "$WAVE_BASE" ]] || fail "missing wave base SHA/tag"
FILES_CHANGED=$(git diff --name-only "${WAVE_BASE}..HEAD" | wc -l | tr -d ' '); [[ "$FILES_CHANGED" -le 150 ]] || fail "CodeRabbit scope ${FILES_CHANGED} exceeds 150 files"
attempt=1
while [[ -e "${BASE}/5_progress/coderabbit-wave-${WAVE}-attempt-${attempt}.jsonl" || -e "${BASE}/5_progress/coderabbit-wave-${WAVE}-attempt-${attempt}-normalized.jsonl" ]]; do attempt=$((attempt+1)); done
CR_RAW="${BASE}/5_progress/coderabbit-wave-${WAVE}-attempt-${attempt}.jsonl"
CR_NORMALIZED="${BASE}/5_progress/coderabbit-wave-${WAVE}-attempt-${attempt}-normalized.jsonl"
  set +e; timeout --foreground "$CODERABBIT_TIMEOUT" coderabbit review --agent --base-commit "$WAVE_BASE" >"$CR_RAW"; CR_RC=$?; set -e
: >"$CR_NORMALIZED"
if ! jq -c 'select(.type=="finding") | {source:"coderabbit",severity:((.severity // null)|if type=="string" then ascii_downcase | if .=="blocker" then "critical" elif .=="major" then "high" elif .=="minor" or .=="trivial" or .=="info" then "low" elif .=="moderate" then "medium" else . end else . end),category:(.category // null),summary:((.codegenInstructions // null)|if type=="string" then gsub("^(\\*\\*)?🤖?[[:space:]]*Prompt for AI Agents:?\\*\\*?[[:space:]]*";"") | sub("^Verify each finding against the latest code and only fix it if needed\\.[[:space:]]*";"") else . end),file:(.fileName // null),line:(.line // .startLine // null),anchor:(.anchor // null)}' "$CR_RAW" >"$CR_NORMALIZED"; then
  if [[ "$CR_RC" -eq 124 ]]; then
    fail "CodeRabbit timed out and its output is not valid JSONL (raw: $CR_RAW)"
  else
    fail "CodeRabbit output is not valid JSONL (raw: $CR_RAW)"
  fi
fi
RAW_FINDINGS=$(jq -s '[.[]|select(.type=="finding")]|length' "$CR_RAW")
NORMALIZED_FINDINGS=$(jq -s 'length' "$CR_NORMALIZED")
[[ "$RAW_FINDINGS" -eq "$NORMALIZED_FINDINGS" ]] || fail "CodeRabbit finding count mismatch raw=${RAW_FINDINGS}, normalized=${NORMALIZED_FINDINGS}"
jq -e -s 'all(.[]; (.source=="coderabbit") and (.severity|type=="string") and (.severity|IN("critical","high","medium","low")) and (.summary|type=="string" and test("\\S")) and ((.category==null) or (.category|type=="string")) and ((.file==null) or (.file|type=="string")) and ((.line==null) or ((.line|type)=="number" and (.line|floor)==.line)) and ((.anchor==null) or (.anchor|type=="string")))' "$CR_NORMALIZED" >/dev/null \
  || fail "CodeRabbit emitted invalid finding records (normalized: $CR_NORMALIZED)"
[[ "$CR_RC" -eq 124 ]] && fail "CodeRabbit timed out (raw: $CR_RAW)"
[[ "$CR_RC" -eq 0 ]] || fail "CodeRabbit errored rc=${CR_RC} (raw: $CR_RAW)"
if jq -e 'select(.type=="error")' "$CR_RAW" >/dev/null; then fail "CodeRabbit emitted an error event (raw: $CR_RAW)"; fi

LEDGER_AVAILABLE=false
if [[ -f scripts/ledger.mjs ]] && command -v node >/dev/null; then LEDGER_AVAILABLE=true; fi
if [[ "$RAW_FINDINGS" -gt 0 && "$LEDGER_AVAILABLE" == true ]]; then
  node scripts/ledger.mjs add "$PROJ" "$THEME" --wave "$WAVE" <"$CR_NORMALIZED" >/dev/null || fail "ledger ingestion failed"
fi
CUMULATIVE_BLOCKING=0
if [[ "$LEDGER_AVAILABLE" == true && -f "$BASE/findings.json" ]]; then
  CUMULATIVE_BLOCKING=$(jq --argjson advisory "$ADVISORY_JSON" '[.findings[] | select(.status=="open") | .severity as $s | select(($advisory | index($s) | not))] | length' "$BASE/findings.json")
elif [[ "$LEDGER_AVAILABLE" == false ]]; then
  CUMULATIVE_BLOCKING=$(jq -s --argjson advisory "$ADVISORY_JSON" '[.[] | .severity as $s | select(($advisory | index($s) | not))] | length' "$CR_NORMALIZED")
fi
[[ "$CUMULATIVE_BLOCKING" -eq 0 ]] || fail "${CUMULATIVE_BLOCKING} cumulative/current open blocking finding(s) remain after review ingestion"
assert_verified_head; assert_clean_worktree

step "5/7 Sonar local scan"
SONAR_STARTED_AT=$(date +%s)
run_with_timeout "$SONAR_TIMEOUT" sonar_cmd bash -c "$SONAR_CMD"
# sonar-scanner always writes .scannerwork/report-task.txt on ANY completed
# analysis submission (even ones that later fail server-side); the `sonar`
# operator CLI does not. Its absence or staleness proves sonar_cmd exited 0
# without a real scanner run completing — a no-op or wrong CLI would still
# exit 0 and must not be reported green.
[[ -f .scannerwork/report-task.txt ]] || fail "sonar_cmd exited 0 but .scannerwork/report-task.txt is missing — sonar-scanner did not actually run"
REPORT_TASK_MTIME=$(date -r .scannerwork/report-task.txt +%s 2>/dev/null || echo 0)
[[ "$REPORT_TASK_MTIME" -ge "$SONAR_STARTED_AT" ]] || fail "sonar_cmd exited 0 but .scannerwork/report-task.txt is stale (from an earlier run) — sonar-scanner did not run this time"
SONAR_STATUS=green
assert_verified_head; assert_clean_worktree

step "6/7 Browser smoke test"
ROUTES_JSON=$(jq -c --arg wave "$WAVE" '[.frontend.routes[]? | select((.wave|tostring)==$wave)]' "$CFG")
if [[ $(jq 'length' <<<"$ROUTES_JSON") -eq 0 ]]; then
  ROUTES_JSON=$(jq -c "[${WAVE_KEY}.frontend_routes[]? | if type==\"string\" then {path:.,expected_url:.,expected_text:null,protected:false,auth_state:null} else . end]" "$CFG")
fi
ROUTE_COUNT=$(jq 'length' <<<"$ROUTES_JSON"); ROUTES_STR=backend-only
if [[ "$ROUTE_COUNT" -eq 0 ]]; then echo "   (backend-only wave — skipped)"; else
  ROUTES_STR=$(jq -r '[.[].path]|join(" ")' <<<"$ROUTES_JSON")
  for ((index=0; index<ROUTE_COUNT; index++)); do
    route=$(jq -c ".[$index]" <<<"$ROUTES_JSON"); path=$(jq -r '.path' <<<"$route"); protected=$(jq -r '.protected // false' <<<"$route"); auth_state=$(jq -r '.auth_state // empty' <<<"$route")
    if [[ "$protected" == true && -z "$auth_state" ]]; then
      coverage=$(jq -c '.authenticated_e2e_test_files // []' <<<"$route")
      [[ $(jq 'length' <<<"$coverage") -gt 0 ]] || fail "protected route ${path} lacks auth_state or authenticated E2E coverage"
      jq -e --argjson coverage "$coverage" "${WAVE_KEY}.regression_commands as \$reg | ([\$reg[].test_files[]?] | unique) as \$files | (\$coverage - \$files | length)==0" "$CFG" >/dev/null || fail "protected route ${path} lacks auth_state or successful authenticated E2E coverage"
      echo "   ✓ protected ${path}: covered by authenticated regression"
    fi
  done
  SMOKE_ROUTES_JSON=$(jq -c '[.[] | select((.protected // false)==false or ((.auth_state // "")|length)>0)]' <<<"$ROUTES_JSON")
  SMOKE_COUNT=$(jq 'length' <<<"$SMOKE_ROUTES_JSON")
  if [[ "$SMOKE_COUNT" -eq 0 ]]; then
    echo "   (all protected routes covered by authenticated regression — browser smoke skipped)"
  else
    command -v agent-browser >/dev/null || fail "agent-browser not installed but smoke routes are configured"
    command -v curl >/dev/null || fail "curl not installed but smoke routes are configured"
    DEV_URL=$(jq -r '.frontend.dev_url // .dev_url // "http://localhost:3000"' "$CFG"); DEV_CMD=$(jq -r '.frontend.dev_cmd // .dev_cmd // empty' "$CFG")
    READY_PATH=$(jq -r '.frontend.readiness.path // "/"' "$CFG"); READY_TIMEOUT=$(jq -r '.frontend.readiness.timeout_seconds // .timeouts.browser_seconds' "$CFG"); READY_INTERVAL=$(jq -r '.frontend.readiness.interval_seconds // 1' "$CFG")
    READY_URL="${DEV_URL%/}/${READY_PATH#/}"
    if ! curl -fsS --max-time 2 "$READY_URL" >/dev/null 2>&1; then
      [[ -n "$DEV_CMD" ]] || fail "dev server not ready at ${READY_URL} and frontend.dev_cmd is missing"
      DEV_LOG="${BASE}/5_progress/dev-server-wave-${WAVE}.log"
      if command -v setsid >/dev/null; then setsid bash -c "$DEV_CMD" >"$DEV_LOG" 2>&1 & DEV_PID=$!; DEV_PROCESS_GROUP=true
      else bash -c "$DEV_CMD" >"$DEV_LOG" 2>&1 & DEV_PID=$!
      fi
      deadline=$(( $(date +%s) + READY_TIMEOUT ))
      until curl -fsS --max-time 2 "$READY_URL" >/dev/null 2>&1; do kill -0 "$DEV_PID" 2>/dev/null || fail "dev server exited before readiness (log: $DEV_LOG)"; [[ $(date +%s) -lt "$deadline" ]] || fail "dev server readiness timed out (log: $DEV_LOG)"; sleep "$READY_INTERVAL"; done
    fi
    for ((index=0; index<SMOKE_COUNT; index++)); do
      route=$(jq -c ".[$index]" <<<"$SMOKE_ROUTES_JSON"); path=$(jq -r '.path' <<<"$route"); auth_state=$(jq -r '.auth_state // empty' <<<"$route")
      [[ -z "$auth_state" || -f "$auth_state" ]] || fail "auth_state missing for ${path}: ${auth_state}"
      target="${DEV_URL%/}/${path#/}"; expected=$(jq -r '.expected_url // .path' <<<"$route"); [[ "$expected" =~ ^https?:// ]] || expected="${DEV_URL%/}/${expected#/}"
      expected_text=$(jq -r '.expected_text // empty' <<<"$route"); session="skillchain-wave-${WAVE}-route-${index}"
      browser=(agent-browser --session "$session"); [[ -z "$auth_state" ]] || browser+=(--state "$auth_state")
      run_with_timeout "$BROWSER_TIMEOUT" "smoke ${path}" "${browser[@]}" open "$target"
      actual=$("${browser[@]}" get url); [[ "$actual" == "$expected" ]] || fail "smoke ${path} redirected/resolved to '${actual}', expected '${expected}'"
      text_out=$("${browser[@]}" read); [[ -z "$expected_text" ]] || grep -Fq "$expected_text" <<<"$text_out" || fail "smoke ${path} missing expected_text '${expected_text}'"
      "${browser[@]}" errors >/dev/null || fail "browser errors on ${path}"
      "${browser[@]}" close >/dev/null 2>&1 || true
    done
  fi
fi
assert_verified_head; assert_clean_worktree

step "7/7 Component registry"
if [[ -f scripts/gen-component-registry.mjs && ( -d src/components || -d src/features ) ]]; then
  set +e; node scripts/gen-component-registry.mjs --check; REG_RC=$?; set -e
  [[ "$REG_RC" -eq 0 || "$REG_RC" -eq 3 ]] || fail "component registry out of date"
else echo "   (component registry unavailable/not applicable — skipped)"; fi

assert_verified_head; assert_clean_worktree
TS=$(date -Iseconds)
cat >>"$PROGRESS" <<EOF

### Wave ${WAVE} Gate — PASSED ($TS)
- [x] Current ACs: ${AC_COUNT} commands green at ${VERIFIED_HEAD}
- [x] Declared broad regressions: ${REG_COUNT} commands green
- [x] Build: \`${BUILD_CMD}\`
- [x] CodeRabbit: attempt ${attempt} ingested; cumulative open blocking findings after ledger status: 0
- [x] Sonar: ${SONAR_STATUS}
- [x] Component registry: checked
- [x] Smoke/authenticated E2E: ${ROUTES_STR}
EOF
echo "✅ Wave ${WAVE} Gate PASSED — current ACs plus declared regressions verified (not every historical AC command)"

NEXT=$((WAVE+1)); NEXT_TAG="wave-${NEXT}-start-PROJ-${PROJ}"
git rev-parse --verify "${NEXT_TAG}^{commit}" >/dev/null 2>&1 || git tag "$NEXT_TAG" HEAD 2>/dev/null || true
NEXT_PLAN="${BASE}/3-4_plan/PROJ-${PROJ}-wave-${NEXT}-plan.md"
if [[ -f "$NEXT_PLAN" ]]; then
  echo "→ NEXT ACTION: Start Wave ${NEXT}."
else
  echo "→ NEXT ACTION: Start the PROJ-end Quality Gate (including the one-time Takahashi minimalism review), then QA."
fi
