#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLICE="$ROOT/codex/skills/5_executing/scripts/story-slice.mjs"
CASE="$(mktemp -d)"
trap 'rm -rf "$CASE"' EXIT

cat >"$CASE/plan.md" <<'PLAN'
# Wave 1

## Execution
- **Mode:** `parallel`

## PROJ-1-PRD-1-US-1: First
**Acceptance Criteria:**
- [ ] PROJ-1-PRD-1-US-1-AC-1: works

### Task PROJ-1-PRD-1-US-1-T1: Build
````md
```
## not a heading inside a fence
````

## PROJ-1-PRD-1-US-10: Tenth
- [ ] PROJ-1-PRD-1-US-10-AC-1: other
PLAN

node "$SLICE" "$CASE/plan.md" PROJ-1-PRD-1-US-1 >"$CASE/out"
head -n 1 "$CASE/out" | grep -qx '## PROJ-1-PRD-1-US-1: First' || { echo "slice must start at its heading" >&2; exit 1; }
grep -qF '## not a heading inside a fence' "$CASE/out" || { echo "fenced ## line must not end the slice" >&2; exit 1; }
grep -qF 'US-10' "$CASE/out" && { echo "slice leaked into US-10" >&2; exit 1; }
grep -qF 'Execution' "$CASE/out" && { echo "slice leaked the lead header" >&2; exit 1; }
node "$SLICE" "$CASE/plan.md" PROJ-1-PRD-1-US-10 | grep -qF 'US-10-AC-1' || { echo "last section must slice to EOF" >&2; exit 1; }

if node "$SLICE" "$CASE/plan.md" PROJ-1-PRD-1-US-2 >/dev/null 2>&1; then echo "missing ID accepted" >&2; exit 1; fi
printf '\n## PROJ-1-PRD-1-US-1: Again\n' >>"$CASE/plan.md"
if node "$SLICE" "$CASE/plan.md" PROJ-1-PRD-1-US-1 >/dev/null 2>&1; then echo "duplicate ID accepted" >&2; exit 1; fi

node "$SLICE" "$ROOT/scripts/fixtures/wave-plan-validator/plan-valid.md" PROJ-1-PRD-1-US-1 | grep -qF '### Task PROJ-1-PRD-1-US-1-T1' || { echo "validator fixture did not slice" >&2; exit 1; }
echo "story-slice: ok"
