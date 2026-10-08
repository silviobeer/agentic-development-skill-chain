#!/usr/bin/env bash
# migration-drift-check.sh — guards against a stale shared local Supabase DB.
#
# Every git worktree of a repo shares the SAME local Supabase Postgres
# instance (one Docker stack, keyed by supabase/config.toml's project_id,
# which is identical across every branch/worktree of the same repo).
# A migration applied from ANY worktree silently changes the schema every
# OTHER worktree's code and grants assume — with no error until a query the
# old schema allowed stops working (e.g. a revoked grant behind a new RPC).
# worktree.sh's with-shared-lock only serializes CONCURRENT migrations; it
# does nothing about this SEQUENTIAL drift between worktrees.
#
# Compares the local DB's applied migrations against THIS worktree's
# supabase/migrations/*.sql via `supabase migration list --local`. Fails
# only when the DB has a migration this worktree's folder does not know
# about — that is the case that produces silently-wrong runtime behavior.
# A worktree having migration files not yet applied is the normal
# `supabase migration up` case and is not treated as drift.
#
# No-ops (exit 0) when this repo has no supabase/migrations directory
# (keeps the skill chain database-agnostic) or when the local DB/CLI is
# unreachable — tool presence is preflight's job, not this check's.
#
# Usage: migration-drift-check.sh
# Exit: 0 clean, no-op, or undetermined · 1 drift detected
set -euo pipefail

[ -d supabase/migrations ] || exit 0

# A global `supabase` binary can predate --output-format json (added in a
# later CLI release) while `npx supabase` resolves the version this repo
# actually pins in package.json — try both rather than trusting whichever
# happens to be on PATH first.
CANDIDATES=()
command -v supabase >/dev/null 2>&1 && CANDIDATES+=("supabase")
command -v npx >/dev/null 2>&1 && npx supabase --version >/dev/null 2>&1 && CANDIDATES+=("npx supabase")
[ "${#CANDIDATES[@]}" -gt 0 ] || {
  echo "– migration-drift-check: supabase CLI unavailable — skip" >&2
  exit 0
}

LIST_JSON=""
for candidate in "${CANDIDATES[@]}"; do
  output="$($candidate migration list --local --output-format json 2>/dev/null)" || continue
  jq -e '.migrations' >/dev/null 2>&1 <<<"$output" || continue
  LIST_JSON="$output"
  break
done
[ -n "$LIST_JSON" ] || {
  echo "– migration-drift-check: no available supabase CLI returned parseable JSON — skip (local DB down via \`supabase start\`, or every available CLI predates --output-format json)" >&2
  exit 0
}

DRIFT="$(jq -r '.migrations[] | select(.local == "" and .remote != "") | .remote' <<<"$LIST_JSON")"
[ -z "$DRIFT" ] && exit 0

echo "❌ migration drift: the local Supabase DB has migration(s) this worktree's supabase/migrations/ has no file for:" >&2
while IFS= read -r version; do
  echo "   - $version" >&2
done <<<"$DRIFT"
echo "→ Another worktree of this repo applied these to the ONE shared local Postgres instance (worktrees share it by design)." >&2
echo "→ FIX: run \`supabase db reset\` from THIS worktree to rebuild the local DB from this worktree's own supabase/migrations/ (wipes local dev data)." >&2
exit 1
