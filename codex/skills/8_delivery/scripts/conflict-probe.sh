#!/usr/bin/env bash
# conflict-probe.sh — P8 step 1: probe the PROJ branch against main
# WITHOUT touching any real branch.
#
# Creates a throwaway detached worktree on the target branch, attempts
# `git merge --no-commit --no-ff <proj-branch>` there, records the
# conflicted files, aborts, and removes the worktree (trap-guarded).
# Classification is file-type heuristic: lockfiles and generated files
# are `trivial` (auto-fixable); everything else is `semantic` (risk
# assessment into the PR + escalate — CONCEPT.md §4 P8).
#
# Usage:  conflict-probe.sh <proj-x> <theme> [target-branch]   (default: main)
# Output: JSON report on stdout:
#         {"branch","target","verdict":"none|trivial|semantic","conflicts":[{"file","class"}]}
# Exit:   0 probe ran (read verdict from JSON) · 1 probe failed · 64 usage
set -euo pipefail

PROJ="${1:-}"; THEME="${2:-}"; TARGET="${3:-main}"
if [ -z "$PROJ" ] || [ -z "$THEME" ]; then
  echo "Usage: $0 <proj-x> <theme> [target-branch]" >&2
  exit 64
fi

BRANCH="proj/PROJ-${PROJ}"
git rev-parse --verify --quiet "$BRANCH" >/dev/null || { echo "conflict-probe.sh: branch $BRANCH not found" >&2; exit 1; }
git rev-parse --verify --quiet "$TARGET" >/dev/null || { echo "conflict-probe.sh: target $TARGET not found" >&2; exit 1; }

WT="$(mktemp -d)/probe"
cleanup() {
  git -C "$WT" merge --abort >/dev/null 2>&1 || true
  git worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$(dirname "$WT")"
}
trap cleanup EXIT

git worktree add --detach "$WT" "$TARGET" >/dev/null 2>&1

CONFLICTS=""
if ! git -C "$WT" merge --no-commit --no-ff "$BRANCH" >/dev/null 2>&1; then
  CONFLICTS="$(git -C "$WT" diff --name-only --diff-filter=U)"
fi

# trivial: lockfiles + generated artifacts; everything else: semantic
printf '%s\n' "$CONFLICTS" | jq -R -s \
  --arg branch "$BRANCH" --arg target "$TARGET" '
  [ split("\n")[] | select(length > 0)
    | { file: .,
        class: (if test("(^|/)(package-lock\\.json|pnpm-lock\\.yaml|yarn\\.lock|bun\\.lockb?|Cargo\\.lock|composer\\.lock|poetry\\.lock)$")
                   or test("\\.(generated|min)\\.")
                then "trivial" else "semantic" end) }
  ] as $c
  | { branch: $branch,
      target: $target,
      verdict: (if ($c | length) == 0 then "none"
                elif ([$c[] | select(.class == "semantic")] | length) > 0 then "semantic"
                else "trivial" end),
      conflicts: $c }'
