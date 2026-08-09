#!/usr/bin/env bash
#
# wave-gate.sh — Wave Completion Gate
#
# Validates that the current wave is cleanly finished before the next wave
# starts. Exit 0 = pass. Non-zero exit = BLOCK next wave.
#
# Usage:
#   bash scripts/wave-gate.sh <wave-number> <proj-x> <theme>
# Example:
#   bash scripts/wave-gate.sh 2 1 auth
#
# Requires:
#   - jq (for parsing wave-gate-config.json)
#   - The config file at specs/PROJ-<X>-<theme>/3-4_plan/wave-gate-config.json
#   - coderabbit CLI
#   - agent-browser CLI (for frontend smoke tests when frontend_routes is non-empty)
#
# Copy this file into every project that uses the skill chain, at:
#   scripts/wave-gate.sh
#
set -euo pipefail

STATUS_ONLY=false
if [[ "${1:-}" == "--status" ]]; then
  STATUS_ONLY=true
  shift
fi

WAVE="${1:-}"
PROJ="${2:-}"
THEMA="${3:-}"

if [[ -z "$WAVE" || -z "$PROJ" || -z "$THEMA" ]]; then
  echo "Usage: $0 [--status] <wave-number> <proj-x> <theme>" >&2
  exit 64
fi

BASE="specs/PROJ-${PROJ}-${THEMA}"
PROGRESS="${BASE}/5_progress/PROJ-${PROJ}-progress.md"
CFG="${BASE}/3-4_plan/wave-gate-config.json"
RALPH_STATE="${BASE}/5_progress/ralph-wave-${WAVE}.json"
RALPH_PID="${BASE}/5_progress/ralph-wave-${WAVE}.pid"
RALPH_HEARTBEAT="${BASE}/5_progress/ralph-wave-${WAVE}.heartbeat"

fail() { echo "❌ Wave ${WAVE} Gate FAILED: $1" >&2 ; exit 1 ; }
step() { echo "→ [$(date +%H:%M:%S)] $1" ; }

# Run a command with a timeout; fail with a descriptive message on timeout.
# Usage: run_with_timeout <seconds> <label> <cmd...>
run_with_timeout() {
  local secs="$1" ; shift
  local label="$1" ; shift
  local start=$(date +%s)
  set +e
  timeout --foreground "${secs}" "$@"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    local elapsed=$(( $(date +%s) - start ))
    if [[ $rc -eq 124 ]]; then
      fail "${label} timed out after ${secs}s (elapsed ${elapsed}s)"
    fi
    fail "${label} failed with exit ${rc} (elapsed ${elapsed}s)"
  fi
  local elapsed=$(( $(date +%s) - start ))
  echo "   ✓ ${label} done in ${elapsed}s"
}

[[ -f "$CFG" ]]       || fail "config missing: $CFG"
[[ -f "$PROGRESS" ]]  || fail "progress missing: $PROGRESS"
command -v jq >/dev/null || fail "jq not installed"

WAVE_KEY=".waves[\"${WAVE}\"]"
jq -e "$WAVE_KEY" "$CFG" >/dev/null || fail "wave ${WAVE} not configured in $CFG"

# Timeouts are config-owned so every agent and rerun uses the same budget.
AC_TIMEOUT=$(jq -er '.timeouts.ac_seconds' "$CFG") || fail "timeouts.ac_seconds missing in $CFG"
BUILD_TIMEOUT=$(jq -er '.timeouts.build_seconds' "$CFG") || fail "timeouts.build_seconds missing in $CFG"
CODERABBIT_TIMEOUT=$(jq -er '.timeouts.coderabbit_seconds' "$CFG") || fail "timeouts.coderabbit_seconds missing in $CFG"
BROWSER_TIMEOUT=$(jq -er '.timeouts.browser_seconds' "$CFG") || fail "timeouts.browser_seconds missing in $CFG"
for pair in "ac_seconds:$AC_TIMEOUT" "build_seconds:$BUILD_TIMEOUT" "coderabbit_seconds:$CODERABBIT_TIMEOUT" "browser_seconds:$BROWSER_TIMEOUT"; do
  key="${pair%%:*}"
  value="${pair#*:}"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]] || fail "invalid timeout ${key}='${value}' in $CFG"
done

# Long Ralph runs are resumable. This is deliberately not state.json: it is
# ephemeral verification evidence, kept beside progress.md and written after
# every command so an interrupted run never loses already-green ACs.
RALPH_STALL_SECONDS=$(jq -r '.timeouts.ralph_stall_seconds // .timeouts.ac_seconds' "$CFG")
RATE_LIMIT_BACKOFF_SECONDS=$(jq -r "${WAVE_KEY}.rate_limit_backoff_seconds // .rate_limit_backoff_seconds // 330" "$CFG")
AUTH_PACING_SECONDS=$(jq -r "${WAVE_KEY}.auth_pacing_seconds // 0" "$CFG")
for pair in "ralph_stall_seconds:$RALPH_STALL_SECONDS" "rate_limit_backoff_seconds:$RATE_LIMIT_BACKOFF_SECONDS" "auth_pacing_seconds:$AUTH_PACING_SECONDS"; do
  key="${pair%%:*}"
  value="${pair#*:}"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "invalid ${key}='${value}' in $CFG"
done

heartbeat() { date +%s > "$RALPH_HEARTBEAT"; }

sleep_with_heartbeat() {
  local remaining="$1" chunk
  while [[ "$remaining" -gt 0 ]]; do
    chunk=$(( remaining > 30 ? 30 : remaining ))
    sleep "$chunk"
    remaining=$(( remaining - chunk ))
    heartbeat
  done
}

init_ralph_state() {
  [[ -f "$RALPH_STATE" ]] && return
  local tmp
  tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
  jq -n --arg wave "$WAVE" --arg started "$(date -Iseconds)" \
    '{version: 1, wave: $wave, started_at: $started, updated_at: $started, ralph_status: "running", commands: []}' \
    > "$tmp"
  mv "$tmp" "$RALPH_STATE"
}

record_ac() {
  local index="$1" command="$2" attempts="$3" rc="$4" selected="$5" status="$6" log="$7" tmp
  tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
  jq --argjson index "$index" --arg command "$command" --argjson attempts "$attempts" \
    --argjson rc "$rc" --argjson selected "$selected" --arg status "$status" \
    --arg log "$log" --arg updated "$(date -Iseconds)" '
      .updated_at = $updated |
      .commands = ((.commands // []) | map(select(.index != $index)) +
        [{index: $index, command: $command, attempts: $attempts, rc: $rc,
          selected: $selected, status: $status, log: $log, updated_at: $updated}])
    ' "$RALPH_STATE" > "$tmp" && mv "$tmp" "$RALPH_STATE"
}

selected_count() {
  local log="$1" match
  match=$(grep -Eo 'Running[[:space:]]+[0-9]+[[:space:]]+tests?' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<< "$match" | head -1; return; }
  match=$(grep -Eo 'Tests[[:space:]]+[0-9]+[[:space:]]+passed' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<< "$match" | head -1; return; }
  match=$(grep -Eo '^#[[:space:]]+tests[[:space:]]+[0-9]+' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<< "$match" | tail -1; return; }
  match=$(grep -Eo '(^|[^0-9])[0-9]+[[:space:]]+passed([[:space:]]|$)' "$log" 2>/dev/null | head -1 || true)
  [[ -n "$match" ]] && { grep -Eo '[0-9]+' <<< "$match" | head -1; return; }
  echo 0
}

provider_rate_limited() {
  grep -Eiq 'over_request_rate_limit|Request[[:space:]]+rate[[:space:]]+limit[[:space:]]+reached|HTTP(/[0-9.]+)?[[:space:]]+429([^0-9]|$)|"status"[[:space:]]*:[[:space:]]*429([^0-9]|$)|status[[:space:]]*=[[:space:]]*429([^0-9]|$)' "$1"
}

ralph_status() {
  [[ -f "$RALPH_STATE" ]] || fail "no Ralph state recorded: $RALPH_STATE"
  local pid="" heartbeat_at="" age="" heartbeat_age_json=0 state_status
  [[ -f "$RALPH_PID" ]] && pid=$(tr -cd '0-9' < "$RALPH_PID")
  [[ -f "$RALPH_HEARTBEAT" ]] && heartbeat_at=$(tr -cd '0-9' < "$RALPH_HEARTBEAT")
  if [[ -n "$heartbeat_at" ]]; then age=$(( $(date +%s) - heartbeat_at )); heartbeat_age_json="$age"; else age="unknown"; fi
  jq --arg pid "$pid" --argjson heartbeat_age "$heartbeat_age_json" '. + {pid: ($pid | if . == "" then null else tonumber end), heartbeat_age_seconds: $heartbeat_age}' "$RALPH_STATE"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    [[ "$age" == "unknown" || "$age" -le "$RALPH_STALL_SECONDS" ]] || fail "Ralph PID ${pid} is alive but made no progress for ${age}s (limit ${RALPH_STALL_SECONDS}s)"
    return
  fi
  state_status=$(jq -r '.ralph_status // "running"' "$RALPH_STATE")
  [[ -z "$pid" && "$state_status" == complete ]] && return
  [[ -z "$pid" ]] && fail "Ralph state is ${state_status} but has no PID; rerun the gate to resume from $RALPH_STATE"
  fail "Ralph PID ${pid} is not alive; rerun the gate to resume from $RALPH_STATE"
}

if [[ "$STATUS_ONLY" == true ]]; then
  ralph_status
  exit 0
fi

# CodeRabbit findings whose severity is listed here are logged as advisory.
# Everything else blocks.
jq -e "${WAVE_KEY}.advisory_severities | type == \"array\"" "$CFG" >/dev/null \
  || fail "waves.${WAVE}.advisory_severities missing or not an array in $CFG"
mapfile -t ADVISORY_SEVERITIES < <(jq -r "${WAVE_KEY}.advisory_severities[] | ascii_downcase" "$CFG")
if [[ "${#ADVISORY_SEVERITIES[@]}" -eq 0 ]]; then
  ADVISORY_JSON='[]'
else
  ADVISORY_JSON=$(printf '%s\n' "${ADVISORY_SEVERITIES[@]}" | jq -R . | jq -cs .)
fi
ADVISORY_LABEL=$(IFS=, ; echo "${ADVISORY_SEVERITIES[*]:-none}")

echo "=== Wave ${WAVE} Completion Gate — advisory severities: ${ADVISORY_LABEL} (PROJ-${PROJ}-${THEMA}) ==="

# ─── 1. Ralph: AC checks ────────────────────────────────────────────────────
step "1/6 Ralph: AC verification"
AC_COUNT=$(jq -r "${WAVE_KEY}.ac_commands | length" "$CFG")
if [[ "$AC_COUNT" -eq 0 ]]; then
  fail "no ac_commands defined for wave ${WAVE}"
fi

init_ralph_state
if [[ -f "$RALPH_PID" ]]; then
  previous_pid=$(tr -cd '0-9' < "$RALPH_PID")
  if [[ -n "$previous_pid" ]] && kill -0 "$previous_pid" 2>/dev/null; then
    ralph_status
    fail "Ralph is already running as PID ${previous_pid}; use --status, never pgrep"
  fi
  echo "   ⚠ stale Ralph PID ${previous_pid:-unknown}; resuming recorded AC results"
  rm -f "$RALPH_PID"
fi
printf '%s\n' "$$" > "$RALPH_PID"
heartbeat
trap 'rm -f "$RALPH_PID"' EXIT

LAST_AUTH="${BASE}/5_progress/ralph-wave-${WAVE}.auth-last"
for ((index = 0; index < AC_COUNT; index++)); do
  entry=$(jq -c "${WAVE_KEY}.ac_commands[$index]" "$CFG")
  entry_type=$(jq -r 'type' <<< "$entry")
  case "$entry_type" in
    string) command=$(jq -r . <<< "$entry"); auth_consuming=false ;;
    object)
      command=$(jq -r '.command // empty' <<< "$entry")
      auth_consuming=$(jq -r '.auth_consuming // false' <<< "$entry")
      [[ "$auth_consuming" == true || "$auth_consuming" == false ]] || fail "AC $((index + 1)) auth_consuming must be boolean"
      ;;
    *) fail "AC $((index + 1)) must be a command string or {command, auth_consuming}" ;;
  esac
  [[ -n "$command" ]] || fail "AC $((index + 1)) command is empty"

  if jq -e --argjson index "$index" '.commands[]? | select(.index == $index and .status == "passed" and .rc == 0 and .selected > 0)' "$RALPH_STATE" >/dev/null; then
    echo "   ✓ AC $((index + 1)) already green; skipped (recorded state)"
    continue
  fi

  if [[ "$auth_consuming" == true && "$AUTH_PACING_SECONDS" -gt 0 && -f "$LAST_AUTH" ]]; then
    last_auth=$(tr -cd '0-9' < "$LAST_AUTH")
    wait_for=$(( AUTH_PACING_SECONDS - ($(date +%s) - last_auth) ))
    if [[ "$wait_for" -gt 0 ]]; then
      echo "   ⏳ AC $((index + 1)) consumes auth budget; pacing ${wait_for}s"
      sleep_with_heartbeat "$wait_for"
    fi
  fi

  attempts=$(jq -r --argjson index "$index" '[.commands[]? | select(.index == $index)][0].attempts // 0' "$RALPH_STATE")
  for retry in 1 2; do
    attempts=$((attempts + 1))
    log="${BASE}/5_progress/ralph-wave-${WAVE}-ac-$((index + 1))-attempt-${attempts}.log"
    effective_timeout=$(( AC_TIMEOUT < RALPH_STALL_SECONDS ? AC_TIMEOUT : RALPH_STALL_SECONDS ))
    echo "   $ $command"
    heartbeat
    [[ "$auth_consuming" == true ]] && date +%s > "$LAST_AUTH"
    set +e
    timeout --foreground "$effective_timeout" bash -c "$command" > "$log" 2>&1
    rc=$?
    set -e
    selected=$(selected_count "$log")
    heartbeat
    if [[ "$rc" -eq 0 && "$selected" -gt 0 ]]; then
      record_ac "$index" "$command" "$attempts" "$rc" "$selected" passed "$log"
      echo "   ✓ AC $((index + 1)): ${selected} selected test(s), attempt ${attempts}"
      break
    fi
    if [[ "$rc" -eq 0 ]]; then
      record_ac "$index" "$command" "$attempts" "$rc" "$selected" failed_empty_selection "$log"
      fail "AC $((index + 1)) selected 0 tests despite rc=0 (log: $log)"
    fi
    if [[ "$rc" -eq 124 ]]; then
      record_ac "$index" "$command" "$attempts" "$rc" "$selected" stalled "$log"
      fail "AC $((index + 1)) made no completed progress for ${effective_timeout}s (log: $log)"
    fi
    if provider_rate_limited "$log" && [[ "$retry" -eq 1 ]]; then
      record_ac "$index" "$command" "$attempts" "$rc" "$selected" rate_limited "$log"
      echo "   ⚠ provider rate limit in AC $((index + 1)); pausing ${RATE_LIMIT_BACKOFF_SECONDS}s, then retrying once (log: $log)"
      sleep_with_heartbeat "$RATE_LIMIT_BACKOFF_SECONDS"
      continue
    fi
    record_ac "$index" "$command" "$attempts" "$rc" "$selected" failed "$log"
    fail "AC $((index + 1)) failed rc=${rc}, selected=${selected} (log: $log)"
  done
done
rm -f "$RALPH_PID"
trap - EXIT
tmp=$(mktemp "${RALPH_STATE}.tmp.XXXXXX")
jq --arg updated "$(date -Iseconds)" '.ralph_status = "complete" | .updated_at = $updated' "$RALPH_STATE" > "$tmp" && mv "$tmp" "$RALPH_STATE"

# ─── 2. Build ───────────────────────────────────────────────────────────────
step "2/6 Build"
BUILD_CMD=$(jq -r '.build_cmd // empty' "$CFG")
[[ -n "$BUILD_CMD" ]] || fail "build_cmd missing in config"
echo "   $ $BUILD_CMD"
run_with_timeout "$BUILD_TIMEOUT" "build" bash -c "$BUILD_CMD"

# ─── 3. CodeRabbit (non-advisory severities must be zero) ───────────────────
step "3/6 CodeRabbit wave review"
command -v coderabbit >/dev/null || fail "coderabbit not installed"

# Wave base SHA resolution is intentionally hard: env override or explicit tag.
# No commit-message, HEAD~20, or root fallback, because wide reviews bury signal.
WAVE_BASE="${WAVE_BASE_SHA:-}"
if [[ -n "$WAVE_BASE" ]]; then
  git rev-parse --verify "${WAVE_BASE}^{commit}" >/dev/null 2>&1 \
    || fail "WAVE_BASE_SHA env set to '${WAVE_BASE}' but this commit does not exist"
  echo "   base source: \$WAVE_BASE_SHA env override"
else
  WAVE_BASE=$(git rev-parse --verify "wave-${WAVE}-start-PROJ-${PROJ}^{commit}" 2>/dev/null || true)
  [[ -n "$WAVE_BASE" ]] || fail "missing wave base. Set WAVE_BASE_SHA or create tag wave-${WAVE}-start-PROJ-${PROJ}; no fallback is allowed."
  echo "   base source: git tag wave-${WAVE}-start-PROJ-${PROJ}"
fi
echo "   base: $WAVE_BASE"

COMMITS_SINCE=$(git rev-list --count "${WAVE_BASE}..HEAD" 2>/dev/null || echo "?")
FILES_CHANGED=$(git diff --name-only "${WAVE_BASE}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
echo "   diff scope: ${COMMITS_SINCE} commits, ${FILES_CHANGED} files"
 # CodeRabbit's review ceiling is a hard boundary, not an excuse to omit
 # review. A green gate must mean the entire wave was reviewable.
 if [[ "$FILES_CHANGED" -gt 150 ]]; then
   fail "CodeRabbit review scope is ${FILES_CHANGED} files (limit 150). Split the wave or establish a narrower reviewed base; do not continue without a complete review."
 fi

CR_OUT=$(mktemp)
CR_START=$(date +%s)
set +e
timeout --foreground "$CODERABBIT_TIMEOUT" \
  coderabbit review --agent --base-commit "$WAVE_BASE" > "$CR_OUT"
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  elapsed=$(( $(date +%s) - CR_START ))
  if [[ $rc -eq 124 ]]; then
    fail "coderabbit review timed out after ${CODERABBIT_TIMEOUT}s (elapsed ${elapsed}s, raw: $CR_OUT). Increase timeouts.coderabbit_seconds in $CFG."
  fi
  fail "coderabbit review errored rc=${rc} (elapsed ${elapsed}s, see $CR_OUT)"
fi
echo "   ✓ coderabbit done in $(( $(date +%s) - CR_START ))s"

BLOCKING=$( { grep -E '^\{.*\}$' "$CR_OUT" 2>/dev/null || true; } | jq -rs --argjson advisory "$ADVISORY_JSON" '
  [ .[]
    | (.severity? // .priority? // .level? // "" | tostring | ascii_downcase) as $sev
    | select($sev != "" and (($advisory | index($sev)) | not))
  ] | length
' 2>/dev/null)
ADVISORY=$( { grep -E '^\{.*\}$' "$CR_OUT" 2>/dev/null || true; } | jq -rs --argjson advisory "$ADVISORY_JSON" '
  [ .[]
    | (.severity? // .priority? // .level? // "" | tostring | ascii_downcase) as $sev
    | select($sev != "" and (($advisory | index($sev)) != null))
  ] | length
' 2>/dev/null)
BLOCKING=${BLOCKING:-0}
ADVISORY=${ADVISORY:-0}
[[ "$ADVISORY" -gt 0 ]] && echo "   ⚠ ${ADVISORY} advisory finding(s): ${ADVISORY_LABEL}"

# Findings ledger ingest (framework runs): all CodeRabbit findings flow
# into findings.json via ledger.mjs — deduplicated, never re-entered by hand.
# No ledger.mjs in the project → plain pre-framework behavior, no-op.
if [[ -f scripts/ledger.mjs ]] && command -v node >/dev/null; then
  grep -E '^\{.*\}$' "$CR_OUT" 2>/dev/null | jq -c '
    { source: "coderabbit",
      severity: ((.severity? // .priority? // .level? // "low") | tostring | ascii_downcase),
      category: ((.category? // "review") | tostring),
      summary: ((.message? // .description? // .title? // "coderabbit finding") | tostring),
      file: ((.file? // .path? // empty) | tostring),
      line: (.line? // .startLine? // empty) }
    | with_entries(select(.value != null and .value != ""))
  ' 2>/dev/null | node scripts/ledger.mjs add "$PROJ" "$THEMA" --wave "$WAVE" \
    && echo "   ✓ findings ingested into ledger" \
    || echo "   ⚠ ledger ingest skipped (no parseable findings)"
fi

if [[ "$BLOCKING" -ne 0 ]]; then
  echo "   blocking findings:"
  grep -E '^\{.*\}$' "$CR_OUT" | jq -c --argjson advisory "$ADVISORY_JSON" '
    (.severity? // .priority? // .level? // "" | tostring | ascii_downcase) as $sev
    | select($sev != "" and (($advisory | index($sev)) | not))
  '
  fail "${BLOCKING} non-advisory CodeRabbit finding(s) remain (raw output: $CR_OUT)"
fi
rm -f "$CR_OUT"

# ─── 4. Sonar local scan + secrets check ────────────────────────────────────
# Skippable per CONCEPT.md §7: missing CLI or missing config → logged skip,
# never a silent one. The command is config-owned (.sonar_cmd) — this script
# does not guess CLI flags.
step "4/6 Sonar local scan + secrets check"
SONAR_CMD=$(jq -r '.sonar_cmd // empty' "$CFG")
SONAR_STATUS="skipped"
if ! command -v sonar >/dev/null; then
  echo "   (sonar CLI not installed — SKIPPED, logged)"
elif [[ -z "$SONAR_CMD" ]]; then
  echo "   (no sonar_cmd in $CFG — SKIPPED, logged)"
else
  SONAR_TIMEOUT=$(jq -r '.timeouts.sonar_seconds // 120' "$CFG")
  echo "   $ $SONAR_CMD"
  run_with_timeout "$SONAR_TIMEOUT" "sonar local scan" bash -c "$SONAR_CMD"
  SONAR_STATUS="green"
fi

# ─── 5. Smoke test ──────────────────────────────────────────────────────────
step "5/6 Browser smoke test"
mapfile -t ROUTES < <(jq -r "${WAVE_KEY}.frontend_routes[]? // empty" "$CFG")
if [[ "${#ROUTES[@]}" -eq 0 ]]; then
  echo "   (backend-only wave — skipped)"
else
  if command -v agent-browser >/dev/null; then
    BASE_URL=$(jq -r '.dev_url // "http://localhost:3000"' "$CFG")
    for route in "${ROUTES[@]}"; do
      [[ -z "$route" ]] && continue
      echo "   $ agent-browser open ${BASE_URL}${route}"
      run_with_timeout "$BROWSER_TIMEOUT" "smoke ${route}" \
        bash -c 'agent-browser open "$1" && agent-browser read && agent-browser errors' _ "${BASE_URL}${route}"
    done
  else
    fail "agent-browser not installed but frontend routes defined"
  fi
fi

step "6/6 Component registry"
# The registry is generated from the component doc blocks. A stale file or an
# undocumented component blocks the wave — this replaces the per-edit hook.
if [[ -f scripts/gen-component-registry.mjs ]]; then
  if [[ -d src/components || -d src/features ]]; then
    set +e
    node scripts/gen-component-registry.mjs --check
    REG_RC=$?
    set -e
    case "$REG_RC" in
      0) ;;
      # exit 3 = registry still hand-written; the migration is a human call and
      # must not block waves. Reported every gate so it stays visible.
      3) echo "   (registry not migrated yet — reported, not blocking)" ;;
      *) fail "component registry out of date or component missing its doc block" ;;
    esac
  else
    echo "   (no component directories — skipped)"
  fi
else
  echo "   (scripts/gen-component-registry.mjs not installed — skipped)"
fi

# ─── Record in progress.md ──────────────────────────────────────────────────
TS=$(date -Iseconds)
ROUTES_STR="${ROUTES[*]:-backend-only}"

cat >> "$PROGRESS" <<EOF

### Wave ${WAVE} Gate — PASSED ($TS)
- [x] Ralph: ${AC_COUNT} AC commands green
- [x] Build: \`${BUILD_CMD}\`
- [x] CodeRabbit: 0 non-advisory findings (advisory severities: ${ADVISORY_LABEL})
- [x] Sonar: ${SONAR_STATUS}
- [x] Component registry: generated + current
- [x] Smoke: ${ROUTES_STR}
EOF

echo "✅ Wave ${WAVE} Gate PASSED"

# ─── Auto-tag the NEXT wave's base SHA ──────────────────────────────────────
# HEAD at this point = end of Wave N = start of Wave N+1. Tagging it here
# means Skill 5 Step 2a becomes a belt-and-braces for Wave 1 only; the main
# agent cannot forget to tag for Wave 2+.
NEXT=$((WAVE + 1))
NEXT_TAG="wave-${NEXT}-start-PROJ-${PROJ}"
if git rev-parse --verify "${NEXT_TAG}^{commit}" >/dev/null 2>&1; then
  echo "   tag ${NEXT_TAG} already exists — leaving untouched"
else
  git tag "$NEXT_TAG" HEAD 2>/dev/null && \
    echo "   tagged: ${NEXT_TAG} → HEAD (base for Wave ${NEXT} CodeRabbit review)" || \
    echo "   (could not create tag ${NEXT_TAG} — continuing)"
fi

# ─── NEXT ACTION hint (biases the lead agent to auto-continue) ──────────────
NEXT_PLAN="${BASE}/3-4_plan/PROJ-${PROJ}-wave-${NEXT}-plan.md"
echo ""
if [[ -f "$NEXT_PLAN" ]]; then
  echo "→ NEXT ACTION: Start Wave ${NEXT} NOW. Read ${NEXT_PLAN} and spawn teammates immediately."
  echo "  Do NOT pause. Do NOT ask the user. Do NOT summarize. The gate is the signal."
else
  echo "→ NEXT ACTION: All waves complete for PROJ-${PROJ}-${THEMA}."
  echo "  Start Skill 5 Step 9 Quality Gate: run code-reviewer-gate + optional sonar-cli stream."
  echo "  After Quality Gate passes → /compact → invoke /6_qa (see Skill 5 Step 11 handoff)."
fi
