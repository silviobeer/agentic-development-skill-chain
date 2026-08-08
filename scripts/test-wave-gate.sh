#!/usr/bin/env bash
# Focused negative controls for the resumable Ralph portion of wave-gate.sh.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="${GATE:-${ROOT}/claude/skills/5_executing/scripts/wave-gate.sh}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() { set +e; "$@" >/dev/null 2>&1; local rc=$?; set -e; [[ $rc -ne 0 ]] || fail "expected failure: $*"; }

case_dir() {
  local name="$1"
  CASE="$TMP/$name"
  mkdir -p "$CASE/specs/PROJ-1-test/3-4_plan" "$CASE/specs/PROJ-1-test/5_progress" "$CASE/bin"
  cp "$GATE" "$CASE/scripts-wave-gate.sh"
  printf '# Progress\n' > "$CASE/specs/PROJ-1-test/5_progress/PROJ-1-progress.md"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$CASE/bin/coderabbit"
  chmod +x "$CASE/bin/coderabbit"
  git -C "$CASE" init -q
  git -C "$CASE" config user.email test@example.invalid
  git -C "$CASE" config user.name test
  git -C "$CASE" commit --allow-empty -qm init
  git -C "$CASE" tag wave-1-start-PROJ-1
}

write_config() { printf '%s\n' "$1" > "$CASE/specs/PROJ-1-test/3-4_plan/wave-gate-config.json"; }
run_gate() { (cd "$CASE" && PATH="$CASE/bin:$PATH" bash ./scripts-wave-gate.sh 1 1 test); }
status_gate() { (cd "$CASE" && PATH="$CASE/bin:$PATH" bash ./scripts-wave-gate.sh --status 1 1 test); }

base='{"build_cmd":"true","timeouts":{"ac_seconds":5,"build_seconds":5,"coderabbit_seconds":5,"browser_seconds":5},"waves":{"1":{"advisory_severities":[],"ac_commands":%s,"frontend_routes":[]}}}'

case_dir resume
write_config "$(printf "$base" '["printf '\''Running 1 test\\n1 passed\\n'\''; echo ran >> runs"]')"
run_gate
run_gate
[[ $(wc -l < "$CASE/runs") -eq 1 ]] || fail "green AC was rerun"
jq -e '.commands[0] | .rc == 0 and .selected == 1 and .attempts == 1 and .status == "passed"' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "resume state incomplete"

case_dir empty-selection
write_config "$(printf "$base" '["printf '\''Running 0 tests\\n'\''"]')"
expect_fail run_gate
jq -e '.commands[0].status == "failed_empty_selection" and .commands[0].rc == 0 and .commands[0].selected == 0' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "empty selection passed"

case_dir loose-rate-limit
write_config "$(printf "$base" '["printf '\''a test is rate limited server-side\\n'\''; exit 1"]')"
expect_fail run_gate
jq -e '.commands[0].status == "failed" and .commands[0].attempts == 1' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "test-name rate limit was retried"

case_dir provider-rate-limit
write_config '{"build_cmd":"true","timeouts":{"ac_seconds":5,"build_seconds":5,"coderabbit_seconds":5,"browser_seconds":5},"rate_limit_backoff_seconds":0,"waves":{"1":{"advisory_severities":[],"ac_commands":["if [ ! -f first ]; then touch first; printf '\''over_request_rate_limit\\n'\''; exit 1; fi; printf '\''Running 1 test\\n1 passed\\n'\''"],"frontend_routes":[]}}}'
run_gate
jq -e '.commands[0].status == "passed" and .commands[0].attempts == 2 and .commands[0].selected == 1' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "provider retry did not happen exactly once"

case_dir coderabbit-failure
write_config "$(printf "$base" '["printf '\''Running 1 test\\n1 passed\\n'\''"]')"
printf '#!/usr/bin/env bash\nexit 1\n' > "$CASE/bin/coderabbit"
chmod +x "$CASE/bin/coderabbit"
expect_fail run_gate

case_dir auth-pacing
write_config '{"build_cmd":"true","timeouts":{"ac_seconds":5,"build_seconds":5,"coderabbit_seconds":5,"browser_seconds":5},"waves":{"1":{"advisory_severities":[],"auth_pacing_seconds":1,"ac_commands":[{"command":"date +%s >> auth-times; printf '\''Running 1 test\\n1 passed\\n'\''","auth_consuming":true},{"command":"date +%s >> auth-times; printf '\''Running 1 test\\n1 passed\\n'\''","auth_consuming":true}],"frontend_routes":[]}}}'
run_gate
mapfile -t auth_times < "$CASE/auth-times"
[[ $(( auth_times[1] - auth_times[0] )) -ge 1 ]] || fail "auth-consuming commands were not paced"

case_dir stall
write_config '{"build_cmd":"true","timeouts":{"ac_seconds":5,"ralph_stall_seconds":1,"build_seconds":5,"coderabbit_seconds":5,"browser_seconds":5},"waves":{"1":{"advisory_severities":[],"ac_commands":["sleep 2"],"frontend_routes":[]}}}'
expect_fail run_gate
jq -e '.commands[0].status == "stalled" and .commands[0].rc == 124' "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json" >/dev/null || fail "stalled AC was not red"

case_dir stale-heartbeat
write_config '{"build_cmd":"true","timeouts":{"ac_seconds":5,"ralph_stall_seconds":1,"build_seconds":5,"coderabbit_seconds":5,"browser_seconds":5},"waves":{"1":{"advisory_severities":[],"ac_commands":["true"],"frontend_routes":[]}}}'
printf '{"commands":[],"ralph_status":"running"}\n' > "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.json"
printf '%s\n' "$$" > "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.pid"
printf '%s\n' "$(( $(date +%s) - 10 ))" > "$CASE/specs/PROJ-1-test/5_progress/ralph-wave-1.heartbeat"
expect_fail status_gate

echo 'wave-gate negative controls: PASS'
