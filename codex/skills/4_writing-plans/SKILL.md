---
name: writing-plans
description: "Create wave-based implementation plans from architecture + PRDs. One plan file per wave. Use when: (1) the PROJ architecture is approved and PRDs exist, (2) user stories across PRDs need to be grouped into parallel execution waves, (3) before any code is written. Not for: high-level design (use architecture), requirements gathering, or direct implementation."
---

# Writing Plans

## External handoff inputs (conditional)

In external mode, replace local PRD globs in cross-review command examples with the manifest and all referenced scoped baseline/response/engineering inputs; follow `cross-review`'s external-ground-truth rules. Do not execute an absent `2_PRDs/` glob as if it covered the external baseline.

For `external-handoff.json`, read [the receiving input contract](../2e_handoff-refinement/references/input-contract.md) before extracting stories. Use its resolved inventory in the existing gates instead of requiring locally authored PRDs. The local-only extraction/repair directions below do not authorize rewriting received files: route product gaps to `handoff-refinement`, and product-owned revisions to `review-reconcile`.

Preserve source IDs and AC text verbatim; use explicit local story/AC aliases from the inventory and keep engineering criteria separately identified. Plan only the selected repository's assigned scope. Record pinned external dependencies, ownership, integration tests and release ordering; check aggregate source coverage in the coordination location instead of duplicating every product requirement into every repo. Carry approved responses and engineering constraints into worker context. Optional declared engineering stories use `PROJ-<X>-ENG-US-<N>` with `ENG-AC-*` criteria and normal task/test/gate mappings; include their prerequisites in the same wave graph. Keep a technical task inside its product story when it has no independently verifiable outcome. Route missing or incorrectly split engineering stories back to `handoff-refinement`, not product PRD authoring. New or changed inputs invalidate affected plans/reviews and compiled contexts; reconcile and rerun gates before handoff. Existing linear plans need no new manifest or approval.

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


## Session Boundary

Through Step 4, each producing skill runs in its own user-started session.
Complete this skill's checks, automatic cross-review, reconciliation and required
user review here, then stop at the handoff. Do not invoke the next producing
skill, including a prerequisite or another PROJ, in this session. Internal
helpers and cross-review remain in this session. `/compact` is not a new session.
End with a copyable start prompt naming the next skill, workspace, PROJ (if any),
actual input artifact paths and any blockers. The next session reads those
artifacts rather than relying on chat history. Do not create a separate session-context file.
If blocked, name the owning skill and issue in the prompt; do not claim readiness.
If the track is complete, report completion without inventing a next step.


Turn the PROJ architecture + all PRDs into **one plan file per wave** plus `wave-gate-config.json`. A wave is a set of user stories (possibly across PRDs) that can run in parallel. Plans say WHAT and in what order; workers derive HOW. DRY, YAGNI, TDD, frequent commits.

## Inputs

All under `specs/PROJ-<X>-<theme>/`:

| Source | Owns |
|---|---|
| `3-4_plan/PROJ-<X>-architecture.md` | cross-cutting decisions (data model, tech, dependencies) |
| `2_PRDs/PROJ-<X>-PRD-*.md` | user stories and ACs |
| `1d_prototypes/implementation-handoff.md` (UI PROJs) | project mode, reuse, new component candidates, tokens, interaction contract, mockup tolerance |
| `3-4_plan/PROJ-<X>-migration-design.md` (if present) | migration SQL/trigger detail — cite by decision, never copy |

Before processing the inputs, run both structure gates:

```bash
bash ~/.codex/skills/5_executing/scripts/chain check prds specs/PROJ-<X>-<theme>/2_PRDs
bash ~/.codex/skills/5_executing/scripts/chain check architecture \
  specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md \
  specs/PROJ-<X>-<theme>/2_PRDs
```

Failure blocks planning. Return malformed inputs to the owning skill and its
review, then repeat these checks. Older documents need their missing fields
corrected explicitly; no automatic rewrite or bypass.

Also read the feature's `agent.md` (e.g. `src/features/<feature>/agent.md`) if present and carry its gotchas into tasks. For any UI work (`frontend.routes` or frontend-implementer tasks), regenerate the component registry first — even on greenfield, where it writes an empty one:

```bash
bash scripts/chain render registry
# nested app root: bash scripts/chain render registry <app> --out docs/components.md
```

`docs/components.md` is generated from code; fix undocumented components in the code, never in the registry.

**Sibling PROJs:** plan only the current PROJ's stories. Siblings are prerequisites, external contracts, or future dependents — no waves for them. If a prerequisite sibling is incomplete, mark dependent stories blocked and don't plan those waves. Shared design language may be referenced, but UI tasks map to current-PROJ PRDs and mockups.

## Workflow

### 1. Extract stories

Extract every user story and AC verbatim. IDs: story `PROJ-<X>-PRD-<Y>-US-<Z>`, criterion `PROJ-<X>-PRD-<Y>-US-<Z>-AC-<N>` (globally unique; `<N>` is the AC number in the PRD, never a renumbering). The AC wording in the plan is an exact copy of the PRD entry, taken from the word after the checkbox and `AC-<N>:` prefix. `chain check plan` compares it against `2_PRDs/` and fails on any deviation or missing PRD entry, provided `2_PRDs/` exists in the project (without the folder, i.e. a legacy project, it only prints a note and compares nothing); only line endings, trailing whitespace per line and blank lines at the end of the AC are ignored. A multi-line AC runs until the next AC line, a heading, `---` or a label line (`**Smoke Test:**` and the like); indented code blocks belong to the AC. Fix a wrong AC in the PRD (via `requirements-engineer`), never in the plan. Check the codebase for relevant files, patterns, and conventions.

### 2. Build the dependency graph and waves

All stories from all PRDs go into one graph; cross-PRD edges are allowed. A wave = stories with no mutual dependency whose prerequisites are complete.

- **Vertical stories.** Each story must yield one independently verifiable outcome through every layer it needs. Schema/API/UI are tasks within a story, not separate stories. Backend-only and enabling stories qualify when their contract is testable. A story with no standalone verifiable outcome goes back to `requirements-engineer` (plus its PRD cross-review, then re-check affected architecture). Never silently change PRD text.
- **Wide migrations** without a useful vertical slice: `expand → migrate (bounded batches, explicit blocking edges) → contract`. Missing stories/ACs for those stages go back to `requirements-engineer`; never invent plan-only stories. Every wave must still pass its AC and regression gates — if intermediate waves can't stay green, return to `architecture` (and its cross-review); never waive the gate.
- **The plans are the wave shape.** Step 5's lead reads each plan's `## User Stories in this Wave` table and `## Execution` block through `chain render slice` (the table as JSON through `chain check plan --stories <plan>`); never copy the shape into another file.
- **`**PRDs involved:**` is machine-read.** The context compiler puts only the architecture decisions whose `Affects` names one of these PRDs into the wave's worker files, so list every PRD that owns a story in the wave.
- Put the dependency analysis into the Wave 1 plan as a reference.

### 3. Write one plan per wave

Each task = one testable, committable unit of behaviour, nested under its story, described as behaviour to test (not test code). Foundational work (schema, routing) goes to the earliest story that needs it. Save to `3-4_plan/PROJ-<X>-wave-<N>-plan.md`:

````markdown
# PROJ-<X> Wave <N> Implementation Plan

**Goal:** [one sentence]
**Architecture Reference:** `3-4_plan/PROJ-<X>-architecture.md`
**PRDs involved:** PROJ-<X>-PRD-1, PROJ-<X>-PRD-2, …

## Wave Position
- **Previous waves:** Wave <N-1> — [completed / in progress]
- **Next waves:** Wave <N+1>, … (depend on this wave)

## User Stories in this Wave

| US ID | Scope | Agent Type | Complexity | Can start when |
|---|---|---|---|---|
| PROJ-<X>-PRD-1-US-1 | backend | backend-implementer | sonnet | immediately |
| PROJ-<X>-PRD-2-US-1 | backend | backend-implementer | opus (migration) | immediately |

## Execution
- **Mode:** `parallel` | `sequential`
- **Runtime constraints:** `none` | [shared process / external mutable service / test harness, and its owner]

---

## PROJ-<X>-PRD-1-US-1: [verbatim from PRD]
**Scope:** backend → backend-implementer
**Split:** `none` | `contract` | `fan-out` [+ disjoint file sets when not `none`]

**Acceptance Criteria:**
- [ ] PROJ-<X>-PRD-1-US-1-AC-1: [exact PRD wording]

**Smoke Test:** (frontend/full-stack only)
- Route: `/path`
- Verify: "[what agent-browser checks]"

**UI Implementation Notes:** (frontend/full-stack only)
- Project mode: greenfield | brownfield | hybrid
- Mockup reference: [screen/source + preview location from implementation-handoff.md]
- Selected direction: [from Visual Companion / handoff]
- Reuse: [handoff + `docs/components.md`]
- Create new: [candidates + one-line justification]
- Design tokens: [tokens/fonts/spacing to preserve]
- Interaction contract: [panels/modals/drawers/tabs/states/responsive]
- Implementation tolerance: existing app components and tokens beat mockup approximations; keep the selected layout direction.

### Task PROJ-<X>-PRD-1-US-1-T1: [Component Name]
**Fulfills:** PROJ-<X>-PRD-1-US-1-AC-1

**Files:**
- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts`
- Test: `tests/exact/path/to/test.ts`

**Gate commands:**
- `PROJ-<X>-PRD-1-US-1-AC-1`: `npm test -- tests/exact/path/to/test.ts`

**What to build:** [1-2 sentences, observable behaviour, concrete inputs/outputs]

**Components:** (UI tasks only)
- Reuse: [from registry]
- Create new: [name — semantic neighbours checked and why none fit, e.g. `PriceBadge — Badge is status-only, Chip is interactive; no monetary primitive`]

**UI handoff constraints:** (UI tasks only)
- Follow: [handoff interaction/tokens/reuse notes]
- May approximate: [non-pixel-perfect details]
- Must not change without user approval: [layout direction / interaction container]

**TDD cycle:**
- RED: test that [observable behaviour]
- GREEN: implement [minimal thing]
- REFACTOR: [concern, or "standard cleanup"]
- COMMIT: `feat(PROJ-<X>-PRD-1): implement [task name]`

> ⚠️ **Gotcha:** [only from agent.md]

### Post-Wave Notes (reserved for documentation harvest)
- Deviations from plan: —
- Surprising gotchas: —
- New dependencies: —
````

Field rules:
- **Complexity** (Skill 5 picks the model from it): `sonnet` by default — CRUD, forms, straightforward components/routes/services, test-only refactors, polish. `opus` for architecture-sensitive work — state machines, concurrency, cross-feature contracts, DB migrations, auth/session, money, crypto. Name the reason when not obvious. No haiku.
- **Execution mode:** `parallel` only with no dependency **and** no shared runtime hazard; `sequential` when stories contend on a dev server/port, hosted DB or other mutable service, browser profile, cache, or shared harness. Runtime constraints name the owner; file contact stays in the cross-US note. `Execution`, not `Can start when`, decides concurrent dispatch.
- **DB/browser isolation:** state the real fixture namespace and lock layer, not just the tool. Prefer run/scenario/retry-scoped projects and row IDs over one shared mutable fixture where RLS, global state, and teardown allow. Remote browser fixtures are committed and cleaned up, never hidden in an outer rollback. Plan a small isolation proof before parallelizing an existing shared harness. Independent lifecycles may use `chain worktree with-shared-lock --shared`; migrations/resets and overlapping fixtures stay exclusive on the same lock file. Budget lock wait separately from test time; measure browser startup before proposing session reuse. See executing's `references/worker-lifecycle.md`.
- **`Agent Type` decides the worker context.** Step 5 compiles one worker file per story, with the role rules and project context of the role named in this column; the lead spawns that role. Use the canonical names `implementer` (full-stack), `frontend-implementer`, `backend-implementer` — exactly one per story, no `A then B` or `A + B`: a story that needs both a backend and a frontend worker is `Split: contract` instead. One table row per story, and the row and the story section must agree: `Scope` (table vs `**Scope:**`), the `→ agent` in `**Scope:**`, and `Split` (`contract` contradicts a single-sided `frontend` or `backend` scope). A missing, duplicate, or unsupported entry stops `compile` and `check` with exit 2, naming the story and plan file.
- **Split:** `contract` = full-stack story split into backend + frontend workers against the wave's section in `api-contracts.md`; `fan-out` = same-shaped units over disjoint files, parallelized after the first unit exists.
- **`api-contracts.md`** (this skill writes it, at `specs/PROJ-<X>-<theme>/api-contracts.md`): required for every `contract` split and for parallel stories that share an interface. One `## Wave <N>: <interface>` section per wave — request/response shape, who implements and who consumes, error cases; no code. The bundle compiler injects only the sections whose heading names the running wave, so a contract outside such a heading reaches no worker.
- **Libraries:** a task that implements a capability listed in the architecture's `## Dependencies` names the coverage recorded there (package, existing code or platform feature) in its GREEN step; plan a hand-built version only where that section records it as hand-built. A generic capability that section does not cover goes back to `architecture`.
- **Post-Wave Notes** stay empty — Skill 7 fills them after QA.
- **Commits:** `feat(PROJ-<X>-PRD-<Y>): implement [task name]`, Y = the task's story's PRD.

### 4. Write `wave-gate-config.json`

Write `3-4_plan/wave-gate-config.json` from the example and judgment rules in [references/wave-gate-config.md](references/wave-gate-config.md). The validator enforces structure. The optional `coderabbit: { "enabled": false }` switch (default on; it turns the wave gate's automatic CodeRabbit review off) is documented there: never set it on your own, only when the user explicitly asks for it.

### 5. Self-review and validate

Run the validator first — it checks plan/config structure, AC↔task↔command↔test mapping, AC wording against the PRDs, task length, literal SQL/DDL, and narrated-diff text. Failure blocks review and handoff; re-run after every plan/config change:

```bash
bash ~/.codex/skills/5_executing/scripts/chain check plan \
  specs/PROJ-<X>-<theme>/3-4_plan
bash ~/.codex/skills/5_executing/scripts/chain render context check <X> <theme> --roles-dir ~/.codex/skills/5_executing/manifests/roles
```

The `check` compiles every wave's worker and role files in memory (writes nothing).
Before P0, use the installed role manifests explicitly: project roles may still
await synchronization. A green installed-role check does not authorize implementation;
P0 must reconcile sync conflicts and pass the default project-role check without
`--roles-dir` before execution.
It exits 1 when a role would exceed its budget at P0, and 2 when a story cannot be
assigned a role — fix it now while the architecture is
open: tighten the Summary lines or the verbatim sections, or move a PRD to
another wave. It also fails on a malformed decision or key flow, or one whose PRDs are in no wave; return
that to `architecture`.

Then check with fresh eyes what it can't:

1. No TBD/TODO or "What to build" without concrete inputs/outputs; tasks fit in under an hour.
2. Every story delivers a standalone verifiable outcome. Wide migrations: expand/migrate/contract ordered so each wave stays green.
3. **Story size:** one story = one worker (its tasks may share files, so they never run in parallel). A story ~2× its siblings or >~6 tasks → own wave, or a valid `Split` (`contract` needs `api-contracts.md`; `fan-out` needs named disjoint file sets). Still too big → `requirements-engineer` splits the PRD story (with cross-review), then replan.
4. File paths match the project; each wave can run after its predecessors; same-wave stories touching the same file/module are flagged.
5. Every UI task has `Reuse:`/`Create new:` against a freshly generated registry, with semantic neighbours named (Badge/Chip/Tag, Card/Panel, Drawer/Sheet). Every frontend/full-stack story has UI Implementation Notes and every UI task its handoff constraints.
6. Every plan has `Execution`, a complete `**PRDs involved:**` line, and every story the empty Post-Wave Notes block.
7. **Platform authority:** each deployment/platform value (region, runtime, API feature, env setting) names the platform query, CLI, or deployment response that validates it. A mutating command (e.g. `config:push`) is not verification unless it reads back and compares.

Fix plan-only issues inline and re-validate; return PRD or architecture defects to their owning skill and its cross-review before regenerating.

### 6. Cross-review (automatic)

Right after the validator passes, in the same turn and without asking, review the **complete** set:

```bash
bash scripts/chain review plan <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-*-plan.md \
    specs/PROJ-<X>-<theme>/3-4_plan/wave-gate-config.json \
    specs/PROJ-<X>-<theme>/api-contracts.md \
  --ground-truth specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md \
    specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-*.md docs/GUIDELINES.md \
  --author-provider <current-writer> --persist --round 1
```

- Drop paths that don't exist (the script fails on missing files). If the context cap rejects the input, tell the user what you dropped — drop ground truth before any wave plan.
- Follow cross-review's reconcile/re-review loop through round 3 while any findings remain; stop early when clean. Escalate remaining Critical/High before execution; ask only about unresolved product decisions. Manual extra rounds are unlimited.
- `--persist` is required: CP1's fast path reads `.cross_review[]` in state.json and the ledger; without it CP1 always runs the full interactive loop.

### 7. Hand off to Step 5

Present waves, stories per wave, execution mode, and the cross-review result. Don't ask for approval — Checkpoint 1 approves architecture and plans together (auto-approves when both cross-reviews are clean). Then **end the turn** and provide the next-session start prompt. The user opens a new session and invokes **executing-large-model** (5b, the default Step 5), which runs CP1 and P0 through its checkpoint and setup subskills before any implementation. The session boundary adds no new approval gate. Report a blocker instead only if Critical/High findings remain after round 3, a product decision is open, a PRD/architecture handback is unresolved, or the user wants to review the plans first.

Say once, then end the turn:

> "Plans complete in `specs/PROJ-<X>-<theme>/3-4_plan/` (wave plans + `wave-gate-config.json`). Open a new session, then `/5b_executing-large-model` (or `/5_executing` on a weaker model): it runs CP1 and P0 (branch + preflight) through the Step 5 subskills; the setup subskill installs the gate scripts and preflights `jq`, `coderabbit` (unless `coderabbit.enabled=false`), and browser tooling in the PROJ worktree. Quality Gate and QA follow the last wave automatically.
>
> Once P0 is done, Step 5 asks whether to run P5 to a PR unattended or continue interactively."

## Rules

- Exact file paths. Precise behaviour ("reject empty X with 400 and message Y").
- No pre-written test, implementation, or SQL/DDL code — describe it, or cite `migration-design.md` by decision.
- Cite architecture decisions by ID ("per architecture Decision 4"); don't restate rationale.
- ACs must be deterministically verifiable — Ralph runs real test commands.
- Frontend/full-stack stories need a Smoke Test; UI tasks need explicit handoff constraints, not raw mockup interpretation.
- Waves respect the dependency graph, including cross-PROJ prerequisites.

## Git Commit

`docs(PROJ-<X>): Add wave-<N> implementation plan` — one per wave file, or all together.

Legacy PROJ folders: see `0_chain-guide/references/legacy-layout.md`.
