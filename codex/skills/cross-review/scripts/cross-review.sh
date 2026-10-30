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
#     [--also-focus <concept|requirements|architecture|plan,...>]
#     [--joint] [--personas [chen,weber,...]] [--persist] [--require-provider claude|codex]
#     [--round N] [--diff-base SHA] [--diff-paths <git-pathspec...>] [--timeout S]
# Exit: 0 clean/no blocking findings; 3 Critical/High findings; 1 infra error;
#       64 invalid invocation.
set -euo pipefail
_compat_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_compat_dir/compat.sh" ]; then source "$_compat_dir/compat.sh"; else source "$_compat_dir/../../5_executing/scripts/compat.sh"; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-}"; PROJ="${2:-}"; THEME="${3:-}"
usage() {
  echo "Usage: cross-review.sh <concept|requirements|architecture|plan|qa|docs> <proj-x> <theme> --artifacts <file...> [--ground-truth <file...>] [--author-provider claude|codex] [--author-model M] [--author-key K] [--also-focus M,...] [--joint] [--personas [chen,weber,...]] [--persist] [--require-provider claude|codex] [--round N] [--diff-base SHA] [--diff-paths <git-pathspec...>] [--timeout S]" >&2
  exit 64
}
[ -n "$MODE" ] && [ -n "$PROJ" ] && [ -n "$THEME" ] || usage
shift 3
case "$MODE" in concept|requirements|architecture|plan|qa|docs) ;; *) echo "cross-review.sh: unknown mode '$MODE'" >&2; exit 64 ;; esac

ARTIFACTS=(); GROUND_TRUTH=(); DIFF_PATHS=(); ALSO_FOCUS=(); AUTHOR_KEY=""; AUTHOR_PROVIDER=""; AUTHOR_MODEL=""
PERSONA_KEYS=(chen weber sharma mueller rodriguez takahashi); PERSONA_SEL=()
persona_key() { # last or first name of one of the six QA personas -> canonical key
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    chen|sarah) echo chen ;; weber|marcus) echo weber ;; sharma|priya) echo sharma ;;
    mueller|thomas) echo mueller ;; rodriguez|elena) echo rodriguez ;; takahashi|ken) echo takahashi ;;
    *) return 1 ;;
  esac
}
ROUND=1; DIFF_BASE=""; TIMEOUT=600; JOINT=0; QA_PERSONAS=0; PERSIST_REQUESTED=0; REQUIRED_PROVIDER=""; EXPLICIT_AUTHOR=0; MAX_CONTEXT_BYTES="${CROSS_REVIEW_MAX_CONTEXT_BYTES:-900000}"
while [ $# -gt 0 ]; do
  case "$1" in
    --artifacts) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do ARTIFACTS+=("$1"); shift; done ;;
    --ground-truth) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do GROUND_TRUTH+=("$1"); shift; done ;;
    --author-key) AUTHOR_KEY="${2:?}"; shift 2 ;;
    --also-focus) IFS=, read -r -a ALSO_FOCUS <<<"${2:?}"; shift 2 ;;
    --author-provider) AUTHOR_PROVIDER="${2:?}"; EXPLICIT_AUTHOR=1; shift 2 ;;
    --author-model) AUTHOR_MODEL="${2:?}"; shift 2 ;;
    --joint) JOINT=1; shift ;;
    --personas) QA_PERSONAS=1; shift
      if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then # optional comma list: a subset of the six personas
        case ",$1," in *,,*) echo "cross-review.sh: --personas list has an empty entry: '$1'" >&2; exit 64 ;; esac
        IFS=, read -r -a _names <<<"$1"; shift
        for _n in "${_names[@]}"; do
          _k="$(persona_key "$_n")" || { echo "cross-review.sh: unknown persona '$_n' (chen, weber, sharma, mueller, rodriguez, takahashi)" >&2; exit 64; }
          case " ${PERSONA_SEL[*]-} " in *" $_k "*) ;; *) PERSONA_SEL+=("$_k") ;; esac
        done
      fi ;;
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
[[ "$ROUND" =~ ^[1-9][0-9]*$ ]] || { echo "cross-review.sh: --round must be a positive integer" >&2; exit 64; }
[[ "$MAX_CONTEXT_BYTES" =~ ^[0-9]+$ ]] || { echo "cross-review.sh: CROSS_REVIEW_MAX_CONTEXT_BYTES must be a non-negative integer" >&2; exit 64; }
[ "$QA_PERSONAS" -eq 0 ] || { [ "$MODE" = qa ] && [ "$JOINT" -eq 0 ]; } || { echo "cross-review.sh: --personas is only valid for qa without --joint" >&2; exit 64; }
[ ${#ALSO_FOCUS[@]} -eq 0 ] || case "$MODE" in qa|docs) echo "cross-review.sh: --also-focus is not valid for $MODE" >&2; exit 64 ;; esac
for m in ${ALSO_FOCUS[@]+"${ALSO_FOCUS[@]}"}; do
  case "$m" in concept|requirements|architecture|plan) [ "$m" != "$MODE" ] || { echo "cross-review.sh: --also-focus repeats mode '$m'" >&2; exit 64; } ;; *) echo "cross-review.sh: --also-focus takes concept|requirements|architecture|plan, got '$m'" >&2; exit 64 ;; esac
done
case "$AUTHOR_PROVIDER" in ""|claude|codex) ;; *) echo "cross-review.sh: --author-provider must be claude or codex" >&2; exit 64 ;; esac
case "$REQUIRED_PROVIDER" in ""|claude|codex) ;; *) echo "cross-review.sh: --require-provider must be claude or codex" >&2; exit 64 ;; esac

resolve() { if [ -f "$1" ]; then echo "$1"; else echo "$SCRIPT_DIR/$2"; fi; }
STATE_SH="$(resolve scripts/state.sh ../../5_executing/scripts/state.sh)"
LEDGER="$(resolve scripts/findings.mjs ../../6_qa/scripts/findings.mjs)"
TMPL="$(resolve templates/cross-review-prompt.md.tmpl ../templates/cross-review-prompt.md.tmpl)"
[ -f "$TMPL" ] || { echo "cross-review.sh: prompt template not found" >&2; exit 1; }
BASE="specs/PROJ-${PROJ}-${THEME}"

# A supplied author is the pre-P0 path. It deliberately emits findings to the
# stage ledger without creating phase state.
PERSIST=0
if { [ "$EXPLICIT_AUTHOR" -eq 0 ] || [ "$PERSIST_REQUESTED" -eq 1 ]; } && [ -f "$BASE/state.json" ]; then
  [ -f "$STATE_SH" ] && [ -f "$LEDGER" ] || { echo "cross-review.sh: state exists but state.sh or findings.mjs is unavailable" >&2; exit 1; }
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
pick_review_model() { # strongest Claude model that is not the author's (alias or full id), best first; QA personas take the strongest even when it is the author model
  local m; for m in ${CLAUDE_MODEL_RANK:-fable opus sonnet}; do
    [ "$QA_PERSONAS" -eq 1 ] && { echo "$m"; return 0; }
    case "${1:-}" in *"$m"*) ;; *) echo "$m"; return 0 ;; esac
  done
  echo "cross-review.sh: no Claude model left after excluding author model '${1:-}'" >&2; return 1
}
REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-$(pick_review_model "$AUTHOR_MODEL")}"; REVIEWERS=(); DEGRADED_FALLBACK=false
if [ "$REQUIRED_PROVIDER" = codex ] && ! codex_available; then
  echo "cross-review.sh: Codex is required for this review but is unavailable or unauthenticated" >&2
  exit 1
fi
if [ "$JOINT" -eq 1 ]; then
  if codex_available; then REVIEWERS=("claude:${REVIEW_MODEL}" "codex:"); else REVIEWERS=("claude:${REVIEW_MODEL}"); DEGRADED_FALLBACK=true; fi
elif [ "$AUTHOR_PROVIDER" = claude ]; then
  if codex_available; then REVIEWERS=("codex:"); else REVIEWERS=("claude:${REVIEW_MODEL}"); DEGRADED_FALLBACK=true; fi
elif ! claude_available && [ "$MODE" = qa ] && [ "$QA_PERSONAS" -eq 1 ] && codex_available; then REVIEWERS=("codex:"); DEGRADED_FALLBACK=true
else REVIEWERS=("claude:${REVIEW_MODEL}"); fi
[ -z "$REQUIRED_PROVIDER" ] || [ "${REVIEWERS[0]%%:*}" = "$REQUIRED_PROVIDER" ] || { echo "cross-review.sh: required reviewer $REQUIRED_PROVIDER was not selected" >&2; exit 1; }
for reviewer in "${REVIEWERS[@]}"; do
  if [ "${reviewer%%:*}" = claude ] && ! claude_available; then
    echo "cross-review.sh: Claude is required for this review but is unavailable or unauthenticated" >&2
    exit 1
  fi
done
if [ "$DEGRADED_FALLBACK" = true ] && [ "$QA_PERSONAS" -eq 0 ] && [ -n "$AUTHOR_MODEL" ] && [ "$REVIEW_MODEL" = "$AUTHOR_MODEL" ]; then
  echo "cross-review.sh: fallback reviewer equals author model" >&2; exit 1
fi
PANEL_LABEL=six; [ ${#PERSONA_SEL[@]} -eq 0 ] || [ ${#PERSONA_SEL[@]} -eq 6 ] || PANEL_LABEL="${#PERSONA_SEL[@]} selected"
[ "$QA_PERSONAS" -eq 0 ] || [ "$DEGRADED_FALLBACK" = false ] || echo "cross-review (qa): opposite provider unavailable; continuing ${PANEL_LABEL} QA personas with ${REVIEWERS[0]%%:*} ${REVIEWERS[0]#*:} (degraded, same vendor, strongest model)" >&2

FOCUS_ALL=""
# The review's own mode first; --also-focus appends the focus of further artifact kinds (one run, one record).
for FOCUS_MODE in "$MODE" ${ALSO_FOCUS[@]+"${ALSO_FOCUS[@]}"}; do
FOCUS=""
case "$FOCUS_MODE" in
  concept) FOCUS='- Product coherence: goal, users, scope, non-goals, success criteria and risks agree.\n- Buildability: no decision-critical ambiguity is deferred or disguised as a later concern.\n- Boundary discipline: do not smuggle PRDs, UI design, architecture or implementation plans into the concept.\n- Grounding: claims about the existing product agree with the supplied context.\n- Cap-gaming: flag load-bearing scope, success criteria or constraints removed to fit the 150-line cap while trivia remains.' ;;
  requirements) FOCUS='- Coverage and traceability: every approved concept, role, flow, state, constraint and mockup contract is represented exactly once; flag omissions, contradictions and invented scope.\n- Testability: Given/When/Then and acceptance criteria are observable, unambiguous, independently verifiable and include meaningful negative outcomes.\n- Edge behavior: permissions, empty and invalid data, failures, retries, limits, concurrency and security-sensitive paths have explicit expected behavior where relevant.\n- Cross-PRD consistency: identifiers, terminology, dependencies, preconditions and outcomes agree across the full PRD set.\n- Boundary discipline: requirements state product behavior and non-functional constraints without prematurely choosing architecture or implementation.' ;;
  architecture) FOCUS='- Decision completeness: architecture resolves the cross-cutting choices required by the concept and PRDs.\n- Feasibility: proposed data, integrations, APIs, ownership and operations fit the supplied system truth.\n- Traceability: no requirement or constraint is silently lost, contradicted, or overbuilt.\n- Risk: identify unsafe assumptions, missing failure paths, migration concerns, and non-functional gaps.\n- Baseline changes: every decision that contradicts or changes docs/ARCHITECTURE.md (stack, boundaries, data ownership, invariants) carries a Changes baseline line naming that section, and its Summary says what it supersedes; flag silent contradictions.\n- Summary fidelity: each decision'"'"'s and key flow'"'"'s Summary line is the only text implementers receive; flag one that drops, softens or contradicts a binding part of its decision or flow diagram, and an Affects list that omits a PRD it constrains.' ;;
  plan) FOCUS='- Executability: each task has clear file ownership, dependencies, acceptance criteria and verification.\n- Coverage: every relevant requirement and architecture decision is implemented exactly once.\n- Sequencing: waves are dependency-safe and expose shared-file or integration hazards.\n- Scope: reject invented work, hidden technical decisions, and plans that cannot be validated.' ;;
  qa) FOCUS='- Evidence integrity: QA claims are tied to supplied browser/test evidence, not implementation assertions. A clean change-stream hash can cover many tracked files; distinguish no net endpoint changes from zero matched paths. Matching endpoints do not prove absence of transient reverted writes, untracked-file content changes, ignored/excluded changes or HEAD movement.\n- Adversarial coverage: acceptance criteria, edge cases, security and regressions have meaningful attempts and negative controls.\n- Finding quality: severity, reproduction and anchors are actionable; do not silently downgrade a release-blocking result.\n- Release decision: reject READY when supplied evidence or the implementation diff leaves a Critical/High risk unaddressed.' ;;
  docs) FOCUS='- Trap placement: for every new GUIDELINES Trap, require evidence of a default wrong path or expensive/QA-invisible damage, plus a project-specific trigger, alternative and reason; reject generic role-rule duplicates, and route ordinary antipattern checks and Known Debt to review-checklist.\n- Factual accuracy: every statement describes supplied ground truth, not merely plans.\n- Stale claims: flag renamed, removed, or changed modules and flows.\n- Cap-gaming: flag load-bearing truth removed to meet a size cap while trivia remains.\n- Wrong promotions: reject durable rules promoted from one-off incidents.\n- Current state, not chronicle: docs/ARCHITECTURE.md describes the system as it is now; flag per-PROJ or "built in PROJ-n" sections and Changes baseline lines of the PROJ architecture whose section was not updated.' ;;
esac
if [ "$FOCUS_MODE" = "$MODE" ]; then FOCUS_ALL="$FOCUS"; else FOCUS_ALL+="\n\nAlso review the ${FOCUS_MODE} artifact(s) among the artifacts under review with these ${FOCUS_MODE}-mode criteria:\n${FOCUS}"; fi
done
FOCUS="$FOCUS_ALL"

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
  if [ "$MODE" = qa ]; then
    SNAPSHOT_PATHS=("${DIFF_PATHS[@]}"); [ ${#SNAPSHOT_PATHS[@]} -gt 0 ] || SNAPSHOT_PATHS=(.)
    MATCHED_PATHS="$(git ls-files -z -- "${SNAPSHOT_PATHS[@]}" | tr -cd '\0' | wc -c | tr -d ' ')"
    MATERIAL+=$'\n## Worktree change-stream snapshot (review invocation only)\n'
    MATERIAL+="Matched tracked paths: $MATCHED_PATHS"$'\n'
    MATERIAL+='Command: `(git status --porcelain=v1 -- <pathspecs>; git diff --no-ext-diff HEAD -- <pathspecs>) | git hash-object --stdin`'$'\nPathspecs: '
    MATERIAL+="$(printf '%q ' "${SNAPSHOT_PATHS[@]}")"$'\nHEAD: '"$(git rev-parse HEAD)"$'\nChange-stream hash: '
    MATERIAL+="$( { git status --porcelain=v1 -- "${SNAPSHOT_PATHS[@]}"; git diff --no-ext-diff HEAD -- "${SNAPSHOT_PATHS[@]}"; } | git hash-object --stdin)"
    MATERIAL+=$'\nA clean change stream is valid when tracked paths match; zero matched paths does not establish coverage. This records the current endpoint, not historical before/after snapshots. Matching endpoint hashes establish only no net selected status/diff change, not absence of transient reverted writes, untracked-file content changes, ignored/excluded changes or HEAD movement.\n'
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

RESOURCE_CONFIG="$BASE/3-4_plan/wave-gate-config.json"
[ -f "$RESOURCE_CONFIG" ] || RESOURCE_CONFIG="$BASE/6_plan/wave-gate-config.json"
run_adapter() { local provider="${1%%:*}" model="${1#*:}" out="$2" prompt="${3:-$PROMPT_FILE}"; local args=(--prompt "$prompt" --timeout "$TIMEOUT" --resource-config "$RESOURCE_CONFIG"); [ -n "$model" ] && args+=(--model "$model"); bash "$SCRIPT_DIR/review-with-${provider}.sh" "${args[@]}" >"$out"; }
run_checked_adapter() {
  local reviewer="$1" out="$2" prompt="${3:-$PROMPT_FILE}" rc=0
  run_adapter "$reviewer" "$out" "$prompt" || rc=$?
  if [ "$rc" -ne 0 ]; then
    local classification=adapter-failure
    [ "$rc" -ne 75 ] || classification=provider-unavailable
    if [ "$rc" -eq 64 ] || [ "$rc" -eq 77 ]; then classification=infrastructure; fi
    jq -cn --arg mode "$MODE" --argjson round "$ROUND" --arg provider "${reviewer%%:*}" --arg model "${reviewer#*:}" --arg classification "$classification" --argjson exit_code "$rc" --arg at "$(now_iso)" \
      '{event:"cross-review-failed-attempt",mode:$mode,round:$round,provider:$provider,model:$model,classification:$classification,exit_code:$exit_code,at:$at}' >&2
  fi
  return "$rc"
}
RCS=(); OUT_FILES=("$OUT_A" "$OUT_B")
if [ "$QA_PERSONAS" -eq 1 ]; then
  # Tool-measured concerns leave the persona focus only when the project configured the tool.
  GATE_CFG="$BASE/3-4_plan/wave-gate-config.json"
  cfg_has() { [ -f "$GATE_CFG" ] && jq -e --arg k "$1" '(.[$k] // "") | type == "string" and test("\\S")' "$GATE_CFG" >/dev/null 2>&1; }
  WEBER_FOCUS='Find architecture, coupling, error-handling, testability and duplicate-domain-logic risks.'
  RODRIGUEZ_FOCUS='Find cross-wave coherence, scope-creep and next-PROJ architecture risks.'
  TAKAHASHI_FOCUS='Find YAGNI, abstraction, duplication, dead-path and needless-option risks; include a simplification sketch.'
  ARCH_NOTE=' Dependency direction and import layering are machine-checked by the project (arch_rules_cmd); do not re-flag them.'
  cfg_has arch_rules_cmd && { WEBER_FOCUS+="$ARCH_NOTE"; RODRIGUEZ_FOCUS+="$ARCH_NOTE"; }
  cfg_has complexity_cmd && TAKAHASHI_FOCUS+=' Complexity thresholds and mechanical duplication are machine-checked by the project (complexity_cmd); do not re-flag them, only duplication of established project primitives.'
  PERSONAS=(
    'Dr. Sarah Chen — Security Lead|Find security/auth/injection/secret/authorization risks in the QA evidence and diff.'
    "Marcus Weber — Principal Engineer|$WEBER_FOCUS"
    'Priya Sharma — Performance Engineer|Find latency, N+1, unbounded work, bundle, cache and pagination risks.'
    'Thomas Mueller — SRE / Reliability Engineer|Find failure-mode, retry, idempotency, timeout, observability, race and resource-leak risks.'
    "Elena Rodriguez — Principal Architect|$RODRIGUEZ_FOCUS "'Also emit exactly one `low` finding with category `retrospective` whose summary is a 5-15 bullet retrospective (what should change for the next PROJ); it counts as a finding, so do not also emit review-clean.'
    "Ken Takahashi — Minimalism Engineer|$TAKAHASHI_FOCUS "'Also emit exactly one `low` finding with category `retrospective` whose summary is a 5-15 bullet retrospective (what to delete, inline, merge or avoid in the next PROJ); it counts as a finding, so do not also emit review-clean.'
  )
  # No list = all six in canonical order; a subset keeps that order, so its first persona is the probe.
  PERSONA_IDX=()
  for i in "${!PERSONA_KEYS[@]}"; do
    [ ${#PERSONA_SEL[@]} -eq 0 ] || case " ${PERSONA_SEL[*]} " in *" ${PERSONA_KEYS[$i]} "*) ;; *) continue ;; esac
    PERSONA_IDX+=("$i")
  done
  run_persona() { # index -> runs one persona worker; rc is the adapter exit code
    local i="$1" persona="${PERSONAS[$1]%%|*}" focus="${PERSONAS[$1]#*|}"
    { cat "$PROMPT_FILE"; printf '\n## Assigned QA persona\nYou are %s. %s\nReview only this discipline; emit the strict machine-readable findings contract.\n' "$persona" "$focus"; } > "$QA_PERSONA_DIR/$i.prompt"
    run_checked_adapter "${REVIEWERS[0]}" "$QA_PERSONA_DIR/$i.out" "$QA_PERSONA_DIR/$i.prompt"
  }
  for panel_attempt in 1 2; do
    OUT_FILES=(); panel_rc=0
    # The first chosen persona runs alone as a probe: quota or auth exhaustion costs one call, never the whole panel.
    # The rest run in batches of the host's max_parallel_commands (default 2): resource_run admits no more,
    # and a queued worker would hit its wait_seconds deadline (exit 77) during a long review.
    run_persona "${PERSONA_IDX[0]}" || panel_rc=$?
    cap="$(jq -r '.resources.max_parallel_commands // 2' "$RESOURCE_CONFIG" 2>/dev/null || echo 2)"
    case "$cap" in ''|*[!0-9]*|0) cap=2 ;; esac
    for ((n=1; panel_rc == 0 && n < ${#PERSONA_IDX[@]}; n+=cap)); do
      PERSONA_PIDS=()
      for i in "${PERSONA_IDX[@]:n:cap}"; do run_persona "$i" & PERSONA_PIDS+=($!); done
      for pid in "${PERSONA_PIDS[@]}"; do
        rc=0; wait "$pid" || rc=$?
        # Keep the first failure, but infrastructure failures (64/77) always win.
        if [ "$rc" -ne 0 ] && { [ "$panel_rc" -eq 0 ] || [ "$rc" -eq 64 ] || [ "$rc" -eq 77 ]; }; then panel_rc=$rc; fi
      done
    done
    [ "$panel_rc" -ne 0 ] || for i in "${PERSONA_IDX[@]}"; do OUT_FILES+=("$QA_PERSONA_DIR/$i.out"); done
    [ "$panel_rc" -ne 0 ] || break
    if [ "$panel_rc" -eq 75 ] && [ "$panel_attempt" -eq 1 ] && [ -z "$REQUIRED_PROVIDER" ] && [ "$DEGRADED_FALLBACK" = false ]; then
      alternative=codex; [ "${REVIEWERS[0]%%:*}" != codex ] || alternative=claude
      if "${alternative}_available"; then
        REVIEWERS=("$alternative:"); [ "$alternative" != claude ] || REVIEWERS=("claude:$REVIEW_MODEL")
        DEGRADED_FALLBACK=true
        echo "cross-review (qa): runtime provider unavailable; restarting all ${PANEL_LABEL} personas with $alternative (degraded); failed partial outputs are discarded" >&2
        continue
      fi
    fi
    echo "cross-review.sh: adapter failed (exit $panel_rc) — review did not complete; no round recorded" >&2; if [ "$panel_rc" -eq 64 ] || [ "$panel_rc" -eq 77 ]; then exit "$panel_rc"; fi; exit 1
  done
elif [ ${#REVIEWERS[@]} -eq 2 ]; then
  run_checked_adapter "${REVIEWERS[0]}" "$OUT_A" & PID_A=$!
  run_checked_adapter "${REVIEWERS[1]}" "$OUT_B" & PID_B=$!
  set +e; wait "$PID_A"; RCS+=($?); wait "$PID_B"; RCS+=($?); set -e
else
  rc=0; run_checked_adapter "${REVIEWERS[0]}" "$OUT_A" || rc=$?; RCS+=("$rc")
fi
for rc in "${RCS[@]}"; do [ "$rc" -eq 0 ] || { echo "cross-review.sh: adapter failed (exit $rc) — review did not complete; no round recorded" >&2; if [ "$rc" -eq 64 ] || [ "$rc" -eq 77 ]; then exit "$rc"; fi; exit 1; }; done

ALL_LINES="$(cat "${OUT_FILES[@]}" 2>/dev/null | jq -cs 'map(select(type == "object") | .source = "cross-review") | unique_by([(.category // ""), (.file // ""), (.line // 0), .summary])[]' 2>/dev/null || true)"
FINDING_LINES="$(printf '%s\n' "$ALL_LINES" | jq -c 'select(.category != "review-clean")' 2>/dev/null || true)"
FINDINGS_ADDED="$(printf '%s\n' "$FINDING_LINES" | grep -c '^{' || true)"
ROUND_BLOCKING="$(printf '%s\n' "$FINDING_LINES" | jq -s '[.[] | select(.severity == "critical" or .severity == "high")] | length' 2>/dev/null || echo 0)"

# Free-standing reviews have no PROJ directory and must not create one.
if [ ! -d "$BASE" ]; then
  [ -z "$FINDING_LINES" ] || printf '%s\n' "$FINDING_LINES"
  [ "$ROUND_BLOCKING" -eq 0 ] || { echo "cross-review (${MODE}): ${ROUND_BLOCKING} blocking finding(s)" >&2; exit 3; }
  echo "cross-review (${MODE}): clean — ${FINDINGS_ADDED} non-blocking finding(s) reported without a PROJ ledger" >&2
  exit 0
fi

if [ -n "$FINDING_LINES" ]; then printf '%s\n' "$FINDING_LINES" | node "$LEDGER" add "$PROJ" "$THEME" --stage "$MODE" >&2; fi
BLOCKING="$(node "$LEDGER" list "$PROJ" "$THEME" | jq '[.findings[]? | select(.status == "open") | select(.severity == "critical" or .severity == "high") | select(.source == "cross-review" or ((.sources // []) | index("cross-review")))] | length')"
if [ "$PERSIST" -eq 0 ]; then
  [ -z "$FINDING_LINES" ] || printf '%s\n' "$FINDING_LINES"
  echo "cross-review (${MODE}): this call: ${ROUND_BLOCKING} Critical/High finding(s)" >&2
  [ "$BLOCKING" -eq 0 ] || { echo "cross-review (${MODE}): ${BLOCKING} open blocking finding(s)" >&2; exit 3; }
  echo "cross-review (${MODE}): findings saved in the stage folder; ${FINDINGS_ADDED} reported" >&2
  exit 0
fi
REVIEWER_PROVIDER="${REVIEWERS[0]%%:*}"; REVIEWER_MODEL="${REVIEWERS[0]#*:}"; [ ${#REVIEWERS[@]} -eq 2 ] && { REVIEWER_PROVIDER="claude+codex"; REVIEWER_MODEL="$REVIEW_MODEL"; }; [ "$REVIEWER_PROVIDER" = codex ] && REVIEWER_MODEL="codex-default"
CURRENT="$(bash "$STATE_SH" get "$PROJ" "$THEME" '.cross_review // []' 2>/dev/null || echo '[]')"
PERSONAS_JSON='[]'  # optional record field: only a subset run lists its personas (absent = all six)
[ "$QA_PERSONAS" -eq 0 ] || [ ${#PERSONA_IDX[@]} -eq 6 ] || PERSONAS_JSON="$(for i in "${PERSONA_IDX[@]}"; do echo "${PERSONA_KEYS[$i]}"; done | jq -Rcs 'split("\n") | map(select(. != ""))')"
RECORD="$(jq -n --arg mode "$MODE" --argjson round "$ROUND" --arg rp "$REVIEWER_PROVIDER" --arg rm "$REVIEWER_MODEL" --argjson deg "$DEGRADED_FALLBACK" --argjson fa "$FINDINGS_ADDED" --argjson personas "$PERSONAS_JSON" --arg at "$(now_iso)" '{mode:$mode,round:$round,reviewer_provider:(if $rp == "claude+codex" then "claude" else $rp end),reviewer_model:$rm,joint:($rp == "claude+codex"),degraded_fallback:$deg,findings_added:$fa,at:$at} + (if ($personas | length) > 0 then {personas:$personas} else {} end)')"
UPDATED="$(jq -c --argjson rec "$RECORD" '. + [$rec]' <<<"$CURRENT")"; bash "$STATE_SH" set "$PROJ" "$THEME" .cross_review "$UPDATED" >/dev/null
echo "cross-review (${MODE}, round ${ROUND}): this call: ${ROUND_BLOCKING} Critical/High finding(s)"
if [ "$BLOCKING" -gt 0 ]; then echo "cross-review (${MODE}, round ${ROUND}): ${BLOCKING} open Critical/High finding(s) in the ledger — BLOCKING."; exit 3; fi
echo "cross-review (${MODE}, round ${ROUND}): clean — ${FINDINGS_ADDED} non-blocking finding(s) ingested"
