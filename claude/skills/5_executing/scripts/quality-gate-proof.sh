#!/usr/bin/env bash
# quality-gate-proof.sh — refuse to seal P5 without machine-readable evidence
# that the PROJ-end Quality Gate ran, including Sonar or a valid skip reason.
# Usage: quality-gate-proof.sh <proj-x> <theme>
set -euo pipefail

PROJ="${1:-}"; THEME="${2:-}"
[ -n "$PROJ" ] && [ -n "$THEME" ] || { echo "Usage: $0 <proj-x> <theme>" >&2; exit 64; }
PROGRESS="specs/PROJ-${PROJ}-${THEME}/5_progress/PROJ-${PROJ}-progress.md"
[ -f "$PROGRESS" ] || { echo "quality gate proof: progress file missing: $PROGRESS" >&2; exit 1; }

fail() { echo "quality gate proof: $*" >&2; exit 1; }
section_passed() { # <heading>; matches only within its ### block
  awk -v heading="$1" 'on && /^### / { exit } $0 == "### " heading { on=1 } on && /^Status: passed$/ { ok=1 } END { exit ok ? 0 : 1 }' <<<"$QUALITY"
}
QUALITY="$(awk 'on && /^## / { exit } /^## Quality Gate —/ { on=1 } on { print }' "$PROGRESS")"
[ -n "$QUALITY" ] || fail "Quality Gate section missing"
section_passed 'Code Review' || fail "Code Review needs Status: passed"
section_passed 'Build' || fail "Build needs Status: passed"
section_passed 'Tests' || fail "Tests need Status: passed"
section_passed 'Lint' || fail "Lint needs Status: passed"
grep -q '^### SonarCloud' <<<"$QUALITY" || fail "SonarCloud evidence missing"
SONAR="$(awk 'on && /^### / { exit } /^### SonarCloud/ { on=1 } on { print }' <<<"$QUALITY")"
if grep -qE 'Status: ran' <<<"$SONAR"; then
  :
elif grep -qE 'Status: skipped \((sonar CLI unavailable|project not configured)\)' <<<"$SONAR"; then
  if command -v sonar >/dev/null && command -v sonar-scanner >/dev/null && [ -f sonar-project.properties ]; then
    fail "Sonar was skipped although both CLIs and sonar-project.properties are present"
  fi
else
  fail "SonarCloud needs Status: ran or an explicit allowed skip reason"
fi
echo "✓ Quality Gate proof present (code review, build, Sonar disposition)"
