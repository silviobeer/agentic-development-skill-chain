#!/usr/bin/env bash
# Behavior tests for P0 preflight's coderabbit.enabled switch (both platform copies).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Fake bin: every hard tool present EXCEPT coderabbit (added per case).
FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
for command_name in gh claude; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/$command_name"
  chmod +x "$FAKE_BIN/$command_name"
done
printf '#!/usr/bin/env bash\nexit 1\n' >"$FAKE_BIN/npx"
chmod +x "$FAKE_BIN/npx"
# PATH minus every directory providing a real coderabbit
CLEAN_PATH=$(IFS=:; out=""; for d in $PATH; do [[ -x "$d/coderabbit" ]] || out+="${out:+:}$d"; done; printf '%s' "$out")

# The plan folder in these fixtures is empty, so the unrelated worker-context check always fails;
# assertions therefore look at the coderabbit lines and the hard-tools verdict, not the bare exit code.
cr_hard() { grep -E 'hard tools missing:' <<<"$OUT" | grep -q coderabbit; }

# run_case <platform> <config-json|-> <with-coderabbit:yes|no|broken-auth> ; sets RC and OUT
run_case() {
  local platform="$1" config="$2" cr="$3" work
  work="$(mktemp -d "$TMP/case.XXXXXX")"
  mkdir -p "$work/specs/PROJ-1-cr/3-4_plan" "$work/bin"
  [[ "$config" == - ]] || printf '%s\n' "$config" >"$work/specs/PROJ-1-cr/3-4_plan/wave-gate-config.json"
  case "$cr" in
    yes) printf '#!/usr/bin/env bash\nexit 0\n' >"$work/bin/coderabbit"; chmod +x "$work/bin/coderabbit" ;;
    broken-auth) printf '#!/usr/bin/env bash\n[ "${1:-}" = auth ] && exit 1\nexit 0\n' >"$work/bin/coderabbit"; chmod +x "$work/bin/coderabbit" ;;
  esac
  set +e
  OUT=$(cd "$work" && PATH="$work/bin:$FAKE_BIN:$CLEAN_PATH" PREFLIGHT_SKIP_LIVE_PROBE=1 PREFLIGHT_CODEX_INACTIVE=1 \
    bash "$ROOT/$platform/skills/5_executing/scripts/preflight.sh" 1 cr 2>&1)
  RC=$?
  set -e
}

for platform in claude codex; do
  # (a) no config / key absent / enabled:true -> coderabbit stays a hard tool
  for config in - '{"waves":{}}' '{"coderabbit":{"enabled":true}}' '{"coderabbit":{}}'; do
    run_case "$platform" "$config" no
    [[ "$RC" -eq 1 ]] && grep -q 'coderabbit MISSING (hard)' <<<"$OUT" || fail "$platform: coderabbit missing was not a hard stop for config $config (rc=$RC)"
    run_case "$platform" "$config" broken-auth
    [[ "$RC" -eq 1 ]] && grep -q 'coderabbit auth BROKEN' <<<"$OUT" || fail "$platform: broken coderabbit auth was not a hard stop for config $config (rc=$RC)"
    run_case "$platform" "$config" yes
    grep -q '✓ coderabbit auth' <<<"$OUT" && ! cr_hard || fail "$platform: working coderabbit rejected for config $config: $OUT"
  done

  # (b) enabled:false -> neither tool nor auth is required; logged skip
  for cr in no broken-auth; do
    run_case "$platform" '{"coderabbit":{"enabled":false}}' "$cr"
    ! cr_hard || fail "$platform: disabled preflight still hard-stopped on coderabbit ($cr): $OUT"
    grep -q 'coderabbit + auth skipped: disabled by wave-gate-config' <<<"$OUT" || fail "$platform: skip not logged ($cr)"
    ! grep -q 'coderabbit MISSING\|coderabbit auth BROKEN' <<<"$OUT" || fail "$platform: disabled preflight still flagged coderabbit ($cr)"
  done

  # (c) invalid value -> hard stop, and coderabbit stays required (never a silent skip)
  for invalid in '"false"' 'false' 'null' '[]' '{"enabled":"false"}' '{"enabled":false,"bogus":1}'; do
    run_case "$platform" "{\"coderabbit\":$invalid}" no
    [[ "$RC" -eq 1 ]] && grep -q 'coderabbit must be an object' <<<"$OUT" && cr_hard || fail "$platform: invalid coderabbit $invalid was not a hard stop (rc=$RC)"
    grep -q 'coderabbit MISSING (hard)' <<<"$OUT" || fail "$platform: invalid coderabbit $invalid silently dropped the tool requirement"
  done
done

echo 'preflight coderabbit switch tests (claude + codex): PASS'
