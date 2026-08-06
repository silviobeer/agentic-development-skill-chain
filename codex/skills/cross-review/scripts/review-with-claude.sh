#!/usr/bin/env bash
# review-with-claude.sh — Claude adapter for the cross-review gate (CONCEPT.md §4/§7).
#
# Invokes `claude -p` strictly read-only on a rendered review prompt and
# normalizes the output to the findings JSON-lines contract (ledger.mjs):
# only lines that parse as objects with severity+summary survive, each
# stamped with "provider":"claude". The invocation runs as its own process
# group and is killed whole (TERM then KILL) on timeout — no orphans.
#
# Usage: review-with-claude.sh --prompt <file> [--model M] [--timeout S]
# Exit:  0 valid finding lines on stdout · 1 CLI failed/timeout/zero valid lines · 64 usage
set -euo pipefail

PROMPT="" MODEL="" TIMEOUT=600
while [ $# -gt 0 ]; do
  case "$1" in
    --prompt)  PROMPT="${2:?}"; shift 2 ;;
    --model)   MODEL="${2:?}"; shift 2 ;;
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    *) echo "review-with-claude.sh: unknown option $1" >&2; exit 64 ;;
  esac
done
[ -n "$PROMPT" ] && [ -f "$PROMPT" ] || { echo "review-with-claude.sh: --prompt <file> required" >&2; exit 64; }
command -v claude >/dev/null 2>&1 || { echo "review-with-claude.sh: claude CLI not found" >&2; exit 1; }

RAW="$(mktemp)"
trap 'rm -f "$RAW"' EXIT

kill_tree() { # whole process group, TERM then KILL (mirrors run-phase.sh kill_group)
  kill -TERM -- "-$1" 2>/dev/null || true
  sleep 2
  kill -KILL -- "-$1" 2>/dev/null || true
}

MODEL_ARGS=()
[ -n "$MODEL" ] && MODEL_ARGS=(--model "$MODEL")
# The prompt embeds every review input and forbids commands. Safe mode keeps
# the user's subscription OAuth while disabling user/project customization
# (plugins, hooks, skills, MCP); strict MCP prevents configured connectors from
# re-entering. `--tools ""` then disables the built-in tool set as well.
setsid claude -p "$(cat "$PROMPT")" ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  --safe-mode --strict-mcp-config --tools "" --max-turns 1 --effort low \
  --no-session-persistence </dev/null >"$RAW" 2>&1 &
PID=$!
trap 'kill_tree "$PID"; exit 1' INT TERM

DEADLINE=$((SECONDS + TIMEOUT))
while kill -0 "$PID" 2>/dev/null; do
  if [ "$SECONDS" -ge "$DEADLINE" ]; then
    kill_tree "$PID"
    echo "review-with-claude.sh: timed out after ${TIMEOUT}s (process group killed)" >&2
    exit 1
  fi
  sleep 2
done
set +e; wait "$PID" 2>/dev/null; RC=$?; set -e
trap 'rm -f "$RAW"' EXIT
if [ "$RC" -ne 0 ]; then
  echo "review-with-claude.sh: claude exited $RC" >&2
  tail -n 5 "$RAW" >&2 || true
  exit 1
fi

NORMALIZED="$(grep '^{' "$RAW" 2>/dev/null | jq -cs '
  map(select(type == "object" and .severity? and .summary?) + {provider: "claude"})
  | unique_by([(.category // ""), (.file // ""), (.line // 0), .summary])[]
' 2>/dev/null || true)"
VALID="$(printf '%s\n' "$NORMALIZED" | grep -c '^{' || true)"

if [ "$VALID" -eq 0 ]; then
  echo "review-with-claude.sh: zero valid finding lines — a clean review must emit the review-clean line" >&2
  tail -n 5 "$RAW" >&2 || true
  exit 1
fi

CLEAN="$(printf '%s\n' "$NORMALIZED" | jq -s '[.[] | select(.category == "review-clean")] | length')"
FINDINGS="$(printf '%s\n' "$NORMALIZED" | jq -s '[.[] | select(.category != "review-clean")] | length')"
if [ "$CLEAN" -gt 0 ] && [ "$FINDINGS" -gt 0 ]; then
  echo "review-with-claude.sh: review-clean and findings appeared together — output contract violated" >&2
  exit 1
fi
printf '%s\n' "$NORMALIZED"
