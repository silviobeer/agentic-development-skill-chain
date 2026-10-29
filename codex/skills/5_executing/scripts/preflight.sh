#!/usr/bin/env bash
# preflight.sh — P0 tool/auth preflight against the CONCEPT.md §7 CLI list.
#
# Checks presence AND auth state (not just command -v), including a bounded
# live probe per provider (claude hard, codex degradable). Behavior per §7:
#   - HARD tool missing/unauth -> exit 1 = stop condition, never skipped silently
#     (git, gh + auth, claude + live probe, node, jq, coderabbit + auth,
#      realpath, flock)
#   - coderabbit + auth are hard unless wave-gate-config.json sets
#     coderabbit.enabled=false (logged skip). No readable config yet (preflight
#     can run before the plan exists) means the default applies: CodeRabbit is
#     required, never waved through. An invalid coderabbit value is a hard stop
#     and CodeRabbit stays required.
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
           "$HOME/.claude/skills/5_executing/scripts/$n" \
           "$HOME/.codex/skills/5_executing/scripts/$n"; do
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

# Preflight runs in the control checkout's shell, which may not be the same
# session any secret (SONAR_TOKEN or otherwise) was exported into.
source "$SCRIPT_DIR/compat.sh"
source "$SCRIPT_DIR/env-local.sh"
resource_exit() {
  local rc="$1"
  if [ "$rc" -eq 64 ] || [ "$rc" -eq 77 ]; then
    if [ -f "$BASE/state.json" ]; then
      "$STATE_SH" set "$PROJ" "$THEME" .preflight "$(jq -cn --arg at "$(now_iso)" --argjson rc "$rc" '{at:$at,ok:false,hard_missing:["host-resources"],skipped:[],resource_exit:$rc}')" >/dev/null
    fi
  fi
  exit "$rc"
}
if ! resource_lease_held; then
  resource_rc=0
  resource_run "$GATE_CFG" preflight bash "$0" "$@" || resource_rc=$?
  resource_exit "$resource_rc"
fi
resource_check "$GATE_CFG" preflight || resource_exit "$?"
agent_browser_contract() {
  agent-browser open --help >/dev/null 2>&1 \
    && agent-browser snapshot --help >/dev/null 2>&1 \
    && agent-browser errors --help >/dev/null 2>&1
}

echo "→ P0 preflight (PROJ-${PROJ}-${THEME})"

# coderabbit.enabled is optional in wave-gate-config.json; default (absent/true/no config) = required.
CODERABBIT_ENABLED=true
if [ -f "$GATE_CFG" ] && have jq; then
  if jq -e 'if has("coderabbit") then (.coderabbit | type=="object" and ((keys - ["enabled"]) | length==0) and ((has("enabled") | not) or (.enabled | type=="boolean"))) else true end' "$GATE_CFG" >/dev/null 2>&1; then
    CODERABBIT_ENABLED=$(jq -r '.coderabbit.enabled | if type=="boolean" then . else true end' "$GATE_CFG")
  else
    say "❌ coderabbit must be an object with an optional boolean 'enabled' (hard — invalid CodeRabbit policy)"
    HARD_MISSING+=("coderabbit-config")
  fi
fi

# --- hard tools ---------------------------------------------------------
for tool in git gh claude node jq coderabbit unlink; do
  [ "$tool" != coderabbit ] || [ "$CODERABBIT_ENABLED" = true ] || continue # disabled: logged skip with the auth check below
  if have "$tool"; then say "✓ $tool"; else say "❌ $tool MISSING (hard)"; HARD_MISSING+=("$tool"); fi
done

# Optional GNU tools: information only, the portable fallbacks in compat.sh cover their absence.
have flock || say "– flock absent: exclusive mkdir-lock fallback in use (optional: brew install flock)"
[ "${TIMEOUT_BIN[0]}" != perl ] || say "– timeout absent: built-in perl fallback in use (optional: brew install coreutils)"

# npm or pnpm — hard when the project builds with node (package.json present)
APP_ROOT="."
[ -f "$GATE_CFG" ] && APP_ROOT=$(jq -r 'if (.app_root | type) == "string" then .app_root else "." end' "$GATE_CFG" 2>/dev/null || echo .)
case "$APP_ROOT" in ''|/*|..|../*|*/..|*/../*) APP_ROOT="." ;; esac # an invalid app_root is the plan validator's and worktree.sh's job to refuse
if [ -f "$APP_ROOT/package.json" ]; then
  if have pnpm || have npm; then say "✓ npm/pnpm"; else say "❌ npm/pnpm MISSING (hard — package.json present)"; HARD_MISSING+=("npm/pnpm"); fi
else
  say "– npm/pnpm: no $APP_ROOT/package.json, not required"
fi

# agent-browser — hard for legacy per-wave routes and structured top-level routes
if [ -f "$GATE_CFG" ] && jq -e '[.waves[]?.frontend_routes[]?, .frontend.routes[]?] | length > 0' "$GATE_CFG" >/dev/null 2>&1; then
  if have agent-browser && agent_browser_contract; then
    say "✓ agent-browser (frontend waves planned; open/snapshot/errors contract)"
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
if [ "$CODERABBIT_ENABLED" != true ]; then
  say "– coderabbit + auth skipped: disabled by wave-gate-config (coderabbit.enabled=false)"
  SKIPPED+=("coderabbit: disabled by config")
elif have coderabbit; then
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
  elif "${TIMEOUT_BIN[@]}" --foreground "$PROBE_TIMEOUT" claude -p "Reply with exactly: OK" </dev/null >/dev/null 2>&1; then
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
elif ! "${TIMEOUT_BIN[@]}" --foreground "$PROBE_TIMEOUT" codex exec --sandbox read-only --skip-git-repo-check "Reply with exactly: OK" </dev/null >/dev/null 2>&1; then
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
SUPABASE_AVAILABLE=false
if have supabase; then
  say "✓ supabase"; SUPABASE_AVAILABLE=true
elif have npx && npx supabase --version >/dev/null 2>&1; then
  say "✓ supabase (via npx)"; SUPABASE_AVAILABLE=true
else
  say "– supabase missing: skip (logged)"; SKIPPED+=("supabase")
fi

# Git worktrees of this repo share ONE local Supabase Postgres instance
# (same supabase/config.toml project_id). A worktree that never re-checks
# the DB's actually-applied migrations against its OWN supabase/migrations/
# can silently trust a schema another worktree advanced out from under it
# (see migration-drift-check.sh) — the with-shared-lock only serializes
# concurrent migrations, not this sequential drift.
if [ "$SUPABASE_AVAILABLE" = true ] && [ -d supabase/migrations ]; then
  if DRIFT_SH="$(resolve_helper migration-drift-check.sh)"; then
    if bash "$DRIFT_SH"; then
      say "✓ local Supabase DB matches this worktree's migrations"
    else
      say "❌ local Supabase DB has migrations this worktree's supabase/migrations/ doesn't (hard — see message above; run \`supabase db reset\` from this worktree)"
      HARD_MISSING+=("migration-drift")
    fi
  else
    say "⚠ migration-drift-check.sh not found — cannot verify the local DB matches this worktree's migrations"
  fi
fi
if have sonar; then
  if [ -n "${SONAR_TOKEN:-}" ] || sonar auth status >/dev/null 2>&1; then
    say "✓ sonar auth (SONAR_TOKEN or auth status)"
  else
    say "– optional PROJ-end sonar auth unverified (no SONAR_TOKEN); required Sonar analysis must still provide scanner auth and fail closed"
    SKIPPED+=("sonar-auth")
  fi
fi

# --- Sonar policy: only configured or explicitly required analysis is mandatory ---
# sonar_cmd remains required plan metadata; it alone does not require analysis.
# A wrapped scanner still needs an engine and scanner auth when analysis is required.
if [ -f "$GATE_CFG" ] && ! jq -e 'type == "object" and (if has("sonar_required") then (.sonar_required | type == "boolean") else true end)' "$GATE_CFG" >/dev/null 2>&1; then
  say "❌ sonar_required must be boolean when present (hard — invalid Sonar policy)"
  HARD_MISSING+=("sonar_required")
elif [ -e sonar-project.properties ] || { [ -f "$GATE_CFG" ] && jq -e '.sonar_required == true' "$GATE_CFG" >/dev/null 2>&1; }; then
  if [ ! -f "$GATE_CFG" ] || ! jq -e '.sonar_cmd | select(type=="string" and test("\\S"))' "$GATE_CFG" >/dev/null 2>&1; then
    say "❌ required Sonar analysis needs a non-empty sonar_cmd"
    HARD_MISSING+=("sonar_cmd")
  else
    sonar_cmd=$(jq -r '.sonar_cmd' "$GATE_CFG")
    sonar_def="$sonar_cmd"
    sonar_script=$(printf '%s' "$sonar_cmd" | sed -nE 's/^(npm run|pnpm run|pnpm|yarn) ([A-Za-z0-9:._-]+)$/\2/p')
    if [ -n "$sonar_script" ] && [ -f package.json ]; then
      sonar_def=$(jq -r --arg s "$sonar_script" '.scripts[$s] // ""' package.json)
    fi

    sonar_engine=""
    if have sonar-scanner; then
      sonar_engine="sonar-scanner on PATH"
    elif printf '%s' "$sonar_def" | grep -qE '@sonar/scan|sonarqube-scanner|sonar-scanner'; then
      sonar_engine="npm-wrapped scanner engine"
    fi

    sonar_auth=""
    if [ -n "${SONAR_TOKEN:-}" ]; then
      sonar_auth="SONAR_TOKEN in env"
    elif printf '%s' "$sonar_def" | grep -q '\.env\.local' \
      && [ -f .env.local ] && grep -q '^SONAR_TOKEN=' .env.local; then
      sonar_auth="SONAR_TOKEN sourced from .env.local by sonar_cmd"
    fi

    if [ -z "$sonar_engine" ]; then
      say "❌ no scanner engine for sonar_cmd '$sonar_cmd' (hard — no sonar-scanner on PATH and no npm-wrapped scanner in its definition)"
      HARD_MISSING+=("sonar-scanner")
    elif [ -z "$sonar_auth" ]; then
      say "❌ SONAR_TOKEN not reachable by sonar_cmd (hard — not in env and not in an .env.local the command sources; \`sonar auth status\` alone does not authenticate the scanner, see sonar-cli skill)"
      HARD_MISSING+=("sonar-scanner-auth")
    else
      say "✓ scanner engine ($sonar_engine), auth ($sonar_auth) for required Sonar analysis"
    fi
  fi
elif [ -f "$GATE_CFG" ]; then
  say "– Sonar skipped (project not configured)"
  SKIPPED+=("sonar: project not configured")
fi

# Framework-owned files are versioned for the run but must not inherit the
# target repo's formatting policy. Keep the lock out of git as well.
if [ -f biome.json ]; then
  node - <<'NODE'
const fs = require("fs");
const { execFileSync } = require("child_process");
const path = "biome.json";
const raw = fs.readFileSync(path, "utf8");
const config = JSON.parse(raw);
const ignored = [".claude/settings.json", "scripts/compile-context.mjs", "scripts/story-slice.mjs", "scripts/validate-wave-plan.mjs", "scripts/validate-prds.mjs", "scripts/validate-architecture.mjs", "scripts/document-parser.mjs", "scripts/resolve-inputs.mjs", "scripts/integration-status.mjs", "scripts/architecture-parser.mjs", "scripts/gen-component-registry.mjs", "scripts/findings.mjs", "scripts/findings-store.mjs", "scripts/render.mjs", "scripts/sync-framework.mjs", "scripts/quality.mjs", ".skillchain-helpers.json"];
config.files ??= {};
// Biome 2 removed `files.ignore` in favour of negated patterns in
// `files.includes`, and rejects the old key outright — writing it makes
// `biome check` exit non-zero on configuration alone. Follow whichever form
// the target repo already uses; otherwise use the installed Biome major.
if (Array.isArray(config.files.includes)) {
  const negations = ignored.map((f) => `!${f}`);
  config.files.includes = [...new Set([...config.files.includes, ...negations])];
} else if (Array.isArray(config.files.ignore)) {
  config.files.ignore = [...new Set([...(config.files.ignore ?? []), ...ignored])];
} else {
  let major = config.$schema?.match(/\/schemas\/(\d+)(?:\.|\/)/)?.[1];
  for (const command of ["biome", "./node_modules/.bin/biome"]) {
    if (major) break;
    try {
      major = execFileSync(command, ["--version"], { encoding: "utf8" }).match(/\b(\d+)\./)?.[1];
    } catch {}
  }
  if (!major) throw new Error("Cannot determine Biome major version; add $schema to biome.json");
  if (Number(major) >= 2) config.files.includes = ["**", ...ignored.map((f) => `!${f}`)];
  else config.files.ignore = ignored;
}
// Keep the target's own indentation: this file is linted by the formatter it
// configures, so reflowing it to two spaces fails a tab-indented repo's lint.
const indent = /^\t/m.test(raw) ? "\t" : 2;
fs.writeFileSync(path, JSON.stringify(config, null, indent) + "\n");
NODE
  say "✓ Biome ignores merged for framework-owned files"
elif [ ! -f biome.jsonc ]; then
  printf '%b\n' '{' '\t"files": {' '\t\t"includes": [' '\t\t\t"**",' '\t\t\t"!.claude/settings.json",' '\t\t\t"!scripts/compile-context.mjs",' '\t\t\t"!scripts/story-slice.mjs",' '\t\t\t"!scripts/validate-wave-plan.mjs",' '\t\t\t"!scripts/validate-prds.mjs",' '\t\t\t"!scripts/validate-architecture.mjs",' '\t\t\t"!scripts/document-parser.mjs",' '\t\t\t"!scripts/resolve-inputs.mjs",' '\t\t\t"!scripts/integration-status.mjs",' '\t\t\t"!scripts/architecture-parser.mjs",' '\t\t\t"!scripts/gen-component-registry.mjs",' '\t\t\t"!scripts/findings.mjs",' '\t\t\t"!scripts/findings-store.mjs",' '\t\t\t"!scripts/render.mjs"' '\t\t]' '\t}' '}' > biome.json
  say "✓ Biome ignores created for framework-owned files"
else
  say "⚠ biome.jsonc detected — add framework-owned scripts + .claude/settings.json to files.ignore before the setup commit"
fi
if ! grep -qxF '.state.lock' .gitignore 2>/dev/null; then
  [ -s .gitignore ] && [ -z "$(tail -c1 .gitignore)" ] || printf '\n' >> .gitignore
  printf '.state.lock\n' >> .gitignore
fi

# --- worker context: compile check once a plan folder exists (HARD) -------
if [ -d "$BASE/3-4_plan" ] || [ -d "$BASE/6_plan" ]; then
  if COMPILER="$(resolve_helper compile-context.mjs)" \
     && node "$COMPILER" check "$PROJ" "$THEME" >/dev/null 2>&1; then
    say "✓ worker context check (every story maps to a role, budgets hold)"
  else
    say "❌ worker context check FAILED (budget breach, unassignable story, outdated manifest, or compiler missing — hard) — run: bash scripts/chain render context check $PROJ $THEME"
    HARD_MISSING+=("context-check")
  fi
else
  say "– worker context check skipped: no plan folder ($BASE/3-4_plan or 6_plan) yet"
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
    say "– docs/components.md missing but components exist — generate it: node scripts/gen-component-registry.mjs (installed by setup subskill step 5)"
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
    --arg at "$(now_iso)" \
    --argjson ok "$OK" \
    --argjson hard "$(printf '%s\n' "${HARD_MISSING[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')" \
    --argjson skipped "$(printf '%s\n' "${SKIPPED[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')" \
    --arg claude "$CLAUDE_STATE" \
    --arg codex "$CODEX_STATE" \
    '{at: $at, ok: $ok, hard_missing: $hard, skipped: $skipped, providers: {claude: $claude, codex: $codex}}')"
  "$STATE_SH" set "$PROJ" "$THEME" .preflight "$PREFLIGHT_JSON" >/dev/null
  if [ "$CODEX_STATE" != "ok" ]; then
    "$STATE_SH" set "$PROJ" "$THEME" .degraded true >/dev/null
    "$STATE_SH" set "$PROJ" "$THEME" .degraded_reason "$DEGRADED_REASON" >/dev/null
  fi
  say "✓ preflight block written to $BASE/state.json"
else
  say "⚠ $BASE/state.json missing — report not persisted (run Checkpoint 1 via 5_executing first)"
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
