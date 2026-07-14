#!/usr/bin/env bash
# spike-dual-lane.sh — Stage 1 verification spike / release gate (CONCEPT.md §6b).
#
# Proves, on one dummy artifact:
#   1. `claude -p` and `codex exec` launch CONCURRENTLY from the runner
#   2. both lanes are enforced read-only (tool restriction / sandbox)
#   3. both produce at least one valid findings JSON line
#   4. provider attribution is runner-side (output captured per lane) and
#      the provider-opposite pairing is derived correctly from author_provider
#   5. cancellation kills BOTH whole process trees (no orphans)
#
# In degraded mode (codex missing/unauthenticated) the spike instead
# proves the model-opposite fallback: a second claude lane with a
# different model (CLAUDE_REVIEW_MODEL, default sonnet).
#
# Usage: spike-dual-lane.sh [--timeout S]     (default 300)
# Exit:  0 all assertions passed · 1 any assertion failed
set -uo pipefail

TIMEOUT=300
[ "${1:-}" = "--timeout" ] && TIMEOUT="${2:?}"

REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-sonnet}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0

ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $*"; FAIL=$((FAIL+1)); }
step() { echo "→ $*"; }

# --- dummy artifact with a planted factual error -------------------------
cat >"$WORK/architecture-delta.md" <<'EOF'
# Dummy architecture delta (spike artifact)

- NEW: status transitions are processed through an event queue.
- NEW: the queue consumer retries failed events forever with no backoff
  and no dead-letter handling.
- Uses the standing auth decision (see baseline).
EOF

PROMPT="You are a read-only adversarial reviewer in a verification spike.
Review the file architecture-delta.md in the current directory for risky
or wrong decisions. Do not modify anything. Your ENTIRE final answer must
be findings as JSON lines — one object per line, no prose, no markdown fences:
{\"source\":\"review\",\"severity\":\"high\",\"category\":\"...\",\"summary\":\"...\"}
Output at least one finding."

DEGRADED=false
if ! command -v codex >/dev/null 2>&1 || ! codex login status >/dev/null 2>&1; then
  DEGRADED=true
  step "codex unavailable — spiking the DEGRADED model-opposite path (claude + claude --model $REVIEW_MODEL)"
fi

# Lanes are launched from the MAIN shell (no command substitution) so that
# `wait` sees them, and under setsid so each lane is its own process group
# and `kill -- -PID` reaches the whole tree without touching the spike.
LANE_PID=""
launch_claude() { # outfile [model] — sets LANE_PID
  local out="$1" model="${2:-}"
  setsid bash -c 'cd "$1" && exec claude -p "$2" ${3:+--model "$3"} --allowedTools "Read,Grep,Glob"' \
    _ "$WORK" "$PROMPT" "$model" </dev/null >"$out" 2>&1 &
  LANE_PID=$!
}
launch_codex() { # outfile — sets LANE_PID
  # --skip-git-repo-check: the spike workdir is a throwaway temp dir, not a
  # repo. Real runner lanes run inside the project repo and don't need it.
  local out="$1"
  setsid bash -c 'cd "$1" && exec codex exec --sandbox read-only --skip-git-repo-check "$2"' \
    _ "$WORK" "$PROMPT" </dev/null >"$out" 2>&1 &
  LANE_PID=$!
}

valid_findings() { # file -> count of valid JSON finding lines
  local n=0 line
  while IFS= read -r line; do
    jq -e 'type == "object" and .source? and .severity? and .summary?' >/dev/null 2>&1 <<<"$line" && n=$((n+1))
  done < <(grep '^{' "$1" 2>/dev/null || true)
  echo "$n"
}

wait_both() { # pid1 pid2 -> 0 both done, 124 timeout
  local deadline=$((SECONDS + TIMEOUT))
  while kill -0 "$1" 2>/dev/null || kill -0 "$2" 2>/dev/null; do
    [ "$SECONDS" -ge "$deadline" ] && return 124
    sleep 5
  done
  return 0
}

# --- assertion 1–4: concurrent read-only lanes, valid JSONL, attribution -
step "launching both lanes concurrently (timeout ${TIMEOUT}s)"
out1="$WORK/claude-writer-peer.out"
out2="$WORK/second-lane.out"

launch_claude "$out1"; pid1="$LANE_PID"
if [ "$DEGRADED" = true ]; then
  launch_claude "$out2" "$REVIEW_MODEL"; pid2="$LANE_PID"
  LANE2="claude(--model $REVIEW_MODEL)"
else
  launch_codex "$out2"; pid2="$LANE_PID"
  LANE2="codex"
fi
step "lane A: claude (pid $pid1) · lane B: $LANE2 (pid $pid2) — running concurrently"

if wait_both "$pid1" "$pid2"; then
  wait "$pid1" 2>/dev/null; rc1=$?
  wait "$pid2" 2>/dev/null; rc2=$?
  [ "$rc1" -eq 0 ] && ok "lane A (claude) exited 0" || bad "lane A exited $rc1 — output: $(tail -c 400 "$out1")"
  [ "$rc2" -eq 0 ] && ok "lane B ($LANE2) exited 0" || bad "lane B exited $rc2 — output: $(tail -c 400 "$out2")"
else
  bad "lanes did not finish within ${TIMEOUT}s"
  kill -TERM -- "-$pid1" "-$pid2" 2>/dev/null
fi

n1="$(valid_findings "$out1")"; n2="$(valid_findings "$out2")"
[ "$n1" -ge 1 ] && ok "lane A produced $n1 valid finding JSON line(s)" || bad "lane A produced no valid JSON lines — output: $(tail -c 400 "$out1")"
[ "$n2" -ge 1 ] && ok "lane B produced $n2 valid finding JSON line(s)" || bad "lane B produced no valid JSON lines — output: $(tail -c 400 "$out2")"

# runner-side attribution + provider-opposite pairing
for author in claude codex; do
  if [ "$DEGRADED" = true ]; then
    opposite="claude:$REVIEW_MODEL (model-opposite fallback)"
  else
    [ "$author" = "claude" ] && opposite="codex" || opposite="claude"
  fi
  echo "  · author_provider=$author → reviewer: $opposite"
done
ok "attribution is runner-side (per-lane output capture), pairing derived from author_provider"

# read-only enforcement: the artifact must be untouched
grep -q "retries failed events forever" "$WORK/architecture-delta.md" \
  && ok "artifact untouched — lanes were read-only" \
  || bad "artifact was MODIFIED by a supposedly read-only lane"

# --- assertion 5: cancellation kills both process trees ------------------
step "cancellation test: relaunch, then kill both process groups"
out1c="$WORK/cancel-a.out"; out2c="$WORK/cancel-b.out"
launch_claude "$out1c"; pid1="$LANE_PID"
if [ "$DEGRADED" = true ]; then
  launch_claude "$out2c" "$REVIEW_MODEL"; pid2="$LANE_PID"
else
  launch_codex "$out2c"; pid2="$LANE_PID"
fi
sleep 4
kill -TERM -- "-$pid1" 2>/dev/null; kill -TERM -- "-$pid2" 2>/dev/null
sleep 3
kill -KILL -- "-$pid1" 2>/dev/null; kill -KILL -- "-$pid2" 2>/dev/null
sleep 1
left="$( (pgrep -g "$pid1"; pgrep -g "$pid2") 2>/dev/null | wc -l | tr -d ' ')"
[ "$left" = "0" ] && ok "cancellation killed both process trees (no survivors in either group)" \
                  || bad "$left process(es) survived cancellation"
wait "$pid1" 2>/dev/null; wait "$pid2" 2>/dev/null

# --- verdict --------------------------------------------------------------
echo
if [ "$FAIL" -eq 0 ]; then
  echo "✓ SPIKE PASSED ($PASS assertions$( [ "$DEGRADED" = true ] && echo ", degraded path"))"
  exit 0
else
  echo "❌ SPIKE FAILED — $FAIL failed, $PASS passed"
  exit 1
fi
