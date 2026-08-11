#!/usr/bin/env bash
# preflight.sh — P0 tool/auth preflight against the CONCEPT.md §7 CLI list.
#
# Checks presence AND auth state (not just command -v), including a bounded
# live probe per provider (claude hard, codex degradable). Behavior per §7:
#   - HARD tool missing/unauth -> exit 1 = stop condition, never skipped silently
#     (git, gh + auth, claude + live probe, node, jq, coderabbit + auth,
#      realpath, flock)
#   - skippable tool missing   -> logged skip (optional PROJ-end sonar tooling, supabase)
#   - codex missing/unauth/probe-fail -> NOT fatal: degraded single-provider
#                                 run, recorded in state.json and flagged in
#                                 the morning report + PR body (never silent)
#   - agent-browser            -> hard when legacy frontend_routes or structured frontend.routes exist
# Env: PREFLIGHT_PROBE_TIMEOUT (default 90) · PREFLIGHT_SKIP_LIVE_PROBE=1 · PREFLIGHT_CODEX_INACTIVE=1
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
GATE_CFG="$BASE/3-4_plan/wave-gate-config.json"
[ -f "$GATE_CFG" ] || GATE_CFG="$BASE/6_plan/wave-gate-config.json"

# Sibling Stage 2 helpers may not be next to this script yet (preflight runs
# BEFORE the framework copy step on a fresh target): fall back to the
# installed skill trees so a lone repo copy of preflight.sh still works.
resolve_helper() { # <name> -> path on stdout, or return 1
  local n="$1" p
  for p in "$SCRIPT_DIR/$n" \
           "$HOME/.claude/skills/4b_setup/scripts/$n" \
           "$HOME/.codex/skills/4b_setup/scripts/$n"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

HARD_MISSING=()
SKIPPED=()
DEGRADED_REASON=""
CODEX_STATE="ok"

say()  { echo "  $*"; }
have() { command -v "$1" >/dev/null 2>&1; }
agent_browser_contract() {
  agent-browser open --help >/dev/null 2>&1 \
    && agent-browser read --help >/dev/null 2>&1 \
    && agent-browser errors --help >/dev/null 2>&1
}

echo "→ P0 preflight (PROJ-${PROJ}-${THEME})"

# --- hard tools ---------------------------------------------------------
for tool in git gh claude node jq coderabbit realpath flock unlink; do
  if have "$tool"; then say "✓ $tool"; else say "❌ $tool MISSING (hard)"; HARD_MISSING+=("$tool"); fi
done

# npm or pnpm — hard when the project builds with node (package.json present)
if [ -f package.json ]; then
  if have pnpm || have npm; then say "✓ npm/pnpm"; else say "❌ npm/pnpm MISSING (hard — package.json present)"; HARD_MISSING+=("npm/pnpm"); fi
else
  say "– npm/pnpm: no package.json, not required"
fi

# agent-browser — hard for legacy per-wave routes and structured top-level routes
if [ -f "$GATE_CFG" ] && jq -e '[.waves[]?.frontend_routes[]?, .frontend.routes[]?] | length > 0' "$GATE_CFG" >/dev/null 2>&1; then
  if have agent-browser && agent_browser_contract; then
    say "✓ agent-browser (frontend waves planned; open/read/errors contract)"
  else
    say "❌ agent-browser MISSING or incompatible (hard — frontend waves planned)"
    HARD_MISSING+=("agent-browser")
  fi
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
if [ "${PREFLIGHT_CODEX_INACTIVE:-0}" = "1" ]; then
  CODEX_STATE="inactive"
  DEGRADED_REASON="codex deliberately disabled (PREFLIGHT_CODEX_INACTIVE=1)"
elif ! have codex; then
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
for tool in sonar sonar-scanner; do
  if have "$tool"; then say "✓ $tool"; else say "– $tool missing: skip (logged)"; SKIPPED+=("$tool"); fi
done
if have supabase; then
  say "✓ supabase"
elif have npx && npx supabase --version >/dev/null 2>&1; then
  say "✓ supabase (via npx)"
else
  say "– supabase missing: skip (logged)"; SKIPPED+=("supabase")
fi
if have sonar; then
  if [ -n "${SONAR_TOKEN:-}" ] || sonar auth status >/dev/null 2>&1; then
    say "✓ sonar auth (SONAR_TOKEN or auth status)"
  else
    say "– optional PROJ-end sonar auth unverified (no SONAR_TOKEN); mandatory wave sonar_cmd must still provide working auth and fail closed"
    SKIPPED+=("sonar-auth")
  fi
fi

# Framework-owned files are versioned for the run but must not inherit the
# target repo's formatting policy. Keep the lock out of git as well.
if [ -f biome.json ]; then
  node - <<'NODE'
const fs = require("fs");
const path = "biome.json";
const raw = fs.readFileSync(path, "utf8");
const config = JSON.parse(raw);
const ignored = [".claude/settings.json", "scripts/compile-context-bundles.mjs", "scripts/context-injector.mjs", "scripts/gen-component-registry.mjs", "scripts/ledger.mjs", "scripts/render-pr-body.mjs"];
config.files ??= {};
// Biome 2 removed `files.ignore` in favour of negated patterns in
// `files.includes`, and rejects the old key outright — writing it makes
// `biome check` exit non-zero on configuration alone. Follow whichever form
// the target repo already uses.
if (Array.isArray(config.files.includes)) {
  const negations = ignored.map((f) => `!${f}`);
  config.files.includes = [...new Set([...config.files.includes, ...negations])];
} else {
  config.files.ignore = [...new Set([...(config.files.ignore ?? []), ...ignored])];
}
// Keep the target's own indentation: this file is linted by the formatter it
// configures, so reflowing it to two spaces fails a tab-indented repo's lint.
const indent = /^\t/m.test(raw) ? "\t" : 2;
fs.writeFileSync(path, JSON.stringify(config, null, indent) + "\n");
NODE
  say "✓ Biome ignores merged for framework-owned files"
elif [ ! -f biome.jsonc ]; then
  printf '%b\n' '{' '\t"files": {' '\t\t"includes": [' '\t\t\t"**",' '\t\t\t"!.claude/settings.json",' '\t\t\t"!scripts/compile-context-bundles.mjs",' '\t\t\t"!scripts/context-injector.mjs",' '\t\t\t"!scripts/gen-component-registry.mjs",' '\t\t\t"!scripts/ledger.mjs",' '\t\t\t"!scripts/render-pr-body.mjs"' '\t\t]' '\t}' '}' > biome.json
  say "✓ Biome ignores created for framework-owned files"
else
  say "⚠ biome.jsonc detected — add framework-owned scripts + .claude/settings.json to files.ignore before the setup commit"
fi
grep -qxF '.state.lock' .gitignore 2>/dev/null || printf '.state.lock\n' >> .gitignore

# --- context injector hook (host-neutral, idempotent) ---------------------
# Keep the context hook deterministic. Ponytail deliberately has no matcher:
# its native unset path reaches every normal subagent, including generic
# implementation fallbacks. Runs before the Ponytail check so stale project
# settings are removed before coverage is verified.
INJECTOR_CMD="node scripts/context-injector.mjs claude"
mkdir -p .claude
[ -f .claude/settings.json ] || echo '{}' > .claude/settings.json
if jq -e --arg cmd "$INJECTOR_CMD" \
     '[.hooks.SubagentStart[]?.hooks[]? | select(.command == $cmd)] | length > 0
      and ((.env.PONYTAIL_SUBAGENT_MATCHER // "") == "")' \
     .claude/settings.json >/dev/null 2>&1; then
  say "✓ context injector hook present; Ponytail applies to all subagents (.claude/settings.json)"
else
  TMP_SETTINGS="$(mktemp)"
  if jq --arg cmd "$INJECTOR_CMD" \
       '.hooks.SubagentStart = (
          (.hooks.SubagentStart // [])
          + (if ([.hooks.SubagentStart[]?.hooks[]? | select(.command == $cmd)] | length) > 0
             then [] else [{hooks: [{type: "command", command: $cmd}]}] end))
        | del(.env.PONYTAIL_SUBAGENT_MATCHER)
        | if .env == {} then del(.env) else . end' \
       .claude/settings.json > "$TMP_SETTINGS" 2>/dev/null; then
    mv "$TMP_SETTINGS" .claude/settings.json
    say "✓ context injector hook merged; stale Ponytail matcher removed (.claude/settings.json)"
  else
    rm -f "$TMP_SETTINGS"
    say "⚠ could not merge the injector hook (.claude/settings.json unparseable?) — merge it manually via merge-project-settings.sh"
  fi
fi

# --- ponytail install + parity gate (context system, §7) -----------------
# Ponytail is the single source of the minimalism ladder on both providers.
# Absence, version/mode mismatch, or missing helper is HARD (PONYTAIL_ENFORCE=0
# is the loud, recorded escape hatch — never silent). Degraded runs gate the
# surviving provider alone.
PONYTAIL_JSON=""
PONYTAIL_ARGS=(--json)
[ "$CODEX_STATE" = "ok" ] || PONYTAIL_ARGS+=(--codex-inactive)
if PONYTAIL_SH="$(resolve_helper ponytail-check.sh)"; then
  set +e
  PONYTAIL_JSON="$(bash "$PONYTAIL_SH" "${PONYTAIL_ARGS[@]}" 2>/dev/null)"
  PONYTAIL_RC=$?
  set -e
  if [ "$PONYTAIL_RC" -eq 0 ]; then
    if [ -n "$PONYTAIL_JSON" ] && [ "$(jq -r '.parity_ok' <<<"$PONYTAIL_JSON" 2>/dev/null)" = "true" ]; then
      say "✓ ponytail parity ($(jq -r '"claude " + .claude.version + (if .codex.active then ", codex " + .codex.version else " (codex inactive)" end) + ", mode " + .claude.mode' <<<"$PONYTAIL_JSON"))"
    else
      say "⚠ ponytail gate failed but PONYTAIL_ENFORCE=0 — run continues WITHOUT the ladder (recorded enforced:false; flagged)"
    fi
  else
    say "❌ ponytail MISSING, mode not '$( echo "${PONYTAIL_REQUIRED_MODE:-full}")', or parity mismatch (hard) — run 'bash $PONYTAIL_SH' for the install commands"
    HARD_MISSING+=("ponytail")
  fi
else
  say "❌ ponytail-check.sh not found (script dir or installed skill trees) — Stage 2 helpers not installed (hard)"
  HARD_MISSING+=("ponytail-check.sh")
fi

# --- context bundles: verify when compiled (§5 budget gate is HARD) -------
if [ -f "$BASE/context/bundles.lock.json" ]; then
  if COMPILER="$(resolve_helper compile-context-bundles.mjs)" \
     && node "$COMPILER" verify "$PROJ" "$THEME" >/dev/null 2>&1; then
    say "✓ context bundles verify (hashes match, budgets hold)"
  else
    say "❌ context bundles verify FAILED (budget breach, drift, or compiler missing — hard) — condense docs/, recompile (4b_setup step 6a)"
    HARD_MISSING+=("context-bundles")
  fi
else
  say "– context bundles not compiled yet (4b_setup step 6a runs after this preflight)"
fi

# --- repo structure: migration state of the curated baseline -------------
# BACKSTOP, never a stop condition. The design-system decision belongs to
# 1b_visual-companion (recorded under "Design System State" in
# layout-decision.md) — by P0 it is normally already made. This block catches
# the repos that never went through UI discovery, and it only reports: absence
# is legitimate (backend-only repos, repos predating the design system), and a
# hand-written registry cannot be clobbered because gen-component-registry.mjs
# refuses to overwrite a file it did not generate.
HAS_COMPONENTS=false
if [ -d src/components ]; then
  HAS_COMPONENTS=true
elif find src/features -maxdepth 2 -type d -name components 2>/dev/null | grep -q .; then
  HAS_COMPONENTS=true
fi

if [ "$HAS_COMPONENTS" = true ]; then
  if [ ! -f docs/components.md ]; then
    say "– docs/components.md missing but components exist — generate it: node scripts/gen-component-registry.mjs (installed by 4b_setup step 5)"
    SKIPPED+=("components-registry-missing")
  elif ! grep -q "GENERATED by scripts/gen-component-registry.mjs" docs/components.md; then
    say "– docs/components.md is hand-written — the generator will refuse to overwrite it. One-time migration:"
    say "   1) move each entry's purpose + variants/sizes/states into a doc block above the component export"
    say "   2) node scripts/gen-component-registry.mjs --force · 3) review the diff before committing"
    say "   Skipping the migration is fine — the wave gate's registry step reports it and moves on."
    SKIPPED+=("components-registry-hand-written")
  else
    say "✓ docs/components.md generated"
  fi
fi

if [ -f docs/DESIGN-SYSTEM.md ]; then
  DS_LINES="$(wc -l < docs/DESIGN-SYSTEM.md | tr -d ' ')"
  if [ "$DS_LINES" -gt 80 ]; then
    say "– docs/DESIGN-SYSTEM.md is ${DS_LINES}/80 lines — P7 curation caps will breach; move detail to the /dev/components showcase"
    SKIPPED+=("design-system-over-cap")
  else
    say "✓ docs/DESIGN-SYSTEM.md ${DS_LINES}/80 lines"
  fi
elif [ "$HAS_COMPONENTS" = true ]; then
  say "– no docs/DESIGN-SYSTEM.md — UI work without design rules; run 1c_frontend-design, or proceed knowingly (a knowing skip recorded in layout-decision.md is expected here — do not re-ask)"
  SKIPPED+=("design-system-missing")
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
