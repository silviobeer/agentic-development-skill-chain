#!/usr/bin/env bash
# review-with-codex.sh — Codex adapter for the cross-review gate (CONCEPT.md §4/§7).
#
# Invokes an isolated `codex exec` worker on a self-contained rendered prompt
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
# Mirror the official plugin's independent-worker model while preserving this
# gate's stronger artifact-embedding contract. Stdin avoids command-line size
# limits; JSON events distinguish Codex runtime chatter from its final answer.
# User config/rules and persisted sessions are deliberately excluded so a local
# customization cannot change a supposedly deterministic review gate.
setsid codex exec --skip-git-repo-check --ephemeral --ignore-user-config \
  --ignore-rules --json ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} - \
  <"$PROMPT" >"$RAW" 2>&1 &
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

# A JSON response after Codex failed before it could read anything is not a
# review. Treat its known infrastructure markers as a hard failure.
if grep -Eqi 'review-blocked|bubblewrap|user namespaces|sandbox[[:space:]]+(error|failed)|failed[[:space:]]+to.*sandbox' "$RAW"; then
  echo "review-with-codex.sh: sandbox/infrastructure failure — reviewer did not reliably read the embedded material" >&2
  tail -n 10 "$RAW" >&2 || true
  exit 1
fi

# Codex --json wraps the final response in item.completed/agent_message. Keep
# direct JSON findings as a compatibility path for deterministic CLI stubs.
CANDIDATES="$(while IFS= read -r line; do
  event="$(jq -c . <<<"$line" 2>/dev/null || true)"
  [ -n "$event" ] || continue
  if jq -e 'type == "object" and .severity? and .summary?' >/dev/null <<<"$event"; then
    printf '%s\n' "$event"
  elif jq -e '.type == "item.completed" and .item.type == "agent_message" and (.item.text | type == "string")' >/dev/null <<<"$event"; then
    jq -r '.item.text' <<<"$event"
  fi
done <"$RAW")"
NORMALIZED="$(printf '%s\n' "$CANDIDATES" | grep '^{' | jq -cs '
  map(select(type == "object" and .severity? and .summary?) + {provider: "codex"})
  | unique_by([(.category // ""), (.file // ""), (.line // 0), .summary])[]
' 2>/dev/null || true)"
VALID="$(printf '%s\n' "$NORMALIZED" | grep -c '^{' || true)"

if [ "$VALID" -eq 0 ]; then
  echo "review-with-codex.sh: zero valid finding lines — a clean review must emit the review-clean line" >&2
  tail -n 5 "$RAW" >&2 || true
  exit 1
fi

CLEAN="$(printf '%s\n' "$NORMALIZED" | jq -s '[.[] | select(.category == "review-clean")] | length')"
FINDINGS="$(printf '%s\n' "$NORMALIZED" | jq -s '[.[] | select(.category != "review-clean")] | length')"
if [ "$CLEAN" -gt 0 ] && [ "$FINDINGS" -gt 0 ]; then
  echo "review-with-codex.sh: review-clean and findings appeared together — output contract violated" >&2
  exit 1
fi
printf '%s\n' "$NORMALIZED"
