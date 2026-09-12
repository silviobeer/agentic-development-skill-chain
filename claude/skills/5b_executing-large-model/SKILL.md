---
name: executing-large-model
description: "Lean Step 5 variant for frontier models (Claude Fable/Mythos 5.x, Opus 5, GPT-5.x or later): same state.sh, wave-gate, ledger, Quality Gate and QA-handoff contracts as 5_executing, with the step-by-step TDD choreography and persona reviews removed in favor of intent and invariants; the strongest model leads, workers stay tiered by Complexity, reviews go to the strongest opposite model. Use when: (1) wave plans exist and CP1 is sealed, (2) the writer lane runs on a frontier model, (3) a run should be compared against the full 5_executing procedure. Not for: weaker models, planning, architecture, requirements, or a repo without 5_executing installed."
---

# Executing — large-model variant

Same gates, less procedure. This skill keeps every deterministic contract of
`5_executing` (state, progress file, wave tag, wave gate, Outer Ralph recovery,
Quality Gate proof, Skill 6 handoff) and drops the prose that walks a model
through work it can plan itself. Scripts verify; the model decides.

It ships no scripts. `4b_setup` installs the framework helpers from
`5_executing` into the repo, and this skill calls those copies. `5_executing`
must therefore be installed alongside it.

## When to use this instead of `5_executing`

- The lead and its workers run on a frontier model. On a weaker model, use
  `5_executing`; its procedure exists to keep such a model on track.
- You want to measure whether the procedure still pays for itself. Record the
  variant in `progress.md` (see skeleton) so runs can be compared.

## Non-negotiables

These are the parts that do not depend on model quality. They are unchanged
from `5_executing` and the same scripts enforce them.

1. **Entry.** `bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'`
   must be `P0:done` or `P5:*`. `CP1:*` → run checkpoint (4a); `CP1:approved`
   → run setup (4b). Work only inside `.worktree.path` from state. On every
   start or resume run `node ~/.claude/skills/4b_setup/scripts/sync-framework.mjs`
   (Codex: the installed `.codex/skills` copy), reconcile any reported
   difference, commit, then `bash scripts/state.sh transition <X> <theme> P5 running`
   if the phase was `P0:done`. Without `state.json`, run the standalone
   preflights from `5_executing` § FIRST ACTION step 2 first, then continue here.
2. **Records before work.** `BASE_SHA` comes from `state.json` (standalone:
   `git rev-parse HEAD`). Create
   `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md` from the skeleton
   below before the first dispatch. `wave-gate.sh` and `quality-gate-proof.sh`
   parse it; keep their headings verbatim.
3. **Wave tag.** Before dispatching wave N:
   `git tag "wave-${WAVE}-start-PROJ-${PROJ}"` (delete and recreate on a
   re-run). The gate scopes CodeRabbit to this tag and fails hard without it.
4. **Workers own edits.** Every code, test, and fix edit is worker-owned when
   delegation is available. The lead owns decomposition, dispatch, integration,
   deterministic verification, gates, commits, and records. Editing locally is a
   fallback that must be reported with its reason.
5. **Ownership and shared resources.** Each worker gets disjoint file
   ownership. Honor the plan's `## Execution` block: `sequential` means one
   story at a time. Every migration and every `auth_consuming` command, also
   inside a worker, runs as `scripts/worktree.sh with-shared-lock -- <command>`.
   In a frontend wave the lead owns the dev server; workers never start or stop one.
   Read `5_executing/references/worker-lifecycle.md` when a wave has shared DB
   or browser windows to schedule.
6. **Outer Ralph.** After all workers of a wave are integrated and committed:
   `bash scripts/wave-gate.sh --ac-only <N> <X> <theme>`. Recovery has exactly
   four stages: normal fix round, normal fix round with fresh workers, one
   read-only diagnostic worker, one different implementer applying the
   diagnosis. Failure output goes to workers verbatim. Each correction is
   committed and the same command rerun. Exit 76 (`blocked_external`) is a
   missing prerequisite, not a defect: park via `state.sh`, no repair rounds.
   Still red after stage four → the existing blocked path.
7. **Wave gate.** `bash scripts/wave-gate.sh <N> <X> <theme>` must exit 0
   before any worker for wave N+1 is dispatched. On success the script appends
   `### Wave N Gate — PASSED`; that block is the only proof of completion.
   Then `bash scripts/state.sh set <X> <theme> .waves '{…}'` with current,
   total, and per-story status. Do not stop between waves and do not ask the
   user; the gate is the signal.
8. **Quality Gate.** After the last wave, follow
   `5_executing/references/quality-gate.md`: declared quality-phase commands,
   an integration-focused review of `BASE_SHA..HEAD`, build via
   `quality-evidence.mjs`, Sonar once per PROJ with at most three fix rounds,
   combined recovery rounds. Zero P0/P1 review findings to pass. Fill the
   `## Quality Gate — PROJ-X` section, then `bash scripts/quality-gate-proof.sh <X> <theme>`
   must exit 0.
9. **Handoff.** Framework run: `bash scripts/state.sh transition <X> <theme> P5 done`
   and stop; the runner starts P6 as fresh lanes. Interactive run: invoke
   `/6_qa`. Skill 5 never performs QA itself and never skips Skill 6.
10. **Learnings.** When a worker or the lead hits a wall and gets past it, the
    workaround goes into the feature folder's `agent.md` immediately, using
    `5_executing/templates/agent-md-entry.md.tmpl`.
11. **Commits.** `feat(PROJ-<X>-PRD-<Y>): implement [US-N …]`,
    `fix(PROJ-<X>-PRD-<Y>): address review findings for [US-N]`,
    `fix(PROJ-<X>): address quality gate findings`.

## Left to the model

The following are stated as invariants, not procedures. A frontier model is
expected to choose the concrete steps.

- **Tests.** Every behavior change is covered by a test that fails before the
  change and passes after it, run by command with the output read. Whether
  that is strict RED/GREEN/REFACTOR per task or a test written alongside the
  implementation is the worker's call. A test that was not run is not evidence.
- **Self-review.** Before reporting, a worker re-reads its diff against the
  story once, fixes what it finds within its ownership, runs the targeted
  tests once, and reports anything unresolved. It does not loop.
- **Worker briefs.** A brief carries the story text, its acceptance criteria
  (verified by the lead, not the worker), the task list, the ownership set,
  the shared-resource rule, prior-wave summary, a pointer to `agent.md`, and
  for UI stories a pointer to `1d_mockups/implementation-handoff.md` plus the
  design-system baseline (`docs/DESIGN-SYSTEM.md`, `docs/components.md`) when
  no context bundle injects it. Do not paste framework skill files
  (Tailwind, Next.js) or generic checklists; the model knows the stack.
- **Story granularity.** One story is one worker. The lead does not split a
  story unless its header declares it: `Split: contract` → one backend and one
  frontend worker, both bound to the wave's section of `api-contracts.md`, the
  frontend working against the contract or a stub until the backend lands;
  `Split: fan-out` → one worker builds the first unit, then further workers
  copy its shape over the declared disjoint file sets. A story that turns out
  too large without such a marker is finished by its single worker and noted in
  `Variant Notes` as a planning defect for `4_writing-plans`, not split ad hoc.
- **UI shape.** Registered components and tokens beat mockup CSS; the chosen
  layout direction and interaction contract are preserved. A missing component
  is escalated to the lead and added through the `1c_frontend-design` extension
  procedure, never styled as a one-off.
- **Model choice.** The lead runs on the session model, the strongest one in
  the run: it owns decomposition, integration, and finding triage. Workers are
  tiered from the wave plan's `Complexity` column: `sonnet` by default, `opus`
  where the plan says so; a missing column means `sonnet` plus one line in
  `progress.md`. Reviews go to the strongest opposite-provider model, with the
  in-family fallback handled by `cross-review.sh`. Reviewer strength never
  drops below writer strength.
- **Context.** The lead keeps worker summaries short and reads files only for
  the next decision. Compaction, background spawning, and team versus single
  subagent are host decisions the model makes as it goes.
- **Debugging.** Root cause before fix: full error text, reproduce, diff since
  it last worked, one hypothesis at a time. Repeated failures use the Outer
  Ralph stages in item 6 or the blocked path, never open-ended retries.
- **Reviews.** CodeRabbit inside the wave gate and the Quality Gate reviewer
  are the only Step 5 reviews. No minimalism persona, no six-persona panel;
  those belong to Skill 6.

## Worker brief

```
Implement US-<N> "<title>" for PROJ-<X>.

Story: <Given/When/Then>
Acceptance criteria (the lead verifies these; do not run the AC commands):
<list>
Tasks: <list with file paths>
You own: <files/dirs>. Touch nothing else; escalate if you must.
Shared resources: wrap every migration and auth-consuming command as
  scripts/worktree.sh with-shared-lock -- <cmd>. Do not start or stop a dev server.
Prior waves: <one paragraph>. Notes: <path>/agent.md (read first, append walls).
UI (if any): 1d_mockups/implementation-handoff.md; reuse registered components.

Every behavior change needs a test that failed before and passes after; run it
and read the output. Before reporting, re-read your diff against the story once,
fix what you find, run targeted tests once, then report in ≤300 tokens:
files changed, tests added and their commands, anything unresolved.
Commit as feat(PROJ-<X>-PRD-<Y>): implement US-<N> <task>.
```

## progress.md skeleton

Headings under `## Quality Gate` are parsed by `quality-gate-proof.sh`; keep
them and their `Status:` lines verbatim.

```markdown
# PROJ-X Progress

## Variant: large-model
## Status: in progress
## Current Wave: 1
## BASE_SHA: <sha>

## US-1: <title> — pending
| AC | Text | Verified |
|----|------|:---:|
| AC-1 | <verbatim> | — |

## Quality Gate — PROJ-X

### Code Review
Status: pending

### SonarCloud
Status: pending

### Build
Status: pending

### Tests
Status: pending

### Lint
Status: pending

### Fixed Issues

### Deferred (user decision)

## Variant Notes
- Complexity column present: yes/no; worker models used per story.
- Recovery stage reached per wave: …
- Compare against a 5_executing run: wall clock, recovery depth, Quality Gate
  P0/P1 count, Skill 6 bug count.

## Open Blockers
```

Update AC rows after the AC-only pass and each recovery stage, and record
reuse or invalidation decisions there. The gate appends its own PASSED blocks.

## Stop conditions

Escalate or park the run, never improvise past these: Outer Ralph exhausted
all four stages; the root cause is in the spec or architecture; a declared
external prerequisite is missing (exit 76); a required tool is absent (install
it, do not bypass the gate); requirements contradict each other. In framework
runs use `state.sh` for the blocked phase and reason and render the stop report.

## Provider notes

- **Claude:** spawn `implementer` / `frontend-implementer` /
  `backend-implementer`, or P0's `skillchain-<role>` types when available;
  otherwise attach the bundle path from
  `node scripts/context-injector.mjs claude <role> --path`. Background spawns
  are the default for independent workers.
- **Codex:** use `spawn_agent` worker roles with explicit file ownership; no
  `/compact`; skill assets live under `.codex/skills`; the installed
  synchronizer is `~/.codex/skills/4b_setup/scripts/sync-framework.mjs`.
