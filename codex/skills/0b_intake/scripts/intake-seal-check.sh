#!/usr/bin/env bash
# intake-seal-check.sh — seal gate for the 0b_intake bootstrap (CONCEPT.md §3).
#
# The intake may only seal (= commit the initial curation baseline) when:
#   (a) every baseline file exists,
#   (b) NO provenance markers remain — [extracted: ...], [assumed], [gap: ...]
#       are working-draft syntax; every one of them was either resolved in the
#       interview/checkpoint or must still be worked through,
#   (c) the file caps hold (curation-caps.sh --require-baseline) — interview
#       output is curated, not dumped.
#
# Usage: intake-seal-check.sh [repo-root]
# Exit:  0 sealable · 1 not sealable (report on stdout)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-.}"
cd "$ROOT"

FAIL=0

BASELINE=(
  docs/PRODUCT.md
  docs/ARCHITECTURE.md
  docs/GUIDELINES.md
  docs/security-baseline.md
  docs/test-conventions.md
  AGENTS.md
)
for f in "${BASELINE[@]}"; do
  if [ -f "$f" ]; then
    echo "OK      $f exists"
  else
    echo "MISSING $f — the intake must draft every baseline file (a thin file with a pointer beats an absent one)"
    FAIL=1
  fi
done

# DESIGN-SYSTEM.md and components.md are UI-only baseline files: a backend-only
# repo never has a component directory and must not be blocked from sealing
# because of it (mirrors curation-caps.sh's own DESIGN-SYSTEM.md optionality).
HAS_COMPONENTS=false
if [ -d src/components ]; then
  HAS_COMPONENTS=true
elif find src/features -maxdepth 2 -type d -name components 2>/dev/null | grep -q .; then
  HAS_COMPONENTS=true
fi
if [ "$HAS_COMPONENTS" = true ]; then
  for f in docs/DESIGN-SYSTEM.md docs/components.md; do
    if [ -f "$f" ]; then
      echo "OK      $f exists"
    else
      echo "MISSING $f — components exist under src/ but $f was not drafted"
      FAIL=1
    fi
  done
else
  echo "OK      docs/DESIGN-SYSTEM.md, docs/components.md not required — no src/components or src/features/*/components found (backend-only repo)"
fi

# (b) residual provenance markers — drafts carry them, the sealed baseline never does
MARKERS="$(grep -rn -e '\[extracted:' -e '\[assumed\]' -e '\[gap' docs/ AGENTS.md 2>/dev/null || true)"
if [ -n "$MARKERS" ]; then
  echo "MARKERS residual provenance markers found — resolve them via interview + checkpoint, then strip:"
  echo "$MARKERS" | sed 's/^/          /'
  FAIL=1
else
  echo "OK      no residual provenance markers"
fi

# (c) reconcile evidence — the interview + checkpoint loop must have run;
# never seal undiscussed drafts as a baseline
if [ -f specs/intake/decisions.md ] && grep -q 'D-BOOTSTRAP-' specs/intake/decisions.md; then
  echo "OK      specs/intake/decisions.md carries D-BOOTSTRAP reconcile decisions"
else
  echo "MISSING specs/intake/decisions.md with D-BOOTSTRAP-<NN> entries — no evidence of the interview/checkpoint reconcile"
  FAIL=1
fi

# (d) file caps — delegated to the curation caps (FORM gate)
if ! bash "$SCRIPT_DIR/curation-caps.sh" --require-baseline .; then
  FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "✓ intake baseline is sealable — commit it: docs: intake baseline — initial curated docs"
else
  echo "❌ intake baseline NOT sealable — fix the items above first" >&2
fi
exit "$FAIL"
