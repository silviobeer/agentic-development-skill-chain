# Worker lifecycle and shared resources

Read before dispatching a wave; apply in sequential mode as well.

## Status, stopping and replacement

- File mtimes and a quiet process snapshot do not establish a stalled worker.
  Reasoning/between-turn waits, long DB tests and resource waits may produce no
  writes. Record a baseline before dispatch, not after files already appeared.
- Ask the active worker for its current stage, command/session, owned files and
  blocker before stopping it. Inspect host task status, tool/test output, child
  processes and lock ownership over time; use the command's declared timeout,
  not an arbitrary 150-second inactivity window. A live PID alone is not progress,
  and absence of a local PID does not prove a model worker is dead.
- If the host reports completion, consume its result. If it is still working,
  wait within the applicable task budget. An unanswered status request alone
  is not proof of a hang; stop only after the host confirms failure or a bounded
  operation exceeds its budget with corroborating evidence. Preserve diagnostics.
- The lead owns cancellation and handover. Confirm the old task stopped and
  its owned child commands released resources before assigning a replacement.
  Inspect its partial diff; do not reset its work. The replacement prompt names
  the retired task ID, transferred files, inherited work and resource owner.
- Never message a retired worker or ask a replacement to contact it. Claude
  teammate messages can resume an idle/stopped teammate; other hosts have
  separate message/resume semantics. Use host status inspection without sending
  messages. Route handover questions to the lead. Reusing a retired worker
  requires an explicit new ownership assignment after releasing its replacement.
- Normal gotcha broadcasts exclude retired workers. Two workers must never
  negotiate ownership by resuming one another.

## Shared DB and browser windows

- Do not schedule a DB-backed story/test and a browser run against the same
  shared fixtures in the same window. Parallelize pure code work only if workers
  hand resource-dependent verification back to the lead for serialization.
  The lead owns the dev server and resource schedule, also for ad-hoc probes.
- With proven independent fixture namespaces, DB and browser verification may
  overlap using `with-shared-lock --shared -- <command>` on the same lock path.
  Shared mode excludes migrations but does not isolate data or auth budgets.
  The default remains exclusive; migrations, resets, global seed changes and
  overlapping mutable fixtures never use shared mode. Read-only assertions can
  still race a fixture reset; a transaction alone does not isolate a whole test.
- Keep one shared lock while browser flows and SQL touch the same database or
  auth budget. Independent fixtures use shared mode on that same schema barrier.
  Separate lock files require independent databases and budgets with every
  client/migration assigned consistently, not merely different tool names.
- Do not wrap a suite in the lock if its SQL helper takes it again. Trace the
  actual acquisition layer; forked test runners may drop fd 8, causing a nested
  acquisition to wait on its own parent. Choose one acquisition layer.
- Lock wait and test timeout are different budgets. The helper returns 73 for
  lock timeout; preserve that as infrastructure in project wrappers. An outer
  `spawnSync` timeout can hide this code before the helper's 600-second wait
  expires. Check contention first, release/schedule correctly, then rerun the
  unchanged test; do not weaken assertions or just increase all timeouts.
  Set the explicit `--timeout` shorter than the wrapper's timeout, accounting
  for the command's own execution budget. The helper emits `SKILLCHAIN_LOCK_WAIT`
  before waiting and `SKILLCHAIN_LOCK_TIMEOUT` on expiry; the gate recognizes
  that timeout marker even when a wrapper converts exit 73 to exit 1.
  Mere earlier waiting does not reclassify a later assertion failure.
  Holder snapshots show kernel PID/mode and process age where available; process
  age is not lock age. Daemon inheritance can leave ownership unresolvable.
- Inspect the actual lock path: `SKILLCHAIN_SHARED_RESOURCE_LOCK` when set,
  otherwise `git rev-parse --git-common-dir` plus
  `skillchain-shared-resources.lock`. `fuser -v <lock-path>` shows descriptor
  users, not definitive exclusive ownership; correlate with `lslocks`, process
  trees and the lead's session records. No live test process is a clue, not
  proof of a leak: an intentional manual session or waiter can look similar.
- `agent-browser` may leave a daemon holding inherited fd 8 after `open`
  returns. Run the entire probe lifecycle in one owned lock window and close
  the named session in `finally`/an EXIT trap, including error paths. Do not
  release serialization while the browser can still mutate shared data.
  Close only a confirmed abandoned session you own; never kill another run's
  browser or unlink the lock file. Unlinking can create two independent locks.
- Do not change descriptor inheritance in the shared helper as a quick fix:
  existing harnesses detect fd 8 ownership. That would require a coordinated
  harness migration and could introduce nested-lock deadlocks.

## Reduce verification cost before increasing concurrency

- Record scenario count and separate lock-wait, fixture setup, browser launch,
  navigation/compile, interaction and cleanup time. Total scenario duration is
  not launch duration. Keep the smallest real regression set for the wave;
  full-suite coverage belongs in the declared quality/CI/nightly phase.
- Prefer one application fixture project/tenant per run + scenario + retry,
  with unique row IDs and scoped queries. This means rows in the existing test
  database, not provisioning a hosted Supabase project per test. Seed every
  dependency the test reads; immutable shared reference data must be asserted.
  Include membership/RLS, global uniqueness, triggers, auth actors and background
  jobs in the isolation audit. Reusing an actor may still couple preferences.
- Remote browser tests require committed fixtures visible to the application's
  separate DB connections. An outer SQL transaction + rollback cannot wrap
  independent HTTP requests. Single-connection DB tests may use rollback.
  Remote fixtures need scoped teardown in `finally` and a bounded orphan-cleanup
  procedure after crashes; isolation does not remove cleanup or shared quotas.
- Hold a fixture lock across seed → interaction → assertions → cleanup, not
  merely each SQL statement. Release between independent scenarios where the
  harness owns the lock. Do not put a suite-wide exclusive parent around
  scenario-level locks; that defeats the narrower scope or self-deadlocks.
  Auth-consuming gate commands still have an exclusive outer lock: do not
  relabel them to bypass it. Reassess actual auth consumption, including token
  refresh, before claiming a reused session needs no auth budget.
- Prefer reusing a browser process with fresh isolated contexts per scenario
  when the existing runner supports it. Reuse verified storage state as allowed;
  keep fresh-login tests separate. Do not reuse cookies, local/session storage,
  service workers or in-memory UI state without reset/isolation evidence.
  With a CLI that cannot create fresh contexts in one process, retain fresh
  sessions until measurement justifies a harness change; no mandatory new runner.
- Migration: first make two scenarios independent and pass individually, in
  reversed order, on retry and concurrently. Then opt their entire fixture
  lifecycles into shared mode, retaining an exclusive migration/reset path on
  the same lock file in every worktree. Do not mass-switch SQL calls or infer
  lock mode from SQL text. Keep conflicting/global scenarios exclusive.
  A local file lock coordinates one host only; remote CI/other hosts require
  separate test databases or a cooperating database-side migration coordinator.
