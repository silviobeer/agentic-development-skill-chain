#!/usr/bin/env bash
# run-phase.sh — host-neutral dual-lane phase runner (CONCEPT.md §5, §6b).
#
# Starts fresh Claude and Codex lanes for one phase of a PROJ run:
# concurrency of MODELS is the default, concurrency of WRITES is not —
# exactly one writer lane per phase, the other lane is a read-only peer.
# Handoff between phases happens ONLY via state.json + files on disk.
#
# P6 is SEQUENTIAL by design: the read-only QA finder runs first, its
# findings are ingested into the ledger, and only then does the P6
# controller lane start — so the controller can never seal the phase
# before the findings exist. The runner additionally refuses P6:done
# while the ledger still has open Critical/High findings.
#
# Degraded mode (§7): codex missing/unauthenticated does NOT stop the
# run — the peer/review role falls back to a DIFFERENT Claude model than
# the writer's (both models pinned explicitly and recorded in state.json;
# the runner refuses to start if writer and reviewer models are equal).
#
# Stop policy (§8): a failed or timed-out writer lane cancels its peer
# immediately and parks the run — rescue branch for uncommitted work,
# state -> blocked with the exact cause, rendered stop report. SIGINT/
# SIGTERM on the runner kill both lane process groups (no orphans).
#
# Usage:
#   run-phase.sh <P0|P5|P6|P7|P8> <proj-x> <theme> [--timeout S] [--writer claude|codex]
#   run-phase.sh auto <proj-x> <theme> [--timeout S]
#       advance phase by phase until P8:done or blocked, then render the
#       morning report + best-effort notification
#
# Env:  CLAUDE_WRITER_MODEL  claude writer model (default: opus)
#       CLAUDE_REVIEW_MODEL  model-opposite reviewer in degraded mode (default: sonnet)
#       PEER_GRACE           seconds a peer may keep running after the writer finished (default: 300)
# Exit: 0 phase(s) done · 1 stop condition (run parked) · 64 usage
set -euo pipefail

RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PHASE_ARG="${1:-}"; PROJ="${2:-}"; THEME="${3:-}"
if [ -z "$PHASE_ARG" ] || [ -z "$PROJ" ] || [ -z "$THEME" ]; then
  echo "Usage: $0 <P0|P5|P6|P7|P8|auto> <proj-x> <theme> [--timeout S] [--writer claude|codex]" >&2
  exit 64
fi
shift 3

TIMEOUT=3600
WRITER_PROVIDER="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    --writer)  WRITER_PROVIDER="${2:?}"; shift 2 ;;
    *) echo "run-phase.sh: unknown option $1" >&2; exit 64 ;;
  esac
done

BASE="specs/PROJ-${PROJ}-${THEME}"
LANE_DIR="$BASE/5_progress/lanes"
WRITER_MODEL="${CLAUDE_WRITER_MODEL:-opus}"
REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-sonnet}"
PEER_GRACE="${PEER_GRACE:-300}"
PHASES=(CP1 P0 P5 P6 P7 P8 done)

# Ponytail's unset matcher is its all-subagent path. Do not let a caller's
# narrow matcher silently drop generic implementation fallbacks.
unset PONYTAIL_SUBAGENT_MATCHER

# Pin the injector to THIS run's PROJ — without these the injector falls back
# to guessing the most recently modified specs/PROJ-* (wrong with parallel PROJs).
export SKILLCHAIN_PROJ="$PROJ" SKILLCHAIN_THEME="$THEME"

# Model-opposite is only real if the models actually differ (review fix #4).
if [ "$WRITER_MODEL" = "$REVIEW_MODEL" ]; then
  echo "run-phase.sh: CLAUDE_WRITER_MODEL and CLAUDE_REVIEW_MODEL are both '$WRITER_MODEL' — degraded review would be same-model. Refusing." >&2
  exit 64
fi

# state.sh: prefer the repo copy (4b_setup installs it), fall back to the skill tree
if [ -x scripts/state.sh ]; then
  STATE_SH="scripts/state.sh"
elif [ -x "$RUNNER_DIR/../claude/skills/4b_setup/scripts/state.sh" ]; then
  STATE_SH="$RUNNER_DIR/../claude/skills/4b_setup/scripts/state.sh"
else
  echo "run-phase.sh: state.sh not found (scripts/state.sh or skill tree)" >&2; exit 1
fi

LEDGER=""
[ -f scripts/ledger.mjs ] && LEDGER="scripts/ledger.mjs"
[ -z "$LEDGER" ] && [ -f "$RUNNER_DIR/../claude/skills/6_qa/scripts/ledger.mjs" ] && LEDGER="$RUNNER_DIR/../claude/skills/6_qa/scripts/ledger.mjs"

step() { echo "→ [$(date -Iseconds)] $*"; }
state_get() { "$STATE_SH" get "$PROJ" "$THEME" "$1"; }

phase_index() {
  local p="$1" i
  for i in "${!PHASES[@]}"; do [ "${PHASES[$i]}" = "$p" ] && { echo "$i"; return 0; }; done
  return 1
}

phase_skill() { # skill loaded by the writer lane
  case "$1" in
    P0) echo "setup (4b_setup)" ;;
    P5) echo "executing (5_executing)" ;;
    P6) echo "p6-controller" ;;
    P7) echo "documentation (7_documentation)" ;;
    P8) echo "delivery (8_delivery)" ;;
    *) return 1 ;;
  esac
}

peer_wanted() { # concurrent peer lane (P6 runs its finder SEQUENTIALLY instead)
  case "$1" in P5|P7) return 0 ;; *) return 1 ;; esac
}

codex_available() {
  command -v codex >/dev/null 2>&1 && codex login status >/dev/null 2>&1
}

kill_group() { # kill a lane's whole process group, TERM then KILL
  kill -TERM -- "-$1" 2>/dev/null || true
  sleep 2
  kill -KILL -- "-$1" 2>/dev/null || true
}

# Any signal to the runner must not orphan the setsid lane trees (review fix #5).
ACTIVE_PIDS=()
on_signal() {
  echo "run-phase.sh: interrupted — killing lane process groups" >&2
  local p
  for p in ${ACTIVE_PIDS[@]+"${ACTIVE_PIDS[@]}"}; do kill_group "$p"; done
  exit 130
}
trap on_signal INT TERM

record_lane() { # provider role model started ended exit outfile
  local lanes
  lanes="$(state_get .lanes)"
  lanes="$(jq -c --arg p "$1" --arg r "$2" --arg m "$3" --arg ph "$PHASE" --arg s "$4" --arg e "$5" \
              --argjson x "$6" --arg o "$7" \
              '. + [{provider:$p, role:$r, model:$m, phase:$ph, started_at:$s, ended_at:$e, exit_code:$x, output_file:$o}]' \
              <<<"$lanes")"
  "$STATE_SH" set "$PROJ" "$THEME" .lanes "$lanes" >/dev/null
}

render_prompt() { # role task_text out_var — writes prompt file, sets $out_var to its path
  local role="$1" task="$2" out_var="$3" rules out tpl
  out="$LANE_DIR/${PHASE}-${role}-prompt.md"
  if [ "$role" = "writer" ]; then
    rules="- You are the ONLY lane allowed to write files, run mutating commands, and commit. One writer per phase — never assume a second writer exists.
- Follow the skill's own workflow, including its wave gates and escalation rules."
  else
    rules="- You are STRICTLY READ-ONLY on the repository: never modify tracked files, never commit. Running tests/dev servers is allowed where your tools permit it.
- Produce independent review/prep input: risks, missing tests, weak ACs, factual errors.
- Output findings as JSON lines, one per line, nothing else in the final answer:
  {\"source\":\"review\",\"severity\":\"critical|high|medium|low\",\"category\":\"...\",\"summary\":\"...\",\"file\":\"...\",\"line\":N}
- The runner feeds your lines into the findings ledger; invalid lines are dropped."
  fi
  # Context bundles (Stage 2): P5/P7 writer lanes get a POINTER to the
  # compiled bundles — never the bundle text itself (the SubagentStart hook
  # injects it into Claude subagents; codex lanes read their projection file).
  local ctx=""
  if [ -f "$BASE/context/bundles.lock.json" ] && { [ "$PHASE" = "P5" ] || [ "$PHASE" = "P7" ]; } && [ "$role" = "writer" ]; then
    ctx="
## Context bundles

Compiled role bundles live in \`$BASE/context/\` (hashes in
\`bundles.lock.json\` — the canonical hash is identical for both
providers). Rules:
- Claude subagents receive their type-scoped bundle automatically via the
  SubagentStart hook — NEVER paste bundle contents into spawn prompts.
- A Codex lane reads \`$BASE/context/bundle-<role>.codex.md\` before
  implementing.
- Micro-fixer spawns receive NOTHING beyond the finding, file paths, and
  an optional agent.md pointer (tier 0).
- If a bundle is missing or stale, recompile via
  \`node scripts/compile-context-bundles.mjs compile $PROJ $THEME\` —
  do not hand-assemble context."
  fi
  tpl="$(cat "$RUNNER_DIR/prompts/lane-prompt.md.tmpl")"
  tpl="${tpl//'{{PROJ_NUMBER}}'/$PROJ}"
  tpl="${tpl//'{{PROJ}}'/PROJ-$PROJ}"
  tpl="${tpl//'{{THEME}}'/$THEME}"
  tpl="${tpl//'{{PHASE}}'/$PHASE}"
  tpl="${tpl//'{{ROLE}}'/$role}"
  tpl="${tpl//'{{TASK}}'/$task}"
  tpl="${tpl//'{{ROLE_RULES}}'/$rules}"
  tpl="${tpl//'{{CONTEXT_BUNDLES}}'/$ctx}"
  printf '%s\n' "$tpl" >"$out"
  printf -v "$out_var" '%s' "$out"
}

LANE_PID=""
LANE_MODEL=""
launch_lane() { # provider role promptfile outfile — sets LANE_PID/LANE_MODEL (main shell, so `wait` works)
  local provider="$1" role="$2" prompt="$3" out="$4"
  case "${provider}:${role}" in
    claude:writer)
      LANE_MODEL="$WRITER_MODEL"
      setsid claude -p "$(cat "$prompt")" --model "$WRITER_MODEL" \
        --dangerously-skip-permissions </dev/null >"$out" 2>&1 &
      ;;
    claude:peer)
      local tools="Read,Grep,Glob"
      [ "$PHASE" = "P6" ] && tools="Read,Grep,Glob,Bash"   # the QA finder must run tests/browser
      LANE_MODEL="$REVIEW_MODEL"    # pinned explicitly — never the writer's model (review fix #4)
      setsid claude -p "$(cat "$prompt")" --model "$LANE_MODEL" \
        --allowedTools "$tools" </dev/null >"$out" 2>&1 &
      ;;
    codex:writer)
      LANE_MODEL="codex-default"
      setsid codex exec --sandbox workspace-write "$(cat "$prompt")" </dev/null >"$out" 2>&1 &
      ;;
    codex:peer)
      LANE_MODEL="codex-default"
      setsid codex exec --sandbox read-only "$(cat "$prompt")" </dev/null >"$out" 2>&1 &
      ;;
    *) echo "run-phase.sh: unknown lane ${provider}:${role}" >&2; return 1 ;;
  esac
  LANE_PID=$!
  ACTIVE_PIDS+=("$LANE_PID")
}

# Wait for the writer up to $TIMEOUT. The peer is advisory: a failed or
# timed-out writer cancels the peer IMMEDIATELY (review fix #5); a finished
# writer gives the peer a bounded grace period, then cancels it.
WRITER_RC=0; PEER_RC=0; TIMED_OUT=0
wait_lanes() { # writer_pid [peer_pid]
  local wpid="$1" ppid="${2:-}" deadline=$((SECONDS + TIMEOUT))
  TIMED_OUT=0
  while kill -0 "$wpid" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      TIMED_OUT=1
      kill_group "$wpid"
      [ -n "$ppid" ] && kill_group "$ppid"
      break
    fi
    sleep 5
  done
  set +e; wait "$wpid" 2>/dev/null; WRITER_RC=$?; set -e
  if [ -n "$ppid" ]; then
    if [ "$TIMED_OUT" -eq 1 ] || [ "$WRITER_RC" -ne 0 ]; then
      kill_group "$ppid"
    else
      local grace=$((SECONDS + PEER_GRACE))
      while kill -0 "$ppid" 2>/dev/null; do
        if [ "$SECONDS" -ge "$grace" ]; then
          step "peer still running ${PEER_GRACE}s after the writer finished — cancelling (advisory lane)"
          kill_group "$ppid"
          break
        fi
        sleep 5
      done
    fi
    set +e; wait "$ppid" 2>/dev/null; PEER_RC=$?; set -e
  fi
  ACTIVE_PIDS=()
}

ingest_findings() { # outfile — peer/finder findings -> ledger (line-validated)
  local out="$1"
  [ -n "$LEDGER" ] && [ -f "$out" ] || return 0
  local valid_lines="" line v
  while IFS= read -r line; do
    v="$(jq -c 'select(type == "object" and .source? and .severity? and .summary?)' <<<"$line" 2>/dev/null || true)"
    [ -n "$v" ] && valid_lines+="$v"$'\n'
  done < <(grep '^{' "$out" 2>/dev/null || true)
  if [ -n "$valid_lines" ]; then
    printf '%s' "$valid_lines" | node "$LEDGER" add "$PROJ" "$THEME" || step "findings ingest failed (non-fatal)"
  else
    step "lane produced no valid finding lines (non-fatal)"
  fi
}

open_blocking_count() {
  if [ -z "$LEDGER" ] || [ ! -f "$BASE/findings.json" ]; then echo 0; return; fi
  node "$LEDGER" stats "$PROJ" "$THEME" 2>/dev/null | jq -r '.open_blocking // 0' || echo 0
}

# P7 gate helpers (Stage 2). Reading findings.json is legal — only WRITES
# must go through ledger.mjs.
open_cross_review_blocking() {
  if [ ! -f "$BASE/findings.json" ]; then echo 0; return; fi
  jq '[.findings[]
       | select(.status == "open")
       | select(.severity == "critical" or .severity == "high")
       | select(.source == "cross-review" or ((.sources // []) | index("cross-review")))
      ] | length' "$BASE/findings.json" 2>/dev/null || echo 0
}

curation_caps_path() { # repo copy first (4b_setup installs it), then skill tree
  if [ -f scripts/curation-caps.sh ]; then
    echo "scripts/curation-caps.sh"
  elif [ -f "$RUNNER_DIR/../claude/skills/7_documentation/scripts/curation-caps.sh" ]; then
    echo "$RUNNER_DIR/../claude/skills/7_documentation/scripts/curation-caps.sh"
  fi
}

quality_gate_proof_path() {
  local p
  for p in scripts/quality-gate-proof.sh "$RUNNER_DIR/../claude/skills/5_executing/scripts/quality-gate-proof.sh"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

stop_run() { # reason error_file
  local reason="$1" err="${2:-}"
  step "STOP CONDITION: $reason"
  local p
  for p in ${ACTIVE_PIDS[@]+"${ACTIVE_PIDS[@]}"}; do kill_group "$p"; done
  ACTIVE_PIDS=()
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    # Build the rescue commit through a TEMPORARY index so the working tree
    # is never touched — a checkout dance would delete the untracked
    # state.json/lane outputs the stop report still needs.
    local rescue tmpidx tree commit
    rescue="rescue/PROJ-${PROJ}-$(date +%Y%m%d-%H%M%S)"
    tmpidx="$(mktemp)"
    if GIT_INDEX_FILE="$tmpidx" git read-tree HEAD 2>/dev/null \
       && GIT_INDEX_FILE="$tmpidx" git add -A 2>/dev/null \
       && tree="$(GIT_INDEX_FILE="$tmpidx" git write-tree 2>/dev/null)" \
       && commit="$(git commit-tree "$tree" -p HEAD -m "rescue(PROJ-${PROJ}): parked by run-phase.sh — $reason" 2>/dev/null)" \
       && git branch "$rescue" "$commit" 2>/dev/null; then
      step "rescue branch: $rescue (working tree untouched)"
      rm -f "$tmpidx"
      "$STATE_SH" set "$PROJ" "$THEME" .stop "{\"reason\": $(jq -Rn --arg r "$reason" '$r'), \"at\": \"$(date -Iseconds)\", \"rescue_branch\": \"$rescue\"}" >/dev/null
    else
      rm -f "$tmpidx"
      step "WARNING: rescue branch creation failed — uncommitted work remains only in the working tree"
      "$STATE_SH" set "$PROJ" "$THEME" .stop "{\"reason\": $(jq -Rn --arg r "$reason" '$r'), \"at\": \"$(date -Iseconds)\"}" >/dev/null
    fi
  else
    "$STATE_SH" set "$PROJ" "$THEME" .stop "{\"reason\": $(jq -Rn --arg r "$reason" '$r'), \"at\": \"$(date -Iseconds)\"}" >/dev/null
  fi
  local cur_ph cur_st
  cur_ph="$("$STATE_SH" get "$PROJ" "$THEME" .phase 2>/dev/null || echo "$PHASE")"
  cur_st="$("$STATE_SH" get "$PROJ" "$THEME" .status 2>/dev/null || echo "?")"
  if ! "$STATE_SH" transition "$PROJ" "$THEME" "$cur_ph" blocked >/dev/null 2>&1; then
    step "WARNING: could not transition ${cur_ph}:${cur_st} -> blocked — state remains '${cur_st}'; the stop cause is recorded in .stop and the stop report. Do NOT trust '${cur_st}' for this phase."
  fi
  node "$RUNNER_DIR/render-report.mjs" stop "$PROJ" "$THEME" --reason "$reason" ${err:+--error-file "$err"} || true
  "$STATE_SH" set "$PROJ" "$THEME" .stop.report "$BASE/5_progress/stop-report.md" >/dev/null 2>&1 || true
  exit 1
}

check_precondition() { # sets SKIP_PHASE=1 when the phase is already done
  SKIP_PHASE=0
  local cur_phase cur_status ci ti
  cur_phase="$(state_get .phase)"; cur_status="$(state_get .status)"
  ci="$(phase_index "$cur_phase")"; ti="$(phase_index "$PHASE")"
  if [ "$ci" -eq "$ti" ]; then
    # plain `if` (not `[..] && {..}`): under set -e the failed test as the
    # function's last command would kill the runner when resuming a phase
    # that is already <phase>:running
    if [ "$cur_status" = "done" ]; then step "$PHASE already done — skipping"; SKIP_PHASE=1; fi
  elif [ "$ti" -eq $((ci + 1)) ]; then
    case "$cur_status" in done|approved) : ;; *) stop_run "phase $PHASE requested but state is ${cur_phase}:${cur_status}" ;; esac
  else
    stop_run "phase $PHASE requested but state is ${cur_phase}:${cur_status} (illegal jump)"
  fi
}

verify_sealed() { # writer must have sealed the phase
  local cur_phase cur_status
  cur_phase="$(state_get .phase)"; cur_status="$(state_get .status)"
  if [ "${cur_phase}:${cur_status}" != "${PHASE}:done" ]; then
    stop_run "$PHASE writer lane exited 0 but did not seal the phase (state is ${cur_phase}:${cur_status})" "$1"
  fi
}

setup_providers() {
  DEGRADED=false
  if ! codex_available; then
    DEGRADED=true
    "$STATE_SH" set "$PROJ" "$THEME" .degraded true >/dev/null
    "$STATE_SH" set "$PROJ" "$THEME" .degraded_reason "codex missing or unauthenticated at ${PHASE}" >/dev/null
    step "DEGRADED single-provider mode — writer model ${WRITER_MODEL}, model-opposite reviewer ${REVIEW_MODEL}"
    WRITER="claude"; PEER="claude"
  else
    WRITER="$WRITER_PROVIDER"
    if [ "$WRITER" = "claude" ]; then PEER="codex"; else PEER="claude"; fi
  fi
}

run_p6() {
  # Stage 1/2: read-only QA finder — SEQUENTIAL, before the controller,
  # so every finding is in the ledger before triage starts (review fix #1).
  local ts finder_out finder_prompt finder_pid finder_start tree_before tree_after
  ts="$(date +%Y%m%d-%H%M%S)"
  finder_out="$LANE_DIR/P6-${PEER}-finder-${ts}.out"
  render_prompt peer "Load and execute the QA skill qa (6_qa) READ-ONLY for specs/PROJ-${PROJ}-${THEME}: find bugs, do not fix anything. Also write every finding as a ledger record (node scripts/ledger.mjs add ${PROJ} ${THEME})." finder_prompt
  tree_before="$(git status --porcelain 2>/dev/null | sha1sum)"
  step "P6 finder lane (sequential, before controller): $PEER — output $finder_out"
  launch_lane "$PEER" peer "$finder_prompt" "$finder_out"
  finder_pid="$LANE_PID"; finder_start="$(date -Iseconds)"
  wait_lanes "$finder_pid"
  record_lane "$PEER" peer "$LANE_MODEL" "$finder_start" "$(date -Iseconds)" "$WRITER_RC" "$finder_out"
  [ "$TIMED_OUT" -eq 1 ] && stop_run "P6 finder timed out after ${TIMEOUT}s" "$finder_out"
  [ "$WRITER_RC" -ne 0 ] && stop_run "P6 finder lane ($PEER) exited $WRITER_RC — no QA verdict, cannot continue" "$finder_out"
  tree_after="$(git status --porcelain 2>/dev/null | sha1sum)"
  [ "$tree_before" = "$tree_after" ] || stop_run "P6 finder modified the working tree — finder must be read-only" "$finder_out"
  ingest_findings "$finder_out"

  # Stage 2/2: P6 controller — the only writer of this phase.
  local ctl_out ctl_prompt ctl_pid ctl_start task
  ctl_out="$LANE_DIR/P6-${WRITER}-controller-${ts}.out"
  task="$(cat "$RUNNER_DIR/prompts/p6-controller.md")

Substitute <X>=${PROJ} and <theme>=${THEME} in every command above."
  render_prompt writer "$task" ctl_prompt
  step "P6 controller lane: $WRITER — output $ctl_out"
  launch_lane "$WRITER" writer "$ctl_prompt" "$ctl_out"
  ctl_pid="$LANE_PID"; ctl_start="$(date -Iseconds)"
  wait_lanes "$ctl_pid"
  record_lane "$WRITER" writer "$LANE_MODEL" "$ctl_start" "$(date -Iseconds)" "$WRITER_RC" "$ctl_out"
  [ "$TIMED_OUT" -eq 1 ] && stop_run "P6 controller timed out after ${TIMEOUT}s" "$ctl_out"
  [ "$WRITER_RC" -ne 0 ] && stop_run "P6 controller lane ($WRITER) exited $WRITER_RC" "$ctl_out"
  verify_sealed "$ctl_out"

  # Hard exit rule (§8): P6:done is not accepted with open Critical/High.
  local blocking
  blocking="$(open_blocking_count)"
  [ "$blocking" = "0" ] || stop_run "P6 sealed done but ledger has ${blocking} open Critical/High finding(s)" "$ctl_out"
}

run_generic() {
  local skill ts writer_out peer_out writer_prompt peer_prompt writer_pid peer_pid=""
  skill="$(phase_skill "$PHASE")"
  ts="$(date +%Y%m%d-%H%M%S)"
  writer_out="$LANE_DIR/${PHASE}-${WRITER}-writer-${ts}.out"
  peer_out="$LANE_DIR/${PHASE}-${PEER}-peer-${ts}.out"

  render_prompt writer "Load and execute the skill ${skill} for specs/PROJ-${PROJ}-${THEME} end to end." writer_prompt
  step "$PHASE writer lane: $WRITER ($skill) — output $writer_out"
  launch_lane "$WRITER" writer "$writer_prompt" "$writer_out"
  writer_pid="$LANE_PID"
  local writer_model="$LANE_MODEL" peer_model=""
  local writer_start peer_start
  writer_start="$(date -Iseconds)"

  if peer_wanted "$PHASE"; then
    render_prompt peer "Independently review the ${PHASE} work of specs/PROJ-${PROJ}-${THEME} (peer of skill ${skill}): prepare test/risk input and flag defects." peer_prompt
    step "$PHASE peer lane: $PEER (read-only) — output $peer_out"
    launch_lane "$PEER" peer "$peer_prompt" "$peer_out"
    peer_pid="$LANE_PID"; peer_model="$LANE_MODEL"
    peer_start="$(date -Iseconds)"
  fi

  wait_lanes "$writer_pid" ${peer_pid:+"$peer_pid"}

  record_lane "$WRITER" writer "$writer_model" "$writer_start" "$(date -Iseconds)" "$WRITER_RC" "$writer_out"
  if [ -n "$peer_pid" ]; then
    record_lane "$PEER" peer "$peer_model" "$peer_start" "$(date -Iseconds)" "$PEER_RC" "$peer_out"
    ingest_findings "$peer_out"
    [ "$PEER_RC" -ne 0 ] && step "peer lane ($PEER) exited $PEER_RC — advisory only, continuing (logged in state.json)"
  fi

  [ "$TIMED_OUT" -eq 1 ] && stop_run "$PHASE writer timed out after ${TIMEOUT}s (peer cancelled)" "$writer_out"
  [ "$WRITER_RC" -ne 0 ] && stop_run "$PHASE writer lane ($WRITER) exited $WRITER_RC (peer cancelled)" "$writer_out"
  verify_sealed "$writer_out"

  # Re-run the evidence checker outside the writer lane: a prose checklist
  # cannot make a skipped Quality Gate look clean.
  if [ "$PHASE" = "P5" ]; then
    local quality_proof
    quality_proof="$(quality_gate_proof_path || true)"
    [ -n "$quality_proof" ] || stop_run "P5 sealed done but quality-gate-proof.sh is missing — cannot verify Quality Gate evidence" "$writer_out"
    bash "$quality_proof" "$PROJ" "$THEME" >/dev/null 2>&1 || stop_run "P5 sealed done but Quality Gate proof is missing or invalid (run scripts/quality-gate-proof.sh for details)" "$writer_out"
  fi

  # Hard exit rule (§8, Stage 2): P7:done is not accepted while a curation
  # gate is red — independent re-verification, mirror of the P6 gate. The
  # writer runs curation-caps.sh + cross-review.sh itself; sealing past a
  # red gate parks the run here. Zero findings alone is NOT enough: the
  # truth gate demands EVIDENCE that a docs cross-review actually ran
  # during this P7 — otherwise a skipped review looks identical to a
  # clean one.
  if [ "$PHASE" = "P7" ]; then
    local caps xr_blocking p7_started xr_evidence
    caps="$(curation_caps_path)"
    [ -n "$caps" ] || stop_run "P7 sealed done but curation-caps.sh is missing (repo and skill tree) — the form gate cannot be verified, refusing to advance" "$writer_out"
    bash "$caps" >/dev/null 2>&1 || stop_run "P7 sealed done but curation caps FAIL (form gate red — run 'bash $caps' for the report)" "$writer_out"
    p7_started="$(jq -r '[.history[]? | select(.to == "P7:running")] | last | .at // ""' "$BASE/state.json" 2>/dev/null || echo "")"
    xr_evidence="$(jq --arg t "$p7_started" \
      '[.cross_review[]? | select(.mode == "docs" and (.at // "") >= $t)] | length' \
      "$BASE/state.json" 2>/dev/null || echo 0)"
    [ "${xr_evidence:-0}" -ge 1 ] || stop_run "P7 sealed done but NO docs cross-review ran during this P7 (no .cross_review record since ${p7_started:-phase start}) — truth gate has no evidence" "$writer_out"
    xr_blocking="$(open_cross_review_blocking)"
    [ "$xr_blocking" = "0" ] || stop_run "P7 sealed done but ledger has ${xr_blocking} open Critical/High cross-review finding(s) (truth gate red)" "$writer_out"
  fi
}

run_one_phase() {
  PHASE="$1"
  phase_skill "$PHASE" >/dev/null || { echo "run-phase.sh: phase $PHASE not runnable (use P0/P5/P6/P7/P8)" >&2; exit 64; }
  mkdir -p "$LANE_DIR"
  check_precondition
  [ "$SKIP_PHASE" -eq 1 ] && return 0
  setup_providers
  if [ "$PHASE" = "P6" ]; then run_p6; else run_generic; fi
  step "$PHASE done"
}

if [ "$PHASE_ARG" = "auto" ]; then
  for ph in P0 P5 P6 P7 P8; do
    cur_phase="$(state_get .phase)"; cur_status="$(state_get .status)"
    ci="$(phase_index "$cur_phase")"; ti="$(phase_index "$ph")"
    [ "$ti" -lt "$ci" ] && continue                       # already past it
    [ "$ti" -eq "$ci" ] && [ "$cur_status" = "done" ] && continue
    run_one_phase "$ph"
  done
  step "run complete — rendering morning report"
  ONELINER="$(node "$RUNNER_DIR/render-report.mjs" morning specs | head -n 1)"
  command -v notify-send >/dev/null 2>&1 && notify-send "SkillChain run" "$ONELINER" || true
  echo "$ONELINER"
else
  run_one_phase "$PHASE_ARG"
fi
