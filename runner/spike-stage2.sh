#!/usr/bin/env bash
# spike-stage2.sh — Stage 2 verification spike / release gate (CONCEPT.md §10.2).
#
# Proves, on disposable fixtures:
#   context compiler   — determinism, budget breach writes nothing, projection
#                        hash parity (claude/codex embed the canonical body),
#                        verify catches drift and tampering
#   context injector   — tier matrix (micro-fixer/explore nothing, frontend vs
#                        backend scoping, reviewer minimal), never-inject
#                        (no PRD/progress.md content in any bundle), stale-hash refusal
#   curation caps      — pass + per-cap fail fixtures, --require-baseline
#   ponytail gate      — parity ok / version mismatch / absent (enforce on+off)
#   cross-review       — symmetric deterministic routing via PATH-shimmed CLIs
#                        (opposite provider, six-persona parity, auth preflight,
#                        structured output, ledger attribution, protocol controls,
#                        round cap, same-model refusal), process-group timeout,
#                        LIVE adapter smoke per available direction (+ degraded
#                        model-opposite fallback), degraded flag in the morning report
#   P7 runner gate     — stubbed lanes seal P7:done; failing caps park the run,
#                        an open Critical/High cross-review finding parks the run,
#                        green gates let it pass
#
# Usage: spike-stage2.sh [--skip-live]   (--skip-live: no real LLM calls)
# Exit:  0 all assertions passed · 1 any assertion failed
set -uo pipefail

SKIP_LIVE=0
[ "${1:-}" = "--skip-live" ] && SKIP_LIVE=1

SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SPIKE_DIR/.." && pwd)"
SKILLS="$REPO_ROOT/claude/skills"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $*"; FAIL=$((FAIL+1)); }
step() { echo "→ $*"; }

# =============================================================================
# Fixture repo: intake-style baseline + one PROJ, framework scripts installed
# =============================================================================
FIX="$WORK/repo"
mkdir -p "$FIX"/{docs,src/feature,scripts,templates/roles,specs/PROJ-96-stage2/2_PRDs,specs/PROJ-96-stage2/5_progress}
cd "$FIX"
git init -q -b main; git config user.email spike@local; git config user.name spike

printf '# Product\nA queue-backed task app.\n' > docs/PRODUCT.md
printf '# Architecture\nsrc/queue.js implements exponential backoff with a dead-letter queue for failed events.\n' > docs/ARCHITECTURE.md
printf '# Guidelines\n- errors via Result type\n' > docs/GUIDELINES.md
printf '# Design system\n- token: --color-primary\n' > docs/DESIGN-SYSTEM.md
printf '# Components\n- Button\n' > docs/components.md
printf '# Security baseline\n- no secrets in code\n' > docs/security-baseline.md
printf '# Test conventions\n- vitest\n' > docs/test-conventions.md
printf '# Rules\n- rule 1\n' > AGENTS.md
printf '// retry forever, NO backoff, NO dead-letter handling\nmodule.exports = () => {};\n' > src/queue.js
printf '# PRD\nNEVER-INJECT-MARKER-PRD full requirement text.\n' > specs/PROJ-96-stage2/2_PRDs/PROJ-96-PRD-1.md
printf '# Progress\nNEVER-INJECT-MARKER-PROGRESS wave log.\n' > specs/PROJ-96-stage2/5_progress/PROJ-96-progress.md
printf '## Wave 1 — queue API\nPOST /enqueue\n' > specs/PROJ-96-stage2/api-contracts.md
printf '# Ground file\nAssumption: node 22.\n' > specs/PROJ-96-stage2/ground-file.md
mkdir -p specs/intake
printf '# Bootstrap decisions\n\n- D-BOOTSTRAP-01 · Point: error convention · Decision: adopt\n' > specs/intake/decisions.md

for s in 4b_setup/scripts/state.sh 4b_setup/scripts/compile-context-bundles.mjs \
         4b_setup/scripts/context-injector.mjs 4b_setup/scripts/ponytail-check.sh \
         6_qa/scripts/ledger.mjs 7_documentation/scripts/curation-caps.sh \
         0b_intake/scripts/intake-seal-check.sh \
         cross-review/scripts/cross-review.sh cross-review/scripts/review-with-claude.sh \
         cross-review/scripts/review-with-codex.sh; do
  cp "$SKILLS/$s" scripts/
done
mkdir -p templates
cp "$SKILLS/cross-review/templates/cross-review-prompt.md.tmpl" templates/
cp "$SKILLS"/4b_setup/manifests/roles/*.md templates/roles/
chmod +x scripts/*.sh
git add -A; git commit -qm base
BASE_SHA="$(git rev-parse HEAD)"

bash scripts/state.sh init 96 stage2 >/dev/null
bash scripts/state.sh set 96 stage2 .base_sha "\"$BASE_SHA\"" >/dev/null

# =============================================================================
step "context compiler"
# =============================================================================
node scripts/compile-context-bundles.mjs compile 96 stage2 >/dev/null 2>&1 \
  && ok "compile succeeds on the baseline fixture" || bad "compile failed"
CTX=specs/PROJ-96-stage2/context
S1="$(cat "$CTX"/bundle-*.md | sha1sum)"
node scripts/compile-context-bundles.mjs compile 96 stage2 >/dev/null 2>&1
S2="$(cat "$CTX"/bundle-*.md | sha1sum)"
[ "$S1" = "$S2" ] && ok "deterministic: two compiles are byte-identical" || bad "compiles differ"

BEFORE="$(find "$CTX" -type f -exec sha1sum {} + | sha1sum)"
CONTEXT_BUNDLE_BUDGET=40 node scripts/compile-context-bundles.mjs compile 96 stage2 >/dev/null 2>&1
RC=$?
AFTER="$(find "$CTX" -type f -exec sha1sum {} + | sha1sum)"
[ "$RC" -ne 0 ] && [ "$BEFORE" = "$AFTER" ] && ok "budget breach: exit != 0 and NOTHING written" || bad "budget breach rc=$RC, dir changed: $([ "$BEFORE" != "$AFTER" ] && echo yes || echo no)"

PARITY_OK=1
for r in implementer frontend-implementer backend-implementer reviewer; do
  canon="$(sha256sum "$CTX/bundle-$r.md" | cut -d' ' -f1)"
  for p in claude codex; do
    emb="$(tail -n +2 "$CTX/bundle-$r.$p.md" | sha256sum | cut -d' ' -f1)"
    [ "$emb" = "$canon" ] || PARITY_OK=0
  done
done
[ "$PARITY_OK" -eq 1 ] && ok "projection parity: claude+codex embed the canonical body verbatim (same hash)" || bad "projection embeds a different body"

node scripts/compile-context-bundles.mjs verify 96 stage2 >/dev/null 2>&1 && ok "verify passes on fresh compile" || bad "verify failed on fresh compile"
echo "drift" >> docs/GUIDELINES.md
node scripts/compile-context-bundles.mjs verify 96 stage2 >/dev/null 2>&1 && bad "verify missed semantic drift" || ok "verify catches semantic drift (doc changed after compile)"
git checkout -q docs/GUIDELINES.md
echo "tamper" >> "$CTX/bundle-reviewer.md"
node scripts/compile-context-bundles.mjs verify 96 stage2 >/dev/null 2>&1 && bad "verify missed tampering" || ok "verify catches on-disk tampering"
node scripts/compile-context-bundles.mjs compile 96 stage2 >/dev/null 2>&1

# =============================================================================
step "context injector (tier matrix + never-inject)"
# =============================================================================
inject() { printf '{"hook_event_name":"SubagentStart","agent_type":"%s"}' "$1" | node scripts/context-injector.mjs claude 2>/dev/null; }
T0_OK=1
[ -z "$(inject skillchain-micro-fixer)" ] || T0_OK=0
[ -z "$(inject Explore)" ] || T0_OK=0
[ -z "$(inject totally-unknown-agent)" ] || T0_OK=0
[ "$T0_OK" -eq 1 ] && ok "tier 0/explore/unknown spawns get NOTHING" || bad "tier-0 class received context"
FE="$(inject frontend-implementer | jq -r '.hookSpecificOutput.additionalContext')"
BE="$(inject backend-implementer  | jq -r '.hookSpecificOutput.additionalContext')"
RV="$(inject skillchain-reviewer-security | jq -r '.hookSpecificOutput.additionalContext')"
{ grep -q "Design system" <<<"$FE" && ! grep -q "Security baseline" <<<"$FE" \
  && grep -q "Security baseline" <<<"$BE" && ! grep -q "Design system" <<<"$BE"; } \
  && ok "tier 1 type-scoping: frontend gets design-system (no security), backend the inverse" \
  || bad "tier-1 scoping wrong"
{ grep -q "Product" <<<"$RV" && grep -q "Review criteria" <<<"$RV" && ! grep -q "Guidelines (docs" <<<"$RV"; } \
  && ok "tier 2 reviewer bundle is minimal (product + criteria + diff scope)" || bad "reviewer bundle wrong"
grep -rq "NEVER-INJECT-MARKER" "$CTX"/bundle-*.md && bad "never-inject violated: PRD/progress content in a bundle" \
  || ok "never-inject holds: no PRD/progress.md content in any bundle"
echo "tamper" >> "$CTX/bundle-implementer.md"
[ -z "$(inject implementer)" ] && ok "stale bundle (hash mismatch) injects NOTHING" || bad "stale bundle was injected"
node scripts/compile-context-bundles.mjs compile 96 stage2 >/dev/null 2>&1
# SKILLCHAIN_PROJ/THEME pin the injector to the run's PROJ (the runner exports
# them) — a newer decoy PROJ must not hijack injection
mkdir -p specs/PROJ-97-decoy/context
echo '{}' > specs/PROJ-97-decoy/context/bundles.lock.json
echo '{"phase":"P5"}' > specs/PROJ-97-decoy/state.json
PIN="$(printf '{"hook_event_name":"SubagentStart","agent_type":"implementer"}' | SKILLCHAIN_PROJ=96 SKILLCHAIN_THEME=stage2 node scripts/context-injector.mjs claude 2>/dev/null)"
[ -n "$PIN" ] && ok "SKILLCHAIN_PROJ/THEME pin the injector to the run's PROJ (decoy ignored)" || bad "project pinning failed — injector guessed wrong PROJ"
rm -rf specs/PROJ-97-decoy

# =============================================================================
step "curation caps + intake seal"
# =============================================================================
bash scripts/curation-caps.sh . >/dev/null 2>&1 && ok "caps pass on the clean baseline" || bad "caps failed on clean baseline"
CAPS_OK=1
seq 1 31 > docs/PRODUCT.md;      bash scripts/curation-caps.sh . >/dev/null 2>&1 && CAPS_OK=0; git checkout -q docs/PRODUCT.md
seq 1 201 > docs/ARCHITECTURE.md; bash scripts/curation-caps.sh . >/dev/null 2>&1 && CAPS_OK=0; git checkout -q docs/ARCHITECTURE.md
seq 1 101 > src/feature/agent.md; bash scripts/curation-caps.sh . >/dev/null 2>&1 && CAPS_OK=0; rm src/feature/agent.md
seq 1 41 > AGENTS.md;             bash scripts/curation-caps.sh . >/dev/null 2>&1 && CAPS_OK=0; git checkout -q AGENTS.md
[ "$CAPS_OK" -eq 1 ] && ok "each cap breach fails (PRODUCT 31, ARCHITECTURE 201, agent.md 101, AGENTS.md 41)" || bad "a cap breach passed"
bash scripts/intake-seal-check.sh . >/dev/null 2>&1 && ok "intake seal check passes on the clean baseline" || bad "seal check failed clean"
echo 'claim [assumed]' >> docs/GUIDELINES.md
bash scripts/intake-seal-check.sh . >/dev/null 2>&1 && bad "seal check missed a residual provenance marker" || ok "seal check fails on residual provenance markers"
git checkout -q docs/GUIDELINES.md
mv specs/intake/decisions.md specs/intake/decisions.md.bak
bash scripts/intake-seal-check.sh . >/dev/null 2>&1 && bad "seal check missed missing reconcile evidence" || ok "seal check fails without D-BOOTSTRAP reconcile evidence (undiscussed drafts never seal)"
mv specs/intake/decisions.md.bak specs/intake/decisions.md

# =============================================================================
step "ponytail parity gate (stubbed registries)"
# =============================================================================
PT="$WORK/pt"; mkdir -p "$PT/cache/4.8.4/.codex-plugin" "$PT/cfg"
echo '{"version":2,"plugins":{"ponytail@ponytail":[{"version":"4.8.4"}]}}' > "$PT/claude.json"
echo '{"version":"4.8.4"}' > "$PT/cache/4.8.4/.codex-plugin/plugin.json"
printf '[plugins."ponytail@ponytail"]\nenabled = true\n' > "$PT/codex.toml"
echo '{"defaultMode":"full"}' > "$PT/cfg/config.json"
ptc() { PONYTAIL_CLAUDE_REGISTRY="$PT/claude.json" PONYTAIL_CODEX_CACHE="$PT/cache" \
        PONYTAIL_CODEX_CONFIG="$PT/codex.toml" PONYTAIL_CONFIG="$PT/cfg/config.json" \
        bash scripts/ponytail-check.sh "$@"; }
ptc >/dev/null 2>&1 && ok "parity ok -> exit 0" || bad "parity fixture failed"
mkdir -p "$PT/cache/4.9.0/.codex-plugin"; echo '{"version":"4.9.0"}' > "$PT/cache/4.9.0/.codex-plugin/plugin.json"
ptc >/dev/null 2>&1 && bad "version mismatch passed" || ok "version mismatch -> exit 1 (blocks P0)"
rm -rf "$PT/cache/4.9.0"
echo '{"version":2,"plugins":{}}' > "$PT/claude.json"
ptc >/dev/null 2>&1 && bad "absent plugin passed with enforce on" || ok "absent plugin + enforce -> exit 1"
PONYTAIL_ENFORCE=0 ptc --json 2>/dev/null | jq -e '.enforced == false and .parity_ok == false' >/dev/null \
  && PONYTAIL_ENFORCE=0 ptc >/dev/null 2>&1 \
  && ok "PONYTAIL_ENFORCE=0: exit 0 but recorded enforced:false (loud escape hatch)" \
  || bad "enforce-off path wrong"
echo '{"version":2,"plugins":{"ponytail@ponytail":[{"version":"4.8.4"}]}}' > "$PT/claude.json"
echo '{"defaultMode":"off"}' > "$PT/cfg/config.json"
ptc >/dev/null 2>&1 && bad "mode 'off' passed the gate" || ok "mode 'off' -> exit 1 (ladder disabled is a failed gate, not parity)"
echo '{"defaultMode":"full"}' > "$PT/cfg/config.json"
PONYTAIL_CLAUDE_REGISTRY="$PT/claude.json" PONYTAIL_CODEX_CACHE="$PT/cache" \
  PONYTAIL_CODEX_CONFIG="$PT/codex.toml" PONYTAIL_CONFIG="$PT/cfg/config.json" \
  PONYTAIL_SUBAGENT_MATCHER='implementer|frontend-implementer|backend-implementer|micro-fixer' bash scripts/ponytail-check.sh >/dev/null 2>&1 \
  && bad "scoped ladder matcher passed the gate" \
  || ok "scoped ladder matcher -> exit 1 (generic implementation fallback would be missed)"

# =============================================================================
step "cross-review mechanics (PATH-shimmed CLIs, deterministic)"
# =============================================================================
STUB="$WORK/stub"; mkdir -p "$STUB"
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
[ "${1:-}" != auth ] || { [ "${CLAUDE_AUTH_FAIL:-0}" -eq 0 ]; exit; }
[ -z "${QA_STUB_LOG:-}" ] || printf 'claude\n' >> "$QA_STUB_LOG"
input="$(cat)"
case "$input" in
  *"## Artifact under review:"*) ;;
  *) exit 9 ;;
esac
if [ "${REQUIREMENTS_STUB:-0}" -eq 1 ]; then
  case "$input" in
    *"Testability:"*"Cross-PRD consistency:"*) ;;
    *) exit 10 ;;
  esac
fi
severity="${CLAUDE_STUB_SEVERITY:-high}"
category="${CLAUDE_STUB_CATEGORY:-claude-stale-claim}"
printf '{"is_error":false,"structured_output":{"findings":[{"severity":"%s","category":"%s","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub claude finding"}]}}\n' "$severity" "$category"
EOF
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
[ "$1" = "login" ] && exit 0
[ -z "${QA_STUB_LOG:-}" ] || printf 'codex\n' >> "$QA_STUB_LOG"
input="$(cat)"
case "$input" in
  *"## Artifact under review: docs/ARCHITECTURE.md"*) ;;
  *) exit 9 ;;
esac
echo '{"severity":"medium","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub codex finding"}'
EOF
chmod +x "$STUB/claude" "$STUB/codex"
bash scripts/state.sh set 96 stage2 .authorship '{"docs-delta":{"author_provider":"claude","author_model":"opus"},"codex-delta":{"author_provider":"codex","author_model":"gpt-5.6"}}' >/dev/null
PATH="$STUB:$PATH" bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 1 >/dev/null 2>&1
RC=$?
XRP="$(jq -r '.cross_review[-1].reviewer_provider' specs/PROJ-96-stage2/state.json 2>/dev/null)"
[ "$RC" -eq 0 ] && [ "$XRP" = "codex" ] && ok "claude-authored -> codex reviews; round recorded in state" || bad "routing rc=$RC reviewer=$XRP"
LED="$(jq -r '[.findings[] | select((.source == "cross-review") and .provider == "codex")] | length' specs/PROJ-96-stage2/findings.json 2>/dev/null)"
[ "${LED:-0}" -ge 1 ] && ok "finding landed in the ledger: source=cross-review, provider attributed" || bad "ledger has no attributed cross-review finding"
# Mirror the normal persistent route: Codex-authored material must reach an
# authenticated Claude reviewer, be provider-stamped, and land in state/ledger.
PATH="$STUB:$PATH" CLAUDE_STUB_SEVERITY=medium bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key codex-delta --round 1 >/dev/null 2>&1
RC=$?
XRP="$(jq -r '.cross_review[-1].reviewer_provider' specs/PROJ-96-stage2/state.json 2>/dev/null)"
LED="$(jq -r '[.findings[] | select((.source == "cross-review") and .provider == "claude")] | length' specs/PROJ-96-stage2/findings.json 2>/dev/null)"
[ "$RC" -eq 0 ] && [ "$XRP" = "claude" ] && [ "${LED:-0}" -ge 1 ] \
  && ok "codex-authored -> authenticated Claude review is recorded and ingested" \
  || bad "Codex->Claude persistent routing rc=$RC reviewer=$XRP ledger=$LED"
# Codex QA must start six separate Claude persona workers, not one simulated
# panel. Authentication probes are excluded from the worker count.
QA_CLAUDE_LOG="$WORK/qa-claude-personas.log"
PATH="$STUB:$PATH" QA_STUB_LOG="$QA_CLAUDE_LOG" CLAUDE_STUB_SEVERITY=medium \
  bash scripts/cross-review.sh qa 96 stage2 --artifacts docs/ARCHITECTURE.md \
  --author-provider codex --persist --personas --round 1 >/dev/null 2>&1
RC=$?
QA_XR="$(jq -r '.cross_review[-1] | .mode + ":" + .reviewer_provider' specs/PROJ-96-stage2/state.json 2>/dev/null)"
[ "$RC" -eq 0 ] && [ "$QA_XR" = "qa:claude" ] && [ "$(wc -l < "$QA_CLAUDE_LOG" | tr -d ' ')" -eq 6 ] \
  && ok "Codex QA starts six separate Claude personas and records the review" \
  || bad "Codex QA persona routing rc=$RC record=$QA_XR workers=$(wc -l < "$QA_CLAUDE_LOG" | tr -d ' ')"
# A Codex-authored run has no same-provider fallback. Fail before rendering or
# invoking a reviewer when Claude authentication is unavailable.
CLAUDE_AUTH_OUT="$WORK/claude-auth-fail.out"
PATH="$STUB:$PATH" CLAUDE_AUTH_FAIL=1 bash scripts/cross-review.sh docs 97 pre-p0 \
  --artifacts docs/ARCHITECTURE.md --author-provider codex >"$CLAUDE_AUTH_OUT" 2>&1
RC=$?
[ "$RC" -eq 1 ] && grep -q 'Claude is required.*unavailable or unauthenticated' "$CLAUDE_AUTH_OUT" \
  && ok "Codex->Claude fails early and clearly when Claude auth is unavailable" \
  || bad "Claude auth preflight did not fail closed (rc=$RC)"
# QA evidence authored in Claude gets six *separate* Codex persona workers.
# They must not be one prompt that merely names six personas.
QA_LOG="$WORK/qa-personas.log"
PATH="$STUB:$PATH" QA_STUB_LOG="$QA_LOG" bash scripts/cross-review.sh qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas --round 1 >/dev/null 2>&1
RC=$?
QA_XR="$(jq -r '.cross_review[-1] | .mode + ":" + .reviewer_provider' specs/PROJ-96-stage2/state.json 2>/dev/null)"
[ "$RC" -eq 0 ] && [ "$QA_XR" = "qa:codex" ] && [ "$(wc -l < "$QA_LOG" | tr -d ' ')" -eq 6 ] \
  && ok "Claude QA starts six separate Codex personas and records the review" \
  || bad "Claude QA persona routing rc=$RC record=$QA_XR workers=$(wc -l < "$QA_LOG" | tr -d ' ')"
printf '#!/bin/sh\nexit 1\n' > "$STUB/codex"; chmod +x "$STUB/codex"
QA_FALLBACK_LOG="$WORK/qa-fallback-personas.log"; QA_FALLBACK_OUT="$WORK/qa-fallback.out"
PATH="$STUB:$PATH" QA_STUB_LOG="$QA_FALLBACK_LOG" bash scripts/cross-review.sh qa 96 stage2 --artifacts docs/ARCHITECTURE.md --author-provider claude --persist --personas >"$QA_FALLBACK_OUT" 2>&1
RC=$?
QA_FALLBACK="$(jq -r '.cross_review[-1] | .reviewer_provider + ":" + (.degraded_fallback | tostring)' specs/PROJ-96-stage2/state.json 2>/dev/null)"
[ "$RC" -eq 3 ] && [ "$QA_FALLBACK" = "claude:true" ] && [ "$(wc -l < "$QA_FALLBACK_LOG" | tr -d ' ')" -eq 6 ] \
  && grep -q 'Codex unavailable; continuing six QA personas with Claude (degraded)' "$QA_FALLBACK_OUT" \
  && ok "missing Codex -> six Claude personas, recorded degraded fallback and visible warning" \
  || bad "Codex fallback wrong rc=$RC record=$QA_FALLBACK workers=$(wc -l < "$QA_FALLBACK_LOG" | tr -d ' ')"
# Restore the successful adapter stub for the remaining protocol controls.
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
[ "$1" = "login" ] && exit 0
echo '{"severity":"medium","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub codex finding"}'
EOF
chmod +x "$STUB/codex"
# Before P0 there is no state.json. An explicit author must route the review,
# embed its input, and report findings only to the human (stdout).
OUT="$(PATH="$STUB:$PATH" bash scripts/cross-review.sh concept 97 pre-p0 --artifacts docs/ARCHITECTURE.md --author-provider claude 2>/dev/null)"
RC=$?
printf '%s\n' "$OUT" | jq -e 'select(.provider == "codex" and .source == "cross-review")' >/dev/null 2>&1 \
  && [ "$RC" -eq 0 ] && [ ! -e specs/PROJ-97-pre-p0/findings.json ] \
  && ok "pre-P0 explicit author reports to human without state.json or ledger" \
  || bad "pre-P0 explicit-author path failed (rc=$RC)"
# Requirements is a first-class pre-P0 mode. A prompt above the former 128 KiB
# default must stream to Claude through stdin; an explicitly configured cap
# remains enforceable.
awk 'BEGIN { for (i = 0; i < 150000; i++) printf "x" }' > docs/large-requirements.md
REQUIREMENTS_STUB=1 PATH="$STUB:$PATH" bash scripts/cross-review.sh requirements 97 pre-p0 \
  --artifacts docs/large-requirements.md --author-provider codex >/dev/null 2>&1
RC=$?
[ "$RC" -eq 3 ] \
  && ok "requirements mode streams >128 KiB to Claude without an artificial default cap" \
  || bad "large requirements review failed before provider review (rc=$RC)"
CROSS_REVIEW_MAX_CONTEXT_BYTES=1024 PATH="$STUB:$PATH" \
  bash scripts/cross-review.sh requirements 97 pre-p0 \
  --artifacts docs/large-requirements.md --author-provider codex >/dev/null 2>&1
[ $? -eq 1 ] && ok "explicit cross-review context cap remains enforceable" \
  || bad "explicit cross-review context cap was ignored"
PATH="$STUB:$PATH" bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 3 >/dev/null 2>&1
[ $? -eq 64 ] && ok "round 3 refused (max 2 rounds, then §8)" || bad "round 3 not refused"

# Adapter output is a gate protocol, not best-effort parsing: duplicate
# findings collapse, and a clean marker may never coexist with a finding.
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
[ "$1" = "login" ] && exit 0
echo '{"severity":"medium","category":"duplicate","file":"docs/ARCHITECTURE.md","line":2,"summary":"same finding"}'
echo '{"severity":"medium","category":"duplicate","file":"docs/ARCHITECTURE.md","line":2,"summary":"same finding"}'
EOF
chmod +x "$STUB/codex"
printf 'prompt' > "$WORK/p.md"
OUT="$(PATH="$STUB:$PATH" bash scripts/review-with-codex.sh --prompt "$WORK/p.md" --timeout 10 2>/dev/null)"
[ "$(printf '%s\n' "$OUT" | grep -c '^{' || true)" -eq 1 ] \
  && ok "adapter deduplicates identical findings" || bad "adapter did not deduplicate findings"
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
[ "$1" = "login" ] && exit 0
echo '{"severity":"low","category":"review-clean","summary":"clean"}'
echo '{"severity":"medium","category":"contradiction","file":"docs/ARCHITECTURE.md","line":2,"summary":"not clean"}'
EOF
chmod +x "$STUB/codex"
PATH="$STUB:$PATH" bash scripts/review-with-codex.sh --prompt "$WORK/p.md" --timeout 10 >/dev/null 2>&1
[ $? -eq 1 ] && ok "adapter rejects review-clean plus findings" || bad "adapter accepted contradictory clean output"
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
[ "$1" = "login" ] && exit 0
echo 'bubblewrap: user namespaces unavailable'
echo '{"severity":"medium","category":"false-success","file":"docs/ARCHITECTURE.md","line":2,"summary":"must not pass"}'
EOF
chmod +x "$STUB/codex"
PATH="$STUB:$PATH" bash scripts/review-with-codex.sh --prompt "$WORK/p.md" --timeout 10 >/dev/null 2>&1
[ $? -eq 1 ] && ok "adapter rejects sandbox false-success output" || bad "adapter accepted sandbox false-success"
# opposite provider "unavailable": stub codex fails login (a bare rm would fall
# through to a REAL codex on PATH) -> model-opposite fallback
printf '#!/bin/sh\nexit 1\n' > "$STUB/codex"; chmod +x "$STUB/codex"
PATH="$STUB:$PATH" CLAUDE_REVIEW_MODEL=sonnet bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 2 >/dev/null 2>&1
DEG="$(jq -r '.cross_review[-1] | (.degraded_fallback|tostring) + ":" + .reviewer_model' specs/PROJ-96-stage2/state.json)"
[ "$DEG" = "true:sonnet" ] && ok "degraded: model-opposite fallback used and flagged in state" || bad "degraded record wrong: $DEG"
PATH="$STUB:$PATH" CLAUDE_REVIEW_MODEL=opus bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta >/dev/null 2>&1
[ $? -eq 1 ] && ok "reviewer model == author model refused (gate never same-model)" || bad "same-model review not refused"

# Claude's adapter must enforce the same protocol controls as Codex while
# consuming Claude Code's validated structured_output envelope.
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
echo '{"is_error":false,"structured_output":{"findings":[{"severity":"medium","category":"duplicate","file":"docs/ARCHITECTURE.md","line":2,"summary":"same finding"},{"severity":"medium","category":"duplicate","file":"docs/ARCHITECTURE.md","line":2,"summary":"same finding"}]}}'
EOF
chmod +x "$STUB/claude"
OUT="$(PATH="$STUB:$PATH" bash scripts/review-with-claude.sh --prompt "$WORK/p.md" --timeout 10 2>/dev/null)"
[ "$(printf '%s\n' "$OUT" | grep -c '^{' || true)" -eq 1 ] \
  && printf '%s\n' "$OUT" | jq -e 'select(.provider == "claude")' >/dev/null 2>&1 \
  && ok "Claude adapter parses structured output, stamps provider, and deduplicates" \
  || bad "Claude adapter structured-output normalization failed"
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
echo '{"is_error":false,"structured_output":{"findings":[{"severity":"low","category":"review-clean","summary":"clean"},{"severity":"medium","category":"contradiction","summary":"not clean"}]}}'
EOF
chmod +x "$STUB/claude"
PATH="$STUB:$PATH" bash scripts/review-with-claude.sh --prompt "$WORK/p.md" --timeout 10 >/dev/null 2>&1
[ $? -eq 1 ] && ok "Claude adapter rejects review-clean plus findings" || bad "Claude adapter accepted contradictory clean output"
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
echo '{"is_error":false,"result":"review-blocked: sandbox failed","structured_output":{"findings":[{"severity":"medium","category":"false-success","summary":"must not pass"}]}}'
EOF
chmod +x "$STUB/claude"
PATH="$STUB:$PATH" bash scripts/review-with-claude.sh --prompt "$WORK/p.md" --timeout 10 >/dev/null 2>&1
[ $? -eq 1 ] && ok "Claude adapter rejects infrastructure false-success output" || bad "Claude adapter accepted infrastructure false-success"
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
echo '{"is_error":true,"terminal_reason":"api_error","result":"Not logged in"}'
EOF
chmod +x "$STUB/claude"
PATH="$STUB:$PATH" bash scripts/review-with-claude.sh --prompt "$WORK/p.md" --timeout 10 >/dev/null 2>&1
[ $? -eq 1 ] && ok "Claude adapter rejects rc=0 API/auth error envelopes" || bad "Claude adapter accepted an API/auth error envelope"
truncate -s 10000001 "$WORK/over-claude-stdin-limit.md"
PATH="$STUB:$PATH" bash scripts/review-with-claude.sh --prompt "$WORK/over-claude-stdin-limit.md" --timeout 10 >"$WORK/claude-size.out" 2>&1
[ $? -eq 1 ] && grep -q 'stdin is limited to 10 MB' "$WORK/claude-size.out" \
  && ok "Claude adapter reports the provider's 10 MB stdin ceiling explicitly" \
  || bad "Claude adapter did not explain the provider stdin ceiling"

# adapter timeout kills the whole process group
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
sleep 300 &
sleep 300
EOF
chmod +x "$STUB/claude"
printf 'prompt' > "$WORK/p.md"
PATH="$STUB:$PATH" bash scripts/review-with-claude.sh --prompt "$WORK/p.md" --timeout 3 >/dev/null 2>&1
RC=$?
sleep 1
if [ "$RC" -ne 0 ] && ! pgrep -f "sleep 300" >/dev/null 2>&1; then
  ok "adapter timeout: exit != 0 and the whole process group is dead (no orphans)"
else
  bad "adapter timeout left survivors (rc=$RC)"; pkill -f "sleep 300" 2>/dev/null
fi

# degraded flag renders in the morning report
bash scripts/state.sh set 96 stage2 .degraded true >/dev/null
bash scripts/state.sh set 96 stage2 .degraded_reason '"codex unavailable at P7 (spike)"' >/dev/null
node "$SPIKE_DIR/render-report.mjs" morning specs >/dev/null 2>&1
grep -rq "cross-review: model-opposite fallback" specs/morning-report-*.md 2>/dev/null \
  && ok "degradation rendered in the morning report (cross-review: model-opposite fallback)" \
  || bad "morning report missing the degradation flag"
bash scripts/state.sh set 96 stage2 .degraded false >/dev/null

# =============================================================================
step "P7 runner gate (stubbed lanes seal P7:done)"
# =============================================================================
# advance the fixture state to P6:done so P7 is the legal next phase
for t in "CP1 running" "CP1 approved" "P0 running" "P0 done" "P5 running" "P5 done" "P6 running" "P6 done"; do
  bash scripts/state.sh transition 96 stage2 $t >/dev/null
done
# two writer stubs: one seals WITHOUT any cross-review evidence, one records
# a docs cross-review round (as the real documentation skill would) first
write_stub_writer() { # <with-evidence: 0|1>
  if [ "$1" -eq 1 ]; then
    cat > "$STUB/claude" <<'EOF'
#!/bin/sh
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null 2>&1
CUR="$(bash scripts/state.sh get 96 stage2 '.cross_review // []')"
UPD="$(printf '%s' "$CUR" | jq -c --arg at "$(date -Iseconds)" '. + [{mode:"docs",round:1,reviewer_provider:"codex",reviewer_model:"codex-default",degraded_fallback:false,findings_added:0,at:$at}]')"
bash scripts/state.sh set 96 stage2 .cross_review "$UPD" >/dev/null 2>&1
bash scripts/state.sh transition 96 stage2 P7 done >/dev/null 2>&1
exit 0
EOF
  else
    cat > "$STUB/claude" <<'EOF'
#!/bin/sh
# stub P7 writer: seals the phase without running any curation gate
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null 2>&1
bash scripts/state.sh transition 96 stage2 P7 done >/dev/null 2>&1
exit 0
EOF
  fi
  chmod +x "$STUB/claude"
}
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
case "$1" in login) exit 0 ;; esac
echo '{"source":"review","severity":"low","category":"note","summary":"stub peer note"}'
EOF
chmod +x "$STUB/codex"
mark_open_xr_fixed() {
  for id in $(jq -r '.findings[] | select(.status=="open" and (.source=="cross-review" or ((.sources // []) | index("cross-review")))) | .id' specs/PROJ-96-stage2/findings.json); do
    node scripts/ledger.mjs set-status 96 stage2 "$id" fixed deadbeef >/dev/null 2>&1
  done
}

# gate 1: caps red -> parked (checked before evidence and findings)
write_stub_writer 0
seq 1 31 > docs/PRODUCT.md
mark_open_xr_fixed
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7a.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
{ [ "$RC" -eq 1 ] && [ "$ST" = "P7:blocked" ] && grep -q "curation caps FAIL" "$WORK/p7a.out"; } \
  && ok "P7 sealed with failing caps -> runner parks the run (P7:blocked, form gate)" \
  || bad "caps gate: rc=$RC state=$ST"
git checkout -q docs/PRODUCT.md

# gate 2: caps green but NO cross-review ever ran -> parked (a skipped review
# must not look like a clean one)
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7b.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
{ [ "$RC" -eq 1 ] && [ "$ST" = "P7:blocked" ] && grep -q "NO docs cross-review" "$WORK/p7b.out"; } \
  && ok "P7 sealed with zero findings but NO review evidence -> runner parks (evidence gate)" \
  || bad "evidence gate: rc=$RC state=$ST"

# gate 3: evidence present, open Critical/High cross-review finding -> parked
write_stub_writer 1
printf '{"source":"cross-review","severity":"critical","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"provider":"codex","summary":"spike blocking finding"}\n' \
  | node scripts/ledger.mjs add 96 stage2 >/dev/null 2>&1
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7c.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
{ [ "$RC" -eq 1 ] && [ "$ST" = "P7:blocked" ] && grep -q "cross-review finding" "$WORK/p7c.out"; } \
  && ok "P7 sealed with an open Critical/High cross-review finding -> runner parks (truth gate)" \
  || bad "truth gate: rc=$RC state=$ST"

# gate 4: evidence + clean ledger + caps green -> phase completes
mark_open_xr_fixed
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7d.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
[ "$RC" -eq 0 ] && [ "$ST" = "P7:done" ] && ok "green gates + evidence -> P7 completes normally" || bad "green path: rc=$RC state=$ST"

# =============================================================================
if [ "$SKIP_LIVE" -eq 1 ]; then
  step "live adapter smoke SKIPPED (--skip-live)"
else
  step "live cross-review adapter smoke (real CLIs, planted factual error)"
  # docs/ARCHITECTURE.md claims backoff+DLQ; src/queue.js says the opposite.
  LIVE_PROMPT="$WORK/live-prompt.md"
  cat > "$LIVE_PROMPT" <<EOF
You are a read-only adversarial docs reviewer in a verification spike, in
the directory $FIX. Compare the following embedded files. Do not run commands
or modify anything.

## Artifact under review: docs/ARCHITECTURE.md
$(cat "$FIX/docs/ARCHITECTURE.md")

## Ground truth: src/queue.js
$(cat "$FIX/src/queue.js")

Your entire final answer must use the adapter's machine-readable findings
transport, with no prose or fences. When a validated schema is supplied,
populate its findings array; otherwise emit one JSON object per line:
{"source":"cross-review","severity":"high","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"..."}
If (and only if) everything is accurate: {"source":"cross-review","severity":"low","category":"review-clean","summary":"clean"}
EOF
  LIVE_TIMEOUT=300
  if command -v claude >/dev/null 2>&1; then
    OUT="$(bash scripts/review-with-claude.sh --prompt "$LIVE_PROMPT" --model "${CLAUDE_REVIEW_MODEL:-sonnet}" --timeout "$LIVE_TIMEOUT" 2>/dev/null)"
    N="$(grep -c '^{' <<<"$OUT" 2>/dev/null || true)"
    [ "${N:-0}" -ge 1 ] && ok "live claude adapter: $N valid JSON line(s) (codex-authored -> claude direction / model-opposite fallback)" \
                        || bad "live claude adapter produced no valid lines"
  else
    bad "claude CLI missing — cannot spike the hard provider"
  fi
  if command -v codex >/dev/null 2>&1 && codex login status >/dev/null 2>&1; then
    OUT="$(bash scripts/review-with-codex.sh --prompt "$LIVE_PROMPT" --timeout "$LIVE_TIMEOUT" 2>/dev/null)"
    N="$(grep -c '^{' <<<"$OUT" 2>/dev/null || true)"
    [ "${N:-0}" -ge 1 ] && ok "live codex adapter: $N valid JSON line(s) (claude-authored -> codex direction)" \
                        || bad "live codex adapter produced no valid lines"
  else
    step "codex unavailable — claude-authored->codex live direction not testable on this machine (degraded parity already proven above)"
  fi
fi

# =============================================================================
echo
if [ "$FAIL" -eq 0 ]; then
  echo "✓ STAGE 2 SPIKE PASSED ($PASS assertions$( [ "$SKIP_LIVE" -eq 1 ] && echo ", live skipped"))"
  exit 0
else
  echo "❌ STAGE 2 SPIKE FAILED — $FAIL failed, $PASS passed"
  exit 1
fi
