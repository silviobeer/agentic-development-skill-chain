#!/usr/bin/env bash
# harvest-debt.sh — collect `ponytail:` debt markers into the findings ledger.
#
# The ponytail comment convention IS the debt-marker convention (CONCEPT.md §7).
# This script greps the tree for markers and records each as a ledger finding
# with status `deferred`, so the PR body and morning report can render the
# debt section from data. Idempotent: ledger.mjs dedupes on file/line/category.
#
# Usage:   harvest-debt.sh <proj-x> <theme> [search-root]
#          search-root defaults to src; pass . to scan the whole repo
# Exit:    0 ok (also when zero markers found) · 1 ledger write failed · 64 usage
set -euo pipefail

PROJ="${1:-}"; THEME="${2:-}"; ROOT_DIR="${3:-src}"
if [ -z "$PROJ" ] || [ -z "$THEME" ]; then
  echo "Usage: $0 <proj-x> <theme> [search-root]" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$ROOT_DIR" ]; then
  echo "harvest-debt.sh: search root '$ROOT_DIR' does not exist — nothing to harvest"
  exit 0
fi

MATCHES="$(grep -R -n -I 'ponytail:' "$ROOT_DIR" \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=specs 2>/dev/null || true)"

if [ -z "$MATCHES" ]; then
  echo "harvest-debt.sh: no ponytail: markers under $ROOT_DIR"
  exit 0
fi

# One raw finding per marker; summary = the marker text after "ponytail:".
jq -R -c '
  capture("^(?<file>[^:]+):(?<line>[0-9]+):(?<rest>.*)$")
  | (.rest | (capture("ponytail:\\s*(?<note>.*)") // {note: .})) as $m
  | {
      source: "debt",
      severity: "low",
      status: "deferred",
      category: "debt",
      summary: ("ponytail: " + ($m.note | ltrimstr(" "))),
      file: .file,
      line: (.line | tonumber),
      debt_marker: $m.note
    }
' <<<"$MATCHES" | node "$SCRIPT_DIR/ledger.mjs" add "$PROJ" "$THEME"
