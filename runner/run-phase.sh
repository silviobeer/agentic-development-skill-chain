#!/usr/bin/env bash
# run-phase.sh — host-neutral dual-lane phase runner (CONCEPT.md §5, §6b).
#
# Starts fresh Claude and Codex lanes for one phase of a PROJ run:
# concurrency of MODELS is the default, concurrency of WRITES is not —
# exactly one writer lane per phase, the other lane is a read-only peer.
# Handoff between phases happens ONLY via state.json + files on disk.
#
# Degraded mode (§7): codex missing/unauthenticated does NOT stop the
# run — the peer/review role falls back to a DIFFERENT Claude model
# (model-opposite, default sonnet), recorded in state.json, never silent.
#
# Stop policy (§8): a failed writer lane parks the run — rescue branch
# for uncommitted work, state -> blocked with the exact cause, rendered
# stop report. Nothing is simply aborted.
#
# Usage:
#   run-phase.sh <P0|P5|P6|P7|P8> <proj-x> <theme> [--timeout S] [--writer claude|codex]
#   run-phase.sh auto <proj-x> <theme> [--timeout S]
#       advance phase by phase until P8:done or blocked, then render the
#       morning report + best-effort notification
#
# Env:  CLAUDE_REVIEW_MODEL  model-opposite reviewer in degraded mode (default: sonnet)
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
LANE_DIR="$BASE/7_progress/lanes"
REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-sonnet}"
PHASES=(CP1 P0 P5 P6 P7 P8 done)

# state.sh: prefer the repo copy (4b_setup installs it), fall back to the skill tree
if [ -x scripts/state.sh ]; then
  STATE_SH="scripts/state.sh"
elif [ -x "$RUNNER_DIR/../claude/skills/4b_setup/scripts/state.sh" ]; then
  STATE_SH="$RUNNER_DIR/../claude/skills/4b_setup/scripts/state.sh"
else
  echo "run-phase.sh: state.sh not found (scripts/state.sh or skill tree)" >&2; exit 1
fi

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

peer_wanted() { # peer lane only where independent review/prep adds value
  case "$1" in P5|P6|P7) return 0 ;; *) return 1 ;; esac
}

codex_available() {
  command -v codex >/dev/null 2>&1 && codex login status >/dev/null 2>&1
}

record_lane() { # provider role started ended exit outfile
  local lanes
  lanes="$(state_get .lanes)"
  lanes="$(jq -c --arg p "$1" --arg r "$2" --arg ph "$PHASE" --arg s "$3" --arg e "$4" \
              --argjson x "$5" --arg o "$6" \
              '. + [{provider:$p, role:$r, phase:$ph, started_at:$s, ended_at:$e, exit_code:$x, output_file:$o}]' \
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
    rules="- You are STRICTLY READ-ONLY: no file writes, no mutating commands, no commits — enforced by your tool sandbox.
- Produce independent review/prep input: risks, missing tests, weak ACs, factual errors.
- Output findings as JSON lines, one per line, nothing else in the final answer:
  {\"source\":\"review\",\"severity\":\"critical|high|medium|low\",\"category\":\"...\",\"summary\":\"...\",\"file\":\"...\",\"line\":N}
- The runner feeds your lines into the findings ledger; invalid lines are dropped."
  fi
  tpl="$(cat "$RUNNER_DIR/prompts/lane-prompt.md.tmpl")"
  tpl="${tpl//'{{PROJ_NUMBER}}'/$PROJ}"
  tpl="${tpl//'{{PROJ}}'/PROJ-$PROJ}"
  tpl="${tpl//'{{THEME}}'/$THEME}"
  tpl="${tpl//'{{PHASE}}'/$PHASE}"
  tpl="${tpl//'{{ROLE}}'/$role}"
  tpl="${tpl//'{{TASK}}'/$task}"
  tpl="${tpl//'{{ROLE_RULES}}'/$rules}"
  printf '%s\n' "$tpl" >"$out"
  printf -v "$out_var" '%s' "$out"
}

LANE_PID=""
launch_lane() { # provider role promptfile outfile — sets LANE_PID (must run in the main shell so `wait` works)
  local provider="$1" role="$2" prompt="$3" out="$4"
  case "${provider}:${role}" in
    claude:writer)
      setsid claude -p "$(cat "$prompt")" --dangerously-skip-permissions </dev/null >"$out" 2>&1 &
      ;;
    claude:peer)
      local model_args=()
      [ "$DEGRADED" = true ] && model_args=(--model "$REVIEW_MODEL")
      setsid claude -p "$(cat "$prompt")" ${model_args[@]+"${model_args[@]}"} \
        --allowedTools "Read,Grep,Glob" </dev/null >"$out" 2>&1 &
      ;;
    codex:writer)
      setsid codex exec --sandbox workspace-write "$(cat "$prompt")" </dev/null >"$out" 2>&1 &
      ;;
    codex:peer)
      setsid codex exec --sandbox read-only "$(cat "$prompt")" </dev/null >"$out" 2>&1 &
      ;;
    *) echo "run-phase.sh: unknown lane ${provider}:${role}" >&2; return 1 ;;
  esac
  LANE_PID=$!
}

wait_with_timeout() { # pid... — waits up to $TIMEOUT, kills whole process groups on expiry
  local deadline=$((SECONDS + TIMEOUT)) pid alive
  while :; do
    alive=0
    for pid in "$@"; do kill -0 "$pid" 2>/dev/null && alive=1; done
    [ "$alive" -eq 0 ] && return 0
    if [ "$SECONDS" -ge "$deadline" ]; then
      for pid in "$@"; do kill -TERM -- "-$pid" 2>/dev/null || true; done
      sleep 3
      for pid in "$@"; do kill -KILL -- "-$pid" 2>/dev/null || true; done
      return 124
    fi
    sleep 5
  done
}

stop_run() { # reason error_file
  local reason="$1" err="${2:-}"
  step "STOP CONDITION: $reason"
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    local cur rescue
    cur="$(git branch --show-current)"
    rescue="rescue/PROJ-${PROJ}-$(date +%Y%m%d-%H%M%S)"
    git checkout -b "$rescue" >/dev/null 2>&1
    git add -A && git commit -m "rescue(PROJ-${PROJ}): parked by run-phase.sh — $reason" >/dev/null
    git checkout "$cur" >/dev/null 2>&1
    "$STATE_SH" set "$PROJ" "$THEME" .stop "{\"reason\": $(jq -Rn --arg r "$reason" '$r'), \"at\": \"$(date -Iseconds)\", \"rescue_branch\": \"$rescue\"}" >/dev/null
    step "rescue branch: $rescue"
  else
    "$STATE_SH" set "$PROJ" "$THEME" .stop "{\"reason\": $(jq -Rn --arg r "$reason" '$r'), \"at\": \"$(date -Iseconds)\"}" >/dev/null
  fi
  local cur_ph
  cur_ph="$("$STATE_SH" get "$PROJ" "$THEME" .phase 2>/dev/null || echo "$PHASE")"
  "$STATE_SH" transition "$PROJ" "$THEME" "$cur_ph" blocked >/dev/null 2>&1 || true
  node "$RUNNER_DIR/render-report.mjs" stop "$PROJ" "$THEME" --reason "$reason" ${err:+--error-file "$err"} || true
  "$STATE_SH" set "$PROJ" "$THEME" .stop.report "$BASE/7_progress/stop-report.md" >/dev/null 2>&1 || true
  exit 1
}

run_one_phase() {
  PHASE="$1"
  phase_skill "$PHASE" >/dev/null || { echo "run-phase.sh: phase $PHASE not runnable (use P0/P5/P6/P7/P8)" >&2; exit 64; }
  mkdir -p "$LANE_DIR"

  # Precondition: current phase resumable, or immediately previous phase sealed
  local cur_phase cur_status ci ti
  cur_phase="$(state_get .phase)"; cur_status="$(state_get .status)"
  ci="$(phase_index "$cur_phase")"; ti="$(phase_index "$PHASE")"
  if [ "$ci" -eq "$ti" ]; then
    [ "$cur_status" = "done" ] && { step "$PHASE already done — skipping"; return 0; }
  elif [ "$ti" -eq $((ci + 1)) ]; then
    case "$cur_status" in done|approved) : ;; *) stop_run "phase $PHASE requested but state is ${cur_phase}:${cur_status}" ;; esac
  else
    stop_run "phase $PHASE requested but state is ${cur_phase}:${cur_status} (illegal jump)"
  fi

  # Providers
  DEGRADED=false
  if ! codex_available; then
    DEGRADED=true
    "$STATE_SH" set "$PROJ" "$THEME" .degraded true >/dev/null
    "$STATE_SH" set "$PROJ" "$THEME" .degraded_reason "codex missing or unauthenticated at ${PHASE}" >/dev/null
    step "DEGRADED single-provider mode — peer/review lanes fall back to claude --model ${REVIEW_MODEL}"
    WRITER="claude"
    PEER="claude"
  else
    WRITER="$WRITER_PROVIDER"
    if [ "$WRITER" = "claude" ]; then PEER="codex"; else PEER="claude"; fi
  fi

  local skill ts writer_out peer_out writer_prompt peer_prompt writer_pid peer_pid=""
  skill="$(phase_skill "$PHASE")"
  ts="$(date +%Y%m%d-%H%M%S)"
  writer_out="$LANE_DIR/${PHASE}-${WRITER}-writer-${ts}.out"
  peer_out="$LANE_DIR/${PHASE}-${PEER}-peer-${ts}.out"

  local task_writer
  if [ "$PHASE" = "P6" ]; then
    task_writer="$(cat "$RUNNER_DIR/prompts/p6-controller.md")

Substitute <X>=${PROJ} and <theme>=${THEME} in every command above."
  else
    task_writer="Load and execute the skill ${skill} for specs/PROJ-${PROJ}-${THEME} end to end."
  fi

  render_prompt writer "$task_writer" writer_prompt
  step "$PHASE writer lane: $WRITER ($skill) — output $writer_out"
  launch_lane "$WRITER" writer "$writer_prompt" "$writer_out"
  writer_pid="$LANE_PID"
  local writer_start peer_start
  writer_start="$(date -Iseconds)"

  if peer_wanted "$PHASE"; then
    local task_peer
    if [ "$PHASE" = "P6" ]; then
      task_peer="Load and execute the QA skill qa (6_qa) READ-ONLY for specs/PROJ-${PROJ}-${THEME}: find bugs, do not fix anything."
    else
      task_peer="Independently review the ${PHASE} work of specs/PROJ-${PROJ}-${THEME} (peer of skill ${skill}): prepare test/risk input and flag defects."
    fi
    render_prompt peer "$task_peer" peer_prompt
    step "$PHASE peer lane: $PEER (read-only) — output $peer_out"
    launch_lane "$PEER" peer "$peer_prompt" "$peer_out"
    peer_pid="$LANE_PID"
    peer_start="$(date -Iseconds)"
  fi

  set +e
  wait_with_timeout $writer_pid ${peer_pid:+$peer_pid}
  timed_out=$?
  wait "$writer_pid" 2>/dev/null; writer_rc=$?
  peer_rc=0
  [ -n "$peer_pid" ] && { wait "$peer_pid" 2>/dev/null; peer_rc=$?; }
  set -e

  record_lane "$WRITER" writer "$writer_start" "$(date -Iseconds)" "$writer_rc" "$writer_out"
  [ -n "$peer_pid" ] && record_lane "$PEER" peer "$peer_start" "$(date -Iseconds)" "$peer_rc" "$peer_out"

  # Peer findings -> ledger (best effort; invalid lines dropped)
  if [ -n "$peer_pid" ] && [ -f "$peer_out" ]; then
    local ledger=""
    [ -f scripts/ledger.mjs ] && ledger="scripts/ledger.mjs"
    [ -z "$ledger" ] && [ -f "$RUNNER_DIR/../claude/skills/6_qa/scripts/ledger.mjs" ] && ledger="$RUNNER_DIR/../claude/skills/6_qa/scripts/ledger.mjs"
    if [ -n "$ledger" ]; then
      # validate line by line so one malformed line cannot poison the batch
      local valid_lines=""
      while IFS= read -r line; do
        v="$(jq -c 'select(type == "object" and .source? and .severity? and .summary?)' <<<"$line" 2>/dev/null || true)"
        [ -n "$v" ] && valid_lines+="$v"$'\n'
      done < <(grep '^{' "$peer_out" 2>/dev/null || true)
      if [ -n "$valid_lines" ]; then
        printf '%s' "$valid_lines" | node "$ledger" add "$PROJ" "$THEME" || step "peer findings ingest failed (non-fatal)"
      else
        step "peer produced no valid finding lines (non-fatal)"
      fi
    fi
  fi

  [ "$timed_out" -eq 124 ] && stop_run "$PHASE timed out after ${TIMEOUT}s (both lanes killed)" "$writer_out"
  [ "$writer_rc" -ne 0 ] && stop_run "$PHASE writer lane ($WRITER) exited $writer_rc" "$writer_out"
  [ "$peer_rc" -ne 0 ] && step "peer lane ($PEER) exited $peer_rc — advisory only, continuing (logged in state.json)"

  # The writer lane seals the phase; verify it did.
  cur_phase="$(state_get .phase)"; cur_status="$(state_get .status)"
  if [ "${cur_phase}:${cur_status}" != "${PHASE}:done" ]; then
    stop_run "$PHASE writer lane exited 0 but did not seal the phase (state is ${cur_phase}:${cur_status})" "$writer_out"
  fi
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
