#!/usr/bin/env bash
# ci-poll.sh — P8 step 4: wait for the PR's CI checks and surface red
# checks with verbatim logs for fix agents.
#
# Resolves the PR head SHA and requires a completed, successful latest run for
# every workflow on that commit. This deliberately treats "no run yet" as red:
# queued concurrency-group work has no PR check to watch.
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

HEAD_SHA="$(gh pr view "$PR" --json headRefOid --jq .headRefOid)"
[ -n "$HEAD_SHA" ] || { echo "ci-poll.sh: could not resolve the head commit of PR #${PR}" >&2; exit 1; }
echo "→ [$(date -Iseconds)] polling PR #${PR} at ${HEAD_SHA:0:7} (timeout ${TIMEOUT}s)"

# Push and pull_request can produce two runs. The newest per workflow is the
# verdict; a newest cancelled/failed run never inherits an older success.
latest_runs() {
  gh run list --commit "$HEAD_SHA" --limit 50 --json databaseId,status,conclusion,name \
    --jq 'group_by(.name) | map(max_by(.databaseId))'
}

DEADLINE=$(( $(date +%s) + TIMEOUT ))
while :; do
  RUNS="$(latest_runs 2>/dev/null || echo '[]')"
  TOTAL=$(jq 'length' <<<"$RUNS")
  PENDING=$(jq '[.[] | select(.status != "completed")] | length' <<<"$RUNS")
  [ "$TOTAL" -gt 0 ] && [ "$PENDING" -eq 0 ] && break
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    if [ "$TOTAL" -eq 0 ]; then
      echo "❌ TIMEOUT: no workflow run appeared for ${HEAD_SHA:0:7}; nothing verified this commit." >&2
    else
      echo "❌ TIMEOUT after ${TIMEOUT}s — still running:" >&2
      jq -r '.[] | select(.status != "completed") | "   \(.name): \(.status)"' <<<"$RUNS" >&2
    fi
    exit 2
  fi
  echo "   [$(date +%H:%M:%S)] ${TOTAL} workflow(s), ${PENDING} not finished — waiting"
  sleep 30
done

RED=0
FAILED=$(jq -r '.[] | select(.conclusion != "success" and .conclusion != "skipped") | "\(.databaseId) \(.name) \(.conclusion)"' <<<"$RUNS")
if [ -n "$FAILED" ]; then
  RED=1
  echo "❌ workflow runs that did not succeed on ${HEAD_SHA:0:7}:" >&2
  sed 's/^/   /' <<<"$FAILED" >&2
fi
CHECKS="$(gh pr checks "$PR" 2>/dev/null || true)"
if grep -qE $'\tfail\t' <<<"$CHECKS"; then
  RED=1
  echo "❌ red PR checks:" >&2
  grep -E $'\tfail\t' <<<"$CHECKS" | sed 's/^/   /' >&2
fi
if [ "$RED" -eq 0 ]; then
  echo "✓ every workflow completed successfully on ${HEAD_SHA:0:7}, and no PR check is red"
  jq -r '.[] | "   \(.name): \(.conclusion)"' <<<"$RUNS"
  exit 0
fi
for run_id in $(jq -r '.[] | select(.conclusion != "success" and .conclusion != "skipped") | .databaseId' <<<"$RUNS"); do
  echo "── failed run ${run_id} on ${HEAD_SHA:0:7} (log-failed, verbatim) ──" >&2
  gh run view "$run_id" --log-failed >&2 || true
done

echo "→ NEXT ACTION: hand the verbatim output above to a fix agent (max 3 attempts, then stop condition §8)." >&2
exit 1
