#!/usr/bin/env bash
# Real flock concurrency checks; no database, browser or external service.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$ROOT/claude/skills/4b_setup/scripts/worktree.sh"
TEST_DIR=$(mktemp -d)
children=()
cleanup() {
  touch "$TEST_DIR/release"
  for pid in "${children[@]}"; do wait "$pid" 2>/dev/null || true; done
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
fail() { echo "shared-lock test: $*" >&2; exit 1; }
await_file() {
  for ((i=0; i<250; i++)); do [ ! -e "$1" ] || return 0; sleep .02; done
  fail "timed out waiting for $1"
}
expect_contention() {
  local mode="$1" rc=0
  (cd "$TEST_DIR/other" && bash "$HELPER" with-shared-lock $mode --timeout 0 -- touch "$TEST_DIR/should-not-run") >"$TEST_DIR/timeout.log" 2>&1 || rc=$?
  [ "$rc" -eq 73 ] || fail "expected contention exit 73, got $rc"
  [ ! -e "$TEST_DIR/should-not-run" ] || fail "blocked command ran"
  grep -q '^SKILLCHAIN_LOCK_WAIT ' "$TEST_DIR/timeout.log" || fail "missing early wait diagnostic"
  grep -q '^SKILLCHAIN_LOCK_TIMEOUT ' "$TEST_DIR/timeout.log" || fail "missing timeout diagnostic"
}
git init -q "$TEST_DIR/repo"
git -C "$TEST_DIR/repo" -c user.name=test -c user.email=test@example.invalid commit --allow-empty -qm init
git -C "$TEST_DIR/repo" worktree add -qb other "$TEST_DIR/other"
for location in repo other; do
  (cd "$TEST_DIR/$location" && timeout 10 bash "$HELPER" with-shared-lock --shared --timeout 0 -- bash -c 'touch "$1"; while [ ! -e "$2" ]; do sleep .02; done' _ "$TEST_DIR/$location-ready" "$TEST_DIR/release") >"$TEST_DIR/$location.log" 2>&1 &
  children+=("$!")
done
await_file "$TEST_DIR/repo-ready"
await_file "$TEST_DIR/other-ready"
expect_contention ""
touch "$TEST_DIR/release"
for pid in "${children[@]}"; do wait "$pid" || fail "shared holder failed"; done
children=()
(cd "$TEST_DIR/repo" && bash "$HELPER" with-shared-lock --timeout 0 -- true) || fail "exclusive lock not released"
unlink "$TEST_DIR/release"
(cd "$TEST_DIR/repo" && timeout 10 bash "$HELPER" with-shared-lock -- bash -c 'touch "$1"; while [ ! -e "$2" ]; do sleep .02; done' _ "$TEST_DIR/exclusive-ready" "$TEST_DIR/release") >"$TEST_DIR/exclusive.log" 2>&1 &
children+=("$!")
await_file "$TEST_DIR/exclusive-ready"
expect_contention "--shared"
expect_contention ""
touch "$TEST_DIR/release"
wait "${children[0]}"
children=()
rc=0
(cd "$TEST_DIR/repo" && bash "$HELPER" with-shared-lock --shared -- bash -c 'exit 17') || rc=$?
[ "$rc" -eq 17 ] || fail "child exit code lost"
for provider in claude codex; do
  for skill in 4b_setup 8_delivery; do cmp "$HELPER" "$ROOT/$provider/skills/$skill/scripts/worktree.sh"; done
done
echo "shared-lock concurrency and diagnostics: PASS"
