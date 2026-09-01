---
name: supabase-local-dev
description: Diagnose and prevent shared-local-Supabase-DB problems on a repo using local Supabase for development — migration drift between git worktrees, RLS/grant surprises, config.toml vs. deployed truth. Use when a Supabase-backed action fails with a permission/grant/RLS error that "shouldn't" happen given the code and the repo's own supabase/migrations/, when switching branches or worktrees on a Supabase project, or when asked to investigate why local dev behavior doesn't match the migrations in the current branch. Not for remote/hosted Supabase project administration, and not part of the core 0-to-8 chain (the chain stays database-agnostic).
---

# Supabase local dev

Every git worktree of a repo shares ONE local Supabase Postgres instance: `supabase/config.toml`'s `project_id` is committed and identical on every branch/worktree, so the Docker stack Supabase CLI starts/reuses is keyed to that same id regardless of which worktree ran `supabase start`. A migration applied from *any* worktree changes the schema every *other* worktree's code, grants, and RLS policies assume — silently, with no error until a query the old schema allowed stops working.

## First move: is this drift?

A Supabase-backed action fails with a permission, grant, RLS, or "function does not exist" error that the current branch's own code and `supabase/migrations/*.sql` don't explain:

```bash
supabase migration list --local --output-format json | jq -r \
  '.migrations[] | select(.local == "" and .remote != "") | .remote'
```

Any output = the local DB has migrations this worktree's `supabase/migrations/` doesn't have a file for — almost certainly applied by another worktree of the same repo. Confirm by checking a `-projN` sibling worktree (or its branch, if the worktree was deleted) for a file starting with that timestamp.

**Fix:** `supabase db reset` from THIS worktree — rebuilds the local DB from this worktree's own migration files. This wipes local dev data (test accounts, seeded rows); warn before running it in a shell that isn't obviously disposable.

**Not drift:** a worktree having local migration files not yet applied (`local` set, `remote` empty) is the normal pending-migration case — `supabase migration up` handles it, no action needed here.

If a global `supabase` binary is older than the CLI version the project pins in `package.json`, `--output-format json` may silently fall back to a text table — prefer `npx supabase` (resolves the pinned version) if the JSON above doesn't parse.

## In the skill chain

`scripts/migration-drift-check.sh` (copied by `4b_setup`, alongside `preflight.sh`/`worktree.sh`) runs this exact check automatically: once at P0 preflight, and again at the start of every `wave-gate.sh` wave (P0 runs once per PROJ; a wave gate re-trusts the shared DB every time, long after P0). Both hard-fail with the migration versions and the `supabase db reset` fix. This skill exists for everything *outside* that flow — a plain dev session on `main`, a manual repro, a bug report that looks like an application bug but is environment drift — where nothing runs the check for you.

## Other shared-local-Supabase gotchas

- **RLS looks broken (or looks fine) in a raw psql/SQL-editor session:** both connect as the `postgres` superuser, which bypasses Row Level Security entirely — a query that returns rows there can still be denied for real users, and vice versa. Only a request that actually goes through the API (PostgREST) assumes the `authenticated` role a JWT's claims grant it. Reproduce RLS-sensitive failures through the actual Supabase client/API path, or simulate the role explicitly (`set role authenticated; set request.jwt.claims = '...';`) — never trust a superuser session's result.
- **`config.toml` says one thing, the running stack does another:** `supabase start`/`db reset` only re-applies config on that call. After editing `config.toml` or grants, read the setting back from the running project (`supabase status`, a direct query, or the Studio UI) — never assume the file is what's live. Three settings believed load-bearing in one project were doing nothing until verified this way.
- **Multiple repos on the same machine don't collide with each other** (each has its own `project_id` and port range) — this is strictly a same-repo, cross-worktree problem.
