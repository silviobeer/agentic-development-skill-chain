#!/usr/bin/env bash
# cross-review.sh — opposite-provider review for chain artifacts.
#
# Every input is embedded in the prompt (with source line numbers). Reviewers
# are instructed not to run commands, so the gate does not depend on a CLI
# sandbox or user namespaces. With --author-provider it also works before P0:
# findings are printed for the human and no state.json/ledger is required.
#
# Usage:
#   cross-review.sh <concept|architecture|plan|docs> <proj-x> <theme>
#     --artifacts <file...> [--ground-truth <file...>]
#     [--author-provider claude|codex] [--author-model M] [--author-key K]
#     [--joint] [--round 1|2] [--diff-base SHA] [--timeout S]
# Exit: 0 clean/no blocking findings; 3 Critical/High findings; 1 infra error;
#       64 invalid invocation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-}"; PROJ="${2:-}"; THEME="${3:-}"
usage() {
  echo "Usage: cross-review.sh <concept|architecture|plan|docs> <proj-x> <theme> --artifacts <file...> [--ground-truth <file...>] [--author-provider claude|codex] [--author-model M] [--author-key K] [--joint] [--round 1|2] [--diff-base SHA] [--timeout S]" >&2
  exit 64
}
[ -n "$MODE" ] && [ -n "$PROJ" ] && [ -n "$THEME" ] || usage
shift 3
case "$MODE" in concept|architecture|plan|docs) ;; *) echo "cross-review.sh: unknown mode '$MODE'" >&2; exit 64 ;; esac

ARTIFACTS=(); GROUND_TRUTH=(); AUTHOR_KEY=""; AUTHOR_PROVIDER=""; AUTHOR_MODEL=""
ROUND=1; DIFF_BASE=""; TIMEOUT=600; JOINT=0; EXPLICIT_AUTHOR=0; MAX_CONTEXT_BYTES="${CROSS_REVIEW_MAX_CONTEXT_BYTES:-131072}"
while [ $# -gt 0 ]; do
  case "$1" in
    --artifacts) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do ARTIFACTS+=("$1"); shift; done ;;
    --ground-truth) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do GROUND_TRUTH+=("$1"); shift; done ;;
    --author-key) AUTHOR_KEY="${2:?}"; shift 2 ;;
    --author-provider) AUTHOR_PROVIDER="${2:?}"; EXPLICIT_AUTHOR=1; shift 2 ;;
    --author-model) AUTHOR_MODEL="${2:?}"; shift 2 ;;
    --joint) JOINT=1; shift ;;
    --round) ROUND="${2:?}"; shift 2 ;;
    --diff-base) DIFF_BASE="${2:?}"; shift 2 ;;
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    *) echo "cross-review.sh: unknown option $1" >&2; usage ;;
  esac
done
[ ${#ARTIFACTS[@]} -gt 0 ] || { echo "cross-review.sh: --artifacts required" >&2; usage; }
[[ "$ROUND" =~ ^[12]$ ]] || { echo "cross-review.sh: --round must be 1 or 2" >&2; exit 64; }
case "$AUTHOR_PROVIDER" in ""|claude|codex) ;; *) echo "cross-review.sh: --author-provider must be claude or codex" >&2; exit 64 ;; esac

resolve() { if [ -f "$1" ]; then echo "$1"; else echo "$SCRIPT_DIR/$2"; fi; }
STATE_SH="$(resolve scripts/state.sh ../../4b_setup/scripts/state.sh)"
LEDGER="$(resolve scripts/ledger.mjs ../../6_qa/scripts/ledger.mjs)"
TMPL="$(resolve templates/cross-review-prompt.md.tmpl ../templates/cross-review-prompt.md.tmpl)"
[ -f "$TMPL" ] || { echo "cross-review.sh: prompt template not found" >&2; exit 1; }
BASE="specs/PROJ-${PROJ}-${THEME}"

# A supplied author is the pre-P0 path. It deliberately emits findings to the
# human instead of creating phase state or ledger data.
PERSIST=0
if [ "$EXPLICIT_AUTHOR" -eq 0 ] && [ -f "$BASE/state.json" ]; then
  [ -f "$STATE_SH" ] && [ -f "$LEDGER" ] || { echo "cross-review.sh: state exists but state.sh or ledger.mjs is unavailable" >&2; exit 1; }
  PERSIST=1
fi
if [ -z "$AUTHOR_PROVIDER" ] && [ "$PERSIST" -eq 1 ]; then
  if [ -n "$AUTHOR_KEY" ]; then
    AUTHOR_PROVIDER="$(bash "$STATE_SH" get "$PROJ" "$THEME" ".authorship[\"$AUTHOR_KEY\"].author_provider // empty" 2>/dev/null || true)"
    AUTHOR_MODEL="$(bash "$STATE_SH" get "$PROJ" "$THEME" ".authorship[\"$AUTHOR_KEY\"].author_model // empty" 2>/dev/null || true)"
  fi
  if [ -z "$AUTHOR_PROVIDER" ]; then
    AUTHOR_PROVIDER="$(bash "$STATE_SH" get "$PROJ" "$THEME" '[(.lanes // [])[] | select(.role == "writer")] | last | .provider // empty' 2>/dev/null || true)"
    AUTHOR_MODEL="$(bash "$STATE_SH" get "$PROJ" "$THEME" '[(.lanes // [])[] | select(.role == "writer")] | last | .model // empty' 2>/dev/null || true)"
  fi
fi
[ -n "$AUTHOR_PROVIDER" ] || { echo "cross-review.sh: supply --author-provider before P0, or a resolvable state.json author" >&2; exit 1; }

codex_available() { command -v codex >/dev/null 2>&1 && codex login status >/dev/null 2>&1; }
REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-sonnet}"; REVIEWERS=(); DEGRADED_FALLBACK=false
if [ "$JOINT" -eq 1 ]; then
  if codex_available; then REVIEWERS=("claude:${REVIEW_MODEL}" "codex:"); else REVIEWERS=("claude:${REVIEW_MODEL}"); DEGRADED_FALLBACK=true; fi
elif [ "$AUTHOR_PROVIDER" = claude ]; then
  if codex_available; then REVIEWERS=("codex:"); else REVIEWERS=("claude:${REVIEW_MODEL}"); DEGRADED_FALLBACK=true; fi
else REVIEWERS=("claude:${REVIEW_MODEL}"); fi
if [ "$DEGRADED_FALLBACK" = true ] && [ -n "$AUTHOR_MODEL" ] && [ "$REVIEW_MODEL" = "$AUTHOR_MODEL" ]; then
  echo "cross-review.sh: fallback reviewer equals author model" >&2; exit 1
fi

FOCUS=""
case "$MODE" in
  concept) FOCUS='- Product coherence: goal, users, scope, non-goals, success criteria and risks agree.\n- Buildability: no decision-critical ambiguity is deferred or disguised as a later concern.\n- Boundary discipline: do not smuggle PRDs, UI design, architecture or implementation plans into the concept.\n- Grounding: claims about the existing product agree with the supplied context.' ;;
  architecture) FOCUS='- Decision completeness: architecture resolves the cross-cutting choices required by the concept and PRDs.\n- Feasibility: proposed data, integrations, APIs, ownership and operations fit the supplied system truth.\n- Traceability: no requirement or constraint is silently lost, contradicted, or overbuilt.\n- Risk: identify unsafe assumptions, missing failure paths, migration concerns, and non-functional gaps.' ;;
  plan) FOCUS='- Executability: each task has clear file ownership, dependencies, acceptance criteria and verification.\n- Coverage: every relevant requirement and architecture decision is implemented exactly once.\n- Sequencing: waves are dependency-safe and expose shared-file or integration hazards.\n- Scope: reject invented work, hidden technical decisions, and plans that cannot be validated.' ;;
  docs) FOCUS='- Factual accuracy: every statement describes supplied ground truth, not merely plans.\n- Stale claims: flag renamed, removed, or changed modules and flows.\n- Cap-gaming: flag load-bearing truth removed to meet a size cap while trivia remains.\n- Wrong promotions: reject durable rules promoted from one-off incidents.' ;;
esac

MATERIAL=""
append_numbered() { # <kind> <path>
  local kind="$1" path="$2"
  [ -f "$path" ] || { echo "cross-review.sh: missing $kind file: $path" >&2; exit 1; }
  MATERIAL+=$'\n## '"$kind: $path"$'\n```text\n'
  MATERIAL+="$(cat -n -- "$path")"
  MATERIAL+=$'\n```\n'
}
for f in "${ARTIFACTS[@]}"; do append_numbered "Artifact under review" "$f"; done
for f in "${GROUND_TRUTH[@]}"; do append_numbered "Ground truth" "$f"; done
if [ -n "$DIFF_BASE" ]; then
  git rev-parse --verify "$DIFF_BASE^{commit}" >/dev/null 2>&1 || { echo "cross-review.sh: invalid --diff-base $DIFF_BASE" >&2; exit 1; }
  MATERIAL+=$'\n## Ground truth: git diff '"$DIFF_BASE"$'..HEAD\n```diff\n'
  MATERIAL+="$(git diff --no-ext-diff "$DIFF_BASE..HEAD")"
  MATERIAL+=$'\n```\n'
fi
CONTEXT_BYTES="$(printf '%s' "$MATERIAL" | wc -c | tr -d ' ')"
if [ "$CONTEXT_BYTES" -gt "$MAX_CONTEXT_BYTES" ]; then
  echo "cross-review.sh: embedded context is ${CONTEXT_BYTES} bytes, above ${MAX_CONTEXT_BYTES}; narrow inputs or set CROSS_REVIEW_MAX_CONTEXT_BYTES explicitly" >&2
  exit 1
fi

PROMPT_FILE="$(mktemp)"; OUT_A="$(mktemp)"; OUT_B="$(mktemp)"
trap 'rm -f "$PROMPT_FILE" "$OUT_A" "$OUT_B"' EXIT
FOCUS_RENDERED="$(printf '%b' "$FOCUS")"
# Do not use Bash's pattern replacement for embedded text: an artifact can
# contain `&`, which some shell configurations expand to the matched token.
# These placeholders occupy their own template lines, so direct line rendering
# preserves every artifact byte exactly.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    '{{REVIEW_FOCUS}}') printf '%s\n' "$FOCUS_RENDERED" ;;
    '{{REVIEW_MATERIAL}}') printf '%s\n' "$MATERIAL" ;;
    *) line="${line//'{{MODE}}'/$MODE}"; line="${line//'{{AUTHOR_PROVIDER}}'/$AUTHOR_PROVIDER}"; printf '%s\n' "$line" ;;
  esac
done <"$TMPL" >"$PROMPT_FILE"

run_adapter() { local provider="${1%%:*}" model="${1#*:}" out="$2"; local args=(--prompt "$PROMPT_FILE" --timeout "$TIMEOUT"); [ -n "$model" ] && args+=(--model "$model"); bash "$SCRIPT_DIR/review-with-${provider}.sh" "${args[@]}" >"$out"; }
RCS=()
if [ ${#REVIEWERS[@]} -eq 2 ]; then run_adapter "${REVIEWERS[0]}" "$OUT_A" & PID_A=$!; run_adapter "${REVIEWERS[1]}" "$OUT_B" & PID_B=$!; set +e; wait "$PID_A"; RCS+=($?); wait "$PID_B"; RCS+=($?); set -e; else set +e; run_adapter "${REVIEWERS[0]}" "$OUT_A"; RCS+=($?); set -e; fi
for rc in "${RCS[@]}"; do [ "$rc" -eq 0 ] || { echo "cross-review.sh: adapter failed (exit $rc) — review did not run" >&2; exit 1; }; done

ALL_LINES="$(cat "$OUT_A" "$OUT_B" 2>/dev/null | jq -cs 'map(select(type == "object") | .source = "cross-review") | unique_by([(.category // ""), (.file // ""), (.line // 0), .summary])[]' 2>/dev/null || true)"
FINDING_LINES="$(printf '%s\n' "$ALL_LINES" | jq -c 'select(.category != "review-clean")' 2>/dev/null || true)"
FINDINGS_ADDED="$(printf '%s\n' "$FINDING_LINES" | grep -c '^{' || true)"
ROUND_BLOCKING="$(printf '%s\n' "$FINDING_LINES" | jq -s '[.[] | select(.severity == "critical" or .severity == "high")] | length' 2>/dev/null || echo 0)"

if [ "$PERSIST" -eq 0 ]; then
  [ -z "$FINDING_LINES" ] || printf '%s\n' "$FINDING_LINES"
  if [ "$ROUND_BLOCKING" -gt 0 ]; then echo "cross-review (${MODE}): ${ROUND_BLOCKING} Critical/High finding(s) for human resolution" >&2; exit 3; fi
  echo "cross-review (${MODE}): clean — ${FINDINGS_ADDED} non-blocking finding(s) reported to the human" >&2
  exit 0
fi

if [ -n "$FINDING_LINES" ]; then printf '%s\n' "$FINDING_LINES" | node "$LEDGER" add "$PROJ" "$THEME"; fi
BLOCKING="$(jq '[.findings[]? | select(.status == "open") | select(.severity == "critical" or .severity == "high") | select(.source == "cross-review" or ((.sources // []) | index("cross-review")))] | length' "$BASE/findings.json" 2>/dev/null || echo 0)"
REVIEWER_PROVIDER="${REVIEWERS[0]%%:*}"; REVIEWER_MODEL="${REVIEWERS[0]#*:}"; [ ${#REVIEWERS[@]} -eq 2 ] && { REVIEWER_PROVIDER="claude+codex"; REVIEWER_MODEL="$REVIEW_MODEL"; }; [ "$REVIEWER_PROVIDER" = codex ] && REVIEWER_MODEL="codex-default"
CURRENT="$(bash "$STATE_SH" get "$PROJ" "$THEME" '.cross_review // []' 2>/dev/null || echo '[]')"
RECORD="$(jq -n --arg mode "$MODE" --argjson round "$ROUND" --arg rp "$REVIEWER_PROVIDER" --arg rm "$REVIEWER_MODEL" --argjson deg "$DEGRADED_FALLBACK" --argjson fa "$FINDINGS_ADDED" --arg at "$(date -Iseconds)" '{mode:$mode,round:$round,reviewer_provider:(if $rp == "claude+codex" then "claude" else $rp end),reviewer_model:$rm,joint:($rp == "claude+codex"),degraded_fallback:$deg,findings_added:$fa,at:$at}')"
UPDATED="$(jq -c --argjson rec "$RECORD" '. + [$rec]' <<<"$CURRENT")"; bash "$STATE_SH" set "$PROJ" "$THEME" .cross_review "$UPDATED" >/dev/null
if [ "$BLOCKING" -gt 0 ]; then echo "cross-review (${MODE}, round ${ROUND}): ${BLOCKING} open Critical/High finding(s) in the ledger — BLOCKING."; exit 3; fi
echo "cross-review (${MODE}, round ${ROUND}): clean — ${FINDINGS_ADDED} non-blocking finding(s) ingested"
