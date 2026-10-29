---
name: executing-large-model
description: "Default Step 5 of the chain: run Checkpoint 1 and P0 setup through 5_executing's checkpoint and setup subskills (each in a subagent, the user dialogue in the lead), then execute the waves with the same chain state, wave-gate, ledger, Quality Gate and QA-handoff contracts as 5_executing — step-by-step TDD choreography and persona reviews replaced by intent and invariants; the strongest model leads, workers stay tiered by Complexity, reviews go to the strongest opposite model. Use when: (1) wave plans exist and need CP1 approval, P0 setup, and execution, (2) an approved plan is ready for execution or a run must resume. Not for: writer lanes on weaker models (use 5_executing), planning, architecture, requirements, or a repo without 5_executing installed."
---

# Executing — large-model variant (default Step 5)

## External handoff inputs (conditional)

For `external-handoff.json`, follow [the receiving input contract](../2e_handoff-refinement/references/input-contract.md) and `5_executing`'s external-input rules before CP1/setup or resume. The resolved baseline, explicit approved responses and separately identified engineering criteria replace local PRD lookup below. Never supersede a worker slice by an assumed product decision: verify the pinned response, repair derived artifacts and recompile. Received files and source AC text remain immutable.

Use one bound repo checkout/worktree and one state per run; verify its accepted baseline and external dependency revisions. A product gap returns to `handoff-refinement` and blocks affected tasks; do not auto-defer it as engineering debt. Passing this repo's gates or opening its PR does not establish shared integration acceptance.

## Artifact Language

From Requirements Engineer (Step 2) onward, write all newly authored artifacts
in English: PRDs, plans, decision records, handoff packages/prompts, findings,
worker reports, QA evidence summaries, documentation and PR descriptions.
Converse with the user in their language. Preserve identifiers, file paths,
verbatim source evidence and the product's required UI/localization language.
Concepts and discovery inputs may use another language; derive English artifacts
from them. Before CP1 approval, return non-English canonical PRD ACs to
Requirements Engineer for an approved English revision before downstream
verbatim copying. On resume after CP1 is sealed, preserve approved PRD/plan ACs
verbatim; a newer language policy alone must not reopen approval. New records
remain English. Change sealed canonical ACs only through an explicit user-
authorized revision and the owning review; never silently translate them.
External received ACs are quoted evidence: preserve their source language even
before CP1; the local-authoring language revision rule above does not authorize
translation or rewriting of an immutable package.


The chain's default execution skill. Same gates as `5_executing`, less
procedure. This skill keeps every deterministic contract of
`5_executing` (state, progress file, wave tag, wave gate, Outer Ralph recovery,
Quality Gate proof, Skill 6 handoff) and drops the prose that walks a model
through work it can plan itself. Scripts verify; the model decides.

It ships no scripts and no subskills of its own: it runs `5_executing`'s
`subskills/checkpoint.md` and `subskills/setup.md`, and the setup subskill
installs `5_executing`'s framework helpers into the repo, which this skill then
calls. `5_executing` must therefore be installed alongside it.

## When to use `5_executing` instead

- The lead (the writer lane) runs on a weaker model (anything below Claude
  Fable/Mythos 5.x, Opus 5, or GPT-5.x). Workers on `sonnet` are expected here
  and are no reason to switch. Its step-by-step procedure exists to keep
  such a model on track. Runner: `SKILLCHAIN_P5_SKILL="executing (5_executing)"`.
- You want to measure whether the procedure still pays for itself. Record the
  variant in `progress.md` (see skeleton) so runs can be compared.

## Non-negotiables

These are the parts that do not depend on model quality. They are unchanged
from `5_executing` and the same scripts enforce them.

1. **CP1 + P0.** CP1 repeats PRD, architecture and plan structure checks before approval; already approved P5 runs keep their legacy context behavior. Read the phase with the installed helper (the repo copy
   arrives with P0): `bash ~/.claude/skills/5_executing/scripts/chain state get <X> <theme> '.phase + ":" + .status'`
   (Codex: the `.codex/skills` copy). The subskills run in subagents; only
   verdicts and the review point list enter this context.
   - No `state.json` → ask the user once: framework run (`chain state init <X> <theme>`
     with the same helper, then route below) or standalone run (preflights from
     `5_executing` § FIRST ACTION step 2). Never implement past an unsealed CP1.
   - `CP1:pending` / `running` / `blocked` → `5_executing/subskills/checkpoint.md`,
     CP1 roles: prepare subagent; unless it returns `sealed`, walk its points
     with the user, appending each outcome to the decision log before the next;
     then the apply subagent. Repeat until `sealed`. Never approve on the
     user's behalf.
   - `CP1:approved`, `P0:running`, `P0:blocked` → one subagent on
     `5_executing/subskills/setup.md` with `<X> <theme>` and this checkout's
     path. `P0:blocked` back → stop and report its reason. Relay any defaulted
     decisions (including the suggested `complexity_cmd` / `arch_rules_cmd` /
     `mutation_cmd` candidates; absent keys simply skip), then `cd` into the
     returned `.worktree.path`.
   - `P0:done` or `P5:*` → continue. The runner's P5 lane arrives here; its
     P0 lane already ran setup. `P6:*`–`P8:*` → resume the in-session driver
     (`5_executing/references/in-session-driver.md`) at that phase.
   - **Unattended handoff, once, on `P0:done`:** follow
     `5_executing/references/unattended-handoff.md` (installed copy) in
     `.worktree.path` (one probe, at most one question: unattended, in this
     session, or interactive).
   In framework runs preflights belong to setup — never re-run them here — and
   work happens only inside `.worktree.path` from state; a standalone run works
   in the current checkout after its own preflights. On every
   start or resume run `bash ~/.claude/skills/5_executing/scripts/chain sync`
   (Codex: the installed `.codex/skills` copy), reconcile any reported
   difference, commit, and in the same step run only the `compile` of item 3
   (no worker between `sync` and `compile`; lead discipline, the retired hook stub catches only workers without a path), then
   `bash scripts/chain state transition <X> <theme> P5 running` if the phase was `P0:done`.
2. **Records before work.** `BASE_SHA` comes from `state.json` (standalone:
   `git rev-parse HEAD`). Create
   `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md` from the skeleton
   below before the first dispatch; if P0 already wrote it (negative controls,
   defaulted decisions), add the missing sections and keep its content. A
   legacy PROJ (`7_progress/`, `6_plan/`) keeps writing where its files already
   are — never a second folder (`0_chain-guide/references/legacy-layout.md`). `chain gate wave` and `chain quality seal`
   parse it; keep their headings verbatim.
3. **Wave start.** Read lazily: at PROJ start only the wave shape — each
   plan's `## User Stories in this Wave` and `## Execution` sections via
   `scripts/chain render slice` (`5_executing` § Input) — and the wave 1 plan; at
   each wave start only that wave's plan, never earlier ones — what previous
   waves built comes from the wave shape plus `progress.md`. Before dispatching wave N:
   `git tag "wave-${WAVE}-start-PROJ-${PROJ}"` unless it exists (keep it on a
   resume; recreate only after a reset restart). The gate scopes CodeRabbit to this tag and fails hard without it.
   Before any worker starts, compile the wave's worker files (this wave's
   architecture decisions and API contracts; no lock, no hash bookkeeping, no `chain state`; the file header carries the plan hash):
   `bash scripts/chain render context compile <X> <theme> --wave <N>`.
   Exit ≠ 0 → no worker until a rerun exits 0; read the warnings before dispatch
   (e.g. `settings.json is not valid JSON — left unchanged`: repair, rerun; see
   `5_executing/subskills/setup.md`).
4. **Workers own edits.** Every code, test, and fix edit is worker-owned when
   delegation is available. The lead owns decomposition, dispatch, integration,
   deterministic verification, gates, commits, and records. Editing locally is a
   fallback that must be reported with its reason.
5. **Ownership and shared resources.** Each worker gets disjoint file
   ownership. Honor the plan's `## Execution` block: `sequential` means one
   story at a time. Every migration and every `auth_consuming` command, also
   inside a worker, runs as `scripts/chain worktree with-shared-lock -- <command>`.
   In a frontend wave the lead owns the dev server; workers never start or stop one.
   In a parallel wave the lead also owns `progress.md`, staging, and commits;
   workers report and do not commit.
   Read `5_executing/references/worker-lifecycle.md` before dispatching every
   wave, sequential ones included: worker status, stopping, and replacement
   rules apply even without shared resources.
6. **Outer Ralph.** After all workers of a wave are integrated and committed,
   close the wave first: match every story's `Smoke Test` route/behavior to gate
   smoke or this wave's authenticated scenarios; missing scenarios go to the
   named browser owner (after DB workers release the shared resource) and are
   integrated and committed with their command/route mappings. A route load
   alone does not prove an interaction. Then
   `bash scripts/chain gate wave --ac-only <N> <X> <theme>`. Recovery has exactly
   four stages: normal fix round, normal fix round with fresh workers, one
   read-only diagnostic worker, one different implementer applying the
   diagnosis. Static-check failures (`complexity_cmd`, `arch_rules_cmd`) follow
   the same four stages.
   Failure output goes to workers verbatim. Each correction is
   committed and the same command rerun. Cached evidence is reused only for the
   same committed `HEAD` and gate-config fingerprint; every correction commit
   invalidates it, and cached Ralph evidence is removed after any dependency,
   runtime, or environment change. Exit 76 (`blocked_external`) is a
   missing prerequisite, not a defect: park via `chain state`, no repair rounds.
   Still red after stage four → the existing blocked path.
7. **Wave gate.** `bash scripts/chain gate wave <N> <X> <theme>` must exit 0
   before any worker for wave N+1 is dispatched. On success the script appends
   `### Wave N Gate — PASSED` (listing the static checks it ran or skipped); that
   block is the only proof of completion.
   Then `bash scripts/chain state set <X> <theme> .waves '{…}'` with current,
   total, and per-story status. Do not stop between waves and do not ask the
   user; the gate is the signal.
8. **Quality Gate.** After the last wave, follow
   `5_executing/references/quality-gate.md`: declared quality-phase commands,
   an integration-focused review of `BASE_SHA..HEAD`, mutation hardening
   (Gate 0b, when `mutation_cmd` is set), build via `chain quality`,
   coverage, Sonar once per PROJ with at most three fix rounds,
   combined recovery rounds; triage findings before fixing
   (`quality-gate.md` § Handling findings). Zero P0/P1 review findings to
   pass. Write the findings under `## Quality Gate — PROJ-X`, then `bash scripts/chain quality seal <X> <theme>`
   must exit 0.
9. **Handoff.** Framework run: `bash scripts/chain state transition <X> <theme> P5 done`
   and stop; the runner starts P6 as fresh lanes. In-session driver run: go on
   with `5_executing/references/in-session-driver.md`. Interactive run: flush
   context — tell the user to run `/compact` (or open a fresh session, ideally
   on a different model) and then `/6_qa`, and end the turn. Skill 5 never
   performs QA itself and never skips Skill 6.
10. **Learnings.** When a worker or the lead hits a wall and gets past it, the
    workaround goes into the feature folder's `agent.md` immediately, using
    `5_executing/templates/agent-md-entry.md.tmpl`.
11. **Commits.** `feat(PROJ-<X>-PRD-<Y>): implement [US-N …]`,
    `fix(PROJ-<X>-PRD-<Y>): address review findings for [US-N]`,
    `fix(PROJ-<X>): address quality gate findings`.

12. **Scope (linear mode; external mode follows the input contract above).** The PRDs in `2_PRDs/` are the authoritative requirements. The
    plan cross-review and CP1 traced the plan's ACs against them and Skill 6
    tests them again, so the lead opens a PRD story only when a plan/PRD AC
    conflict is suspected.
    When they disagree on AC text, the PRD wins: the brief adds the PRD wording
    as superseding the slice, and `progress.md` notes the drift. Sibling
    PROJs referenced by the plan are dependencies or context only — never
    implement their scope; if a wave depends on an incomplete sibling PROJ,
    stop before that wave and report the blocker.

## Left to the model

The following are stated as invariants, not procedures. A frontier model is
expected to choose the concrete steps.

- **Tests.** Every behavior change is covered by a test that fails before the
  change and passes after it, run by command with the output read. Whether
  that is strict RED/GREEN/REFACTOR per task or a test written alongside the
  implementation is the worker's call. Test-evidence rules (positive control,
  external state, polling, shared-lock caveat):
  `5_executing/references/writing-tests.md` § Evidence Rules.
- **Worker briefs.** A story worker's role is the `Agent Type` column of the
  wave plan (binding; read it with `bash scripts/chain check plan --stories
  <wave-plan>`; spawn exactly the role in the file header and the JSON (plans without
  the column: `implementer`, or the two side roles under `Split: contract`);
  only fix workers choose the type, with that type's role file). Its whole brief is ONE file,
  `context/workers/wave-N/<US-ID>[.backend|.frontend].md`: role rules, project
  context (DESIGN-SYSTEM.md rules for frontend and full-stack, `docs/components.md` as a read-by-path reference), the wave's
  architecture and contracts, and the story slice verbatim. A fix worker gets
  `context/roles/wave-N/<role>.md` of the wave of the touched files plus the
  finding (a cross-wave fix stays one worker; the other waves' role files by
  path), the Quality Gate reviewer `roles/wave-<last>/reviewer.md`. The
  spawn prompt carries the path and only what the file lacks: execution mode,
  ownership set, shared-resource rule, a prior-wave summary from `progress.md`,
  a pointer to `agent.md`, on a plan/PRD AC conflict the PRD wording
  (superseding), and for UI stories the sections of
  `1d_prototypes/implementation-handoff.md`. Never paste the slice, the design
  system, framework skill files or generic checklists; a `compile` failure is a
  plan defect to fix first.
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
  in-family fallback handled by `chain review`. Configure reviewer models no
  weaker than the writer: the runner only refuses identical writer and review
  models, so a weaker reviewer is an operator choice to avoid, and any degraded
  fallback must be reported.
- **Context.** The lead keeps worker summaries short and reads files only for
  the next decision. A session that already carried steps 3–4 (PRDs,
  architecture, plans) starts this skill only after the user ran `/compact` or
  in a fresh session — writing-plans ends its turn for that; if it did not,
  ask for the flush and end the turn.
- **Debugging.** Root cause before fix (`5_executing/references/debugging.md`).
  Repeated failures use the Outer Ralph stages in item 6 or the blocked path.
- **Reviews.** CodeRabbit inside the wave gate (mandatory unless
  `coderabbit.enabled=false` in `wave-gate-config.json`, a switch the user must
  ask for) and the Quality Gate reviewer
  (given its role file by path) are the only Step 5 reviews. No minimalism persona, no six-persona panel;
  those belong to Skill 6. Structure and test quality are judged by the
  project's tools (`complexity_cmd`, `arch_rules_cmd`, `mutation_cmd`); a
  failing tool feeds the recovery stages above.

## Worker brief

```
Implementiere US-<N> (Wave <W>) für PROJ-<X>. Dein vollständiger Auftrag steht
in <specs/PROJ-<X>-<theme>/context/workers/wave-<W>/<US-ID>.md>. Lies ihn
vollständig, bevor du irgendetwas anderes tust, und beginne deinen Report mit
`Brief: US-<N>` (Fix-Auftrag: `Brief: <Finding-ID>`). Die ACs verifiziert der
Lead, führe die AC-Commands nicht aus; nenne im Report je AC die Testdatei
(`AC-1 → tests/x.test.ts`).
<only on a plan/PRD AC conflict: PRD wording, superseding the file's slice>
Execution: <parallel|sequential>, <runtime constraints>.
You own: <files/dirs>. Touch nothing else; escalate if you must.
Shared resources: wrap every migration and auth-consuming command as
  scripts/chain worktree with-shared-lock -- <cmd>. Do not start or stop a dev server.
Prior waves: <one paragraph>. Notes: <path>/agent.md (read first, append walls).
UI (if any): the handoff sections the slice points to
  (1d_prototypes/implementation-handoff.md); component mockups do not replace
  production implementation or required tests.

Every behavior change needs a test that failed before and passes after; run it
and read the output (rules: 5_executing/references/writing-tests.md § Evidence Rules).
After writing, read docs/review-checklist.md by path for Inner Ralph self-review
only; never inject it into an implementer bundle. Do not re-flag Known Debt; flag
changes that spread it. Before reporting, re-read your diff against the story once,
fix what you find, run targeted tests once, then report in ≤300 tokens:
files changed, tests added and their commands, anything unresolved.
Sequential wave: commit as feat(PROJ-<X>-PRD-<Y>): implement US-<N> <task>.
Parallel wave: do not stage or commit; the lead integrates and commits.
```

## progress.md skeleton

The `### Gate Status` block under `## Quality Gate` is rendered by
`chain quality` from the evidence records and checked by `chain quality seal`;
never edit it, write only the findings below it.

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
Spec: <findings, worst> — vs PRD/AC/plan
Standards: <findings, worst> — vs AGENTS.md/conventions

### SonarCloud

### Fixed Issues

### Deferred (user decision)

## Variant Notes
- Complexity column present: yes/no; worker models used per story.
- Recovery stage reached per wave: …
- Mutation (when `mutation_cmd` set): rounds used, survivors carried forward (`Survivors: N`, bullets under `### Carried Forward (Mutation`).
- Static checks (when `complexity_cmd`/`arch_rules_cmd` set): first-attempt
  failures per wave, parallel vs sequential, and the rules that fired
  (input for deciding on per-story checks and on trimming `GUIDELINES.md`).
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
runs use `chain state` for the blocked phase and reason and render the stop report.

## Provider notes

- **Claude:** spawn `skillchain-implementer` /
  `skillchain-frontend-implementer` / `skillchain-backend-implementer` (the
  only implementer agent files, written by `compile`; they pin no model — pass
  `model` from the wave plan's Complexity column on every spawn). With a
  generic type the path in the prompt does the same job; no worker file = run
  `compile`, do not spawn. Background spawns are the default for independent
  workers.
- **Codex:** use `spawn_agent` worker roles with explicit file ownership; no
  `/compact`, so item 9 becomes: suggest a different model, then invoke
  `/6_qa`; skill assets live under `.codex/skills`; the installed synchronizer is `~/.codex/skills/5_executing/scripts/chain sync`.
