#!/usr/bin/env bash
# Regression check for the Claude cross-review adapter's --max-turns handling.
# --json-schema structured output needs at least 2 model turns (reasoning +
# the schema-validated tool_use finalization); a one-turn cap can cut a real
# review off as error_max_turns before any finding forms. Confirmed via a
# live claude -p run during the fix — this check guards the code shape only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/codex/skills/cross-review/scripts/review-with-claude.sh"
CASE="$(mktemp -d)"
trap 'rm -rf "$CASE"' EXIT

cat >"$CASE/claude" <<'EOF'
#!/usr/bin/env bash
turns=""
while [ $# -gt 0 ]; do
  case "$1" in --max-turns) turns="$2"; shift 2 ;; *) shift ;; esac
done
printf '%s\n' "$turns" >"$TURNS_CAPTURE"
cat >/dev/null
printf '%s\n' '{"is_error":false,"structured_output":{"findings":[{"severity":"low","category":"review-clean","summary":"clean"}]}}'
EOF
chmod +x "$CASE/claude"

printf 'artifact material\n' >"$CASE/prompt.txt"

run() { TURNS_CAPTURE="$CASE/turns" PATH="$CASE:$PATH" bash "$SCRIPT" --prompt "$CASE/prompt.txt" "$@"; }

run >/dev/null
DEFAULT_TURNS="$(cat "$CASE/turns")"
[ "$DEFAULT_TURNS" -gt 1 ] || { echo "FAIL: default --max-turns is $DEFAULT_TURNS, must be >1 (a 1-turn cap is below the structured-output floor)" >&2; exit 1; }

run --max-turns 3 >/dev/null
[ "$(cat "$CASE/turns")" = 3 ] || { echo "FAIL: --max-turns override was not forwarded to claude" >&2; exit 1; }

for bad in 0 abc; do
  if run --max-turns "$bad" >/dev/null 2>&1; then
    echo "FAIL: --max-turns $bad should have been rejected" >&2
    exit 1
  fi
done

echo "review-with-claude max-turns tests passed"
