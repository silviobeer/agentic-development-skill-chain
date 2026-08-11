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
printf '%s\n' '{"severity":"low","category":"review-clean","summary":"scoped review clean"}'
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
      --diff-base "$BASE_SHA" "${@:2}" --round 1
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

echo 'cross-review diff-scope tests passed'
