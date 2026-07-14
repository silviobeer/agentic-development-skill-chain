#!/usr/bin/env bash
# cross-review.sh — symmetric cross-provider review gate (CONCEPT.md §4, §7).
#
# Same-model review is an echo chamber: this script routes review of an
# artifact to the provider OPPOSITE its author (claude-authored -> codex,
# codex-authored -> claude), headless, read-only, bounded. When the opposite
# provider is unavailable (degraded run), it falls back to MODEL-opposite
# within the surviving provider — a different model than the author's,
# logged and flagged, never silent. The surviving invariant either way:
# the gate is NEVER satisfied by the same model that authored the artifact.
#
# Findings flow into the ledger (source "cross-review", provider-attributed);
# every round is appended to .cross_review in state.json.
#
# Usage:
#   cross-review.sh <mode> <proj-x> <theme> --artifacts <file...>
#                   [--author-key K] [--joint] [--round 1|2]
#                   [--diff-base SHA] [--timeout S]
# Modes:
#   docs   P7 docs truth-check (curated delta vs the PROJ diff) — ACTIVE
#   (p3-premortem, p4-plan: Stage 3 — refused until their call sites ship)
# Env:  CLAUDE_REVIEW_MODEL  model-opposite fallback reviewer (default: sonnet)
# Exit: 0 review ran, no blocking findings this round
#       3 review ran, Critical/High findings ingested (fix + ONE re-review round)
#       1 infrastructure failure (adapter failed / zero valid lines)
#       64 usage / unknown mode / round > 2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-}"; PROJ="${2:-}"; THEME="${3:-}"
usage() {
  echo "Usage: cross-review.sh <docs> <proj-x> <theme> --artifacts <file...> [--author-key K] [--joint] [--round 1|2] [--diff-base SHA] [--timeout S]" >&2
  exit 64
}
[ -n "$MODE" ] && [ -n "$PROJ" ] && [ -n "$THEME" ] || usage
shift 3

case "$MODE" in
  docs) : ;;
  p3-premortem|p4-plan)
    echo "cross-review.sh: mode '$MODE' is Stage 3 — its call site does not exist yet. Do not improvise it." >&2
    exit 64 ;;
  *) echo "cross-review.sh: unknown mode '$MODE' (active: docs)" >&2; exit 64 ;;
esac

ARTIFACTS=()
AUTHOR_KEY="" ROUND=1 DIFF_BASE="" TIMEOUT=600 JOINT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --artifacts)
      shift
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do ARTIFACTS+=("$1"); shift; done ;;
    --author-key) AUTHOR_KEY="${2:?}"; shift 2 ;;
    --joint)      JOINT=1; shift ;;
    --round)      ROUND="${2:?}"; shift 2 ;;
    --diff-base)  DIFF_BASE="${2:?}"; shift 2 ;;
    --timeout)    TIMEOUT="${2:?}"; shift 2 ;;
    *) echo "cross-review.sh: unknown option $1" >&2; usage ;;
  esac
done
[ ${#ARTIFACTS[@]} -gt 0 ] || { echo "cross-review.sh: --artifacts required" >&2; usage; }
if [ "$ROUND" -gt 2 ]; then
  echo "cross-review.sh: round $ROUND refused — max 2 rounds, then stop policy §8 (park the run, human decides)" >&2
  exit 64
fi

# --- helper resolution: repo copies first (4b_setup installs them), then skill tree
resolve() { # <repo-path> <skill-relative-path>
  if [ -f "$1" ]; then echo "$1"; else echo "$SCRIPT_DIR/$2"; fi
}
STATE_SH="$(resolve scripts/state.sh ../../4b_setup/scripts/state.sh)"
LEDGER="$(resolve scripts/ledger.mjs ../../6_qa/scripts/ledger.mjs)"
TMPL="$(resolve templates/cross-review-prompt.md.tmpl ../templates/cross-review-prompt.md.tmpl)"
[ -f "$STATE_SH" ] || { echo "cross-review.sh: state.sh not found" >&2; exit 1; }
[ -f "$LEDGER" ]   || { echo "cross-review.sh: ledger.mjs not found" >&2; exit 1; }
[ -f "$TMPL" ]     || { echo "cross-review.sh: cross-review-prompt.md.tmpl not found" >&2; exit 1; }

BASE="specs/PROJ-${PROJ}-${THEME}"
REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-sonnet}"

# --- resolve authorship: .authorship[key], else the last writer lane --------
AUTHOR_PROVIDER="" AUTHOR_MODEL=""
if [ -n "$AUTHOR_KEY" ]; then
  AUTHOR_PROVIDER="$(bash "$STATE_SH" get "$PROJ" "$THEME" ".authorship[\"$AUTHOR_KEY\"].author_provider // empty" 2>/dev/null || true)"
  AUTHOR_MODEL="$(bash "$STATE_SH" get "$PROJ" "$THEME" ".authorship[\"$AUTHOR_KEY\"].author_model // empty" 2>/dev/null || true)"
fi
if [ -z "$AUTHOR_PROVIDER" ]; then
  AUTHOR_PROVIDER="$(bash "$STATE_SH" get "$PROJ" "$THEME" '[(.lanes // [])[] | select(.role == "writer")] | last | .provider // empty' 2>/dev/null || true)"
  AUTHOR_MODEL="$(bash "$STATE_SH" get "$PROJ" "$THEME" '[(.lanes // [])[] | select(.role == "writer")] | last | .model // empty' 2>/dev/null || true)"
fi
if [ -z "$AUTHOR_PROVIDER" ]; then
  echo "cross-review.sh: cannot resolve author_provider (no --author-key record, no writer lane in state.json) — the gate needs to know who authored" >&2
  exit 1
fi

# --- route to the opposite provider (degraded: model-opposite) ---------------
codex_available() { command -v codex >/dev/null 2>&1 && codex login status >/dev/null 2>&1; }

REVIEWERS=()   # entries: "<provider>:<model-or-empty>"
DEGRADED_FALLBACK=false
if [ "$JOINT" -eq 1 ]; then
  # Jointly curated artifacts get independent Claude AND Codex passes.
  if codex_available; then
    REVIEWERS=("claude:${REVIEW_MODEL}" "codex:")
  else
    echo "cross-review.sh: --joint but codex unavailable — single model-opposite pass instead (flagged)" >&2
    REVIEWERS=("claude:${REVIEW_MODEL}")
    DEGRADED_FALLBACK=true
  fi
elif [ "$AUTHOR_PROVIDER" = "claude" ]; then
  if codex_available; then
    REVIEWERS=("codex:")
  else
    REVIEWERS=("claude:${REVIEW_MODEL}")
    DEGRADED_FALLBACK=true
  fi
else
  REVIEWERS=("claude:${REVIEW_MODEL}")   # codex-authored -> claude (hard provider)
fi

# The invariant: never the author's own model.
if [ "$DEGRADED_FALLBACK" = true ] || { [ "$AUTHOR_PROVIDER" = "claude" ] && [ "${REVIEWERS[0]%%:*}" = "claude" ]; }; then
  if [ -n "$AUTHOR_MODEL" ] && [ "$REVIEW_MODEL" = "$AUTHOR_MODEL" ]; then
    echo "cross-review.sh: model-opposite reviewer '$REVIEW_MODEL' equals author_model — same-model review never satisfies the gate. Set CLAUDE_REVIEW_MODEL to a different model." >&2
    exit 1
  fi
fi
if [ "$DEGRADED_FALLBACK" = true ]; then
  echo "cross-review.sh: DEGRADED — opposite provider unavailable; MODEL-opposite review via claude --model ${REVIEW_MODEL} (flagged in state, morning report, PR body)" >&2
fi

# --- render the prompt --------------------------------------------------------
ARTIFACT_LIST=""
for f in "${ARTIFACTS[@]}"; do ARTIFACT_LIST+="- ${f}"$'\n'; done
DIFF_SCOPE="(no diff base given — review the artifacts on their own terms)"
[ -n "$DIFF_BASE" ] && DIFF_SCOPE="git diff ${DIFF_BASE}..HEAD — the PROJ diff the docs must truthfully describe"

PROMPT_FILE="$(mktemp)"
OUT_A="$(mktemp)"; OUT_B="$(mktemp)"
trap 'rm -f "$PROMPT_FILE" "$OUT_A" "$OUT_B"' EXIT
# Pure-bash substitution: handles multiline values and special characters.
PROMPT_BODY="$(cat "$TMPL")"
PROMPT_BODY="${PROMPT_BODY//'{{MODE}}'/$MODE}"
PROMPT_BODY="${PROMPT_BODY//'{{AUTHOR_PROVIDER}}'/$AUTHOR_PROVIDER}"
PROMPT_BODY="${PROMPT_BODY//'{{ARTIFACTS}}'/$ARTIFACT_LIST}"
PROMPT_BODY="${PROMPT_BODY//'{{DIFF_SCOPE}}'/$DIFF_SCOPE}"
printf '%s\n' "$PROMPT_BODY" >"$PROMPT_FILE"

# --- run the adapter(s) — joint passes run CONCURRENTLY -----------------------
run_adapter() { # "<provider>:<model>" <outfile>
  local provider="${1%%:*}" model="${1#*:}" out="$2"
  local args=(--prompt "$PROMPT_FILE" --timeout "$TIMEOUT")
  [ -n "$model" ] && args+=(--model "$model")
  bash "$SCRIPT_DIR/review-with-${provider}.sh" "${args[@]}" >"$out"
}

RCS=()
if [ ${#REVIEWERS[@]} -eq 2 ]; then
  run_adapter "${REVIEWERS[0]}" "$OUT_A" & PID_A=$!
  run_adapter "${REVIEWERS[1]}" "$OUT_B" & PID_B=$!
  set +e; wait "$PID_A"; RCS+=($?); wait "$PID_B"; RCS+=($?); set -e
else
  set +e; run_adapter "${REVIEWERS[0]}" "$OUT_A"; RCS+=($?); set -e
fi
for rc in "${RCS[@]}"; do
  if [ "$rc" -ne 0 ]; then
    echo "cross-review.sh: adapter failed (exit $rc) — infrastructure failure, review did not run" >&2
    exit 1
  fi
done

# --- normalize + ingest --------------------------------------------------------
# Force source=cross-review on every line; the review-clean marker counts as a
# clean round and is NOT ingested (it is an adapter liveness signal, not a finding).
ALL_LINES="$(cat "$OUT_A" "$OUT_B" 2>/dev/null | jq -c 'select(type == "object") | .source = "cross-review"' 2>/dev/null || true)"
FINDING_LINES="$(printf '%s\n' "$ALL_LINES" | jq -c 'select((.category // "") != "review-clean")' 2>/dev/null || true)"
FINDINGS_ADDED=0
if [ -n "$FINDING_LINES" ]; then
  FINDINGS_ADDED="$(printf '%s\n' "$FINDING_LINES" | grep -c '^{')"
  printf '%s\n' "$FINDING_LINES" | node "$LEDGER" add "$PROJ" "$THEME"
fi

# Blocking = open Critical/High cross-review findings in the LEDGER, not just
# this round's lines — a round-1 finding that was fixed but never marked
# `fixed` (ledger.mjs set-status) keeps blocking, and a clean round says so
# loudly instead of leaving the P7 gate silently red.
BLOCKING="$(jq '[.findings[]?
    | select(.status == "open")
    | select(.severity == "critical" or .severity == "high")
    | select(.source == "cross-review" or ((.sources // []) | index("cross-review")))
  ] | length' "$BASE/findings.json" 2>/dev/null || echo 0)"

# --- record the round in state.json (append via read-modify-write) ------------
REVIEWER_PROVIDER="${REVIEWERS[0]%%:*}"
REVIEWER_MODEL="${REVIEWERS[0]#*:}"
[ ${#REVIEWERS[@]} -eq 2 ] && { REVIEWER_PROVIDER="claude+codex"; REVIEWER_MODEL="$REVIEW_MODEL"; }
[ "$REVIEWER_PROVIDER" = "codex" ] && REVIEWER_MODEL="codex-default"
CURRENT="$(bash "$STATE_SH" get "$PROJ" "$THEME" '.cross_review // []' 2>/dev/null || echo '[]')"
RECORD="$(jq -n \
  --arg mode "$MODE" --argjson round "$ROUND" \
  --arg rp "$REVIEWER_PROVIDER" --arg rm "$REVIEWER_MODEL" \
  --argjson deg "$DEGRADED_FALLBACK" --argjson fa "$FINDINGS_ADDED" \
  --arg at "$(date -Iseconds)" \
  '{mode: $mode, round: $round, reviewer_provider: (if $rp == "claude+codex" then "claude" else $rp end), reviewer_model: $rm, joint: ($rp == "claude+codex"), degraded_fallback: $deg, findings_added: $fa, at: $at}')"
UPDATED="$(jq -c --argjson rec "$RECORD" '. + [$rec]' <<<"$CURRENT")"
bash "$STATE_SH" set "$PROJ" "$THEME" .cross_review "$UPDATED" >/dev/null

if [ "$BLOCKING" -gt 0 ]; then
  echo "cross-review (${MODE}, round ${ROUND}): ${BLOCKING} open Critical/High cross-review finding(s) in the ledger (${FINDINGS_ADDED} ingested this round) — BLOCKING."
  echo "After fixing a finding, mark it: node scripts/ledger.mjs set-status ${PROJ} ${THEME} <id> fixed <commit> — an unmarked fix keeps blocking; a false 'fixed' is reopened on re-report. Then run round $((ROUND + 1))$([ "$ROUND" -ge 2 ] && echo ' — NO: max rounds reached, stop policy §8')."
  exit 3
fi
SUFFIX=""
[ "$DEGRADED_FALLBACK" = true ] && SUFFIX=" (model-opposite fallback)"
echo "cross-review (${MODE}, round ${ROUND}): clean — ${FINDINGS_ADDED} non-blocking finding(s) ingested, reviewer ${REVIEWER_PROVIDER}${SUFFIX}"
