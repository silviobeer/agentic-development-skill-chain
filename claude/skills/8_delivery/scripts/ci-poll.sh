#!/usr/bin/env bash
# ci-poll.sh — P8 step 4: wait for the PR's CI checks and surface red
# checks with verbatim logs for fix agents.
#
# Wraps `gh pr checks --watch`. On red, prints the check table and a
# best-effort `gh run view --log-failed` for each failed GitHub Actions
# run so a fix agent gets the exact failing output, not a paraphrase.
#
# Usage:  ci-poll.sh <pr-number> [timeout-seconds]   (default: 1800)
# Exit:   0 all checks green · 1 at least one check red · 2 timeout · 64 usage
set -euo pipefail

PR="${1:-}"; TIMEOUT="${2:-1800}"
if [ -z "$PR" ]; then
  echo "Usage: $0 <pr-number> [timeout-seconds]" >&2
  exit 64
fi
case "$TIMEOUT" in (*[!0-9]*|'') echo "ci-poll.sh: timeout must be a positive integer" >&2; exit 64 ;; esac

echo "→ [$(date -Iseconds)] polling checks for PR #${PR} (timeout ${TIMEOUT}s)"

set +e
timeout --foreground "$TIMEOUT" gh pr checks "$PR" --watch --fail-fast
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "✓ all checks green for PR #${PR}"
  exit 0
fi

if [ "$rc" -eq 124 ]; then
  echo "❌ CI polling TIMED OUT after ${TIMEOUT}s for PR #${PR}" >&2
  echo "→ NEXT ACTION: stop condition candidate (§8) — inspect CI manually or raise the timeout." >&2
  exit 2
fi

echo "❌ red checks on PR #${PR}:" >&2
gh pr checks "$PR" >&2 || true

# Verbatim logs of failed Actions runs (best effort — non-Actions checks
# have no fetchable log here).
HEAD_BRANCH="$(gh pr view "$PR" --json headRefName --jq .headRefName 2>/dev/null || true)"
if [ -n "$HEAD_BRANCH" ]; then
  for run_id in $(gh run list --branch "$HEAD_BRANCH" --status failure --limit 5 --json databaseId --jq '.[].databaseId' 2>/dev/null || true); do
    echo "── failed run ${run_id} (log-failed, verbatim) ──" >&2
    gh run view "$run_id" --log-failed >&2 || true
  done
fi

echo "→ NEXT ACTION: hand the verbatim output above to a fix agent (max 3 attempts, then stop condition §8)." >&2
exit 1
