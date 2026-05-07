#!/usr/bin/env bash
#
# wave-gate.sh — Wave Completion Gate
#
# Validates that the current wave is cleanly finished before the next wave
# starts. Exit 0 = pass. Non-zero exit = BLOCK next wave.
#
# Usage:
#   bash scripts/wave-gate.sh <wave-number> <proj-x> <thema>
# Example:
#   bash scripts/wave-gate.sh 2 1 auth
#
# Requires:
#   - jq (for parsing wave-gate-config.json)
#   - The config file at specs/PROJ-<X>-<thema>/6_plan/wave-gate-config.json
#   - coderabbit CLI
#   - agent-browser CLI (for frontend smoke tests when routes are configured)
#
# Copy this file into every project that uses the skill chain, at:
#   scripts/wave-gate.sh
#
set -euo pipefail

WAVE="${1:-}"
PROJ="${2:-}"
THEMA="${3:-}"

if [[ -z "$WAVE" || -z "$PROJ" || -z "$THEMA" ]]; then
  echo "Usage: $0 <wave-number> <proj-x> <thema>" >&2
  exit 64
fi

BASE="specs/PROJ-${PROJ}-${THEMA}"
PROGRESS="${BASE}/7_progress/PROJ-${PROJ}-progress.md"
CFG="${BASE}/6_plan/wave-gate-config.json"

fail() { echo "❌ Wave ${WAVE} Gate FAILED: $1" >&2 ; exit 1 ; }
step() { echo "→ [$(date +%H:%M:%S)] $1" ; }

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

# Run a command with a timeout; fail with a descriptive message on timeout.
# Usage: run_with_timeout <seconds> <label> <cmd...>
run_with_timeout() {
  local secs="$1" ; shift
  local label="$1" ; shift
  local start=$(date +%s)
  if ! timeout --foreground "${secs}" "$@"; then
    local rc=$?
    local elapsed=$(( $(date +%s) - start ))
    if [[ $rc -eq 124 ]]; then
      fail "${label} timed out after ${secs}s (elapsed ${elapsed}s)"
    fi
    fail "${label} failed with exit ${rc} (elapsed ${elapsed}s)"
  fi
  local elapsed=$(( $(date +%s) - start ))
  echo "   ✓ ${label} done in ${elapsed}s"
}

# ─── Advisory severities ─────────────────────────────────────────────────────
# CodeRabbit findings whose severity is listed here are logged as advisory.
# Everything else blocks.
jq -e "${WAVE_KEY}.advisory_severities | type == \"array\"" "$CFG" >/dev/null \
  || fail "waves.${WAVE}.advisory_severities missing or not an array in $CFG"
mapfile -t ADVISORY < <(jq -r "${WAVE_KEY}.advisory_severities[] | ascii_downcase" "$CFG")

is_advisory() {
  local sev="$1"
  for adv in "${ADVISORY[@]:-}"; do
    [[ "$sev" == "$adv" ]] && return 0
  done
  return 1
}

NEXT_PLAN="${BASE}/6_plan/PROJ-${PROJ}-wave-$((WAVE + 1))-plan.md"

echo "=== Wave ${WAVE} Completion Gate (PROJ-${PROJ}-${THEMA}) ==="
echo "   advisory severities: ${ADVISORY[*]:-none}"

# ─── 1. Ralph: AC checks ────────────────────────────────────────────────────
step "1/4 Ralph: AC verification"
AC_COUNT=$(jq -r "${WAVE_KEY}.ac_commands | length" "$CFG")
if [[ "$AC_COUNT" -eq 0 ]]; then
  fail "no ac_commands defined for wave ${WAVE}"
fi

while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  echo "   $ $cmd"
  run_with_timeout "$AC_TIMEOUT" "AC: $cmd" bash -c "$cmd"
done < <(jq -r "${WAVE_KEY}.ac_commands[]" "$CFG")

# ─── 2. Build ───────────────────────────────────────────────────────────────
step "2/4 Build"
BUILD_CMD=$(jq -r '.build_cmd // empty' "$CFG")
[[ -n "$BUILD_CMD" ]] || fail "build_cmd missing in config"
echo "   $ $BUILD_CMD"
run_with_timeout "$BUILD_TIMEOUT" "build" bash -c "$BUILD_CMD"

# ─── 3. CodeRabbit ──────────────────────────────────────────────────────────
step "3/4 CodeRabbit wave review"
command -v coderabbit >/dev/null || fail "coderabbit not installed"
  # Wave base SHA resolution (first match wins, hard-fail otherwise):
  #   1. $WAVE_BASE_SHA env override
  #   2. git tag `wave-<N>-start-PROJ-<X>` (set by Skill 5 Step 2a or prev gate)
  # No silent fallbacks — a missing tag is a real bug, not a slow review.
  WAVE_BASE="${WAVE_BASE_SHA:-}"
  if [[ -n "$WAVE_BASE" ]]; then
    git rev-parse --verify "${WAVE_BASE}^{commit}" >/dev/null 2>&1 \
      || fail "WAVE_BASE_SHA env set to '${WAVE_BASE}' but this commit does not exist"
    echo "   base source: \$WAVE_BASE_SHA env override"
  else
    WAVE_TAG="wave-${WAVE}-start-PROJ-${PROJ}"
    WAVE_BASE=$(git rev-parse --verify "${WAVE_TAG}^{commit}" 2>/dev/null || true)
    if [[ -z "$WAVE_BASE" ]]; then
      fail "no wave base SHA — set env WAVE_BASE_SHA or create tag '${WAVE_TAG}' before running the gate. Skill 5 Step 2a sets this tag for Wave 1; later waves are tagged automatically by the previous gate."
    fi
    echo "   base source: tag ${WAVE_TAG}"
  fi
  echo "   base: $WAVE_BASE"
  COMMITS_SINCE=$(git rev-list --count "${WAVE_BASE}..HEAD" 2>/dev/null || echo "?")
  FILES_CHANGED=$(git diff --name-only "${WAVE_BASE}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
  echo "   diff scope: ${COMMITS_SINCE} commits, ${FILES_CHANGED} files"

  CR_OUT=$(mktemp)
  CR_START=$(date +%s)
  if ! timeout --foreground "$CODERABBIT_TIMEOUT" \
       coderabbit review --agent --base-commit "$WAVE_BASE" > "$CR_OUT"; then
    rc=$?
    elapsed=$(( $(date +%s) - CR_START ))
    if [[ $rc -eq 124 ]]; then
      fail "coderabbit review timed out after ${CODERABBIT_TIMEOUT}s (elapsed ${elapsed}s, raw: $CR_OUT). Bump timeouts.coderabbit in $CFG."
    fi
    fail "coderabbit review errored rc=${rc} (elapsed ${elapsed}s, see $CR_OUT)"
  fi
  echo "   ✓ coderabbit done in $(( $(date +%s) - CR_START ))s"

  # Parse all findings, partition into blocking vs advisory.
  # critical/blocker always block. Anything in advisory_severities warns only.
  # Severity field varies across CodeRabbit versions — read defensively.
  ALL_SEVERITIES=$(grep -E '^\{.*\}$' "$CR_OUT" 2>/dev/null | jq -rs '
    [ .[]
      | (.severity? // .priority? // .level? // "" | tostring | ascii_downcase)
    ] | .[]
  ' 2>/dev/null || true)

  BLOCKING=0
  ADVISORY_COUNT=0
  while IFS= read -r sev; do
    [[ -z "$sev" ]] && continue
    case "$sev" in
      critical|blocker)
        BLOCKING=$((BLOCKING + 1))
        ;;
      *)
        if is_advisory "$sev"; then
          ADVISORY_COUNT=$((ADVISORY_COUNT + 1))
        else
          BLOCKING=$((BLOCKING + 1))
        fi
        ;;
    esac
  done <<< "$ALL_SEVERITIES"

  [[ "$ADVISORY_COUNT" -gt 0 ]] && echo "   ⚠ ${ADVISORY_COUNT} advisory findings (not blocking) — review at PROJ-end Quality Gate"

  if [[ "$BLOCKING" -gt 0 ]]; then
    echo "   blocking findings:"
    grep -E '^\{.*\}$' "$CR_OUT" | jq -c --argjson adv "$(printf '%s\n' "${ADVISORY[@]:-}" | jq -Rsc 'split("\n") | map(select(length > 0))')" '
      (.severity? // .priority? // .level? // "" | tostring | ascii_downcase) as $sev
      | select($sev == "critical" or $sev == "blocker" or ($adv | index($sev) | not))
    '
    fail "${BLOCKING} blocking findings remain (raw output: $CR_OUT)"
  fi
  rm -f "$CR_OUT"

# ─── 4. Smoke test ──────────────────────────────────────────────────────────
step "4/4 Browser smoke test"
mapfile -t ROUTES < <(jq -r "${WAVE_KEY}.frontend_routes[]? // empty" "$CFG")
if [[ "${#ROUTES[@]}" -eq 0 ]]; then
  echo "   (backend-only wave — skipped)"
else
  if command -v agent-browser >/dev/null; then
    BASE_URL=$(jq -r '.dev_url // "http://localhost:3000"' "$CFG")
    for route in "${ROUTES[@]}"; do
      [[ -z "$route" ]] && continue
      echo "   $ agent-browser $BASE_URL$route"
      run_with_timeout "$BROWSER_TIMEOUT" "smoke ${route}" \
        agent-browser --url "${BASE_URL}${route}" \
          --prompt "Verify page renders without console errors, primary happy path works" \
          --exit-on-fail
    done
  else
    fail "agent-browser not installed but frontend routes defined"
  fi
fi

# ─── Record in progress.md (verdict only — Skill 7 derives docs from git) ───
TS=$(date -Iseconds)
ROUTES_STR="${ROUTES[*]:-backend-only}"
BUILD_STATUS="\`$(jq -r '.build_cmd // ""' "$CFG")\`"

cat >> "$PROGRESS" <<EOF

### Wave ${WAVE} Gate — PASSED ($TS)
- [x] Ralph: ${AC_COUNT} AC commands green
- [x] Build: ${BUILD_STATUS}
- [x] CodeRabbit: 0 blocking findings (advisory: ${ADVISORY_COUNT:-0})
- [x] Smoke: ${ROUTES_STR}
EOF

echo "✅ Wave ${WAVE} Gate PASSED"

# ─── Auto-tag the NEXT wave's base SHA ──────────────────────────────────────
# HEAD here = end of Wave N = start of Wave N+1.
NEXT=$((WAVE + 1))
NEXT_TAG="wave-${NEXT}-start-PROJ-${PROJ}"
if git rev-parse --verify "${NEXT_TAG}^{commit}" >/dev/null 2>&1; then
  echo "   tag ${NEXT_TAG} already exists — leaving untouched"
else
  git tag "$NEXT_TAG" HEAD 2>/dev/null && \
    echo "   tagged: ${NEXT_TAG} → HEAD (base for Wave ${NEXT} CodeRabbit review)" || \
    echo "   (could not create tag ${NEXT_TAG} — continuing)"
fi

# ─── NEXT ACTION hint ───────────────────────────────────────────────────────
echo ""
if [[ -f "$NEXT_PLAN" ]]; then
  echo "→ NEXT ACTION: Start Wave ${NEXT} NOW. Read ${NEXT_PLAN} and spawn teammates immediately."
  echo "  Do NOT pause. Do NOT ask the user. Do NOT summarize. The gate is the signal."
else
  echo "→ NEXT ACTION: All waves complete for PROJ-${PROJ}-${THEMA}."
  echo "  Start Skill 5 Step 9 Quality Gate: spawn code-reviewer-gate + sonar-scanner-gate in parallel."
  echo "  Ken Takahashi (Minimalism review) runs once at the PROJ-end Quality Gate, not per wave."
  echo "  After Quality Gate passes → /compact → invoke /6_qa (see Skill 5 Step 11 handoff)."
fi
