#!/usr/bin/env bash
# Behavior tests for the shared-local-Supabase-DB migration drift guard.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/claude/skills/4b_setup/scripts/migration-drift-check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

fake_supabase() { # <workdir> <json-body>
  local work="$1" json="$2" bin="$1/bin"
  mkdir -p "$bin"
  cat >"$bin/supabase" <<EOF
#!/usr/bin/env bash
echo '$json'
EOF
  chmod +x "$bin/supabase"
}

run_guard() { # <workdir> -> stdout+stderr combined, sets RC
  local work="$1"
  set +e
  OUTPUT="$(cd "$work" && PATH="$work/bin:$PATH" bash "$GUARD" 2>&1)"
  RC=$?
  set -e
}

# --- no supabase/migrations dir: agnostic no-op, never touches PATH -------
noop="$TMP/noop"
mkdir -p "$noop"
run_guard "$noop"
[[ "$RC" -eq 0 ]] || fail "no-op case: expected exit 0, got $RC ($OUTPUT)"

# --- clean match: every migration applied and on disk ----------------------
clean="$TMP/clean"
mkdir -p "$clean/supabase/migrations"
touch "$clean/supabase/migrations/20260101000000_init.sql"
fake_supabase "$clean" '{"migrations":[{"local":"20260101000000","remote":"20260101000000","time":"t"}],"message":"ok"}'
run_guard "$clean"
[[ "$RC" -eq 0 ]] || fail "clean match: expected exit 0, got $RC ($OUTPUT)"

# --- pending local migration (not yet applied): NOT drift -------------------
pending="$TMP/pending"
mkdir -p "$pending/supabase/migrations"
touch "$pending/supabase/migrations/20260101000000_init.sql"
fake_supabase "$pending" '{"migrations":[{"local":"20260101000000","remote":"","time":"t"}],"message":"ok"}'
run_guard "$pending"
[[ "$RC" -eq 0 ]] || fail "pending local migration must not be treated as drift, got $RC ($OUTPUT)"

# --- drift: DB has a migration this worktree's folder does not have --------
drift="$TMP/drift"
mkdir -p "$drift/supabase/migrations"
touch "$drift/supabase/migrations/20260101000000_init.sql"
fake_supabase "$drift" '{"migrations":[{"local":"20260101000000","remote":"20260101000000","time":"t"},{"local":"","remote":"20990101000000","time":"t2"}]}'
run_guard "$drift"
[[ "$RC" -eq 1 ]] || fail "drift case: expected exit 1, got $RC ($OUTPUT)"
grep -q "20990101000000" <<<"$OUTPUT" || fail "drift message must name the unexpected migration version: $OUTPUT"
grep -q "supabase db reset" <<<"$OUTPUT" || fail "drift message must name the fix command: $OUTPUT"

# --- supabase CLI unreachable: skip, not a failure --------------------------
unreachable="$TMP/unreachable"
mkdir -p "$unreachable/supabase/migrations" "$unreachable/bin"
touch "$unreachable/supabase/migrations/20260101000000_init.sql"
cat >"$unreachable/bin/supabase" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$unreachable/bin/npx" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$unreachable/bin/supabase" "$unreachable/bin/npx"
run_guard "$unreachable"
[[ "$RC" -eq 0 ]] || fail "unreachable DB: expected skip (exit 0), got $RC ($OUTPUT)"

cmp -s "$GUARD" "$ROOT/codex/skills/4b_setup/scripts/migration-drift-check.sh" \
  || fail "migration-drift-check.sh provider copies are not byte-identical"

echo "migration drift guard tests: PASS"
