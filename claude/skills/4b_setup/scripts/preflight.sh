#!/usr/bin/env bash
# preflight.sh — P0 tool/auth preflight against the CONCEPT.md §7 CLI list.
#
# Checks presence AND auth state (not just command -v). Behavior per §7:
#   - HARD tool missing        -> exit 1 = stop condition, never skipped silently
#   - skippable tool missing   -> logged skip (sonar, sonar-scanner, supabase)
#   - codex missing/unauth     -> NOT fatal: degraded single-provider run,
#                                 recorded in state.json and flagged in the
#                                 morning report + PR body (never silent)
#   - agent-browser            -> hard only if any wave has frontend_routes
# Writes the preflight block into state.json via state.sh when it exists;
# otherwise prints the report only.
#
# Usage:  preflight.sh <proj-x> <theme>
# Exit:   0 ok (possibly degraded) · 1 hard tool missing (stop condition) · 64 usage
set -euo pipefail

PROJ="${1:-}"; THEME="${2:-}"
if [ -z "$PROJ" ] || [ -z "$THEME" ]; then
  echo "Usage: $0 <proj-x> <theme>" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_SH="$SCRIPT_DIR/state.sh"
BASE="specs/PROJ-${PROJ}-${THEME}"
GATE_CFG="$BASE/6_plan/wave-gate-config.json"

HARD_MISSING=()
SKIPPED=()
DEGRADED_REASON=""
CODEX_STATE="ok"

say()  { echo "  $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "→ P0 preflight (PROJ-${PROJ}-${THEME})"

# --- hard tools ---------------------------------------------------------
for tool in git gh claude node jq coderabbit; do
  if have "$tool"; then say "✓ $tool"; else say "❌ $tool MISSING (hard)"; HARD_MISSING+=("$tool"); fi
done

# npm or pnpm — hard when the project builds with node (package.json present)
if [ -f package.json ]; then
  if have pnpm || have npm; then say "✓ npm/pnpm"; else say "❌ npm/pnpm MISSING (hard — package.json present)"; HARD_MISSING+=("npm/pnpm"); fi
else
  say "– npm/pnpm: no package.json, not required"
fi

# agent-browser — hard only if any planned wave has frontend routes
if [ -f "$GATE_CFG" ] && jq -e '[.waves[]?.frontend_routes[]?] | length > 0' "$GATE_CFG" >/dev/null 2>&1; then
  if have agent-browser; then say "✓ agent-browser (frontend waves planned)"; else say "❌ agent-browser MISSING (hard — frontend waves planned)"; HARD_MISSING+=("agent-browser"); fi
else
  if have agent-browser; then say "✓ agent-browser"; else say "– agent-browser missing: no frontend waves planned — skip"; SKIPPED+=("agent-browser"); fi
fi

# --- auth states --------------------------------------------------------
if have gh; then
  if gh auth status >/dev/null 2>&1; then say "✓ gh auth"; else say "❌ gh auth BROKEN (hard)"; HARD_MISSING+=("gh-auth"); fi
fi
if have coderabbit; then
  if coderabbit auth status >/dev/null 2>&1; then
    say "✓ coderabbit auth"
  else
    say "⚠ coderabbit auth not verifiable — will surface at the first wave gate"
  fi
fi

# --- codex: preferred, degradable (§7) ----------------------------------
if ! have codex; then
  CODEX_STATE="missing"
  DEGRADED_REASON="codex CLI missing"
elif ! codex login status >/dev/null 2>&1; then
  CODEX_STATE="unauthenticated"
  DEGRADED_REASON="codex CLI unauthenticated"
fi
if [ "$CODEX_STATE" = "ok" ]; then
  say "✓ codex (dual-provider run)"
else
  say "⚠ codex ${CODEX_STATE} → DEGRADED single-provider run; reviews fall back to MODEL-opposite (claude -p --model); flagged in morning report + PR body"
fi

# --- skippable tools ----------------------------------------------------
for tool in sonar sonar-scanner supabase; do
  if have "$tool"; then say "✓ $tool"; else say "– $tool missing: skip (logged)"; SKIPPED+=("$tool"); fi
done

# Ponytail parity check across active providers: Stage 2 (context system).
say "– ponytail parity check: Stage 2, not yet enforced"

# --- record + verdict ---------------------------------------------------
OK=true
[ ${#HARD_MISSING[@]} -eq 0 ] || OK=false

if [ -f "$BASE/state.json" ]; then
  PREFLIGHT_JSON="$(jq -n \
    --arg at "$(date -Iseconds)" \
    --argjson ok "$OK" \
    --argjson hard "$(printf '%s\n' "${HARD_MISSING[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')" \
    --argjson skipped "$(printf '%s\n' "${SKIPPED[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')" \
    --arg codex "$CODEX_STATE" \
    '{at: $at, ok: $ok, hard_missing: $hard, skipped: $skipped, providers: {claude: "ok", codex: $codex}}')"
  "$STATE_SH" set "$PROJ" "$THEME" .preflight "$PREFLIGHT_JSON" >/dev/null
  if [ "$CODEX_STATE" != "ok" ]; then
    "$STATE_SH" set "$PROJ" "$THEME" .degraded true >/dev/null
    "$STATE_SH" set "$PROJ" "$THEME" .degraded_reason "$DEGRADED_REASON" >/dev/null
  fi
  say "✓ preflight block written to $BASE/state.json"
else
  say "⚠ $BASE/state.json missing — report not persisted (run 4a_checkpoint first)"
fi

if [ "$OK" = false ]; then
  echo "❌ preflight FAILED — hard tools missing: ${HARD_MISSING[*]}" >&2
  echo "→ NEXT ACTION: stop condition (§8) — install/authenticate the tools above, then re-run." >&2
  exit 1
fi

if [ "$CODEX_STATE" != "ok" ]; then
  echo "✓ preflight ok (DEGRADED single-provider)"
else
  echo "✓ preflight ok"
fi
