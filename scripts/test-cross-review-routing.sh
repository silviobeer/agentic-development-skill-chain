#!/usr/bin/env bash
# Cross-review routing against PATH-shimmed claude/codex: opposite-provider
# routing in both directions, six separate QA persona workers, auth preflight,
# degraded fallbacks, pre-P0 runs without state.json, the requirements size
# cap, manual rounds, same-model refusal and the degraded flag in the morning
# report. No provider calls.
set -euo pipefail
export SKILLCHAIN_POLL_SECONDS=0.1 # stubs return instantly; production default stays

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$ROOT/claude/skills"
CASE="$(mktemp -d)"
trap 'rm -rf "$CASE"' EXIT
die() { echo "cross-review-routing: $*" >&2; exit 1; }

FIX="$CASE/repo"
mkdir -p "$FIX"/{docs,scripts,templates,specs/PROJ-96-stage2}
cd "$FIX"
git init -q -b main; git config user.email t@local; git config user.name t
printf '# Architecture\nsrc/queue.js implements exponential backoff with a dead-letter queue for failed events.\n' >docs/ARCHITECTURE.md
printf '# Rules\n- rule 1\n' >AGENTS.md
for s in 5_executing/scripts/chain 5_executing/scripts/render.mjs 5_executing/scripts/state.sh 5_executing/scripts/compat.sh 5_executing/scripts/compile-context.mjs 5_executing/scripts/document-parser.mjs 5_executing/scripts/resolve-inputs.mjs 5_executing/scripts/integration-status.mjs 5_executing/scripts/architecture-parser.mjs \
         6_qa/scripts/findings.mjs 6_qa/scripts/findings-store.mjs cross-review/scripts/cross-review.sh cross-review/scripts/review-with-claude.sh \
         cross-review/scripts/review-with-codex.sh; do
  cp "$SKILLS/$s" scripts/
done
cp "$SKILLS/cross-review/templates/cross-review-prompt.md.tmpl" "$SKILLS"/5_executing/templates/{morning,stop}-report.md.tmpl templates/
chmod +x scripts/*.sh scripts/chain
git add -A; git commit -qm base
chain() { bash scripts/chain "$@"; }
chain state init 96 stage2 >/dev/null

STUB="$CASE/stub"; mkdir -p "$STUB"
cat >"$STUB/claude" <<'EOS'
#!/bin/sh
[ "${1:-}" != auth ] || { [ "${CLAUDE_AUTH_FAIL:-0}" -eq 0 ]; exit; }
[ -z "${QA_STUB_LOG:-}" ] || printf 'claude\n' >> "$QA_STUB_LOG"
input="$(cat)"
[ -z "${QA_PERSONA_LOG:-}" ] || printf '%s\n' "$input" | sed -n 's/^You are \(.*\) — .*/\1/p' >> "$QA_PERSONA_LOG"
case "$input" in
  *"## Artifact under review:"*) ;;
  *) exit 9 ;;
esac
if [ "${REQUIREMENTS_STUB:-0}" -eq 1 ]; then
  case "$input" in
    *"Testability:"*"Cross-PRD consistency:"*) ;;
    *) exit 10 ;;
  esac
  case "$input" in
    *END-OF-LARGE-ARTIFACT*) ;;
    *) exit 11 ;;
  esac
fi
printf '{"is_error":false,"structured_output":{"findings":[{"severity":"%s","category":"claude-stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub claude finding"}]}}\n' "${CLAUDE_STUB_SEVERITY:-high}"
EOS
cat >"$STUB/codex" <<'EOS'
#!/bin/sh
[ "$1" = "login" ] && exit 0
[ -z "${QA_STUB_LOG:-}" ] || printf 'codex\n' >> "$QA_STUB_LOG"
input="$(cat)"
[ -z "${QA_PERSONA_LOG:-}" ] || printf '%s\n' "$input" | sed -n 's/^You are \(.*\) — .*/\1/p' >> "$QA_PERSONA_LOG"
case "$input" in
  *"## Artifact under review: docs/ARCHITECTURE.md"*) ;;
  *) exit 9 ;;
esac
echo '{"severity":"medium","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub codex finding"}'
EOS
chmod +x "$STUB/claude" "$STUB/codex"
codex_down() { printf '#!/bin/sh\nexit 1\n' >"$STUB/codex"; }
review() { PATH="$STUB:$PATH" bash scripts/chain review "$@"; }
xr() { jq -r "$1" specs/PROJ-96-stage2/state.json; }          # last cross_review record
workers() { wc -l <"$1" | tr -d ' '; }

chain state set 96 stage2 .authorship '{"docs-delta":{"author_provider":"claude","author_model":"opus"},"codex-delta":{"author_provider":"codex","author_model":"gpt-5.6"}}' >/dev/null

# Claude-authored -> Codex reviews; the round and the provider-stamped finding land in state and ledger.
review docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 1 >/dev/null 2>&1 || die 'claude-authored docs review failed'
[ "$(xr '.cross_review[-1].reviewer_provider')" = codex ] || die 'claude-authored review not routed to codex'
[ "$(jq -r '[.findings[] | select(.source == "cross-review" and .provider == "codex")] | length' specs/PROJ-96-stage2/7_documentation/findings.json)" -ge 1 ] \
  || die 'codex finding missing from the ledger with source=cross-review and provider'

# Codex-authored -> authenticated Claude reviews, is recorded and ingested.
CLAUDE_STUB_SEVERITY=medium review docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key codex-delta --round 1 >/dev/null 2>&1 || die 'codex-authored docs review failed'
[ "$(xr '.cross_review[-1].reviewer_provider')" = claude ] || die 'codex-authored review not routed to claude'
[ "$(jq -r '[.findings[] | select(.source == "cross-review" and .provider == "claude")] | length' specs/PROJ-96-stage2/7_documentation/findings.json)" -ge 1 ] \
  || die 'claude finding missing from the ledger'

# QA starts six separate persona workers on the opposite provider (auth probes are no workers).
LOG="$CASE/qa-claude.log"
QA_STUB_LOG="$LOG" CLAUDE_STUB_SEVERITY=medium review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider codex --persist --personas --round 1 >/dev/null 2>&1 \
  || die 'codex-authored QA review failed'
[ "$(xr '.cross_review[-1] | .mode + ":" + .reviewer_provider')" = qa:claude ] && [ "$(workers "$LOG")" -eq 6 ] \
  || die "codex-authored QA must start six claude personas, got $(workers "$LOG")"
LOG="$CASE/qa-codex.log"
QA_STUB_LOG="$LOG" review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas --round 1 >/dev/null 2>&1 \
  || die 'claude-authored QA review failed'
[ "$(xr '.cross_review[-1] | .mode + ":" + .reviewer_provider')" = qa:codex ] && [ "$(workers "$LOG")" -eq 6 ] \
  || die "claude-authored QA must start six codex personas, got $(workers "$LOG")"

# --personas <list>: only the chosen workers run, in canonical order (the first is the probe), the record names them;
# no list stays six with no `personas` field; unknown names are invalid use.
LOG="$CASE/qa-subset.log"; PLOG="$CASE/qa-subset.personas"; : >"$PLOG"
QA_STUB_LOG="$LOG" QA_PERSONA_LOG="$PLOG" review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas Takahashi,weber,marcus --round 1 >/dev/null 2>&1 \
  || die 'subset QA review failed'
[ "$(workers "$LOG")" -eq 2 ] && [ "$(sed -n 1p "$PLOG")" = 'Marcus Weber' ] && [ "$(sed -n 2p "$PLOG")" = 'Ken Takahashi' ] \
  || die "subset QA must run weber then takahashi only, got $(tr '\n' ',' <"$PLOG")"
[ "$(xr '.cross_review[-1] | .mode + ":" + .reviewer_provider + ":" + (.personas | join(","))')" = qa:codex:weber,takahashi ] \
  || die 'subset QA record must carry the personas array'
LOG="$CASE/qa-subset-claude.log"
QA_STUB_LOG="$LOG" CLAUDE_STUB_SEVERITY=medium review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider codex --persist --personas chen --round 1 >/dev/null 2>&1 \
  || die 'single-persona QA review failed'
[ "$(workers "$LOG")" -eq 1 ] && [ "$(xr '.cross_review[-1].personas | join(",")')" = chen ] || die 'single-persona QA must start one worker and record it'
LOG="$CASE/qa-explicit-six.log"
QA_STUB_LOG="$LOG" review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas chen,weber,sharma,mueller,rodriguez,takahashi --round 1 >/dev/null 2>&1 \
  || die 'explicit six-persona QA review failed'
[ "$(workers "$LOG")" -eq 6 ] && [ "$(xr '.cross_review[-1] | has("personas")')" = false ] || die 'a full explicit list equals the default: six workers, no personas field'
LOG="$CASE/qa-badname.log"; : >"$LOG"
for bad in 'bogus' 'weber,nobody' ',' 'weber,'; do
  rc=0; QA_STUB_LOG="$LOG" review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas "$bad" >"$CASE/badname.out" 2>&1 || rc=$?
  [ "$rc" -eq 64 ] || die "--personas '$bad' must exit 64 (rc=$rc)"
done
[ ! -s "$LOG" ] || die 'an invalid persona list must stop before any worker runs'
rc=0; review docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --personas weber >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 64 ] || die "--personas must stay invalid outside qa (rc=$rc)"
rc=0; review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --joint --personas weber >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 64 ] || die "--personas must stay invalid with --joint (rc=$rc)"

# A Codex author has no same-provider fallback: fail before any reviewer runs when Claude auth is gone.
! out="$(CLAUDE_AUTH_FAIL=1 review docs 97 pre-p0 --artifacts docs/ARCHITECTURE.md --author-provider codex 2>&1)" \
  && grep -q 'Claude is required.*unavailable or unauthenticated' <<<"$out" || die 'codex author without Claude auth must fail closed with a clear message'

# Claude-authored QA with Codex down: six Claude personas, rc 3, degraded fallback recorded and announced.
codex_down
LOG="$CASE/qa-fallback.log"; rc=0
QA_STUB_LOG="$LOG" review qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas >"$CASE/fallback.out" 2>&1 || rc=$?
[ "$rc" -eq 3 ] && [ "$(xr '.cross_review[-1] | .reviewer_provider + ":" + (.degraded_fallback | tostring)')" = claude:true ] && [ "$(workers "$LOG")" -eq 6 ] \
  && grep -q 'opposite provider unavailable; continuing six QA personas with claude' "$CASE/fallback.out" \
  || die "missing codex must degrade to six claude personas (rc=$rc)"

# Model-opposite fallback is flagged in state; the reviewer is never the author model.
before="$(xr '.cross_review | length')"; rc=0
CLAUDE_REVIEW_MODEL=sonnet review docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 2 >/dev/null 2>&1 || rc=$?
{ [ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]; } && [ "$(xr '.cross_review | length')" -eq $((before + 1)) ] \
  && [ "$(xr '.cross_review[-1] | .mode + ":" + (.round|tostring) + ":" + (.degraded_fallback|tostring) + ":" + .reviewer_model')" = docs:2:true:sonnet ] \
  || die "degraded model-opposite fallback not recorded as a new docs round 2 record (rc=$rc)"
rc=0; CLAUDE_REVIEW_MODEL=opus review docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta >"$CASE/same.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] && grep -q 'fallback reviewer equals author model' "$CASE/same.out" || die "reviewer model == author model must be refused (rc=$rc)"

# Restore a healthy codex for the remaining controls.
cat >"$STUB/codex" <<'EOS'
#!/bin/sh
[ "$1" = "login" ] && exit 0
echo '{"severity":"medium","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub codex finding"}'
EOS

# Before P0, persist concept findings without creating runtime state.
mkdir -p specs/PROJ-97-pre-p0
OUT="$(review concept 97 pre-p0 --artifacts docs/ARCHITECTURE.md --author-provider claude 2>/dev/null)" || die 'pre-P0 review failed'
printf '%s\n' "$OUT" | jq -e 'select(.provider == "codex" and .source == "cross-review")' >/dev/null \
  && [ -e specs/PROJ-97-pre-p0/1_concept/findings.json ] && [ ! -e specs/PROJ-97-pre-p0/state.json ] \
  || die 'pre-P0 review must save a local ledger without state.json'

# A free-standing review outside any PROJ must not create project files.
OUT="$(review concept 98 standalone --artifacts docs/ARCHITECTURE.md --author-provider claude 2>/dev/null)" || die 'standalone review failed'
printf '%s\n' "$OUT" | jq -e 'select(.source == "cross-review")' >/dev/null || die 'standalone findings missing'
[ ! -e specs/PROJ-98-standalone ] || die 'standalone review created a PROJ directory'

# Requirements mode: a prompt above the former 128 KiB default streams to Claude; an explicit cap still bites.
{ awk 'BEGIN { for (i = 0; i < 150000; i++) printf "x" }'; echo END-OF-LARGE-ARTIFACT; } >docs/large-requirements.md
rc=0; REQUIREMENTS_STUB=1 review requirements 97 pre-p0 --artifacts docs/large-requirements.md --author-provider codex >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || die "requirements review above 128 KiB must reach the provider with the whole artifact, end marker included (rc=$rc)"
: >"$CASE/capped.log"; rc=0
QA_STUB_LOG="$CASE/capped.log" CROSS_REVIEW_MAX_CONTEXT_BYTES=1024 review requirements 97 pre-p0 --artifacts docs/large-requirements.md --author-provider codex >"$CASE/capped.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] && grep -q 'above configured limit 1024' "$CASE/capped.out" && [ ! -s "$CASE/capped.log" ] \
  || die "an explicit context cap must stop the review before any provider call (rc=$rc)"

# Manual rounds beyond the automatic limit run and persist.
for round in 3 4; do
  rc=0; review docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round "$round" >/dev/null 2>&1 || rc=$?
  { [ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]; } && [ "$(xr '.cross_review[-1].round')" -eq "$round" ] || die "round $round did not run or persist (rc=$rc)"
done

# The degraded flag renders in the morning report.
chain state set 96 stage2 .degraded true >/dev/null
chain state set 96 stage2 .degraded_reason '"codex unavailable at P7"' >/dev/null
chain render report morning specs >/dev/null 2>&1
grep -rq 'Provider degradation: codex unavailable at P7' specs/morning-report-*.md || die 'morning report lacks the degradation flag'
echo "cross-review-routing: ok"
