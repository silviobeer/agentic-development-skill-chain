#!/usr/bin/env bash
#
# proj-readiness-check.sh — Is the next PROJ ready to execute without user input?
#
# Called at the end of Skill 5 (or Skill 7 in autonomous mode) to decide
# whether to auto-continue to the next PROJ or stop.
#
# Usage:
#   bash scripts/proj-readiness-check.sh <current-proj-num>
# Example:
#   bash scripts/proj-readiness-check.sh 1
#
# A PROJ counts as "ready" when it has all of:
#   - specs/PROJ-<N>-<theme>/6_plan/PROJ-<N>-architecture.md
#   - specs/PROJ-<N>-<theme>/6_plan/PROJ-<N>-wave-1-plan.md (at least one wave)
#   - specs/PROJ-<N>-<theme>/6_plan/wave-gate-config.json
#
# Exit codes:
#   0 — next PROJ is ready; prints its folder + NEXT ACTION hint
#   1 — no further PROJ found → entire work stream complete
#   2 — next PROJ exists but is NOT ready (missing files listed)
#   64 — usage error

set -euo pipefail

CURRENT="${1:-}"
[[ -z "$CURRENT" ]] && { echo "Usage: $0 <current-proj-num>" >&2; exit 64; }
[[ "$CURRENT" =~ ^[0-9]+$ ]] || { echo "PROJ number must be numeric, got: $CURRENT" >&2; exit 64; }

NEXT=$((CURRENT + 1))

# Find the next PROJ folder (any thema suffix). Use nullglob so missing matches
# don't expand to the literal pattern.
shopt -s nullglob
matches=(specs/PROJ-${NEXT}-*)
shopt -u nullglob

if [[ "${#matches[@]}" -eq 0 ]]; then
  echo "→ NEXT ACTION: No PROJ-${NEXT} found. Entire work stream complete."
  echo "  Final step: confirm all PROJ documentation committed, then stop."
  exit 1
fi

if [[ "${#matches[@]}" -gt 1 ]]; then
  echo "❌ Ambiguous: multiple folders match specs/PROJ-${NEXT}-*:" >&2
  printf '   %s\n' "${matches[@]}" >&2
  exit 2
fi

NEXT_DIR="${matches[0]}"
PLAN_DIR="${NEXT_DIR}/6_plan"
MISSING=()

[[ -f "${PLAN_DIR}/PROJ-${NEXT}-architecture.md" ]] || MISSING+=("${PLAN_DIR}/PROJ-${NEXT}-architecture.md")
[[ -f "${PLAN_DIR}/PROJ-${NEXT}-wave-1-plan.md" ]]  || MISSING+=("${PLAN_DIR}/PROJ-${NEXT}-wave-1-plan.md")
[[ -f "${PLAN_DIR}/wave-gate-config.json" ]]       || MISSING+=("${PLAN_DIR}/wave-gate-config.json")

if [[ "${#MISSING[@]}" -ne 0 ]]; then
  echo "→ NEXT ACTION: PROJ-${NEXT} folder exists but is NOT fully planned."
  echo "  Missing files:"
  printf '    - %s\n' "${MISSING[@]}"
  echo "  STOP. Invoke Skills 3 (architecture) and 4 (wave plans) for PROJ-${NEXT} with the user."
  exit 2
fi

# PRD coverage: every PRD under 3_PRDs/ must be referenced by at least one wave plan.
# Catches cases where Skill 4 forgot to include US from a late-added PRD.
PRD_DIR="${NEXT_DIR}/3_PRDs"
ORPHANED_PRDS=()
if [[ -d "$PRD_DIR" ]]; then
  shopt -s nullglob
  prd_files=("${PRD_DIR}"/PROJ-${NEXT}-PRD-*.md)
  shopt -u nullglob
  for prd_file in "${prd_files[@]}"; do
    # Strip optional suffix: PROJ-2-PRD-1-collector-framework → PROJ-2-PRD-1
    full_name=$(basename "$prd_file" .md)
    prd_stub=$(echo "$full_name" | grep -oE "^PROJ-${NEXT}-PRD-[0-9]+")
    [[ -z "$prd_stub" ]] && prd_stub="$full_name"
    # Search all wave plans for the PRD stub followed by a non-digit (word boundary).
    # Prevents PROJ-2-PRD-1 from matching PROJ-2-PRD-10.
    if ! grep -Elq "${prd_stub}([^0-9]|$)" "${PLAN_DIR}"/PROJ-${NEXT}-wave-*-plan.md 2>/dev/null; then
      ORPHANED_PRDS+=("$prd_stub ($full_name)")
    fi
  done
fi

if [[ "${#ORPHANED_PRDS[@]}" -ne 0 ]]; then
  echo "→ NEXT ACTION: PROJ-${NEXT} has PRDs not referenced in any wave plan:"
  printf '    - %s\n' "${ORPHANED_PRDS[@]}"
  echo "  These PRDs' user stories would ship unimplemented."
  echo "  STOP. Re-run Skill 4 (writing-plans) for PROJ-${NEXT} to fold them into the wave plans."
  exit 2
fi

# Count wave plans + PRDs for a helpful hint
WAVE_COUNT=$(ls -1 "${PLAN_DIR}"/PROJ-${NEXT}-wave-*-plan.md 2>/dev/null | wc -l)
PRD_COUNT=$(ls -1 "${PRD_DIR}"/PROJ-${NEXT}-PRD-*.md 2>/dev/null | wc -l)

echo "→ NEXT ACTION: Start Skill 5 NOW for PROJ-${NEXT}."
echo "  Folder: ${NEXT_DIR}"
echo "  PRDs: ${PRD_COUNT} (all referenced in wave plans)"
echo "  Waves planned: ${WAVE_COUNT}"
echo "  Do NOT pause. Do NOT ask the user. The PROJ is fully planned — execute it."
echo ""
echo "  Steps: /compact → read ${PLAN_DIR}/PROJ-${NEXT}-wave-1-plan.md → spawn teammates"
exit 0
