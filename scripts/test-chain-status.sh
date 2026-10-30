#!/usr/bin/env bash
# `chain status` must report the expected step for every fixture state, in both provider
# trees, and must never change the workspace (files, .git included).
# Fixtures: scripts/fixtures/chain-status/<state>/tree/ (the workspace), expected.txt
# (default view), expected-short.txt (--short) and an optional setup.sh run after the
# first commit (extra history for the documentation rule).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$ROOT/scripts/fixtures/chain-status"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "test-chain-status: $*" >&2; exit 1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.test GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.test
snapshot() { (cd "$1" && find . -print | LC_ALL=C sort && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum) | shasum; }

count=0
for dir in "$FIX"/*/; do
  name="$(basename "$dir")"
  W="$TMP/$name"; mkdir -p "$W"; cp -R "$dir/tree/." "$W/"
  (cd "$W" && git init -q && git add -A && git commit -q --no-gpg-sign -m fixture && { [ ! -f "$dir/setup.sh" ] || bash "$dir/setup.sh"; }) \
    || fail "$name: fixture setup failed"
  before="$(snapshot "$W")"
  for provider in claude codex; do
    CHAIN="$ROOT/$provider/skills/5_executing/scripts/chain"
    (cd "$W" && bash "$CHAIN" status --short) | cmp - "$dir/expected-short.txt" || fail "$provider $name: --short differs"
    (cd "$W" && bash "$CHAIN" status) | cmp - "$dir/expected.txt" || fail "$provider $name: default view differs"
  done
  [ "$(snapshot "$W")" = "$before" ] || fail "$name: chain status changed the workspace"
  count=$((count + 1))
done
[ "$count" -ge 11 ] || fail "only $count fixtures found"

CHAIN="$ROOT/claude/skills/5_executing/scripts/chain"
# an explicit PROJ wins over the most advanced one and drops the (+N PROJs) suffix
W="$TMP/multi-proj"
[ "$(cd "$W" && bash "$CHAIN" status --short 4)" = "PROJ-4 · 👉 Step 3/8 Architecture · next: writing-plans" ] || fail "explicit PROJ not selected"
rc=0; (cd "$W" && bash "$CHAIN" status 9 >/dev/null 2>&1) || rc=$?; [ "$rc" = 2 ] || fail "unknown PROJ should exit 2, got $rc"
# an explicit number shared by two folders picks the more advanced one
W="$TMP/robustness"
[ "$(cd "$W" && bash "$CHAIN" status --short 1)" = "PROJ-1-beta · 👉 Step 3/8 Architecture · next: writing-plans" ] || fail "explicit duplicate PROJ number not resolved"
# a synchronized repo runs the verb through its own scripts/chain (chain-status.mjs is in the sync inventory)
W="$TMP/qa-running"
node "$ROOT/claude/skills/5_executing/scripts/sync-framework.mjs" --target "$W" >/dev/null || fail "sync into the fixture failed"
(cd "$W" && bash scripts/chain status --short) | cmp - "$FIX/qa-running/expected-short.txt" || fail "synced scripts/chain status differs"
# `new` ignores existing PROJs: a session that has no PROJ number yet must not show another PROJ's step
W="$TMP/receiving-proj"
[ "$(cd "$W" && bash "$CHAIN" status --short new)" = "New PROJ · 👉 Step 1/8 Concept · next: requirements" ] || fail "'new' did not show the pre-PROJ workspace"
rc=0; (cd "$W" && bash "$CHAIN" status --bogus >/dev/null 2>&1) || rc=$?; [ "$rc" = 64 ] || fail "bad flag should exit 64, got $rc"
# outside a chain workspace: --short prints nothing (and succeeds), the default view says why
mkdir -p "$TMP/empty"
[ -z "$(cd "$TMP/empty" && bash "$CHAIN" status --short)" ] || fail "--short must be empty outside a workspace"
(cd "$TMP/empty" && bash "$CHAIN" status) | grep -q "Not a chain workspace" || fail "default view outside a workspace"
# the documentation step needs the docs commit to be newer than the latest feature commit
W="$TMP/docs-done"; git -C "$W" commit -q --allow-empty --no-gpg-sign -m "feat(PROJ-3-PRD-1): follow-up"
(cd "$W" && bash "$CHAIN" status --short) | grep -qF "Step 7/8 Documentation" || fail "a feature commit after the docs commit must reopen documentation"

echo "test-chain-status: ok ($count fixtures)"
