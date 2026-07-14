#!/usr/bin/env bash
# review-with-codex.sh — Codex adapter for the cross-review gate (CONCEPT.md §4/§7).
#
# Invokes `codex exec` strictly read-only on a rendered review prompt and
# normalizes the output to the findings JSON-lines contract (ledger.mjs):
# only lines that parse as objects with severity+summary survive, each
# stamped with "provider":"codex". The invocation runs as its own process
# group and is killed whole (TERM then KILL) on timeout — no orphans.
#
# Usage: review-with-codex.sh --prompt <file> [--model M] [--timeout S]
# Exit:  0 valid finding lines on stdout · 1 CLI failed/timeout/zero valid lines · 64 usage
set -euo pipefail

PROMPT="" MODEL="" TIMEOUT=600
while [ $# -gt 0 ]; do
  case "$1" in
    --prompt)  PROMPT="${2:?}"; shift 2 ;;
    --model)   MODEL="${2:?}"; shift 2 ;;
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    *) echo "review-with-codex.sh: unknown option $1" >&2; exit 64 ;;
  esac
done
[ -n "$PROMPT" ] && [ -f "$PROMPT" ] || { echo "review-with-codex.sh: --prompt <file> required" >&2; exit 64; }
command -v codex >/dev/null 2>&1 || { echo "review-with-codex.sh: codex CLI not found" >&2; exit 1; }

RAW="$(mktemp)"
trap 'rm -f "$RAW"' EXIT

kill_tree() { # whole process group, TERM then KILL (mirrors run-phase.sh kill_group)
  kill -TERM -- "-$1" 2>/dev/null || true
  sleep 2
  kill -KILL -- "-$1" 2>/dev/null || true
}

MODEL_ARGS=()
[ -n "$MODEL" ] && MODEL_ARGS=(--model "$MODEL")
setsid codex exec --sandbox read-only --skip-git-repo-check \
  ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} "$(cat "$PROMPT")" </dev/null >"$RAW" 2>&1 &
PID=$!
trap 'kill_tree "$PID"; exit 1' INT TERM

DEADLINE=$((SECONDS + TIMEOUT))
while kill -0 "$PID" 2>/dev/null; do
  if [ "$SECONDS" -ge "$DEADLINE" ]; then
    kill_tree "$PID"
    echo "review-with-codex.sh: timed out after ${TIMEOUT}s (process group killed)" >&2
    exit 1
  fi
  sleep 2
done
set +e; wait "$PID" 2>/dev/null; RC=$?; set -e
trap 'rm -f "$RAW"' EXIT
if [ "$RC" -ne 0 ]; then
  echo "review-with-codex.sh: codex exited $RC" >&2
  tail -n 5 "$RAW" >&2 || true
  exit 1
fi

VALID=0
while IFS= read -r line; do
  v="$(jq -c 'select(type == "object" and .severity? and .summary?) + {provider: "codex"}' <<<"$line" 2>/dev/null || true)"
  [ -n "$v" ] && { printf '%s\n' "$v"; VALID=$((VALID + 1)); }
done < <(grep '^{' "$RAW" 2>/dev/null || true)

if [ "$VALID" -eq 0 ]; then
  echo "review-with-codex.sh: zero valid finding lines — a clean review must emit the review-clean line" >&2
  tail -n 5 "$RAW" >&2 || true
  exit 1
fi
