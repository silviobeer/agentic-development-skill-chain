---
name: writing-plans
description: "Create wave-based implementation plans from architecture + PRDs. One plan file per wave. Use when: (1) the PROJ architecture is approved and PRDs exist, (2) user stories across PRDs need to be grouped into parallel execution waves, (3) before any code is written. Not for: high-level design (use architecture), requirements gathering, or direct implementation."
---

# Writing Plans

Turn the PROJ architecture + all PRDs into **one plan file per wave** plus `wave-gate-config.json`. A wave is a set of user stories (possibly across PRDs) that can run in parallel. Plans say WHAT and in what order; workers derive HOW. DRY, YAGNI, TDD, frequent commits.

## Inputs

All under `specs/PROJ-<X>-<theme>/`:

| Source | Owns |
|---|---|
| `3-4_plan/PROJ-<X>-architecture.md` | cross-cutting decisions (data model, tech, dependencies) |
| `2_PRDs/*.md` | user stories and ACs |
| `1d_prototypes/implementation-handoff.md` (UI PROJs) | project mode, reuse, new component candidates, tokens, interaction contract, mockup tolerance |
| `3-4_plan/PROJ-<X>-migration-design.md` (if present) | migration SQL/trigger detail — cite by decision, never copy |

Also read the feature's `agent.md` (e.g. `src/features/<feature>/agent.md`) if present and carry its gotchas into tasks. For any UI work (`frontend.routes` or frontend-implementer tasks), regenerate the component registry first — even on greenfield, where it writes an empty one:

```bash
node scripts/gen-component-registry.mjs
```

`docs/components.md` is generated from code; fix undocumented components in the code, never in the registry.

**Sibling PROJs:** plan only the current PROJ's stories. Siblings are prerequisites, external contracts, or future dependents — no waves for them. If a prerequisite sibling is incomplete, mark dependent stories blocked and don't plan those waves. Shared design language may be referenced, but UI tasks map to current-PROJ PRDs and mockups.

## Workflow

### 1. Extract stories

Extract every user story and AC verbatim. IDs: story `PROJ-<X>-PRD-<Y>-US-<Z>`, criterion `PROJ-<X>-PRD-<Y>-US-<Z>-AC-<N>` (globally unique). Check the codebase for relevant files, patterns, and conventions.

### 2. Build the dependency graph and waves

All stories from all PRDs go into one graph; cross-PRD edges are allowed. A wave = stories with no mutual dependency whose prerequisites are complete.

- **Vertical stories.** Each story must yield one independently verifiable outcome through every layer it needs. Schema/API/UI are tasks within a story, not separate stories. Backend-only and enabling stories qualify when their contract is testable. A story with no standalone verifiable outcome goes back to `requirements-engineer` (plus its PRD cross-review, then re-check affected architecture). Never silently change PRD text.
- **Wide migrations** without a useful vertical slice: `expand → migrate (bounded batches, explicit blocking edges) → contract`. Missing stories/ACs for those stages go back to `requirements-engineer`; never invent plan-only stories. Every wave must still pass its AC and regression gates — if intermediate waves can't stay green, return to `architecture` (and its cross-review); never waive the gate.
- **Wave shape.** Implementers never see other waves' plans (`compile-context-bundles.mjs` never-inject list), so append one `## Wave shape` section to `specs/PROJ-<X>-<theme>/architecture-delta.md`: one line per wave — scope, complexity/model, execution mode, dependencies. No task detail. Create the file with just this section if missing.
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
- [ ] PROJ-<X>-PRD-1-US-1-AC-1: [verbatim]

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
- **DB/browser isolation:** state the real fixture namespace and lock layer, not just the tool. Prefer run/scenario/retry-scoped projects and row IDs over one shared mutable fixture where RLS, global state, and teardown allow. Remote browser fixtures are committed and cleaned up, never hidden in an outer rollback. Plan a small isolation proof before parallelizing an existing shared harness. Independent lifecycles may use `worktree.sh with-shared-lock --shared`; migrations/resets and overlapping fixtures stay exclusive on the same lock file. Budget lock wait separately from test time; measure browser startup before proposing session reuse. See executing's `references/worker-lifecycle.md`.
- **Split:** `contract` = full-stack story split into backend + frontend workers against the wave's section in `api-contracts.md`; `fan-out` = same-shaped units over disjoint files, parallelized after the first unit exists.
- **Post-Wave Notes** stay empty — Skill 7 fills them after QA.
- **Commits:** `feat(PROJ-<X>-PRD-<Y>): implement [task name]`, Y = the task's story's PRD.

### 4. Write `wave-gate-config.json`

Write `3-4_plan/wave-gate-config.json` from the example and judgment rules in [references/wave-gate-config.md](references/wave-gate-config.md). The validator enforces structure.

### 5. Self-review and validate

Run the validator first — it checks plan/config structure, AC↔task↔command↔test mapping, task length, literal SQL/DDL, and narrated-diff text. Failure blocks review and handoff; re-run after every plan/config change:

```bash
node ~/.claude/skills/4_writing-plans/scripts/validate-wave-plan.mjs \
  specs/PROJ-<X>-<theme>/3-4_plan
```

Then check with fresh eyes what it can't:

1. No TBD/TODO or "What to build" without concrete inputs/outputs; tasks fit in under an hour.
2. Every story delivers a standalone verifiable outcome. Wide migrations: expand/migrate/contract ordered so each wave stays green.
3. **Story size:** one story = one worker (its tasks may share files, so they never run in parallel). A story ~2× its siblings or >~6 tasks → own wave, or a valid `Split` (`contract` needs `api-contracts.md`; `fan-out` needs named disjoint file sets). Still too big → `requirements-engineer` splits the PRD story (with cross-review), then replan.
4. File paths match the project; each wave can run after its predecessors; same-wave stories touching the same file/module are flagged.
5. Every UI task has `Reuse:`/`Create new:` against a freshly generated registry, with semantic neighbours named (Badge/Chip/Tag, Card/Panel, Drawer/Sheet). Every frontend/full-stack story has UI Implementation Notes and every UI task its handoff constraints.
6. Every plan has `Execution` and every story the empty Post-Wave Notes block; `architecture-delta.md` has `## Wave shape` covering every wave.
7. **Platform authority:** each deployment/platform value (region, runtime, API feature, env setting) names the platform query, CLI, or deployment response that validates it. A mutating command (e.g. `config:push`) is not verification unless it reads back and compares.

Fix plan-only issues inline and re-validate; return PRD or architecture defects to their owning skill and its cross-review before regenerating.

### 6. Cross-review (automatic)

Right after the validator passes, in the same turn and without asking, review the **complete** set:

```bash
bash scripts/cross-review.sh plan <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-*-plan.md \
    specs/PROJ-<X>-<theme>/3-4_plan/wave-gate-config.json \
  --ground-truth specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md \
    specs/PROJ-<X>-<theme>/2_PRDs/*.md docs/GUIDELINES.md \
  --author-provider <current-writer> --persist --round 1
```

- Drop paths that don't exist (the script fails on missing files). If the context cap rejects the input, tell the user what you dropped — drop ground truth before any wave plan.
- Follow cross-review's reconcile/re-review loop through round 3 while any findings remain; stop early when clean. Escalate remaining Critical/High before execution; ask only about unresolved product decisions. Manual extra rounds are unlimited.
- `--persist` is required: CP1's fast path reads `.cross_review[]` in state.json and the ledger; without it CP1 always runs the full interactive loop.

### 7. Hand off to checkpoint

Present waves, stories per wave, execution mode, and the cross-review result. Don't ask for approval — Checkpoint 1 (4a) approves architecture and plans together (auto-approves when both cross-reviews are clean). Invoke **checkpoint** in the same session. Stop instead only if Critical/High findings remain after round 3, a product decision is open, a PRD/architecture handback is unresolved, or the user wants to review the plans first.

Say once before invoking checkpoint:

> "Plans complete in `specs/PROJ-<X>-<theme>/3-4_plan/` (wave plans + `wave-gate-config.json`). For an unattended run say **'continue automatic until delivery, goal is PR draft'**: checkpoint (4a) for CP1, setup (4b) for branch + preflight, then `runner/run-phase.sh auto <X> <theme>` for P5–P8 ending in an open PR and morning report. No other approval stop follows CP1.
>
> Manual path: ensure `scripts/wave-gate.sh` exists (copy from `~/.claude/skills/5_executing/scripts/wave-gate.sh`, `chmod +x`, commit) and `jq`, `coderabbit`, `agent-browser` are installed, then run `/5_executing`. Quality Gate and QA follow the last wave automatically."

## Rules

- Exact file paths. Precise behaviour ("reject empty X with 400 and message Y").
- No pre-written test, implementation, or SQL/DDL code — describe it, or cite `migration-design.md` by decision.
- Cite architecture decisions by ID ("per architecture Decision 4"); don't restate rationale.
- ACs must be deterministically verifiable — Ralph runs real test commands.
- Frontend/full-stack stories need a Smoke Test; UI tasks need explicit handoff constraints, not raw mockup interpretation.
- Waves respect the dependency graph, including cross-PROJ prerequisites.

## Git Commit

`docs(PROJ-<X>): Add wave-<N> implementation plan` — one per wave file, or all together.

## Legacy Folder Layout

Old → current: `2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` · `5_mockups/`, `1d_mockups/` → `1d_prototypes/` · `3_PRDs/` → `2_PRDs/` · `8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` · `7_progress/` → `5_progress/`

If only the legacy folder exists, read from it and keep writing there — never create a second folder. Say once, then continue either way:

> "This PROJ uses the old folder layout (`<old>`). Rename the folders to the current names, or continue with the existing layout?"

Renaming = `git mv` per folder plus updating old paths in the PROJ's own documents; never a precondition.
