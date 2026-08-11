#!/usr/bin/env bash
# Behavior test for the existing Biome 1/2 compatibility branch in P0 preflight.
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

cmp -s "$PREFLIGHT" "$ROOT/claude/skills/4b_setup/scripts/preflight.sh" \
  || fail "preflight provider copies are not byte-identical"

echo "preflight Biome compatibility tests: PASS"
