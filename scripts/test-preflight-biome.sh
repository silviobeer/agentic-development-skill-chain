#!/usr/bin/env bash
# Behavior tests for P0 preflight's Biome compatibility and wrapped Sonar probe.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFLIGHT="$ROOT/codex/skills/4b_setup/scripts/preflight.sh"
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
    PONYTAIL_ENFORCE=0 \
    PONYTAIL_CONFIG="$TMP/ponytail-config.json" \
    PONYTAIL_CLAUDE_REGISTRY="$TMP/no-claude-registry.json" \
    bash "$PREFLIGHT" 1 biome >/dev/null)
}

ignored='[".claude/settings.json","scripts/compile-context-bundles.mjs","scripts/context-injector.mjs","scripts/gen-component-registry.mjs","scripts/ledger.mjs","scripts/render-pr-body.mjs"]'

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
printf 'SONAR_TOKEN=test-token\n' >"$sonar/.env.local"
sonar_output="$(cd "$sonar" && \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  PREFLIGHT_SKIP_LIVE_PROBE=1 \
  PREFLIGHT_CODEX_INACTIVE=1 \
  PONYTAIL_ENFORCE=0 \
  PONYTAIL_CONFIG="$TMP/ponytail-config.json" \
  PONYTAIL_CLAUDE_REGISTRY="$TMP/no-claude-registry.json" \
  bash "$PREFLIGHT" 1 sonar)"
grep -q 'npm-wrapped scanner engine' <<<"$sonar_output" \
  || fail "npm-wrapped sonar_cmd was not accepted without standalone sonar-scanner"

cmp -s "$PREFLIGHT" "$ROOT/claude/skills/4b_setup/scripts/preflight.sh" \
  || fail "preflight provider copies are not byte-identical"

echo "preflight compatibility tests: PASS"
