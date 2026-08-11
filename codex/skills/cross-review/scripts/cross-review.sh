#!/usr/bin/env bash
# cross-review.sh — opposite-provider review for chain artifacts.
#
# Every input is embedded in the prompt (with source line numbers). Reviewers
# are instructed not to run commands, so the gate does not depend on a CLI
# sandbox or user namespaces. With --author-provider it also works before P0:
# findings are printed for the human and no state.json/ledger is required.
#
# Usage:
#   cross-review.sh <concept|requirements|architecture|plan|qa|docs> <proj-x> <theme>
#     --artifacts <file...> [--ground-truth <file...>]
#     [--author-provider claude|codex] [--author-model M] [--author-key K]
#     [--joint] [--personas] [--persist] [--require-provider claude|codex]
#     [--round 1|2] [--diff-base SHA] [--diff-paths <git-pathspec...>] [--timeout S]
# Exit: 0 clean/no blocking findings; 3 Critical/High findings; 1 infra error;
#       64 invalid invocation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-}"; PROJ="${2:-}"; THEME="${3:-}"
usage() {
  echo "Usage: cross-review.sh <concept|requirements|architecture|plan|qa|docs> <proj-x> <theme> --artifacts <file...> [--ground-truth <file...>] [--author-provider claude|codex] [--author-model M] [--author-key K] [--joint] [--personas] [--persist] [--require-provider claude|codex] [--round 1|2] [--diff-base SHA] [--diff-paths <git-pathspec...>] [--timeout S]" >&2
  exit 64
}
[ -n "$MODE" ] && [ -n "$PROJ" ] && [ -n "$THEME" ] || usage
shift 3
case "$MODE" in concept|requirements|architecture|plan|qa|docs) ;; *) echo "cross-review.sh: unknown mode '$MODE'" >&2; exit 64 ;; esac

ARTIFACTS=(); GROUND_TRUTH=(); DIFF_PATHS=(); AUTHOR_KEY=""; AUTHOR_PROVIDER=""; AUTHOR_MODEL=""
ROUND=1; DIFF_BASE=""; TIMEOUT=600; JOINT=0; QA_PERSONAS=0; PERSIST_REQUESTED=0; REQUIRED_PROVIDER=""; EXPLICIT_AUTHOR=0; MAX_CONTEXT_BYTES="${CROSS_REVIEW_MAX_CONTEXT_BYTES:-900000}"
while [ $# -gt 0 ]; do
  case "$1" in
    --artifacts) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do ARTIFACTS+=("$1"); shift; done ;;
    --ground-truth) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do GROUND_TRUTH+=("$1"); shift; done ;;
    --author-key) AUTHOR_KEY="${2:?}"; shift 2 ;;
    --author-provider) AUTHOR_PROVIDER="${2:?}"; EXPLICIT_AUTHOR=1; shift 2 ;;
    --author-model) AUTHOR_MODEL="${2:?}"; shift 2 ;;
    --joint) JOINT=1; shift ;;
    --personas) QA_PERSONAS=1; shift ;;
    --persist) PERSIST_REQUESTED=1; shift ;;
    --require-provider) REQUIRED_PROVIDER="${2:?}"; shift 2 ;;
    --round) ROUND="${2:?}"; shift 2 ;;
    --diff-base) DIFF_BASE="${2:?}"; shift 2 ;;
    --diff-paths) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do DIFF_PATHS+=("$1"); shift; done ;;
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    *) echo "cross-review.sh: unknown option $1" >&2; usage ;;
  esac
done
[ ${#ARTIFACTS[@]} -gt 0 ] || { echo "cross-review.sh: --artifacts required" >&2; usage; }
[ ${#DIFF_PATHS[@]} -eq 0 ] || [ -n "$DIFF_BASE" ] || { echo "cross-review.sh: --diff-paths requires --diff-base" >&2; exit 64; }
[[ "$ROUND" =~ ^[12]$ ]] || { echo "cross-review.sh: --round must be 1 or 2" >&2; exit 64; }
[[ "$MAX_CONTEXT_BYTES" =~ ^[0-9]+$ ]] || { echo "cross-review.sh: CROSS_REVIEW_MAX_CONTEXT_BYTES must be a non-negative integer" >&2; exit 64; }
[ "$QA_PERSONAS" -eq 0 ] || { [ "$MODE" = qa ] && [ "$JOINT" -eq 0 ]; } || { echo "cross-review.sh: --personas is only valid for qa without --joint" >&2; exit 64; }
case "$AUTHOR_PROVIDER" in ""|claude|codex) ;; *) echo "cross-review.sh: --author-provider must be claude or codex" >&2; exit 64 ;; esac
case "$REQUIRED_PROVIDER" in ""|claude|codex) ;; *) echo "cross-review.sh: --require-provider must be claude or codex" >&2; exit 64 ;; esac

resolve() { if [ -f "$1" ]; then echo "$1"; else echo "$SCRIPT_DIR/$2"; fi; }
STATE_SH="$(resolve scripts/state.sh ../../4b_setup/scripts/state.sh)"
LEDGER="$(resolve scripts/ledger.mjs ../../6_qa/scripts/ledger.mjs)"
TMPL="$(resolve templates/cross-review-prompt.md.tmpl ../templates/cross-review-prompt.md.tmpl)"
[ -f "$TMPL" ] || { echo "cross-review.sh: prompt template not found" >&2; exit 1; }
BASE="specs/PROJ-${PROJ}-${THEME}"

# A supplied author is the pre-P0 path. It deliberately emits findings to the
# human instead of creating phase state or ledger data.
PERSIST=0
if { [ "$EXPLICIT_AUTHOR" -eq 0 ] || [ "$PERSIST_REQUESTED" -eq 1 ]; } && [ -f "$BASE/state.json" ]; then
  [ -f "$STATE_SH" ] && [ -f "$LEDGER" ] || { echo "cross-review.sh: state exists but state.sh or ledger.mjs is unavailable" >&2; exit 1; }
  PERSIST=1
fi
[ "$PERSIST_REQUESTED" -eq 0 ] || [ "$PERSIST" -eq 1 ] || { echo "cross-review.sh: --persist requires $BASE/state.json" >&2; exit 1; }
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
claude_available() { command -v claude >/dev/null 2>&1 && claude auth status >/dev/null 2>&1; }
REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-sonnet}"; REVIEWERS=(); DEGRADED_FALLBACK=false
if [ "$REQUIRED_PROVIDER" = codex ] && ! codex_available; then
  echo "cross-review.sh: Codex is required for this review but is unavailable or unauthenticated" >&2
  exit 1
fi
if [ "$JOINT" -eq 1 ]; then
  if codex_available; then REVIEWERS=("claude:${REVIEW_MODEL}" "codex:"); else REVIEWERS=("claude:${REVIEW_MODEL}"); DEGRADED_FALLBACK=true; fi
elif [ "$AUTHOR_PROVIDER" = claude ]; then
  if codex_available; then REVIEWERS=("codex:"); else REVIEWERS=("claude:${REVIEW_MODEL}"); DEGRADED_FALLBACK=true; fi
else REVIEWERS=("claude:${REVIEW_MODEL}"); fi
[ -z "$REQUIRED_PROVIDER" ] || [ "${REVIEWERS[0]%%:*}" = "$REQUIRED_PROVIDER" ] || { echo "cross-review.sh: required reviewer $REQUIRED_PROVIDER was not selected" >&2; exit 1; }
for reviewer in "${REVIEWERS[@]}"; do
  if [ "${reviewer%%:*}" = claude ] && ! claude_available; then
    echo "cross-review.sh: Claude is required for this review but is unavailable or unauthenticated" >&2
    exit 1
  fi
done
if [ "$DEGRADED_FALLBACK" = true ] && [ -n "$AUTHOR_MODEL" ] && [ "$REVIEW_MODEL" = "$AUTHOR_MODEL" ]; then
  echo "cross-review.sh: fallback reviewer equals author model" >&2; exit 1
fi
[ "$QA_PERSONAS" -eq 0 ] || [ "$DEGRADED_FALLBACK" = false ] || echo "cross-review (qa): Codex unavailable; continuing six QA personas with Claude (degraded)" >&2

FOCUS=""
case "$MODE" in
  concept) FOCUS='- Product coherence: goal, users, scope, non-goals, success criteria and risks agree.\n- Buildability: no decision-critical ambiguity is deferred or disguised as a later concern.\n- Boundary discipline: do not smuggle PRDs, UI design, architecture or implementation plans into the concept.\n- Grounding: claims about the existing product agree with the supplied context.' ;;
  requirements) FOCUS='- Coverage and traceability: every approved concept, role, flow, state, constraint and mockup contract is represented exactly once; flag omissions, contradictions and invented scope.\n- Testability: Given/When/Then and acceptance criteria are observable, unambiguous, independently verifiable and include meaningful negative outcomes.\n- Edge behavior: permissions, empty and invalid data, failures, retries, limits, concurrency and security-sensitive paths have explicit expected behavior where relevant.\n- Cross-PRD consistency: identifiers, terminology, dependencies, preconditions and outcomes agree across the full PRD set.\n- Boundary discipline: requirements state product behavior and non-functional constraints without prematurely choosing architecture or implementation.' ;;
  architecture) FOCUS='- Decision completeness: architecture resolves the cross-cutting choices required by the concept and PRDs.\n- Feasibility: proposed data, integrations, APIs, ownership and operations fit the supplied system truth.\n- Traceability: no requirement or constraint is silently lost, contradicted, or overbuilt.\n- Risk: identify unsafe assumptions, missing failure paths, migration concerns, and non-functional gaps.' ;;
  plan) FOCUS='- Executability: each task has clear file ownership, dependencies, acceptance criteria and verification.\n- Coverage: every relevant requirement and architecture decision is implemented exactly once.\n- Sequencing: waves are dependency-safe and expose shared-file or integration hazards.\n- Scope: reject invented work, hidden technical decisions, and plans that cannot be validated.' ;;
  qa) FOCUS='- Evidence integrity: QA claims are tied to supplied browser/test evidence, not implementation assertions or an empty selection.\n- Adversarial coverage: acceptance criteria, edge cases, security and regressions have meaningful attempts and negative controls.\n- Finding quality: severity, reproduction and anchors are actionable; do not silently downgrade a release-blocking result.\n- Release decision: reject READY when supplied evidence or the implementation diff leaves a Critical/High risk unaddressed.' ;;
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
  OMITTED_PATHS=""
  if [ ${#DIFF_PATHS[@]} -gt 0 ]; then
    ALL_DIFF_PATHS="$(git diff --name-only "$DIFF_BASE..HEAD" | sort)"
    SCOPED_DIFF_PATHS="$(git diff --name-only "$DIFF_BASE..HEAD" -- "${DIFF_PATHS[@]}" | sort)"
    OMITTED_PATHS="$(comm -23 <(printf '%s\n' "$ALL_DIFF_PATHS") <(printf '%s\n' "$SCOPED_DIFF_PATHS"))"
    MATERIAL+=$'\n## Diff scope\nGit pathspecs: `'
    MATERIAL+="$(printf '%s ' "${DIFF_PATHS[@]}")"
    MATERIAL+=$'`\n\nOmitted from diff ground truth (may be supplied separately above):\n```text\n'
    MATERIAL+="${OMITTED_PATHS:-none}"
    MATERIAL+=$'\n```\n'
  fi
  MATERIAL+=$'\n## Ground truth: git diff '"$DIFF_BASE"$'..HEAD\n```diff\n'
  MATERIAL+="$(git diff --no-ext-diff "$DIFF_BASE..HEAD" ${DIFF_PATHS:+--} "${DIFF_PATHS[@]}")"
  MATERIAL+=$'\n```\n'
fi
CONTEXT_BYTES="$(printf '%s' "$MATERIAL" | wc -c | tr -d ' ')"
if [ "$MAX_CONTEXT_BYTES" -gt 0 ] && [ "$CONTEXT_BYTES" -gt "$MAX_CONTEXT_BYTES" ]; then
  omitted_label="${OMITTED_PATHS:-none}"
  omitted_label="${omitted_label//$'\n'/, }"
  echo "cross-review.sh: embedded context is ${CONTEXT_BYTES} bytes, above configured limit ${MAX_CONTEXT_BYTES}; omitted changed paths: ${omitted_label}; narrow --diff-paths/inputs or raise CROSS_REVIEW_MAX_CONTEXT_BYTES for a provider that supports it" >&2
  exit 1
fi

PROMPT_FILE="$(mktemp)"; OUT_A="$(mktemp)"; OUT_B="$(mktemp)"; QA_PERSONA_DIR="$(mktemp -d)"
trap 'rm -rf "$PROMPT_FILE" "$OUT_A" "$OUT_B" "$QA_PERSONA_DIR"' EXIT
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

run_adapter() { local provider="${1%%:*}" model="${1#*:}" out="$2" prompt="${3:-$PROMPT_FILE}"; local args=(--prompt "$prompt" --timeout "$TIMEOUT"); [ -n "$model" ] && args+=(--model "$model"); bash "$SCRIPT_DIR/review-with-${provider}.sh" "${args[@]}" >"$out"; }
RCS=(); OUT_FILES=("$OUT_A" "$OUT_B")
if [ "$QA_PERSONAS" -eq 1 ]; then
  PERSONAS=(
    'Dr. Sarah Chen — Security Lead|Find security/auth/injection/secret/authorization risks in the QA evidence and diff.'
    'Marcus Weber — Principal Engineer|Find architecture, coupling, error-handling, testability and duplicate-domain-logic risks.'
    'Priya Sharma — Performance Engineer|Find latency, N+1, unbounded work, bundle, cache and pagination risks.'
    'Thomas Mueller — SRE / Reliability Engineer|Find failure-mode, retry, idempotency, timeout, observability, race and resource-leak risks.'
    'Elena Rodriguez — Principal Architect|Find cross-wave coherence, scope-creep and next-PROJ architecture risks.'
    'Ken Takahashi — Minimalism Engineer|Find YAGNI, abstraction, duplication, dead-path and needless-option risks; include a simplification sketch.'
  )
  OUT_FILES=(); PIDS=()
  for i in "${!PERSONAS[@]}"; do
    persona="${PERSONAS[$i]%%|*}"; focus="${PERSONAS[$i]#*|}"
    persona_prompt="$QA_PERSONA_DIR/$i.prompt"; persona_out="$QA_PERSONA_DIR/$i.out"
    { cat "$PROMPT_FILE"; printf '\n## Assigned QA persona\nYou are %s. %s\nReview only this discipline; emit the strict machine-readable findings contract.\n' "$persona" "$focus"; } > "$persona_prompt"
    run_adapter "${REVIEWERS[0]}" "$persona_out" "$persona_prompt" & PIDS+=("$!")
    OUT_FILES+=("$persona_out")
  done
  set +e; for pid in "${PIDS[@]}"; do wait "$pid"; RCS+=($?); done; set -e
elif [ ${#REVIEWERS[@]} -eq 2 ]; then run_adapter "${REVIEWERS[0]}" "$OUT_A" & PID_A=$!; run_adapter "${REVIEWERS[1]}" "$OUT_B" & PID_B=$!; set +e; wait "$PID_A"; RCS+=($?); wait "$PID_B"; RCS+=($?); set -e; else set +e; run_adapter "${REVIEWERS[0]}" "$OUT_A"; RCS+=($?); set -e; fi
for rc in "${RCS[@]}"; do [ "$rc" -eq 0 ] || { echo "cross-review.sh: adapter failed (exit $rc) — review did not run" >&2; exit 1; }; done

ALL_LINES="$(cat "${OUT_FILES[@]}" 2>/dev/null | jq -cs 'map(select(type == "object") | .source = "cross-review") | unique_by([(.category // ""), (.file // ""), (.line // 0), .summary])[]' 2>/dev/null || true)"
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
