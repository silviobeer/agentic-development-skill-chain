#!/usr/bin/env bash
# preflight.sh — P0 tool/auth preflight against the CONCEPT.md §7 CLI list.
#
# Checks presence AND auth state (not just command -v), including a bounded
# live probe per provider (claude hard, codex degradable). Behavior per §7:
#   - HARD tool missing/unauth -> exit 1 = stop condition, never skipped silently
#     (git, gh + auth, claude + live probe, node, jq, coderabbit + auth)
#   - skippable tool missing   -> logged skip (sonar [+ auth], sonar-scanner, supabase)
#   - codex missing/unauth/probe-fail -> NOT fatal: degraded single-provider
#                                 run, recorded in state.json and flagged in
#                                 the morning report + PR body (never silent)
#   - agent-browser            -> hard only if any wave has frontend_routes
# Env: PREFLIGHT_PROBE_TIMEOUT (default 90) · PREFLIGHT_SKIP_LIVE_PROBE=1
#      skips the LLM probes (test use only — never for real overnight runs)
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

# --- auth states + bounded live probes (§7: not just command -v) --------
# The two LLM probes prove each provider can actually complete a headless
# call before an unattended run depends on it. PREFLIGHT_SKIP_LIVE_PROBE=1
# skips them for fast test runs only — never set it for a real overnight run.
PROBE_TIMEOUT="${PREFLIGHT_PROBE_TIMEOUT:-90}"
CLAUDE_STATE="ok"

if have gh; then
  if gh auth status >/dev/null 2>&1; then say "✓ gh auth"; else say "❌ gh auth BROKEN (hard)"; HARD_MISSING+=("gh-auth"); fi
fi
if have coderabbit; then
  if coderabbit auth status >/dev/null 2>&1; then
    say "✓ coderabbit auth"
  else
    say "❌ coderabbit auth BROKEN (hard — gate component, §7)"
    HARD_MISSING+=("coderabbit-auth")
  fi
fi
if have claude; then
  if [ "${PREFLIGHT_SKIP_LIVE_PROBE:-0}" = "1" ]; then
    say "– claude live probe SKIPPED (PREFLIGHT_SKIP_LIVE_PROBE=1 — test use only)"
  elif timeout --foreground "$PROBE_TIMEOUT" claude -p "Reply with exactly: OK" </dev/null >/dev/null 2>&1; then
    say "✓ claude live probe (bounded, ${PROBE_TIMEOUT}s)"
  else
    say "❌ claude live probe FAILED (hard — it hosts the chain)"
    CLAUDE_STATE="unauthenticated"
    HARD_MISSING+=("claude-probe")
  fi
fi

# --- codex: preferred, degradable (§7) ----------------------------------
if ! have codex; then
  CODEX_STATE="missing"
  DEGRADED_REASON="codex CLI missing"
elif ! codex login status >/dev/null 2>&1; then
  CODEX_STATE="unauthenticated"
  DEGRADED_REASON="codex CLI unauthenticated"
elif [ "${PREFLIGHT_SKIP_LIVE_PROBE:-0}" = "1" ]; then
  say "– codex live probe SKIPPED (PREFLIGHT_SKIP_LIVE_PROBE=1 — test use only)"
elif ! timeout --foreground "$PROBE_TIMEOUT" codex exec --sandbox read-only --skip-git-repo-check "Reply with exactly: OK" </dev/null >/dev/null 2>&1; then
  CODEX_STATE="unauthenticated"
  DEGRADED_REASON="codex live probe failed"
fi
if [ "$CODEX_STATE" = "ok" ]; then
  say "✓ codex auth + live probe (dual-provider run)"
else
  say "⚠ codex ${CODEX_STATE} → DEGRADED single-provider run; reviews fall back to MODEL-opposite (claude -p --model); flagged in morning report + PR body"
fi

# --- skippable tools (auth checked when present; broken auth = logged skip) --
for tool in sonar sonar-scanner supabase; do
  if have "$tool"; then say "✓ $tool"; else say "– $tool missing: skip (logged)"; SKIPPED+=("$tool"); fi
done
if have sonar; then
  if [ -n "${SONAR_TOKEN:-}" ] || sonar auth status >/dev/null 2>&1; then
    say "✓ sonar auth (SONAR_TOKEN or auth status)"
  else
    say "– sonar present but auth unverified (no SONAR_TOKEN) — wave-gate sonar stage will skip with a log entry"
    SKIPPED+=("sonar-auth")
  fi
fi

# --- ponytail install + parity gate (context system, §7) -----------------
# Ponytail is the single source of the minimalism ladder on both providers.
# Absence or version/mode mismatch is HARD (PONYTAIL_ENFORCE=0 is the loud,
# recorded escape hatch — never silent). Degraded runs gate the surviving
# provider alone.
PONYTAIL_JSON=""
PONYTAIL_ARGS=(--json)
[ "$CODEX_STATE" = "ok" ] || PONYTAIL_ARGS+=(--codex-inactive)
set +e
PONYTAIL_JSON="$(bash "$SCRIPT_DIR/ponytail-check.sh" "${PONYTAIL_ARGS[@]}" 2>/dev/null)"
PONYTAIL_RC=$?
set -e
if [ "$PONYTAIL_RC" -eq 0 ]; then
  if [ -n "$PONYTAIL_JSON" ] && [ "$(jq -r '.parity_ok' <<<"$PONYTAIL_JSON" 2>/dev/null)" = "true" ]; then
    say "✓ ponytail parity ($(jq -r '"claude " + .claude.version + (if .codex.active then ", codex " + .codex.version else " (codex inactive)" end) + ", mode " + .claude.mode' <<<"$PONYTAIL_JSON"))"
  else
    say "⚠ ponytail gate failed but PONYTAIL_ENFORCE=0 — run continues WITHOUT the ladder (recorded enforced:false; flagged)"
  fi
else
  say "❌ ponytail MISSING or parity mismatch (hard) — run 'bash $SCRIPT_DIR/ponytail-check.sh' for the install commands"
  HARD_MISSING+=("ponytail")
fi

# --- context bundles: verify when compiled (§5 budget gate is HARD) -------
if [ -f "$BASE/context/bundles.lock.json" ]; then
  if node "$SCRIPT_DIR/compile-context-bundles.mjs" verify "$PROJ" "$THEME" >/dev/null 2>&1; then
    say "✓ context bundles verify (hashes match, budgets hold)"
  else
    say "❌ context bundles verify FAILED (budget breach or drift, hard) — condense docs/, recompile (4b_setup step 6a)"
    HARD_MISSING+=("context-bundles")
  fi
else
  say "– context bundles not compiled yet (4b_setup step 6a runs after this preflight)"
fi

# --- record + verdict ---------------------------------------------------
OK=true
[ ${#HARD_MISSING[@]} -eq 0 ] || OK=false

if [ -f "$BASE/state.json" ]; then
  PREFLIGHT_JSON="$(jq -n \
    --arg at "$(date -Iseconds)" \
    --argjson ok "$OK" \
    --argjson hard "$(printf '%s\n' "${HARD_MISSING[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')" \
    --argjson skipped "$(printf '%s\n' "${SKIPPED[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')" \
    --arg claude "$CLAUDE_STATE" \
    --arg codex "$CODEX_STATE" \
    '{at: $at, ok: $ok, hard_missing: $hard, skipped: $skipped, providers: {claude: $claude, codex: $codex}}')"
  "$STATE_SH" set "$PROJ" "$THEME" .preflight "$PREFLIGHT_JSON" >/dev/null
  if [ -n "$PONYTAIL_JSON" ]; then
    "$STATE_SH" set "$PROJ" "$THEME" .context.ponytail "$PONYTAIL_JSON" >/dev/null \
      || say "⚠ could not record .context.ponytail (state validation?)"
  fi
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
