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
#   cross-review       — deterministic routing via PATH-shimmed CLIs (opposite
#                        provider, ledger attribution, round cap, same-model refusal),
#                        adapter process-group kill on timeout,
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
mkdir -p "$FIX"/{docs,src/feature,scripts,templates/roles,specs/PROJ-96-stage2/3_PRDs,specs/PROJ-96-stage2/7_progress}
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
printf '# PRD\nNEVER-INJECT-MARKER-PRD full requirement text.\n' > specs/PROJ-96-stage2/3_PRDs/PROJ-96-PRD-1.md
printf '# Progress\nNEVER-INJECT-MARKER-PROGRESS wave log.\n' > specs/PROJ-96-stage2/7_progress/PROJ-96-progress.md
printf '## Wave 1 — queue API\nPOST /enqueue\n' > specs/PROJ-96-stage2/api-contracts.md
printf '# Ground file\nAssumption: node 22.\n' > specs/PROJ-96-stage2/ground-file.md

for s in 4b_setup/scripts/state.sh 4b_setup/scripts/compile-context-bundles.mjs \
         4b_setup/scripts/context-injector.mjs 4b_setup/scripts/ponytail-check.sh \
         6_qa/scripts/ledger.mjs 7_documentation/scripts/curation-caps.sh \
         0b_intake/scripts/intake-seal-check.sh \
         3a_cross-review/scripts/cross-review.sh 3a_cross-review/scripts/review-with-claude.sh \
         3a_cross-review/scripts/review-with-codex.sh; do
  cp "$SKILLS/$s" scripts/
done
mkdir -p templates
cp "$SKILLS/3a_cross-review/templates/cross-review-prompt.md.tmpl" templates/
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
        PONYTAIL_SUBAGENT_MATCHER='implementer|frontend-implementer|backend-implementer|micro-fixer' \
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

# =============================================================================
step "cross-review mechanics (PATH-shimmed CLIs, deterministic)"
# =============================================================================
STUB="$WORK/stub"; mkdir -p "$STUB"
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
echo '{"severity":"high","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub claude finding"}'
EOF
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
[ "$1" = "login" ] && exit 0
echo '{"severity":"medium","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"stub codex finding"}'
EOF
chmod +x "$STUB/claude" "$STUB/codex"
bash scripts/state.sh set 96 stage2 .authorship '{"docs-delta":{"author_provider":"claude","author_model":"opus"}}' >/dev/null
PATH="$STUB:$PATH" bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 1 >/dev/null 2>&1
RC=$?
XRP="$(jq -r '.cross_review[-1].reviewer_provider' specs/PROJ-96-stage2/state.json 2>/dev/null)"
[ "$RC" -eq 0 ] && [ "$XRP" = "codex" ] && ok "claude-authored -> codex reviews; round recorded in state" || bad "routing rc=$RC reviewer=$XRP"
LED="$(jq -r '[.findings[] | select((.source == "cross-review") and .provider == "codex")] | length' specs/PROJ-96-stage2/findings.json 2>/dev/null)"
[ "${LED:-0}" -ge 1 ] && ok "finding landed in the ledger: source=cross-review, provider attributed" || bad "ledger has no attributed cross-review finding"
PATH="$STUB:$PATH" bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 3 >/dev/null 2>&1
[ $? -eq 64 ] && ok "round 3 refused (max 2 rounds, then §8)" || bad "round 3 not refused"
# opposite provider "unavailable": stub codex fails login (a bare rm would fall
# through to a REAL codex on PATH) -> model-opposite fallback
printf '#!/bin/sh\nexit 1\n' > "$STUB/codex"; chmod +x "$STUB/codex"
PATH="$STUB:$PATH" CLAUDE_REVIEW_MODEL=sonnet bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta --round 2 >/dev/null 2>&1
DEG="$(jq -r '.cross_review[-1] | (.degraded_fallback|tostring) + ":" + .reviewer_model' specs/PROJ-96-stage2/state.json)"
[ "$DEG" = "true:sonnet" ] && ok "degraded: model-opposite fallback used and flagged in state" || bad "degraded record wrong: $DEG"
PATH="$STUB:$PATH" CLAUDE_REVIEW_MODEL=opus bash scripts/cross-review.sh docs 96 stage2 --artifacts docs/ARCHITECTURE.md --author-key docs-delta >/dev/null 2>&1
[ $? -eq 1 ] && ok "reviewer model == author model refused (gate never same-model)" || bad "same-model review not refused"

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
cat > "$STUB/claude" <<'EOF'
#!/bin/sh
# stub P7 writer: seals the phase without running the curation gates
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null 2>&1
bash scripts/state.sh transition 96 stage2 P7 done >/dev/null 2>&1
exit 0
EOF
cat > "$STUB/codex" <<'EOF'
#!/bin/sh
case "$1" in login) exit 0 ;; esac
echo '{"source":"review","severity":"low","category":"note","summary":"stub peer note"}'
EOF
chmod +x "$STUB/claude" "$STUB/codex"
mark_open_xr_fixed() {
  for id in $(jq -r '.findings[] | select(.status=="open" and (.source=="cross-review" or ((.sources // []) | index("cross-review")))) | .id' specs/PROJ-96-stage2/findings.json); do
    node scripts/ledger.mjs set-status 96 stage2 "$id" fixed deadbeef >/dev/null 2>&1
  done
}

# gate 1: caps red -> parked
seq 1 31 > docs/PRODUCT.md
mark_open_xr_fixed
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7a.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
{ [ "$RC" -eq 1 ] && [ "$ST" = "P7:blocked" ] && grep -q "curation caps FAIL" "$WORK/p7a.out"; } \
  && ok "P7 sealed with failing caps -> runner parks the run (P7:blocked, form gate)" \
  || bad "caps gate: rc=$RC state=$ST"
git checkout -q docs/PRODUCT.md

# gate 2: caps green, open Critical/High cross-review finding -> parked
printf '{"source":"cross-review","severity":"critical","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"provider":"codex","summary":"spike blocking finding"}\n' \
  | node scripts/ledger.mjs add 96 stage2 >/dev/null 2>&1
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7b.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
{ [ "$RC" -eq 1 ] && [ "$ST" = "P7:blocked" ] && grep -q "cross-review finding" "$WORK/p7b.out"; } \
  && ok "P7 sealed with an open Critical/High cross-review finding -> runner parks (truth gate)" \
  || bad "truth gate: rc=$RC state=$ST"

# gate 3: both gates green -> phase completes
mark_open_xr_fixed
bash scripts/state.sh transition 96 stage2 P7 running >/dev/null
PATH="$STUB:$PATH" timeout --foreground 120 "$SPIKE_DIR/run-phase.sh" P7 96 stage2 --timeout 60 >"$WORK/p7c.out" 2>&1
RC=$?
ST="$(bash scripts/state.sh get 96 stage2 '.phase + ":" + .status')"
[ "$RC" -eq 0 ] && [ "$ST" = "P7:done" ] && ok "green gates -> P7 completes normally" || bad "green path: rc=$RC state=$ST"

# =============================================================================
if [ "$SKIP_LIVE" -eq 1 ]; then
  step "live adapter smoke SKIPPED (--skip-live)"
else
  step "live cross-review adapter smoke (real CLIs, planted factual error)"
  # docs/ARCHITECTURE.md claims backoff+DLQ; src/queue.js says the opposite.
  LIVE_PROMPT="$WORK/live-prompt.md"
  cat > "$LIVE_PROMPT" <<EOF
You are a read-only adversarial docs reviewer in a verification spike, in
the directory $FIX. Compare the claim in docs/ARCHITECTURE.md about
src/queue.js with the actual content of src/queue.js. Do not modify anything.
Your ENTIRE final answer must be findings as JSON lines — one object per
line, no prose, no fences:
{"source":"cross-review","severity":"high","category":"stale-claim","file":"docs/ARCHITECTURE.md","line":2,"summary":"..."}
If (and only if) everything is accurate: {"source":"cross-review","severity":"low","category":"review-clean","summary":"clean"}
EOF
  LIVE_TIMEOUT=300
  if command -v claude >/dev/null 2>&1; then
    OUT="$(bash scripts/review-with-claude.sh --prompt "$LIVE_PROMPT" --model "${CLAUDE_REVIEW_MODEL:-sonnet}" --timeout "$LIVE_TIMEOUT" 2>/dev/null)"
    N="$(grep -c '^{' <<<"$OUT" 2>/dev/null || echo 0)"
    [ "${N:-0}" -ge 1 ] && ok "live claude adapter: $N valid JSON line(s) (codex-authored -> claude direction / model-opposite fallback)" \
                        || bad "live claude adapter produced no valid lines"
  else
    bad "claude CLI missing — cannot spike the hard provider"
  fi
  if command -v codex >/dev/null 2>&1 && codex login status >/dev/null 2>&1; then
    OUT="$(bash scripts/review-with-codex.sh --prompt "$LIVE_PROMPT" --timeout "$LIVE_TIMEOUT" 2>/dev/null)"
    N="$(grep -c '^{' <<<"$OUT" 2>/dev/null || echo 0)"
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
