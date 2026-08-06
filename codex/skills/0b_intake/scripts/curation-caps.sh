#!/usr/bin/env bash
# curation-caps.sh — hard FORM gate for the curated context (CONCEPT.md §5).
#
# Caps (deterministic definitions of the §5 limits):
#   docs/PRODUCT.md        <= 30 non-blank lines   ("half page")
#   docs/ARCHITECTURE.md   <= 200 lines
#   docs/DESIGN-SYSTEM.md  <= 80 lines    (injected into every frontend bundle)
#   src/**/agent.md        <= 100 lines each
#   AGENTS.md (root)       <= 40 non-blank lines   (existing 7_documentation cap)
#
# This script checks FORM only. TRUTH (stale claims, cap-gaming — shrinking
# docs by deleting true load-bearing statements) is checked by the
# cross-review P7 pass. Curation must shrink before P7 completes.
#
# Usage: curation-caps.sh [--require-baseline] [repo-root]
#   --require-baseline  missing capped docs are breaches instead of warnings
#                       (used by 0b_intake's seal check; normal P7 runs on
#                       repos without an intake baseline must not hard-fail)
# Exit: 0 all caps ok · 1 any breach
set -euo pipefail

REQUIRE_BASELINE=0
ROOT="."
for arg in "$@"; do
  case "$arg" in
    --require-baseline) REQUIRE_BASELINE=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) ROOT="$arg" ;;
  esac
done
cd "$ROOT"

BREACH=0

nonblank() { grep -c -v '^[[:space:]]*$' "$1" || true; }
total()    { wc -l < "$1" | tr -d ' '; }

check() { # <file> <count> <cap> <unit>
  local file="$1" count="$2" cap="$3" unit="$4"
  if [ "$count" -le "$cap" ]; then
    echo "OK      $file ${count}/${cap} ${unit}"
  else
    echo "BREACH  $file ${count}/${cap} ${unit} — curate: shrink before sealing"
    BREACH=1
  fi
}

missing() { # <file>
  if [ "$REQUIRE_BASELINE" -eq 1 ]; then
    echo "BREACH  $1 missing (required baseline file)"
    BREACH=1
  else
    echo "WARN    $1 missing — no baseline yet (not a breach; run 0a/0c for a new build, 0b_intake for an existing codebase)"
  fi
}

if [ -f docs/PRODUCT.md ]; then
  check docs/PRODUCT.md "$(nonblank docs/PRODUCT.md)" 30 "non-blank lines"
else
  missing docs/PRODUCT.md
fi

if [ -f docs/ARCHITECTURE.md ]; then
  check docs/ARCHITECTURE.md "$(total docs/ARCHITECTURE.md)" 200 "lines"
else
  missing docs/ARCHITECTURE.md
fi

# Only capped when it exists: projects without a UI never create it, and a
# missing design system is not a curation breach.
if [ -f docs/DESIGN-SYSTEM.md ]; then
  check docs/DESIGN-SYSTEM.md "$(total docs/DESIGN-SYSTEM.md)" 80 "lines"
fi

if [ -f AGENTS.md ]; then
  check AGENTS.md "$(nonblank AGENTS.md)" 40 "non-blank lines"
else
  missing AGENTS.md
fi

if [ -d src ]; then
  while IFS= read -r f; do
    check "$f" "$(total "$f")" 100 "lines"
  done < <(find src -type f -name agent.md | sort)
fi

if [ "$BREACH" -eq 0 ]; then
  echo "✓ curation caps ok"
else
  echo "❌ curation caps BREACHED — P7 must not seal until every file above fits its cap" >&2
fi
exit "$BREACH"
