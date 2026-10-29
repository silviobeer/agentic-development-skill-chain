---
name: executing
description: "Execute implementation plans user-story by user-story using agent teams, TDD, wave-scoped Ralph verification, wave gates, and an integration-focused Quality Gate before mandatory QA. Full-procedure Step 5 for weaker writer models; the chain default is 5b_executing-large-model with the same contracts. Hosts the Checkpoint 1 and P0 setup subskills (run in subagents) and the framework scripts. Use when the writer model is below frontier level, or for a comparison run, and: (1) wave plans exist and need CP1 approval, P0 setup, and execution, (2) an approved plan is ready for execution or a run must resume, (3) feature tasks need to be implemented with TDD. Not for: planning, architecture, or requirements."
---

# Executing

## External handoff inputs (conditional)

For `external-handoff.json`, read [the receiving input contract](../2e_handoff-refinement/references/input-contract.md). Verify input hashes, accepted team revision, repository scope and applicable readiness before CP1, setup and resumed work. References below to authoritative PRDs mean the resolved product baseline plus explicit approved responses in this mode; engineering constraints remain separately traceable. Never edit received PRDs, translate source ACs, or use a model review/CP1 decision as product approval. Send newly found product gaps through `handoff-refinement`; block affected tasks pending an explicit response and revalidate affected artifacts. Unresolved product questions cannot be auto-deferred as engineering debt.

Execute one repository per run: its own bound checkout/worktree, state, tests and PR. A prompt that merely says `cd` does not bind a new app session. Verify pinned dependency revisions before dependent waves; preserve integration evidence and outstanding cross-repo work in the coordination location. Repo gates are repo-level results, not whole-feature acceptance. Worker briefs must include applicable approved responses and engineering constraints from the resolved context.

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


> The chain's default Step 5 is `5b_executing-large-model`: same gates, state and
> handoff contracts, less procedure. Use this skill when the writer model is
> below frontier level or for a comparison run. Both run the subskills in
> `subskills/` and the scripts in `scripts/` from this folder.

Orchestrate implementation by creating an agent team and spawning teammates per user story. Workers own code, test, and fix edits; the lead owns decomposition, dispatch, integration, deterministic verification, gates, and operational records. After every worker in a wave finishes, the lead runs one wave-scoped Outer Ralph pass.

**Agent Teams vs Subagents:** This skill uses agent teams so that teammates can communicate with each other during parallel waves. When one teammate discovers a gotcha, it broadcasts to all others immediately — no waiting for the wave to finish. For sequential single-US waves, a regular subagent is fine.

**One PROJ at a time:** The executing loop runs per PROJ. Each PROJ has multiple wave-plan files (`PROJ-<X>-wave-1-plan.md`, `PROJ-<X>-wave-2-plan.md`, …) that are read in order. A single `5_progress/PROJ-<X>-progress.md` tracks all waves. When the user provides multiple PROJ plans, execute each PROJ fully (all waves → Quality Gate → QA) before starting the next.

**Decomposed PROJs:** If the plan references sibling PROJs, treat them as dependencies or context only. Do not implement sibling scope from the current PROJ's waves. If a wave depends on an incomplete sibling PROJ, stop before that wave and report the blocker. Shared design-language files from sibling PROJs may be consumed, but they do not authorize building sibling workflows.

## Context economy — always delegate to subagents

The orchestrator (main agent) must stay lean so it survives the full PROJ → QA → docs chain. **Delegate every code, test, and fix edit when subagents are available and delegation is permitted; the main agent coordinates.**

- **CP1 + P0:** the checkpoint and setup subskills run in spawned subagents; the orchestrator holds only the review point list and the verdicts.
- **CP1 structure:** repeat PRD, architecture and plan structure checks before approval; already approved P5 runs keep their legacy context behavior.
- **US implementation:** always spawned as `skillchain-implementer` / `skillchain-backend-implementer` / `skillchain-frontend-implementer` (`compile` writes them from `manifests/roles/`; no other implementer agent files exist), each reading its worker file by path. Never write code inline.
- **Wave-scoped Outer Ralph:** the main agent owns deterministic commands and evidence; workers own every resulting fix.
- **PROJ-end Ken review:** spawned in Skill 6, not read inline. Ken no longer runs per wave — only once against the assembled PROJ.
- **Quality Gate (Step 9):** `skillchain-reviewer` plus optional `sonar-cli` quality input run as delegated streams, not inline review by the orchestrator.
- **Fix-spawns:** every Critical/High finding is fixed by a spawned subagent, clustered by file.
- **Even trivial or single-file edits:** delegate; there is no size exception.
- **Concurrency:** dispatch independent tasks with disjoint ownership together; serialize dependencies and overlapping ownership.
- **Integration corrections:** send the exact failure to a follow-up worker; the lead does not patch it directly.
- **Fallback:** edit locally only when subagents are unavailable or delegation is prohibited, and report the reason explicitly.

Subagents return a ≤ 300-token summary; raw diffs/logs stay in their context and die with them. The orchestrator keeps only IDs, verdicts, and next-step pointers. If the main agent has to read more than ~3 source files directly for a decision, it's the wrong tool — spawn an `Explore` or domain agent instead.

**Run in background by default.** Spawn all subagents with `run_in_background: true` unless the orchestrator genuinely cannot proceed without the result. Background spawns let the orchestrator dispatch the next wave of work immediately and get notified on completion — parallel fan-out without blocking. Foreground is the exception, not the norm. Dependencies like `implementer → Ralph → Build → Gate` still run sequentially (the orchestrator awaits each stage), but within a stage every independent spawn goes to background in a single parallel batch.

---

## FIRST ACTION (before reading any plan)

<HARD-GATE>
Before doing ANYTHING else — before reading plans, before spawning any agent:
0. If this session already ran steps 3–4 (it holds the PRDs, architecture and plans), do not continue in it: tell the user to run `/compact` (or open a fresh session) and re-invoke this skill, then end the turn. A model cannot compact its own context, and everything Step 5 needs is on disk. Writing-plans normally ends its turn for exactly this; this step is the backstop.
1. **CP1 + P0 — run the checkpoint and setup subskills as subagents.**
   This skill owns Checkpoint 1 and P0; their procedures live in
   `subskills/checkpoint.md` and `subskills/setup.md` and run in spawned
   subagents so this context keeps only verdicts. If
   `specs/PROJ-<X>-<theme>/state.json` is missing, ask the user once:
   framework run (create it with `bash ~/.claude/skills/5_executing/scripts/chain state init <X> <theme>`, then route
   as below — never implement past an unsealed CP1) or standalone run
   (step 2). If it exists, route on
   `bash ~/.claude/skills/5_executing/scripts/chain state get <X> <theme> '.phase + ":" + .status'`
   (the installed helper — the repo copy may not exist before P0):
   - `CP1:pending` / `CP1:running` / `CP1:blocked` → **checkpoint** (`subskills/checkpoint.md`,
     CP1 roles): spawn the prepare subagent and wait for it. `sealed` → go on.
     Otherwise walk its points with the user yourself, one outcome per point,
     then spawn the apply subagent with the decisions verbatim; repeat until
     it returns `sealed`. Never approve on the user's behalf.
   - `CP1:approved`, `P0:running`, `P0:blocked` → **setup**
     (`subskills/setup.md`): spawn ONE subagent with `<X> <theme>` and this
     checkout's path, and wait for it. `P0:blocked` back → STOP and report the
     stop reason; after the fix, re-invoking this skill resumes P0
     idempotently. Relay any defaulted decisions it lists, then `cd` into the
     returned `.worktree.path`.
   - `P0:done` (fresh PROJ) or `P5:*` (resume) → continue below. The phase
     runner arrives here directly; its P0 lane already ran setup.
   - All preflights (permissions, `.coderabbit.yaml` unless `coderabbit.enabled=false`, Supabase/browser/CLI +
     auth) belong to setup's `chain check preflight`; do NOT re-run them here.
   - Verify the current directory is `.worktree.path` from state. P0 owns the
     persistent PROJ worktree and the runner re-executes there; do not implement
     from the control checkout. Dependencies are isolated, while `.env.local`,
     development data, and hosted-auth limits are deliberately shared.
   - **Unattended handoff, once, on `P0:done`:** follow `references/unattended-handoff.md`
     in `.worktree.path` (one probe, at most one question: unattended, in this session, or interactive).
   - **On every implementation start or resume**, after verifying the worktree path and before launching workers, run `bash ~/.claude/skills/5_executing/scripts/chain sync`. Use the installed command, not a potentially stale project copy. A non-zero result blocks implementation: reconcile reported differences against installed sources, test adaptations, and rerun with `--adopt <reviewed-path>` for each resolved file. Never overwrite or blindly adopt project customizations.
   - Commit `.skillchain-helpers.json` and changed managed helpers/templates before implementation. If the refresh changed any helper, template or role manifest, run `bash scripts/chain render context compile <X> <theme> --wave <N>` (N = the wave about to start) in the same step as `sync-framework` — it rewrites the worker and agent files. Start no worker between `sync` and `compile`, and none after a non-zero `compile` until a rerun exits 0 (lead discipline: a worker holding a path to an outdated file is not caught). This new commit invalidates old gate evidence; never refresh during workers or a gate.
   - Then mark the phase if needed: if state shows `P0:done`, run `bash scripts/chain state transition <X> <theme> P5 running`.
2. **Standalone fallback (no state.json — manual run without the framework):**
   run the legacy preflights inline before wave 1: (a) permission preflight —
   `bash scripts/merge-project-settings.sh` (copy from
   `~/.claude/skills/5_executing/scripts/` if missing, commit); full bypass
   (`claude --dangerously-skip-permissions`) only as an explicit user opt-in
   (`subskills/setup.md` §2);
   (b) `.coderabbit.yaml` at repo root, unless `coderabbit.enabled=false` (copy
   `~/.claude/skills/5_executing/references/coderabbit-template.yaml`, adjust
   `path_filters`); (c) tool checks — `jq`, `coderabbit` (unless disabled), browser automation
   when `wave-gate-config.json` has `frontend_routes`, Supabase CLI/MCP when
   the project uses Supabase. Any hard tool missing → STOP.
3. Record BASE_SHA: from `state.json` (`.base_sha`, set by the setup subskill) — standalone: `git rev-parse HEAD`
4. Create `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md` using the template below — if P0 already wrote it (negative controls, defaulted decisions), add the missing template sections and keep its content; never overwrite
5. Store BASE_SHA in progress.md

This file is your single source of truth for the whole PROJ. Update it after EVERY action.
If progress.md does not exist, you have skipped this step — STOP and create it now.
</HARD-GATE>

---

## Wave Completion Gate

<HARD-GATE>
Before spawning ANY teammate for a new wave N+1, you MUST run the Wave Gate script — it MUST exit 0.

Doc-input collection is owned by Skill 7. Do not fill documentation summaries or Post-Wave-Notes blocks during Skill 5. Keep `progress.md`, commit messages, and `agent.md` accurate; Skill 7 harvests those sources after QA.

```bash
bash scripts/chain gate wave <N> <PROJ-X> <theme>
```

Exit code ≠ 0 → STOP. For `blocked_external` / exit 76, retain the AC and
wait for its declared prerequisite (see Step 4); do not dispatch a code repair.
For other failures, fix the failing check and rerun until green. Only then
spawn the next wave's teammates.

For a provider signature only (`over_request_rate_limit`, `Request rate limit reached`, or HTTP/status 429), the gate pauses and retries that AC once. For auth-consuming browser commands, `auth_budget.rate_limit_evidence_cmd` may establish the same fact from server/provider evidence outside the Playwright stream; its output is retained. A second occurrence is red infrastructure, not a reason to widen limits. Other failures — including a test name containing “rate limit” — are ordinary red ACs.

Before P0 seals an auth-budget project, `bash scripts/chain gate wave --auth-budget-negative-control 1 <PROJ-X> <theme>` must return the configured exhausted exit code and persist `infrastructure_failed`. It exercises the configured hooks with `SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1` and never drains a real hosted bucket.

The script validates:
1. **Current wave ACs** — every structured `ac_commands` entry exits 0 and reports a non-empty selected-test count. A cached pass requires the same command, test files, auth classification, gate-config fingerprint, positive selection, and committed `verified_head`; equivalent commands may share execution across AC IDs, with evidence recorded for each ID. Changed or uncommitted code cannot be certified.
2. **Declared targeted regressions** — every `regression_commands` entry covers shared behavior affected by this wave and runs after the current ACs and before smoke; selection-aware entries must prove that they selected tests. Broad hosted-auth/browser suites belong in `phase_commands`, not every wave.
3. **Smoke Test** — the configured dev server is reused or started by the gate. Anonymous routes must match URL and characteristic content; redirects are failures. Protected routes require auth state or authenticated E2E coverage.
4. **Component registry** — `chain render registry --check` passes where applicable.
5. **Static checks (optional)** — `complexity_cmd` and `arch_rules_cmd`, run last in the AC pass (`--ac-only` and the full gate) once the ACs are green; contract in `4_writing-plans/references/wave-gate-config.md`. Absent keys are skipped and noted in the PASSED block.
6. **Build** — `build_cmd` from config exits 0; runs in parallel with CodeRabbit as the last phase.
7. **CodeRabbit** — every attempt archives raw and normalized evidence, validates the finding count, ingests it, and then requires zero cumulative open blocking findings in the ledger. With `coderabbit.enabled=false` in `wave-gate-config.json` (default on; set only on explicit user request) this review is skipped loudly: the gate logs `CodeRabbit: DISABLED by wave-gate-config`, the PASSED block says the same instead of `attempt N ingested`, and the build still runs. No automatic code review then runs in the wave gate; ACs, regressions, smoke, static checks, build and the PROJ-end Quality Gate remain.

The wave gate does not run Sonar. The top-level `sonar_cmd` runs once, at the PROJ-end Quality Gate (Step 9) after all waves pass — not per wave.

A green wave gate proves the current wave's ACs plus its declared broad
regression suite. It does not claim that every earlier AC command was rerun.

On success the script appends a `### Wave N Gate — PASSED` block with timestamp to `progress.md`. This is the canonical proof that the wave is done — no manual checkbox editing.

**Framework runs (state.json exists):** after every green gate, update the machine state too — `bash scripts/chain state set <X> <theme> .waves '{"current": <N>, "total": <M>, "stories": {…per-US status…}}'` (merge with the existing block). The gate pipes its normalized CodeRabbit findings into the ledger when `scripts/chain findings` is present; Sonar evidence remains in the configured system — never re-enter either by hand.

**If a framework helper is missing:** run `bash ~/.claude/skills/5_executing/scripts/chain sync` to restore the managed inventory, resolve any reported conflicts, and commit before running the gate. Standalone runs use the same synchronization before their first wave.

**If jq, coderabbit, or agent-browser are missing:** the script prints a clear error and exits non-zero. Install them, do not work around the gate. (`coderabbit` is not required when `coderabbit.enabled=false`.)

**Optional external enforcement (Claude only, not shipped with this repo or its installers):** if you keep a personal global PreToolUse hook at `~/.claude/hooks/wave-gate-enforcer.js`, it can inspect every `Agent` spawn. When `subagent_type` is a `skillchain-*implementer` type and the prompt mentions Wave N with N > 1, it refuses the spawn unless `### Wave N-1 Gate — PASSED` exists in `5_progress/PROJ-<X>-progress.md`. The script (`chain gate wave`) is the primary and binding gate; without that hook there is no second fail-safe, so the lead must not start wave N+1 before the gate exited 0.
</HARD-GATE>

---

## Memory Files

Two files are maintained throughout execution:

### `progress.md` (short-term memory)
Created at the start of execution, lives in `specs/` alongside the plan.
Tracks granular build state — task completion, test status, AC verification, and blockers.
Updated after every task, after the initial wave verification and each recovery stage, and whenever a blocker occurs.

```markdown
# PROJ-X Progress

## Status: [in progress | blocked | complete]
## Current Wave: [N]
## BASE_SHA: [commit hash before first change]

---

## US-1: [title] — [pending | in progress | complete]

### Tasks
| Task | Tests Written | Tests Passing | Done |
|------|:---:|:---:|:---:|
| 1.1 [name] | ✗ | — | ✗ |
| 1.2 [name] | ✓ | ✓ | ✓ |
| 1.3 [name] | ✓ | ✗ | ✗ |

### Acceptance Criteria
| AC | Text | Verified |
|----|------|:---:|
| AC-1 | [verbatim from spec] | ✓ |
| AC-2 | [verbatim from spec] | ✗ |
| AC-3 | [verbatim from spec] | — |

### Wave-Scoped Ralph Evidence
- Initial pass: AC-1 PASS; AC-2 FAIL — [exact failure reason]
- Recovery stage: normal fix round 1 → follow-up worker dispatched
- Invalidated: AC-1 — evidence from [old HEAD] void after the correction commit (reuse only at the same committed HEAD and gate-config fingerprint)
- Rerun: AC-1 PASS, AC-2 PASS — [exact command, positive selection, verified HEAD]
- Commit: `feat(PROJ-<X>-PRD-<Y>): implement US-1 [name]`

---

## US-2: [title] — pending
*(blocked by US-1)*

---

## Quality Gate — PROJ-X

<!-- quality-status: rendered by chain quality from 5_progress/quality-*.json, never edit -->
### Gate Status

| Check | Status |
|---|---|
| Code Review | pending |
| Mutation | pending |
| Build | pending |
| Tests | pending |
| Lint | pending |
| SonarCloud | pending |
<!-- /quality-status -->

Each `chain quality` action re-renders the block above from the `5_progress/quality-*.json` records (`passed`, `ran`,
`ran (N survivors carried forward)`, `ran (N carried forward)` (Sonar), `skipped (…)` or `pending`). Never edit it; write only the findings below.

### Code Review
Spec: <findings, worst> — vs PRD/AC/plan
Standards: <findings, worst> — vs AGENTS.md/conventions
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| P0 Critical | 0 | 0 | 0 |
| P1 High | 0 | 0 | 0 |
| P2 Medium | 0 | 0 | 0 |
| P3 Low | 0 | 0 | 0 |

### SonarCloud (once per PROJ, via top-level `sonar_cmd`)
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| Critical/Major | 0 | 0 | 0 |
| Minor | 0 | 0 | 0 |
| Info | 0 | 0 | 0 |

### Fixed Issues
- [severity]: `file:line` — [issue] → fixed in [commit]

### Deferred (user decision)
- [severity]: `file:line` — [issue]

---

## Open Blockers
- US-7: [exact reason] — escalated to user [timestamp]
```

**Update rules:**
- Subagent updates task rows after each TDD cycle (tests written → tests passing → done)
- Main agent updates AC rows after the initial wave pass and every recovery stage
- `—` means not yet attempted; `✗` means attempted and failing; `✓` means passing
- Wave-Scoped Ralph Evidence records canonical AC, command, positive selection, committed HEAD, reuse/invalidation, and verbatim failure output

### `agent.md` (long-term memory)
Lives in the feature's **source folder** (e.g., `src/features/deliveries/agent.md`).
Written when any agent hits a wall and finds a workaround — or discovers something a future developer must know.
Written like notes to a developer who has never seen this code.

```markdown
# Agent Notes — [Feature Name]

## Gotchas

### Supabase RLS blocks server actions without explicit role claim
Discovered during US-4 (activate delivery). Server actions run as `anon` unless
`set role authenticated` is called explicitly. Workaround: call `supabase.auth.getUser()`
at the top of every mutating server action before any DB write.

### Zod refinements don't run on optional fields when undefined
If a field is optional and undefined, `.refine()` is skipped entirely.
Use `.optional().refine()` vs `.refine()` on the base type — different behavior.

## Patterns That Work Well
...

## Dead Ends (don't try these again)
...
```

Write to `agent.md` immediately when a learning occurs — not at the end. Future subagents in the same session read it at the start.

---

## Input

Read lazily — the lead's context has to last the whole PROJ, and nothing below is read up front "just in case":

**At PROJ start** — only the wave shape, sliced from the plans themselves (each plan's `## User Stories in this Wave` table and `## Execution` block — stories, agent type, complexity, dependencies, mode), and the wave 1 plan:

```bash
for p in specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-*-plan.md; do bash scripts/chain render slice "$p" "User Stories in this Wave"; bash scripts/chain render slice "$p" Execution; done
```

**At each wave start** — only that wave's plan, `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md`. Its lead-facing header (`## User Stories in this Wave`, `## Execution`) drives dispatch. Each `## <US-ID>` section is that worker's slice — ACs, smoke test, UI Implementation Notes, tasks with TDD cycles and file paths, UI handoff constraints, gotchas — and is compiled verbatim into the worker's file under `## Your Story` (Step 2). Never re-read earlier waves' plans: what previous waves implemented comes from the wave shape plus `5_progress/PROJ-<X>-progress.md`.

**Linear-mode PRDs** — `specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-*.md` stay the authoritative requirements source. The plan's ACs were traced against them by the plan cross-review and CP1, and Skill 6 tests the PRD ACs again, so open the matching PRD story only when a plan/PRD AC conflict is suspected (an AC in the slice reads paraphrased or incomplete, or a worker or the Outer Ralph pass questions one). If plan and PRD disagree on AC text, the PRD wins: add the PRD wording to the spawn prompt, marked as superseding the file's slice, and log the drift in `progress.md`.

**Architecture** — workers get the implementer view of `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md` (their wave's decision Summaries, compiled) through their worker file. The lead opens the full file only for a cross-PRD design question that the slice and the wave shape do not settle.

**UI implementation handoff** — for UI PROJs, read `specs/PROJ-<X>-<theme>/1d_prototypes/implementation-handoff.md` before the first wave with UI stories. It is the compact source for project mode, component reuse, new component candidates, design tokens, interaction contract, implementation tolerance, and demo-only mockup exclusions.

The PRDs define WHAT success means. The wave plans define HOW to get there. The UI handoff defines how to preserve the approved interface shape without treating mockups as pixel-perfect production specs. Resolve screen sources and preview instructions from the handoff (legacy HTML references remain valid). Component mockup code does not replace production implementation or required tests.

**When multiple PROJ plans are provided:** Execute one PROJ fully (all waves → Quality Gate → QA) before starting the next. Each PROJ has its own `5_progress/PROJ-<X>-progress.md`.

---

## Per-PROJ-X Execution Loop

For each PROJ-X plan (in order):

```
0. Record BASE_SHA (git rev-parse HEAD)
1. Create specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md
2. Execute waves (Steps 1–5 below)
3. One wave-scoped Outer Ralph pass, then the wave gate (Steps 4 and 8)
4. Integration-focused Quality Gate after all waves (Step 9)
5. Handoff directly to mandatory Skill 6 QA (Step 10)
6. Mark Step 5 complete
→ Next PROJ-X
```

After ALL PROJ-X plans complete: Final Summary Report (Step 9).

---

## Orchestration (per PROJ-X)

### 0. Record BASE_SHA

Before any implementation changes, record the current commit:
```bash
git rev-parse HEAD
```
Store this in `progress.md` as `BASE_SHA`. It is used later by the Quality Gate to diff only this feature's changes.

### 1. Read the dependency map

Extract waves from the wave shape sliced at PROJ start (see Input; the full plans are read one wave at a time):

```
Wave 1: US-1                    → 1 teammate
Wave 2: US-2, US-7 (parallel)   → 2 teammates simultaneously
Wave 3: US-3                    → 1 teammate
...
```

### 2. Before each wave: read `agent.md`, compile the worker files

Read wave N's plan now — this wave's plan only (see Input).

If `agent.md` exists in the source folder, read it before spawning teammates.
Include relevant sections in the teammate prompt so they don't repeat known dead ends.
(Implementers additionally follow the agent.md read/write protocol in `references/implementer.md`;
entries are rendered with `templates/agent-md-entry.md.tmpl`.)

Compile wave N's worker files: one per story (`context/workers/wave-<N>/<US-ID>.md`) and one per role without a story (`context/roles/wave-<N>/<role>.md`, for reviewers and fix workers). The architecture view carries only this wave's decisions and `api-contracts-own-wave` only its contracts. `compile` also rewrites the `skillchain-*` agent files; it keeps no lock, no hash bookkeeping and no `chain state` entry (each file's first line carries the plan hash):

```bash
bash scripts/chain render context compile <X> <theme> --wave <N>
```

Exit ≠ 0 (budget breach, unassignable story, outdated local manifest, write error): start no worker until a rerun exits 0. Exit 0 is not enough: read the warnings too (e.g. `.claude/settings.json is not valid JSON — left unchanged`: repair, rerun; see `subskills/setup.md`). The file's first line carries the plan hash; after a plan change, rerun `compile`.

### 2a. Mark wave start with a git tag

<HARD-GATE>
Before spawning any teammate for wave N, tag the current HEAD as the wave base. `chain gate wave` resolves this tag to scope the CodeRabbit diff. Without `WAVE_BASE_SHA` or this tag, the gate fails hard. This prevents accidentally reviewing broad branch history.
</HARD-GATE>

```bash
git rev-parse -q --verify "refs/tags/wave-${WAVE}-start-PROJ-${PROJ}" >/dev/null \
  || git tag "wave-${WAVE}-start-PROJ-${PROJ}"
```

One tag per (wave, PROJ) pair. Tags are local-only; do not push. If neither `WAVE_BASE_SHA` nor `wave-${WAVE}-start-PROJ-${PROJ}` exists, `chain gate wave` fails hard. There is no `HEAD~20`, commit-message, or root-commit fallback. An existing tag stays: `chain gate wave` sets the next wave's tag when a gate passes, and on a resume the tag must keep marking the wave base, otherwise workers' commits fall out of the CodeRabbit diff. Delete and re-create it (`git tag -d "wave-${WAVE}-start-PROJ-${PROJ}"`) only when the wave restarts from a reset checkout.

### 3. Create team and spawn teammates for the wave

Before dispatch, read [references/worker-lifecycle.md](references/worker-lifecycle.md)
for worker status/stop/replacement and shared DB/browser scheduling. Assign both
file ownership and resource windows, including the wave's browser scenarios.
Use its verification-cost procedure when browser/DB waits dominate: measure
selection and wait time, establish fixture isolation, then opt independent
lifecycles into shared mode. Existing auth-consuming gate commands remain
exclusively locked; a helper refresh alone does not parallelize those suites.

All implementation work is worker-owned when delegation is available. The lead decomposes the wave, assigns explicit disjoint ownership, dispatches workers, integrates their commits, runs deterministic verification and gates, and maintains operational records. **For waves with 2+ independent user stories:** create an agent team and dispatch them concurrently. Serialize dependent stories or overlapping ownership.

**Honor the plan's `## Execution` block before spawning.** `sequential` means
dispatch exactly one US at a time even when `Can start when` says both are
ready. For any frontend wave, the lead owns the dev server: start and stop it
once for the round; agents reuse it and never start or kill one. For a parallel
wave, the lead also owns every other declared shared resource and the control
plane: `progress.md`, staging, and commits. Include the execution mode, runtime
constraints, and these ownership rules in every spawn prompt.

The development database and hosted-auth budget are shared across the PROJ
worktrees. Every database migration command—including one delegated to a story
agent—and every other explicitly `auth_consuming` command must therefore be
wrapped as `scripts/chain worktree with-shared-lock -- <command>`. Put that exact
constraint in the agent prompt; never let parallel agents run migrations
outside the project lock. That lock only stops concurrent collisions;
`chain gate wave` separately re-checks at the start of every wave that this
worktree's own `supabase/migrations/` still matches what the shared DB has
actually applied (`scripts/chain check migrations`), since a sibling
worktree can advance the schema between waves with no lock involved at all.

**The story worker's role comes from the plan, not from your judgment.** The `Agent Type` column of `## User Stories in this Wave` is binding. Read it with `bash scripts/chain check plan --stories specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md` (JSON per story: `role`, `split`, `complexity`, `fallback`) and spawn that role (`implementer`, `frontend-implementer`, `backend-implementer`; `skillchain-<role>` where the session can spawn P0's agent types). `Split: contract` is one backend and one frontend worker, each with its own file; `Split: fan-out` is one story file shared by all fan-out workers. For every worker file spawn exactly the role named in the file's first line (`role <role>`) and in the `--stories` JSON. Old plans without an `Agent Type` column (`fallback: true`; `compile` warns) get `implementer` for a story without split and the two side roles (`backend-implementer`, `frontend-implementer`) for `Split: contract`. Only fix workers choose the type themselves, and they take the role file of the type they chose:
- fix touches only UI (components, pages, styling) → `frontend-implementer`
- fix touches only server-side (API, DB, server actions) → `backend-implementer`
- both, or unclear → `implementer` (generic)

**Every worker reads one file, named by path in its spawn prompt** (the normal case, not a fallback):
- Story worker: `specs/PROJ-<X>-<theme>/context/workers/wave-<N>/<US-ID>.md` (`<US-ID>.backend.md` / `<US-ID>.frontend.md` under `Split: contract`).
- Fix worker without a story: `specs/PROJ-<X>-<theme>/context/roles/wave-<N>/<role>.md` of the wave the affected files belong to. A fix across waves stays one worker; add the other waves' role files by path.
- Missing file or a wrong one: rerun `compile <X> <theme> --wave <N>` (`show <X> <theme> <US-ID>` / `show <X> <theme> --wave <N> <role>` prints a file); never hand-assemble the context. Where the session cannot spawn the `skillchain-<role>` agent types, use the normal agent type; the path in the prompt does the same job. A `general-purpose` spawn gets no file unless its path is in the prompt. `micro-fixer` and `explore` get none.

**Choose the right model per US (from the wave plan's `Complexity` column):**
Read the `Complexity` column in the wave plan's "User Stories in this Wave" table. Pass the value as the `model` parameter on the `Agent` spawn so the teammate runs on the right brain for the job.
- `sonnet` → `model: "sonnet"` (default for standard US)
- `opus` → `model: "opus"` (architecture-sensitive: state machines, concurrency, cross-feature contracts, migrations, auth/session, money, crypto)

Haiku is deliberately not in the menu — US-level work loses too much fidelity on it. If the wave plan is missing the `Complexity` column (older plan format), default to `sonnet` and log a one-line note in `5_progress/PROJ-<X>-progress.md` so the planner can retrofit it.

```
Create an agent team for Wave N of PROJ-X.

Spawn teammates:
- "us-2" using the skillchain-frontend-implementer agent type, model: "sonnet": [US-2 spawn prompt: path + ownership]
- "us-7" using the skillchain-backend-implementer agent type, model: "opus": [US-7 spawn prompt: path + ownership — this one touches auth/session]

Require plan approval for each implementer before they make changes.
```

**For waves with a single user story:** Use a regular subagent (no team overhead needed). Use the role from the plan's `Agent Type` column. Local editing is permitted only when delegation is unavailable or prohibited; report that reason explicitly.

Spawn prompt for a story worker (about six lines; everything else is in the file). Keep "Wave <N>" in the text: the optional global `wave-gate-enforcer` hook (if installed) reads the wave number from the prompt and abstains without it:

```
Implementiere <US-ID> (Wave <N>). Dein vollständiger Auftrag steht in `<Pfad>`. Lies ihn
vollständig, bevor du irgendetwas anderes tust, und beginne deinen Report mit
`Brief: <US-ID>`. Nenne im Report je AC die Testdatei (`AC-1 → tests/x.test.ts`).
Du besitzt `<Dateien>`. Ausführung: <parallel|sequential>, <Laufzeit-Constraints, Shared-Lock- und Dev-Server-Regel>.
Prior waves: <Zusammenfassung aus progress.md>.
```

A fix worker's prompt names the role file the same way (plus the other waves' role files by path for a cross-wave fix), carries the finding, and asks for a report starting with `Brief: <Finding-ID>`.

Pass to each teammate (via `references/implementer.md` template):
- **The path of its worker file** (above). It holds the role rules, project context, this wave's architecture and API contracts, and `## Your Story` — the story slice with ACs, smoke test, UI Implementation Notes, tasks, UI handoff constraints and gotchas, verbatim from the plan. Never paste or re-type any of it. A `compile` failure (story ID missing or duplicated, unassignable role) is a plan defect: stop and fix the plan, never hand-copy.
- What only the lead knows: execution mode, runtime constraints, file ownership and the shared-lock and dev-server rules (above)
- What previous waves implemented — a short summary from `progress.md` (the wave shape is lead-only, it is not in the worker file)
- Relevant sections from `agent.md`
- The report asks per AC for the test file (`AC-1 → tests/x.test.ts`) and starts with `Brief: <US-ID>`. This is a hint for the lead; the lead still runs the AC commands. A report without `Brief:` means the file was not read: send the worker back.
- **Only on a plan/PRD AC conflict:** the PRD wording, marked as superseding the file's slice.
- **If the US touches UI:** the matching sections from `1d_prototypes/implementation-handoff.md` that the slice's UI Implementation Notes point to but do not quote:
  - Project mode (`greenfield`, `brownfield`, `hybrid`)
  - Mockup file reference and selected UI direction
  - Existing components/tokens to reuse
  - Approved new component candidates
  - Required interaction contract and responsive behavior
  - Implementation tolerance and demo-only exclusions
- **If the US touches UI:** the design system baseline is `docs/DESIGN-SYSTEM.md` (rules) plus `docs/components.md` (inventory). The `frontend-implementer` and the full-stack `implementer` file already contain the rules of `docs/DESIGN-SYSTEM.md` and a mandatory read-by-path reference to `docs/components.md` (the inventory is deliberately not embedded) — do not paste either, that pays the token budget twice. The `backend-implementer` file has neither; UI work in a story belongs to a frontend or full-stack role. The teammate reuses registered components — never one-off styled elements.
- **If a US needs a component the catalog does not have:** the teammate escalates instead of styling a one-off. The main agent runs the extension procedure from `1c_frontend-design` → *Extending The Design System* (variant before new component, confirm with the user, then catalog + `docs/components.md` + `/dev/components` showcase), then the teammate composes the new entry. A component that reaches QA without a catalog and registry entry is a Critical bug (`6_qa` hard-checks this).
- **Do not paste framework skill files** (Tailwind, Next.js) or generic checklists into the prompt: the model knows the stack, and the project's rules arrive through `docs/DESIGN-SYSTEM.md` and `docs/GUIDELINES.md` in the worker file. Pasting them pays those tokens per worker for nothing.

**UI implementation rule:** Existing app components and design tokens take precedence over standalone mockup approximations. Preserve the selected layout direction and interaction contract; do not replace a sidepanel with a modal, a wizard with a single page, or a brownfield component with a one-off styled element unless the user explicitly approved that change.

Wait for all teammates in the wave to complete before running Outer Ralph. If integration or verification exposes a correction, dispatch it to a follow-up worker; do not absorb the edit into the lead. Clean up the team after each wave.

### 4. Wave-scoped Outer Ralph (AC verification)

**Wave closure checklist — parallel and sequential modes alike:**
1. Collect all story `Smoke Test` blocks and match each route/behavior to gate
   smoke or the current wave's authenticated scenario coverage.
2. If scenarios are missing, dispatch their implementation to the named browser
   owner after DB workers release the shared resource. Reuse an existing story
   worker when appropriate; a separate browser worker is not mandatory.
3. Integrate and commit scenario files, exact command/route mappings and any
   selection-only hook. Do not append unrelated waves to a growing shared suite.
4. Only then run AC-only Ralph below; Phase 0 checks declared selection hooks.
   A successful route load alone does not prove the story's interaction.

<HARD-GATE>
After ALL workers in the wave report back and their changes are integrated, run one wave-scoped Outer Ralph pass. Run no story-scoped Outer Ralph pass. Do not proceed to the wave gate until the bounded recovery below passes or reaches the existing blocked path.
</HARD-GATE>

The lead starts the pass through the gate's AC-only mode so evidence is written in the canonical cache schema:

```bash
bash scripts/chain gate wave --ac-only <N> <X> <theme>
```

It runs each uncached AC sequentially under the gate's timeout, auth-budget, pacing, and rate-limit controls. Ordinary AC failures are all evidenced before the pass exits non-zero so disjoint repairs can be batched; infrastructure and exhausted auth budgets still stop immediately. Each evidence record binds the canonical AC ID, task, exact command, test files, positive selected-test count, and committed `HEAD`.

```
run bash scripts/chain gate wave --ac-only <N> <X> <theme>
for normal_fix_round in 1..2:
  cluster failures by disjoint ownership
  dispatch correction workers concurrently where safe
  commit corrections, then rerun the same --ac-only command
if failures remain:
  dispatch one fresh diagnostic worker that makes no edits
  dispatch a different implementer to apply the diagnosis
  commit the correction, then rerun the same --ac-only command
if failures still remain: use the existing blocked-run evidence path
```

**Rules for wave-scoped Ralph:**
- Checks must be **deterministic** — run actual test commands, read actual output. No subjective judgment ("this looks like it works").
- Test-evidence rules (positive control, external state, polling matchers, shared-lock descriptor caveat): `references/writing-tests.md` § Evidence Rules.
- Failure output is passed **verbatim** to correction and diagnostic workers — not summarized or interpreted.
- Reuse requires the same committed `HEAD` and complete gate-config fingerprint. Identical AC commands with matching `test_files` and `auth_consuming` share successful execution across AC IDs, with separate evidence for every ID. Identical failed/empty/timed-out commands also share their result within one AC-only invocation, but failures are retried on the next invocation; infrastructure and auth exhaustion still stop immediately. Every correction commit invalidates reuse; no cross-HEAD impact inference is supported. Remove cached Ralph evidence after dependency, runtime, or environment changes.
- Recovery has exactly four stages: normal fix round 1, normal fix round 2 with fresh workers, fresh diagnosis, then a different diagnosis-driven implementer. Do not add retries or silently weaken an AC.
- A static-check failure is a red AC: same four stages, tool output verbatim; the rerun re-proves the ACs on the new `HEAD`. Gate failure, not a ledger finding.
- If diagnosis finds an invalid or contradictory AC, record the evidence and use the existing blocked/escalation path.
- Exit 76 with `blocked_external` is a missing declared prerequisite, not a
  code defect and not a green AC. Keep the test and plan scope; no repair rounds,
  invented approval, PASSED block or next-wave unlock. Use `chain state` for the
  blocked phase/stop reason and render the stop report. Rerun the unchanged gate
  when the prerequisite arrives: readiness is rechecked and its AC is not cached.
  PR, stop and morning renderers include declared prerequisites; final summaries
  must name each unresolved AC, reason, decision author/date and evidence path.
- The normal wave gate reuses matching AC-only passes. Regression reuse requires explicit `reuse_passed: true` and is limited to deterministic, non-auth local commands independent of external state. Other regressions and remaining gate phases still run. Any committed or non-evidence uncommitted change prevents reuse.

Update `progress.md` after the initial pass, each recovery stage, each reuse or invalidation decision, and the final result.

### 5. Build check — handled by `chain gate wave`

Do not run an extra build between Ralph and the wave gate. Build is intentionally centralized:
- **Wave-end build:** `chain gate wave` runs `build_cmd` once per wave. After ACs, regressions, browser smoke and the component registry check pass, build and CodeRabbit run concurrently on the same committed HEAD as the last gate phase, so an environmental smoke failure costs no review. The coordinator retains separate logs, waits for both results, then checks findings; either failure blocks. Interruption stops both command groups. Database and browser tests remain sequential.
- **PROJ-end build:** the Quality Gate verifies the assembled PROJ before QA, reusing matching final-wave build evidence only when declared artifacts and inputs remain valid.

If the wave gate finds a build failure, dispatch a fix worker with the verbatim compiler output, then rerun the gate.

### 6. Write learnings to `agent.md`

After a wave worker completes or a recovery stage exposes a durable learning, write it to the source folder's `agent.md`. Include:
- Walls hit and how they were bypassed
- Surprising behavior in the framework/DB/tooling
- Patterns that worked well
- Dead ends (so future agents don't repeat them)

### 7. Wave review with CodeRabbit CLI

<HARD-GATE>
CodeRabbit is MANDATORY, except when `wave-gate-config.json` sets `coderabbit.enabled=false`. It is run by `chain gate wave`, not as a separate pre-gate command. Do NOT run a second per-wave review outside the gate, and do NOT substitute a manual review for a disabled CodeRabbit.
If CodeRabbit fails to execute (e.g., not installed, auth error), the gate exits non-zero. Fix the tool/auth problem and rerun the gate.
</HARD-GATE>

The single wave-gate invocation in Step 8 runs CodeRabbit on the wave's changes. This section describes its review requirements; do not invoke the gate here.

The base commit must be either `WAVE_BASE_SHA` or tag `wave-${WAVE}-start-PROJ-${PROJ}`. Missing base = hard fail. No fallback is allowed.

**How to handle findings:**
- Each gate attempt retains `coderabbit-wave-<N>-attempt-<M>.jsonl` and its normalized sibling; never overwrite earlier review evidence.
- Any cumulative open ledger severity not listed in the wave's `advisory_severities` blocks. Fix immediately — spawn a fix teammate before the next wave.
- Listed advisory severities are logged by CodeRabbit output and revisited at the PROJ-end Quality Gate if still relevant.

**Log in progress.md:**
```markdown
### CodeRabbit Review
- Command: `coderabbit review --agent --base-commit $WAVE_BASE_SHA`
- Result: [PASS / findings found / ERROR with reason]
- Critical/High: [N found, N fixed]
- Medium/Low: [N logged for Quality Gate]
```

Update `$WAVE_BASE_SHA` to the current commit after the wave review passes.

### 7b. Browser smoke test (if wave touched frontend)

Scenario authoring must already be complete via the Step 4 closure checklist.
This step verifies coverage; it does not create missing scenarios.

**Skip this step if the wave only contained backend-implementer teammates.**

Browser smoke testing is owned by `chain gate wave`. It reuses a matching reachable server or starts `frontend.dev_cmd`, waits for readiness, logs its output, and stops only the process it started. It then runs `agent-browser` to verify URL and characteristic content. Redirects are failures; protected routes require `auth_state` or authenticated E2E coverage.

```bash
# The lead owns this server for the wave; do not start or stop another one.
agent-browser open http://localhost:3000/[route-affected-by-wave]
agent-browser read
agent-browser errors
```

For multiple pages affected by the wave, run one `agent-browser` call per route.

**Pass criteria:** Anonymous routes keep the expected URL and characteristic text. Protected routes supply `auth_state`, or current-wave AC/regression commands provide equivalent authenticated E2E coverage through `authenticated_e2e_test_files`. Omit `auth_state` for a covered route to avoid repeating its smoke; retain smoke for routes the scenario does not exercise.
**Fail:** Stop and fix before the next wave — broken UI compounds fast.

Log the result in `progress.md` under the wave section:
```markdown
### Browser Smoke Test
- Pages tested: [list of URLs]
- Result: PASS / FAIL
- Details: [agent-browser output summary]
```

**Why agent-browser as an option?** It runs as a standalone CLI — no MCP context required. This means it can also be delegated to a teammate if needed. Full browser testing is reserved for comprehensive QA in Skill 6.

### 7c. Minimalism Review — Ken Takahashi

<HARD-GATE>
Ken does **not** run per wave. CodeRabbit is the only per-wave review. Ken runs once at PROJ end in Skill 6, after all waves have assembled into a complete feature.
</HARD-GATE>

Do not invoke Ken from Skill 5. Do not create Ken wave BUG IDs or Ken wave backlog sections. If minimalism concerns appear during implementation, write them as normal `agent.md` learnings or progress notes; Skill 6 will review the complete PROJ diff with Ken's PROJ-level lens.

### 8. Mark wave complete, auto-continue to next wave

Run the Wave Gate script once (including the Step 7 review and browser smoke):

```bash
bash scripts/chain gate wave <N> <PROJ-X> <theme>
```

- Exit 0 → script appended `### Wave N Gate — PASSED` block to `progress.md`. Commit the wave. **Immediately proceed to next wave — do NOT pause, do NOT ask the user, do NOT announce "ready for next wave".** The gate already proved the wave is done; the next wave's Step 1 (read dependency map) is the next action.
- Exit 76 / `blocked_external` → retain scope and report the missing external
  prerequisite; resume after it is available. No next-wave certification.
- Other non-zero → read the script's error, fix the failing check (spawn fix teammate if code problem, install missing tool if env problem), re-run.

**No stop between waves.** A PROJ with 5 waves should execute as one continuous run: wave 1 → gate ✓ → wave 2 → gate ✓ → … → wave 5 → gate ✓ → Step 9 Quality Gate. Pausing for user confirmation between waves defeats the wave-gate design — the gate IS the signal.

Manual checklist editing in progress.md is no longer sufficient proof of wave completion — only the script's passed-block counts.

### 9. PROJ Quality Gate (integration only, after all waves)

After all waves for this PROJ-X are complete and their gates passed, run the Quality Gate. It evaluates the assembled cross-wave result; it does not replay wave ACs or replace the wave gates.

See `references/quality-gate.md` for full instructions.

**Order: mutation (when configured) → coverage → Sonar; the integration reviewer runs alongside build and coverage where safe.** Use the command/evidence sequence in `references/quality-gate.md`; keep DB/browser work serialized. Collect every stream before dispatching a combined fix round.

Sonar runs here at PROJ end, with bounded fix/rescans — no wave gate runs it. Skip is allowed
only when the tooling genuinely is not available; `scripts/chain quality seal`
rejects a skip when both CLIs and `sonar-project.properties` are present, so
treat this as required whenever the project is Sonar-configured.

Before launching the Sonar stream, check tool availability:

```bash
command -v sonar >/dev/null && command -v sonar-scanner >/dev/null
```

- If both CLIs are available, run the Sonar quality-gate stream using the `sonar-cli` skill guidance, executing the top-level `sonar_cmd` from `wave-gate-config.json` as the analysis command.
- If either CLI is missing, skip Sonar with `chain quality <X> <theme> skip-sonar 'sonar CLI unavailable'`; the status block then reads `skipped (sonar CLI unavailable)`.

```
Create an agent team for Quality Gate of PROJ-X.

Spawn teammates:
- "reviewer" using the `skillchain-reviewer` agent type (tier 2, read-only) with prompt:
  "Your assignment is in `specs/PROJ-<X>-<theme>/context/roles/wave-<last>/reviewer.md` (the last wave's reviewer file; its content is wave-neutral). Read it completely first. Review criteria: cross-wave contracts, shared state, authorization boundaries and unresolved wave findings; use references/code-reviewer.md only for relevant integration risks. Diff scope: the feature diff from BASE_SHA=$BASE_SHA (`git diff $BASE_SHA..HEAD`). Return findings without starting fixes."
- "sonar" only if `sonar` and `sonar-scanner` are installed, a `general-purpose` spawn (no worker file) using the sonar-cli skill with prompt:
  "Wait for successful current-revision coverage, then run the PROJ Sonar scan through `chain quality <X> <theme> run sonar`, which executes the top-level sonar_cmd from wave-gate-config.json from the persistent PROJ worktree, then use sonar CLI/API for quality gate, issue, coverage, and duplication data. Verify a fresh .scannerwork/report-task.txt after sonar_cmd exits 0 so a silent no-op doesn't read as green. If project Sonar config is absent, record an allowed skip. Return findings to the lead; do not start an independent fix loop."
```

The lead uses `chain quality` to verify build (reusing valid final-wave artifacts), coverage, lint and every `phase_commands` entry marked
`quality` from `wave-gate-config.json` once for the assembled PROJ. CI/nightly
entries are verified as wired to their named workflows, not replayed locally. The lead
consolidates reviewer, build, integration/quality-phase, and Sonar results. Do not rerun `ac_commands`; their canonical proof belongs to wave-scoped Ralph and `chain gate wave`.

**After the reviewer and Sonar report:** triage per `references/quality-gate.md` § Handling findings, then clean up the team.

**Exit criteria:**
- Zero P0/P1 code review findings
- If `mutation_cmd` is configured: mutation evidence is current; survivors after three tests-only rounds are carried forward as bullets under `### Carried Forward (Mutation` in `progress.md`, never blocking (the wrapper must print `Survivors: N`)
- `build_cmd` from `wave-gate-config.json` passes once for the assembled PROJ
- Every `quality` phase command passes once; CI/nightly workflow wiring is verified
- If Sonar ran: zero BLOCKER/CRITICAL/MAJOR sonar issues, or every remaining one is listed by issue key under `### Carried Forward (Sonar` after the 3-round fix loop (at least four recorded scans; carried-forward Sonar issues do not block this gate). Record the saved `sonar list issues` output with `chain quality <X> <theme> sonar-issues 5_progress/<file>` after every scan
- If Sonar was skipped because CLIs or project config were unavailable: the skip is recorded with `skip-sonar` and shows in the status block
- Declared integration/quality-phase tests passing, no new lint errors

Write the findings (tables, Fixed, Deferred, Carried Forward) under the Quality Gate section of `progress.md`; `chain quality` renders its `### Gate Status` block.

## 10. Handoff to Skill 6 (QA)

<HARD-GATE>
Skill 5 stops after implementation, wave gates, and the integration-focused PROJ Quality Gate. **Skill 6 is the mandatory comprehensive QA** with the opposite-provider persona review (Chen/Weber/Sharma/Mueller/Rodriguez/Takahashi) + PROJ Retrospective + AGENTS.md candidate collection.

**Framework runs (state.json exists):** seal the phase first —
`bash scripts/chain quality seal <X> <theme>` MUST exit 0 first, then run
`bash scripts/chain state transition <X> <theme> P5 done`. The phase runner
then starts P6 as fresh lanes (read-only QA finder + P6 controller);
do NOT continue into Skill 6 inside this session, unless the user chose the in-session
driver: then follow `references/in-session-driver.md` (it runs QA as a read-only finder in a subagent and the controller itself).

Before Skill 6 (interactive runs):

1. Run `bash scripts/chain quality seal <X> <theme>`; it rejects missing
   or stale build, test, lint, review, mutation and Sonar evidence, a status block
   that does not match the records, and a Sonar skip when the configured scanner
   was available.
2. Hand off with a context flush: wave plans, agent chatter, Ralph recovery evidence and Quality-Gate output are all on disk in `progress.md`. Tell the user to run `/compact` (or open a fresh session, ideally on a different model than the one that implemented — GPT reviewing Claude-built work or vice versa) and then `/6_qa`, and end the turn. A model cannot compact its own context. Skill 6 follows its own release gate and hands passing or Medium/Low-only work directly to Skill 7.

**Do NOT skip Skill 6.** Step 5 deliberately performs no duplicate QA stage; the persona review and PROJ retrospectives produce `AGENTS.md` candidates and `## PROJ Retrospective` notes that Skill 7 consumes.
</HARD-GATE>

## 11. Final Summary Report

After ALL PROJ-X plans are complete AND Skill 6 has finished, present a combined report:

> "All PROJ-X plans implemented and verified.
>
> ## PROJ-A: [topic]
> Implementation:
> - Wave 1: ✓ (N ACs, recovery stage reached: initial | fix-1 | fix-2 | diagnosis | diagnosis-fix)
> - Wave 2: ✓ (N ACs, recovery stage reached: ...)
>
> Quality Gate:
> - Code Review: X found, X fixed, X deferred
> - SonarCloud: X found, X fixed, X deferred OR skipped (reason)
>
> QA:
> - [N] bugs found, [N] fixed, [N] Medium/Low deferred
> - Production-ready: YES / NO
>
> ## PROJ-B: [topic]
> ...
>
> Learnings documented in `src/features/[feature]/agent.md`.
> Progress logs at `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md`."

---

## Subagent Responsibility (per US)

Each implementation subagent:
1. Reads `agent.md` if provided in the prompt
2. Implements all tasks for its US in order (TDD per task — see below)
3. Reports task status after each TDD cycle; the lead updates `progress.md` and commits for parallel waves
4. Runs one bounded **Inner Ralph self-review** after all tasks complete
5. Reports back with full detail

The subagent does NOT verify ACs — that belongs to the lead's wave-scoped Outer Ralph pass.

### TDD cycle (per task)

No production code without a failing test first.

**RED:** Write one failing test. Run it — verify it fails for the expected reason (missing feature, not import error).

**GREEN:** Write the simplest code to pass. Run ALL tests — new + existing must pass.

**REFACTOR:** Remove duplication, improve names. No new behavior. Re-run tests.

Never claim a test passes without running the command and reading actual output.

### Inner Ralph self-review (one bounded pass, after all tasks in US)

```
review the completed story once for:
  - task/spec compliance
  - error handling, type safety, test quality, and architecture
fix confirmed issues within the worker's ownership
run targeted tests once after the fixes
report any unresolved issue to the lead; do not start another self-review cycle
```

Escalate to main agent only if a fix requires spec/architecture changes.

---

## When Something Breaks

Do NOT guess. Follow `references/debugging.md`:

**Phase 1 — Root Cause Investigation:**
1. Read the full error message and stack trace — not a summary
2. Reproduce the failure consistently
3. Check `git diff` — what changed since it last worked?
4. Trace data flow from input to failure point

**Phase 2 — Hypothesis and Fix:**
1. Form ONE hypothesis, test with the smallest possible change
2. Write a failing test reproducing the bug, then fix
3. Run ALL tests — the fix must not introduce regressions

**Bounded recovery:** Wave AC failures use exactly the four Outer Ralph recovery stages in Step 4. Other repeated implementation failures use the existing blocked/escalation path with full attempt history.

**Always write the wall + workaround to `agent.md` when you find one.**

**Escalate to user if:**
- Wave-scoped Outer Ralph exhausted both normal fixes, fresh diagnosis, and the diagnosis-driven implementation
- Root cause is in the spec or architecture
- Missing dependency, broken environment, external service down
- Requirements are ambiguous or contradictory

---

## Commit Format

```
feat(PROJ-<X>-PRD-<Y>): implement [US-N task name]
fix(PROJ-<X>-PRD-<Y>): address review findings for [US-N]
fix(PROJ-<X>): address quality gate findings
```

Legacy PROJ folders: see `0_chain-guide/references/legacy-layout.md`.
