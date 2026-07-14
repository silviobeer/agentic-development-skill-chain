#!/usr/bin/env bash
# state.sh — the SOLE write path to specs/PROJ-<X>-<theme>/state.json.
#
# state.json is the machine-readable state machine of a PROJ run
# (CONCEPT.md §5); progress.md stays the human-readable view. Agents and
# scripts never edit state.json with ad-hoc jq — every read/write goes
# through this helper so writes are validated and transitions stay legal.
#
# Usage:
#   state.sh init       <proj-x> <theme>                  create minimal state.json (phase CP1, pending); idempotent
#   state.sh get        <proj-x> <theme> <jq-path>        print a value, e.g. state.sh get 3 payments .phase
#   state.sh set        <proj-x> <theme> <jq-path> <json> set a value (JSON or bare string); .phase/.status refused — use transition
#   state.sh transition <proj-x> <theme> <phase> <status> legal phase/status transition; appends to .history
#   state.sh show       <proj-x> <theme>                  pretty-print the whole state
#
# Phases:  CP1 -> P0 -> P5 -> P6 -> P7 -> P8 -> done
# Status:  pending -> running -> done|approved|blocked; blocked -> running (resume)
#          'approved' is legal only in CP1. Next phase opens only from done/approved.
#
# Exit codes:
#   0  ok
#   1  validation failed / illegal transition (nothing written)
#   2  state.json missing (run 'state.sh init' — owned by 4a_checkpoint at CP1)
#   64 usage error
set -euo pipefail

PHASES=(CP1 P0 P5 P6 P7 P8 done)

usage() {
  cat >&2 <<'EOF'
Usage:
  state.sh init       <proj-x> <theme>
  state.sh get        <proj-x> <theme> <jq-path>
  state.sh set        <proj-x> <theme> <jq-path> <json-value>
  state.sh transition <proj-x> <theme> <phase> <status>
  state.sh show       <proj-x> <theme>
Phases: CP1 P0 P5 P6 P7 P8 done · Status: pending running approved blocked done
Exit: 0 ok · 1 invalid/illegal · 2 state.json missing · 64 usage
EOF
  exit 64
}

[ $# -ge 3 ] || usage
CMD="$1"; PROJ="$2"; THEME="$3"; shift 3

BASE="specs/PROJ-${PROJ}-${THEME}"
STATE="${BASE}/state.json"
NOW="$(date -Iseconds)"

fail() { echo "state.sh: $*" >&2; exit 1; }

phase_index() {
  local p="$1" i
  for i in "${!PHASES[@]}"; do
    [ "${PHASES[$i]}" = "$p" ] && { echo "$i"; return 0; }
  done
  return 1
}

validate() {
  jq -e '
    . as $s
    | ($s | type == "object")
    and ($s | has("proj") and has("theme") and has("phase") and has("status") and has("updated_at"))
    and ($s.proj | type == "string" and test("^PROJ-[0-9]+$"))
    and (["CP1","P0","P5","P6","P7","P8","done"] | index($s.phase) != null)
    and (["pending","running","approved","blocked","done"] | index($s.status) != null)
    and (($s.status != "approved") or ($s.phase == "CP1"))
  ' "$1" >/dev/null 2>&1
}

# Atomic, validated write: $1 = jq filter, remaining args passed to jq.
write() {
  local filter="$1"; shift
  local tmp
  tmp="$(mktemp "${BASE}/.state.XXXXXX")"
  if ! jq --arg now "$NOW" "$@" "${filter} | .updated_at = \$now" "$STATE" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"; fail "jq filter failed — nothing written"
  fi
  if ! validate "$tmp"; then
    rm -f "$tmp"; fail "resulting state.json would be invalid — nothing written"
  fi
  mv "$tmp" "$STATE"
}

require_state() { [ -f "$STATE" ] || { echo "state.sh: $STATE missing (create it via 'state.sh init' — owned by 4a_checkpoint)" >&2; exit 2; }; }

case "$CMD" in
  init)
    [ -d "$BASE" ] || fail "$BASE does not exist — wrong proj/theme?"
    if [ -f "$STATE" ]; then
      echo "state.sh: $STATE already exists — init is a no-op"
      exit 0
    fi
    jq -n --arg proj "PROJ-${PROJ}" --arg theme "$THEME" --arg now "$NOW" '{
      proj: $proj, theme: $theme,
      phase: "CP1", status: "pending",
      updated_at: $now,
      degraded: false,
      lanes: [], authorship: {}, history: []
    }' >"$STATE"
    validate "$STATE" || { rm -f "$STATE"; fail "initial state invalid (bug)"; }
    echo "state.sh: created $STATE (CP1:pending)"
    ;;

  get)
    [ $# -eq 1 ] || usage
    require_state
    jq -r "$1" "$STATE"
    ;;

  set)
    [ $# -eq 2 ] || usage
    require_state
    PATH_EXPR="$1"; VALUE="$2"
    case "$PATH_EXPR" in
      .phase|.status) fail ".phase/.status are changed via 'transition', not 'set'" ;;
    esac
    if jq -e . >/dev/null 2>&1 <<<"$VALUE"; then
      write "${PATH_EXPR} = \$v" --argjson v "$VALUE"
    else
      write "${PATH_EXPR} = \$v" --arg v "$VALUE"
    fi
    ;;

  transition)
    [ $# -eq 2 ] || usage
    require_state
    TO_PHASE="$1"; TO_STATUS="$2"
    FROM_PHASE="$(jq -r '.phase' "$STATE")"
    FROM_STATUS="$(jq -r '.status' "$STATE")"
    FI="$(phase_index "$FROM_PHASE")" || fail "current phase '$FROM_PHASE' unknown"
    TI="$(phase_index "$TO_PHASE")" || fail "target phase '$TO_PHASE' unknown (phases: ${PHASES[*]})"

    legal=0
    if [ "$TI" -eq "$FI" ]; then
      case "${FROM_STATUS}>${TO_STATUS}" in
        "pending>running") legal=1 ;;
        "running>done"|"running>blocked"|"pending>blocked") legal=1 ;;
        "running>approved") [ "$TO_PHASE" = "CP1" ] && legal=1 ;;
        "blocked>running") legal=1 ;;
      esac
    elif [ "$TI" -eq $((FI + 1)) ]; then
      if [ "$FROM_STATUS" = "done" ] || [ "$FROM_STATUS" = "approved" ]; then
        if [ "$TO_PHASE" = "done" ]; then
          [ "$TO_STATUS" = "done" ] && legal=1
        else
          case "$TO_STATUS" in pending|running) legal=1 ;; esac
        fi
      fi
    fi
    [ "$legal" -eq 1 ] || fail "illegal transition ${FROM_PHASE}:${FROM_STATUS} -> ${TO_PHASE}:${TO_STATUS}"

    write '.phase = $tp | .status = $ts
           | .history += [{from: ($fp + ":" + $fs), to: ($tp + ":" + $ts), at: $now}]' \
      --arg tp "$TO_PHASE" --arg ts "$TO_STATUS" \
      --arg fp "$FROM_PHASE" --arg fs "$FROM_STATUS"
    echo "state.sh: ${FROM_PHASE}:${FROM_STATUS} -> ${TO_PHASE}:${TO_STATUS}"
    ;;

  show)
    require_state
    jq . "$STATE"
    ;;

  *)
    usage
    ;;
esac
