#!/usr/bin/env bash
# Deterministic behavior tests for ledger ingestion, dedupe, and reopen.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

run_suite() {
  local ledger="$1" label="$2" work
  work="$TMP/$label"
  mkdir -p "$work/specs/PROJ-1-test"

  set +e
  (cd "$work" && node "$ledger" add 1 test </dev/null) >"$work/empty.out" 2>&1
  local rc=$?
  set -e
  [[ "$rc" -eq 1 ]] || fail "$label: empty stdin returned $rc, expected 1"
  [[ ! -e "$work/specs/PROJ-1-test/findings.json" ]] || fail "$label: empty stdin wrote a ledger"

  set +e
  printf '%s\n' '{"source":"coderabbit","severity":"major","category":{"name":"review"},"summary":"Bad category","file":"src/a.ts","line":1.5,"anchor":["symbol"]}' \
    | (cd "$work" && node "$ledger" add 1 test) >"$work/invalid.out" 2>&1
  rc=$?
  set -e
  [[ "$rc" -eq 1 ]] || fail "$label: invalid optional field types returned $rc, expected 1"
  [[ ! -e "$work/specs/PROJ-1-test/findings.json" ]] || fail "$label: invalid optional field types wrote a ledger"

  set +e
  printf '%s\n' '{"source":"coderabbit","severity":"major","summary":"   "}' \
    | (cd "$work" && node "$ledger" add 1 test) >"$work/blank-summary.out" 2>&1
  rc=$?
  set -e
  [[ "$rc" -eq 1 ]] || fail "$label: whitespace-only summary returned $rc, expected 1"
  [[ ! -e "$work/specs/PROJ-1-test/findings.json" ]] || fail "$label: whitespace-only summary wrote a ledger"

  set +e
  printf '%s\n' '{"source":"coderabbit","severity":"major","summary":"Bad wave"}' \
    | (cd "$work" && node "$ledger" add 1 test --wave nope) >"$work/invalid-wave.out" 2>&1
  rc=$?
  set -e
  [[ "$rc" -eq 1 ]] || fail "$label: invalid wave returned $rc, expected 1"
  [[ ! -e "$work/specs/PROJ-1-test/findings.json" ]] || fail "$label: invalid wave wrote a ledger"

  printf '%s\n' \
    '{"source":"coderabbit","severity":"major","category":"review","summary":"First issue","file":"src/a.ts"}' \
    '{"source":"coderabbit","severity":"major","category":"review","summary":"Second issue","file":"src/a.ts"}' \
    | (cd "$work" && node "$ledger" add 1 test) >/dev/null
  [[ $(jq '.findings | length' "$work/specs/PROJ-1-test/findings.json") -eq 2 ]] \
    || fail "$label: distinct unanchored findings collapsed"

  printf '%s\n' '{"source":"coderabbit","severity":"major","category":"review","summary":"  FIRST   issue ","file":"src/a.ts"}' \
    | (cd "$work" && node "$ledger" add 1 test) >/dev/null
  [[ $(jq '.findings | length' "$work/specs/PROJ-1-test/findings.json") -eq 2 ]] \
    || fail "$label: genuine duplicate was added"

  local id
  id=$(jq -r '.findings[] | select(.summary == "First issue") | .id' "$work/specs/PROJ-1-test/findings.json")
  (cd "$work" && node "$ledger" set-status 1 test "$id" fixed abc123) >/dev/null
  printf '%s\n' '{"source":"coderabbit","severity":"critical","category":"review","summary":"First issue","file":"src/a.ts"}' \
    | (cd "$work" && node "$ledger" add 1 test) >"$work/reopen.out"
  jq -e --arg id "$id" '.findings[] | select(.id == $id) | .status == "open" and .severity == "critical"' \
    "$work/specs/PROJ-1-test/findings.json" >/dev/null || fail "$label: fixed finding was not reopened/escalated"
  grep -q 'REOPENED' "$work/reopen.out" || fail "$label: reopen was not reported"
}

run_suite "$ROOT/codex/skills/6_qa/scripts/ledger.mjs" codex
run_suite "$ROOT/claude/skills/6_qa/scripts/ledger.mjs" claude
cmp -s "$ROOT/codex/skills/6_qa/scripts/ledger.mjs" "$ROOT/claude/skills/6_qa/scripts/ledger.mjs" \
  || fail "ledger copies are not byte-identical"

echo 'ledger behavior tests: PASS'
