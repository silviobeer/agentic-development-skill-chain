#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/codex/skills/cross-review/scripts/cross-review.sh"
CASE="$(mktemp -d)"
trap 'rm -rf "$CASE"' EXIT

mkdir -p "$CASE/bin" "$CASE/repo/src" "$CASE/repo/specs/run"
cat >"$CASE/bin/codex" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-} ${2:-}" == "login status" ]]; then exit 0; fi
cat >"$PROMPT_CAPTURE"
if [ -n "${REVIEW_OUTPUT:-}" ]; then
  printf '%s\n' "$REVIEW_OUTPUT"
else
  printf '%s\n' '{"severity":"low","category":"review-clean","summary":"scoped review clean"}'
fi
EOF
chmod +x "$CASE/bin/codex"

cd "$CASE/repo"
git init -q
git config user.email test@example.invalid
git config user.name test
printf 'artifact\n' >artifact.md
printf 'base\n' >src/app.ts
printf 'base\n' >specs/run/progress.md
git add . && git commit -qm base
BASE_SHA="$(git rev-parse HEAD)"
printf 'changed\n' >>src/app.ts
printf '%02048d\n' 0 >>specs/run/progress.md
git add . && git commit -qm changed

run_review() {
  PATH="$CASE/bin:$PATH" PROMPT_CAPTURE="$CASE/prompt" CROSS_REVIEW_MAX_CONTEXT_BYTES="$1" \
    bash "$SCRIPT" docs 1 test --artifacts artifact.md --author-provider claude \
      --diff-base "$BASE_SHA" --round 1 "${@:2}"
}

if run_review 1000 >"$CASE/out" 2>&1; then
  echo "expected unscoped diff to exceed the context budget" >&2
  exit 1
fi
grep -q 'above configured limit 1000' "$CASE/out" || { cat "$CASE/out" >&2; exit 1; }

if run_review 200 --diff-paths src >"$CASE/out" 2>&1; then
  echo "expected scoped material plus artifact to exceed the small context budget" >&2
  exit 1
fi
grep -q 'omitted changed paths: specs/run/progress.md' "$CASE/out" || { cat "$CASE/out" >&2; exit 1; }

run_review 4000 --diff-paths src >"$CASE/out" 2>&1
grep -q 'cross-review (docs): clean' "$CASE/out"
grep -q 'Omitted from diff ground truth' "$CASE/prompt"
grep -q 'specs/run/progress.md' "$CASE/prompt"
! grep -q '^+00000000000000000000' "$CASE/prompt"

run_review 4000 --round 3 >"$CASE/out" 2>&1
for severity in medium high; do
  expected=0
  [ "$severity" != high ] || expected=3
  rc=0
  REVIEW_OUTPUT="$(printf '{"severity":"%s","category":"stale-claim","summary":"needs correction"}' "$severity")" \
    run_review 4000 --round 3 >"$CASE/out" 2>&1 || rc=$?
  [ "$rc" -eq "$expected" ] || { cat "$CASE/out" >&2; exit 1; }
  grep -q 'needs correction' "$CASE/out"
done
for round in 0 -1 1.5 01 invalid; do
  rc=0
  run_review 4000 --round "$round" >"$CASE/out" 2>&1 || rc=$?
  [ "$rc" -eq 64 ] || { cat "$CASE/out" >&2; exit 1; }
done

# Manual rounds beyond the automatic limit work before and after state exists.
run_review 4000 --round 4 >"$CASE/out" 2>&1
mkdir -p specs/PROJ-1-test
bash "$ROOT/codex/skills/4b_setup/scripts/state.sh" init 1 test >/dev/null
for round in 4 100; do
  run_review 4000 --round "$round" --persist >"$CASE/out" 2>&1
  [ "$(jq -r '.cross_review[-1].round' specs/PROJ-1-test/state.json)" -eq "$round" ]
done

# Degraded fallback: Codex unavailable → strongest Claude model that is not the author model.
mkdir -p "$CASE/nocodex"
printf '#!/usr/bin/env bash\nexit 1\n' >"$CASE/nocodex/codex"
cat >"$CASE/nocodex/claude" <<'EOF2'
#!/usr/bin/env bash
if [[ "${1:-} ${2:-}" == "auth status" ]]; then exit 0; fi
while [ $# -gt 0 ]; do [ "$1" = --model ] && printf '%s\n' "$2" >>"$MODEL_CAPTURE"; shift; done
cat >/dev/null
printf '%s\n' '{"is_error":false,"structured_output":{"findings":[{"severity":"low","category":"review-clean","summary":"clean"}]}}'
EOF2
chmod +x "$CASE/nocodex/codex" "$CASE/nocodex/claude"
run_degraded() { # author_model
  : >"$CASE/models"
  PATH="$CASE/nocodex:$PATH" MODEL_CAPTURE="$CASE/models" \
    bash "$SCRIPT" docs 1 test --artifacts artifact.md --author-provider claude --author-model "$1" \
      --diff-base "$BASE_SHA" --diff-paths src --round 1 >"$CASE/out" 2>&1
  sort -u "$CASE/models"
}
[ "$(run_degraded claude-fable-5-1)" = opus ] || { cat "$CASE/out" >&2; exit 1; }
[ "$(run_degraded opus)" = fable ] || { cat "$CASE/out" >&2; exit 1; }
[ "$(CLAUDE_REVIEW_MODEL=sonnet run_degraded fable)" = sonnet ] || { cat "$CASE/out" >&2; exit 1; }

echo 'cross-review diff-scope, manual-round and degraded-model tests passed'

