#!/usr/bin/env bash
# ponytail-check.sh — Ponytail install + parity gate for P0 (CONCEPT.md §7).
#
# Ponytail (github DietrichGebert/ponytail) is the single source of the
# minimalism ladder on BOTH providers — the context injector deliberately
# carries no ladder of its own. This check verifies, per provider:
#   installed?  version?  mode?  (mode: PONYTAIL_DEFAULT_MODE env, else
#   ~/.config/ponytail/config.json defaultMode, else "full" — persisted to
#   the config if absent: the ONE mutation this script makes, logged)
# and gates PARITY: when both providers are active, Claude and Codex must
# report the SAME plugin version and mode; a mismatch blocks P0. In degraded
# single-provider mode the gate applies to the surviving provider alone.
#
# It also verifies PONYTAIL_SUBAGENT_MATCHER is scoped to the code-writing
# roles (implementer|frontend-implementer|backend-implementer|micro-fixer)
# so reviewer/explore lanes never receive the ladder (warning + export line,
# not a failure — the runner exports it itself).
#
# Rollout: PONYTAIL_ENFORCE=1 (default, spec-true) — absence or parity
# mismatch exits 1 with the exact install commands. PONYTAIL_ENFORCE=0 is a
# LOUD escape hatch: exit 0, enforced:false in the JSON — never silent.
#
# Usage: ponytail-check.sh [--json] [--codex-inactive]
# Env (test overrides): PONYTAIL_CLAUDE_REGISTRY, PONYTAIL_CODEX_CACHE,
#      PONYTAIL_CODEX_CONFIG, PONYTAIL_CONFIG, PONYTAIL_DEFAULT_MODE,
#      PONYTAIL_ENFORCE, PONYTAIL_SUBAGENT_MATCHER
# Exit: 0 parity ok (or enforce off) · 1 enforcement failure · 64 usage
set -euo pipefail

JSON_OUT=0
CODEX_ACTIVE="auto"
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUT=1 ;;
    --codex-inactive) CODEX_ACTIVE=false ;;
    *) echo "ponytail-check.sh: unknown option $arg" >&2; exit 64 ;;
  esac
done

CLAUDE_REG="${PONYTAIL_CLAUDE_REGISTRY:-$HOME/.claude/plugins/installed_plugins.json}"
CODEX_CACHE="${PONYTAIL_CODEX_CACHE:-$HOME/.codex/plugins/cache/ponytail/ponytail}"
CODEX_TOML="${PONYTAIL_CODEX_CONFIG:-$HOME/.codex/config.toml}"
PT_CONFIG="${PONYTAIL_CONFIG:-$HOME/.config/ponytail/config.json}"
ENFORCE="${PONYTAIL_ENFORCE:-1}"
EXPECTED_MATCHER='implementer|frontend-implementer|backend-implementer|micro-fixer'

say() { [ "$JSON_OUT" -eq 1 ] || echo "$*"; }
note() { echo "ponytail-check: $*" >&2; }

# --- mode (shared runtime config: one source for both providers) -------------
MODE="${PONYTAIL_DEFAULT_MODE:-}"
if [ -z "$MODE" ]; then
  if [ -f "$PT_CONFIG" ]; then
    MODE="$(jq -r '.defaultMode // "full"' "$PT_CONFIG" 2>/dev/null || echo full)"
  else
    mkdir -p "$(dirname "$PT_CONFIG")"
    printf '{"defaultMode":"full"}\n' > "$PT_CONFIG"
    note "persisted default mode 'full' to $PT_CONFIG (config was absent)"
    MODE="full"
  fi
fi

# --- claude ------------------------------------------------------------------
CLAUDE_INSTALLED=false CLAUDE_VERSION=""
if [ -f "$CLAUDE_REG" ]; then
  CLAUDE_VERSION="$(jq -r '.plugins["ponytail@ponytail"][0].version // empty' "$CLAUDE_REG" 2>/dev/null || true)"
  [ -n "$CLAUDE_VERSION" ] && CLAUDE_INSTALLED=true
fi

# --- codex ---------------------------------------------------------------------
if [ "$CODEX_ACTIVE" = "auto" ]; then
  if command -v codex >/dev/null 2>&1; then CODEX_ACTIVE=true; else CODEX_ACTIVE=false; fi
fi
CODEX_INSTALLED=false CODEX_VERSION=""
if [ "$CODEX_ACTIVE" = true ]; then
  if grep -A2 'plugins\."ponytail@ponytail"' "$CODEX_TOML" 2>/dev/null | grep -q 'enabled *= *true'; then
    if [ -d "$CODEX_CACHE" ]; then
      latest="$(ls "$CODEX_CACHE" 2>/dev/null | sort -V | tail -n 1)"
      if [ -n "$latest" ] && [ -f "$CODEX_CACHE/$latest/.codex-plugin/plugin.json" ]; then
        CODEX_VERSION="$(jq -r '.version // empty' "$CODEX_CACHE/$latest/.codex-plugin/plugin.json" 2>/dev/null || true)"
      fi
      [ -z "$CODEX_VERSION" ] && CODEX_VERSION="$latest"
      [ -n "$CODEX_VERSION" ] && CODEX_INSTALLED=true
    fi
  fi
fi

# --- matcher scoping (warning, not failure — the runner exports it) ----------
if [ "${PONYTAIL_SUBAGENT_MATCHER:-}" != "$EXPECTED_MATCHER" ]; then
  note "PONYTAIL_SUBAGENT_MATCHER is not scoped to the code-writing roles — reviewer/explore lanes would receive the ladder. Set:"
  note "  export PONYTAIL_SUBAGENT_MATCHER='${EXPECTED_MATCHER}'"
fi

# --- parity verdict --------------------------------------------------------------
PROBLEMS=()
[ "$CLAUDE_INSTALLED" = true ] || PROBLEMS+=("claude: ponytail not installed")
if [ "$CODEX_ACTIVE" = true ]; then
  [ "$CODEX_INSTALLED" = true ] || PROBLEMS+=("codex: ponytail not installed")
  if [ "$CLAUDE_INSTALLED" = true ] && [ "$CODEX_INSTALLED" = true ] && [ "$CLAUDE_VERSION" != "$CODEX_VERSION" ]; then
    PROBLEMS+=("version mismatch: claude ${CLAUDE_VERSION} vs codex ${CODEX_VERSION} — pin ONE version on both providers")
  fi
fi
PARITY_OK=true
[ ${#PROBLEMS[@]} -eq 0 ] || PARITY_OK=false

ENFORCED=true
[ "$ENFORCE" = "1" ] || ENFORCED=false

RESULT="$(jq -n \
  --argjson ci "$CLAUDE_INSTALLED" --arg cv "$CLAUDE_VERSION" \
  --argjson xi "$CODEX_INSTALLED" --arg xv "$CODEX_VERSION" \
  --argjson xa "$([ "$CODEX_ACTIVE" = true ] && echo true || echo false)" \
  --arg mode "$MODE" \
  --argjson parity "$PARITY_OK" --argjson enforced "$ENFORCED" \
  --arg at "$(date -Iseconds)" \
  '{claude: {installed: $ci, version: $cv, mode: $mode},
    codex:  {installed: $xi, version: $xv, mode: $mode, active: $xa},
    parity_ok: $parity, enforced: $enforced, at: $at}')"
[ "$JSON_OUT" -eq 1 ] && echo "$RESULT"

if [ "$PARITY_OK" = true ]; then
  say "✓ ponytail parity ok — claude ${CLAUDE_VERSION}$([ "$CODEX_ACTIVE" = true ] && echo ", codex ${CODEX_VERSION}" || echo " (codex inactive — degraded, gate applies to claude alone)"), mode ${MODE}"
  exit 0
fi

for p in "${PROBLEMS[@]}"; do note "$p"; done
note "install/align ponytail (one version, both providers):"
note "  claude plugin marketplace add DietrichGebert/ponytail && claude plugin install ponytail@ponytail"
note "  codex plugin marketplace add DietrichGebert/ponytail && codex plugin add ponytail@ponytail"
if [ "$ENFORCED" = true ]; then
  note "❌ ponytail gate FAILED (PONYTAIL_ENFORCE=1) — stop condition for P0"
  exit 1
fi
note "⚠ ponytail gate FAILED but PONYTAIL_ENFORCE=0 — continuing WITHOUT the minimalism ladder (recorded as enforced:false; flagged, never silent)"
exit 0
