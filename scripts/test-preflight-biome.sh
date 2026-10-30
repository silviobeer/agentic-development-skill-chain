#!/usr/bin/env bash
# Behavior tests for P0 preflight's Biome compatibility and wrapped Sonar probe.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFLIGHT="$ROOT/codex/skills/5_executing/scripts/preflight.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
for command_name in gh claude coderabbit; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/$command_name"
  chmod +x "$FAKE_BIN/$command_name"
done
# Prevent a real npx fallback from attempting any package/network lookup.
printf '#!/usr/bin/env bash\nexit 1\n' >"$FAKE_BIN/npx"
chmod +x "$FAKE_BIN/npx"

run_preflight() {
  local work="$1"
  (cd "$work" && \
    PATH="$FAKE_BIN:$PATH" \
    PREFLIGHT_SKIP_LIVE_PROBE=1 \
    PREFLIGHT_CODEX_INACTIVE=1 \
    bash "$PREFLIGHT" 1 biome >/dev/null)
}

ignored='[".claude/settings.json","scripts/compile-context.mjs","scripts/story-slice.mjs","scripts/validate-wave-plan.mjs","scripts/validate-prds.mjs","scripts/validate-architecture.mjs","scripts/document-parser.mjs","scripts/resolve-inputs.mjs","scripts/integration-status.mjs","scripts/architecture-parser.mjs","scripts/gen-component-registry.mjs","scripts/findings.mjs","scripts/findings-store.mjs","scripts/render.mjs", "scripts/chain-status.mjs", "scripts/sync-framework.mjs", "scripts/quality.mjs", ".skillchain-helpers.json"]'

biome1="$TMP/biome1"
mkdir -p "$biome1"
printf '{"files":{"ignore":["existing/**"]}}\n' >"$biome1/biome.json"
run_preflight "$biome1"
run_preflight "$biome1"
jq -e --argjson expected "$ignored" '
  .files.ignore as $actual
  | ($actual | index("existing/**")) != null
    and all($expected[]; . as $item | ($actual | map(select(. == $item)) | length) == 1)
    and (.files | has("includes") | not)
' "$biome1/biome.json" >/dev/null || fail "Biome 1 files.ignore merge is missing, duplicated, or changed shape"

biome2="$TMP/biome2"
mkdir -p "$biome2"
printf '{"files":{"includes":["src/**"]}}\n' >"$biome2/biome.json"
run_preflight "$biome2"
run_preflight "$biome2"
jq -e --argjson expected "$ignored" '
  .files.includes as $actual
  | ($actual | index("src/**")) != null
    and all($expected[]; ("!" + .) as $item | ($actual | map(select(. == $item)) | length) == 1)
    and (.files | has("ignore") | not)
' "$biome2/biome.json" >/dev/null || fail "Biome 2 negated files.includes merge is missing, duplicated, or wrote obsolete files.ignore"

biome2_unset="$TMP/biome2-unset"
mkdir -p "$biome2_unset"
printf '{"$schema":"https://biomejs.dev/schemas/2.5.10/schema.json","files":{"ignoreUnknown":false}}\n' >"$biome2_unset/biome.json"
run_preflight "$biome2_unset"
jq -e '
  (.files.includes[0] == "**")
    and (.files | has("ignore") | not)
' "$biome2_unset/biome.json" >/dev/null || fail "Biome 2 config without includes received obsolete files.ignore"

sonar="$TMP/sonar"
mkdir -p "$sonar/specs/PROJ-1-sonar/3-4_plan"
printf '{"scripts":{"sonar":"set -a; . ./.env.local; set +a; pnpm dlx @sonar/scan@5.0.0"}}\n' >"$sonar/package.json"
printf '{"sonar_cmd":"pnpm sonar"}\n' >"$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json"
# A plan folder makes preflight run the hard worker-context check, so it needs a wave plan.
printf '# Wave 1\n\n**PRDs involved:** PROJ-1-PRD-1\n\n## User Stories in this Wave\n\n| US ID | Scope | Agent Type | Complexity | Can start when |\n|---|---|---|---|---|\n| PROJ-1-PRD-1-US-1 | backend | backend-implementer | sonnet | immediately |\n\n## PROJ-1-PRD-1-US-1: Story\n' \
  >"$sonar/specs/PROJ-1-sonar/3-4_plan/PROJ-1-wave-1-plan.md"
touch "$sonar/sonar-project.properties"
printf 'SONAR_TOKEN=test-token\n' >"$sonar/.env.local"
sonar_output="$(cd "$sonar" && \
  PATH="$FAKE_BIN:$(dirname "$BASH"):/usr/bin:/bin" \
  PREFLIGHT_SKIP_LIVE_PROBE=1 \
  PREFLIGHT_CODEX_INACTIVE=1 \
  bash "$PREFLIGHT" 1 sonar)"
grep -q 'npm-wrapped scanner engine' <<<"$sonar_output" \
  || fail "npm-wrapped sonar_cmd was not accepted without standalone sonar-scanner"
grep -q '✓ worker context check' <<<"$sonar_output" \
  || fail "preflight did not run the worker context check on a plan folder"

# A declared command alone is not an analysis requirement. Persist the P0 disposition.
(cd "$sonar" && bash "$(dirname "$PREFLIGHT")/state.sh" init 1 sonar >/dev/null)
rm "$sonar/.env.local" "$sonar/sonar-project.properties"
for command_name in sonar sonar-scanner; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/$command_name"
  chmod +x "$FAKE_BIN/$command_name"
done
run_sonar_policy() {
  (unset SONAR_TOKEN; cd "$sonar"; PATH="$FAKE_BIN:$(dirname "$BASH"):/usr/bin:/bin" \
    PREFLIGHT_SKIP_LIVE_PROBE=1 PREFLIGHT_CODEX_INACTIVE=1 \
    bash "$PREFLIGHT" 1 sonar >"$TMP/sonar-policy-output" 2>&1)
}
run_sonar_policy || { cat "$TMP/sonar-policy-output" >&2; fail "unconfigured optional Sonar must not require scanner auth"; }
jq -e '.preflight.ok and (.preflight.skipped | index("sonar: project not configured") != null)' \
  "$sonar/specs/PROJ-1-sonar/state.json" >/dev/null || fail "P0 did not persist project-not-configured Sonar disposition"
for policy in configured required false-configured malformed null numeric; do
  rm -f "$sonar/sonar-project.properties"
  printf '{"sonar_cmd":"pnpm sonar"}\n' >"$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json"
  case "$policy" in
    configured) touch "$sonar/sonar-project.properties" ;;
    required) jq '.sonar_required=true' "$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json" >"$TMP/policy" ;;
    false-configured) touch "$sonar/sonar-project.properties"; jq '.sonar_required=false' "$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json" >"$TMP/policy" ;;
    null) jq '.sonar_required=null' "$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json" >"$TMP/policy" ;;
    numeric) jq '.sonar_required=1' "$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json" >"$TMP/policy" ;;
    malformed) jq '.sonar_required="false"' "$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json" >"$TMP/policy" ;;
  esac
  if [ -f "$TMP/policy" ]; then mv "$TMP/policy" "$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json"; fi
  if run_sonar_policy; then fail "$policy Sonar policy must fail closed without scanner auth"; fi
  case "$policy" in malformed|null|numeric) expected=sonar_required ;; *) expected=sonar-scanner-auth ;; esac
  grep -q "$expected" "$TMP/sonar-policy-output" || { cat "$TMP/sonar-policy-output" >&2; fail "$policy failed for wrong reason"; }
done
# Missing scanner engine is also fatal when analysis is required.
rm "$FAKE_BIN/sonar-scanner"
printf '{"sonar_cmd":"true","sonar_required":true}\n' >"$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json"
if run_sonar_policy; then fail "required Sonar without a scanner engine must fail"; fi
grep -q 'no scanner engine' "$TMP/sonar-policy-output" || fail "missing engine failed for wrong reason"
# Restore the configured wrapped-scanner positive control for the installed-helper check.
printf '{"sonar_cmd":"pnpm sonar"}\n' >"$sonar/specs/PROJ-1-sonar/3-4_plan/wave-gate-config.json"
touch "$sonar/sonar-project.properties"
printf 'SONAR_TOKEN=test-token\n' >"$sonar/.env.local"
rm "$FAKE_BIN/sonar"
rm "$sonar/specs/PROJ-1-sonar/state.json"

# A lone project preflight can resolve the new compiler from an installed tree.
installed="$TMP/installed/5_executing"
mkdir -p "$installed/scripts" "$sonar/scripts"
cp "$ROOT/codex/skills/5_executing/scripts/env-local.sh" "$ROOT/codex/skills/5_executing/scripts/compat.sh" "$sonar/scripts/"
cp "$ROOT/codex/skills/5_executing/scripts/compat.sh" \
  "$ROOT/codex/skills/5_executing/scripts/resolve-inputs.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/integration-status.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/compile-context.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/document-parser.mjs" \
  "$ROOT/codex/skills/5_executing/scripts/architecture-parser.mjs" "$installed/scripts/"
cp -R "$ROOT/codex/skills/5_executing/manifests" "$installed/"
node - "$PREFLIGHT" "$sonar/scripts/preflight.sh" "$installed" <<'NODE'
const fs = require("node:fs");
let text = fs.readFileSync(process.argv[2], "utf8");
text = text.replaceAll('$HOME/.claude/skills/5_executing', process.argv[4]).replaceAll('$HOME/.codex/skills/5_executing', process.argv[4]);
fs.writeFileSync(process.argv[3], text);
NODE
fallback_output="$(cd "$sonar" && PATH="$FAKE_BIN:$(dirname "$BASH"):/usr/bin:/bin" \
  PREFLIGHT_SKIP_LIVE_PROBE=1 PREFLIGHT_CODEX_INACTIVE=1 \
  bash scripts/preflight.sh 1 sonar)"
grep -q '✓ worker context check' <<<"$fallback_output" || fail "installed compiler fallback failed"

# No SubagentStart hook is installed, and settings.json is neither created nor changed.
fresh="$TMP/hook-fresh"
mkdir -p "$fresh"
run_preflight "$fresh"
[ ! -e "$fresh/.claude/settings.json" ] || fail "preflight created .claude/settings.json"
keep="$TMP/hook-keep"
mkdir -p "$keep/.claude"
printf '{"env":{"FOO":"1"}}\n' >"$keep/.claude/settings.json"
run_preflight "$keep"
[ "$(jq -c . "$keep/.claude/settings.json")" = '{"env":{"FOO":"1"}}' ] || fail "preflight changed .claude/settings.json"

cmp -s "$PREFLIGHT" "$ROOT/claude/skills/5_executing/scripts/preflight.sh" \
  || fail "preflight provider copies are not byte-identical"

echo "preflight compatibility tests: PASS"

# SC-10: pressure refuses preflight before live provider or package probes.
pressure="$TMP/pressure"
mkdir -p "$pressure/specs/PROJ-1-biome/3-4_plan"
printf '{"resources":{"min_available_mb":1024,"wait_seconds":0}}\n' >"$pressure/specs/PROJ-1-biome/3-4_plan/wave-gate-config.json"
printf 'MemAvailable: 100 kB\n' >"$TMP/meminfo"
(cd "$pressure" && bash "$ROOT/codex/skills/5_executing/scripts/chain" state init 1 biome >/dev/null)
(cd "$pressure" && bash "$ROOT/codex/skills/5_executing/scripts/chain" state set 1 biome .preflight '{"ok":true}' >/dev/null)
printf '#!/usr/bin/env bash\necho called >"$RESOURCE_PROBE_MARKER"\nexit 0\n' >"$FAKE_BIN/claude"
export RESOURCE_PROBE_MARKER="$TMP/provider-probe"
rc=0
(cd "$pressure" && PATH="$FAKE_BIN:$PATH" SKILLCHAIN_MEMINFO_FILE="$TMP/meminfo" SKILLCHAIN_CGROUP_DIR="$TMP/no-cgroup" SKILLCHAIN_RESOURCE_LOCK_DIR="$TMP/resources" bash "$PREFLIGHT" 1 biome >"$TMP/pressure.log" 2>&1) || rc=$?
[ "$rc" -eq 77 ] || fail "pressure must refuse preflight with 77, got $rc: $(cat "$TMP/pressure.log")"
[ ! -e "$RESOURCE_PROBE_MARKER" ] || fail "pressure launched preflight provider probe"

jq -e '.preflight.ok == false and .preflight.resource_exit == 77' "$pressure/specs/PROJ-1-biome/state.json" >/dev/null || fail "refused preflight retained green evidence"

# An ambient marker without the inherited lease cannot bypass admission.
rc=0
(cd "$pressure" && PATH="$FAKE_BIN:$PATH" SKILLCHAIN_RESOURCE_ACTIVE=1 SKILLCHAIN_RESOURCE_LOCK_FILE= SKILLCHAIN_MEMINFO_FILE="$TMP/meminfo" SKILLCHAIN_CGROUP_DIR="$TMP/no-cgroup" SKILLCHAIN_RESOURCE_LOCK_DIR="$TMP/resources" bash "$PREFLIGHT" 1 biome >"$TMP/marker.log" 2>&1) || rc=$?
[ "$rc" -eq 77 ] || fail "ambient marker bypassed admission, got $rc"
[ ! -e "$RESOURCE_PROBE_MARKER" ] || fail "ambient marker launched provider"

# A valid outer lease from another policy must not skip this project's policy.
printf '{"resources":{"test_workers":0,"wait_seconds":0}}\n' >"$pressure/specs/PROJ-1-biome/3-4_plan/wave-gate-config.json"
printf '{"resources":{"min_available_mb":0,"max_memory_psi_full_avg10":100,"wait_seconds":0}}\n' >"$TMP/outer-resources.json"
rc=0
(cd "$pressure" && PATH="$FAKE_BIN:$PATH" SKILLCHAIN_MEMINFO_FILE="$TMP/meminfo" SKILLCHAIN_CGROUP_DIR="$TMP/no-cgroup" SKILLCHAIN_RESOURCE_LOCK_DIR="$TMP/resources" PREFLIGHT_PROBE_TIMEOUT=1 bash -c 'source "$1"; resource_run "$2" outer-preflight bash "$3" 1 biome' _ "$ROOT/codex/skills/5_executing/scripts/compat.sh" "$TMP/outer-resources.json" "$PREFLIGHT" >"$TMP/outer.log" 2>&1) || rc=$?
[ "$rc" -eq 64 ] || fail "outer lease bypassed project policy, got $rc: $(cat "$TMP/outer.log")"
[ ! -e "$RESOURCE_PROBE_MARKER" ] || fail "outer lease launched provider despite invalid project policy"
jq -e '.preflight.ok == false and .preflight.resource_exit == 64' "$pressure/specs/PROJ-1-biome/state.json" >/dev/null || fail "invalid nested policy retained green evidence"

# Stock macOS mkdir leases must reenter once, without recursive preflight launches.
portable="$TMP/portable-lease"
mkdir -p "$portable"
printf 'MemAvailable: 16777216 kB\n' >"$TMP/portable-meminfo"
printf '{"resources":{"min_available_mb":0,"max_memory_psi_full_avg10":100,"wait_seconds":0}}\n' >"$TMP/portable-config.json"
rc=0
(cd "$portable" && PATH="$FAKE_BIN:$PATH" SKILLCHAIN_MEMINFO_FILE="$TMP/portable-meminfo" SKILLCHAIN_CGROUP_DIR="$TMP/no-cgroup" SKILLCHAIN_RESOURCE_LOCK_DIR="$TMP/portable-resources" PREFLIGHT_SKIP_LIVE_PROBE=1 PREFLIGHT_CODEX_INACTIVE=1 REAL_BASH="$BASH" PREFLIGHT_SCRIPT="$PREFLIGHT" REENTRY_COUNT="$TMP/reentry-count" "$BASH" -c '
  command() { if [[ "${1:-}" == -v && "${2:-}" == flock ]]; then return 1; else builtin command "$@"; fi; }
  bash() {
    if [[ "${1:-}" == "$PREFLIGHT_SCRIPT" ]]; then
      local n=0; [[ ! -f "$REENTRY_COUNT" ]] || n=$(cat "$REENTRY_COUNT")
      n=$((n + 1)); echo "$n" >"$REENTRY_COUNT"
      [[ "$n" -le 1 ]] || { echo "unexpected recursive preflight launch" >&2; return 99; }
    fi
    "$REAL_BASH" "$@"
  }
  export -f command bash
  source "$1"
  "${TIMEOUT_BIN[@]}" --foreground 10 "$REAL_BASH" -c '\''source "$1"; resource_run "$2" portable-preflight "$REAL_BASH" "$PREFLIGHT_SCRIPT" 1 portable'\'' _ "$1" "$2"
' _ "$ROOT/codex/skills/5_executing/scripts/compat.sh" "$TMP/portable-config.json" >"$TMP/portable.log" 2>&1) || rc=$?
[ "$rc" -eq 0 ] || fail "portable lease preflight recursed or failed, got $rc: $(cat "$TMP/portable.log")"
[ "$(grep -c '→ P0 preflight' "$TMP/portable.log")" -eq 1 ] || fail "portable preflight body did not run exactly once"
