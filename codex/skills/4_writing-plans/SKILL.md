---
name: writing-plans
description: "Create wave-based implementation plans from architecture + PRDs. One plan file per wave. Use when: (1) the PROJ architecture is approved and PRDs exist, (2) user stories across PRDs need to be grouped into parallel execution waves, (3) before any code is written. Not for: high-level design (use architecture), requirements gathering, or direct implementation."
---

# Writing Plans

Turn the PROJ-level architecture + all PRDs into **one plan file per wave**. Each wave contains parallel-executable user stories that may span multiple PRDs. The plan defines WHAT to build and in what order. Subagents derive HOW during execution.

DRY. YAGNI. TDD. Frequent commits.

## Input

Read both sources:
- Architecture: `specs/PROJ-<X>-<thema>/6_plan/PROJ-<X>-architecture.md` (cross-PRD tech design)
- All PRDs: `specs/PROJ-<X>-<thema>/3_PRDs/*.md` (requirements per feature)
- For UI PROJs, UI implementation handoff: `specs/PROJ-<X>-<thema>/5_mockups/implementation-handoff.md`

The architecture is the source of cross-cutting decisions (data model, tech decisions, dependencies). Each PRD is the source of its user stories and acceptance criteria. The UI implementation handoff is the source for project mode, component reuse, new component candidates, design tokens, interaction contract, and mockup tolerance.

## Workflow

### 1. Analyse inputs

- Read architecture file
- Read every PRD in `3_PRDs/`
- If UI work exists, read `5_mockups/implementation-handoff.md` and extract the implementation-facing UI constraints.
- Extract **all** user stories and acceptance criteria verbatim, prefixing with `PROJ-<X>-PRD-<Y>-US-<Z>` for uniqueness
- Check existing codebase for relevant files, patterns, and conventions
- **Check for `agent.md`** in the feature's source folder (e.g., `src/features/[feature]/agent.md`). If it exists, read it — incorporate known gotchas into the relevant tasks as warnings.
- **Component Registry — mandatory for UI waves:** The canonical registry is `docs/components.md`. If the PROJ has any UI work (any wave with `frontend_routes` or frontend-implementer tasks), spawn `component-scout` unconditionally to build/refresh the registry before drafting task descriptions. Greenfield projects with zero components yet: still spawn the scout — it creates the empty registry file so future waves have it. The registry is the source Task-Components-sections draw from.

### 2. Build the PROJ-wide dependency graph

User stories from **all PRDs** go into one dependency graph. Cross-PRD dependencies are allowed (e.g. `PROJ-1-PRD-2-US-1` depends on `PROJ-1-PRD-1-US-1`).

Determine **waves** — groups of user stories that can run in parallel because none of them depend on each other and all their prerequisites are complete.

```
Wave 1: PROJ-<X>-PRD-1-US-1 (backend), PROJ-<X>-PRD-2-US-1 (backend)
  → parallel, no dependencies
Wave 2: PROJ-<X>-PRD-1-US-2 (frontend), PROJ-<X>-PRD-2-US-2 (frontend)
  → depend on Wave 1
Wave 3: PROJ-<X>-PRD-1-US-3 (full-stack)
  → depends on Wave 2
```

Record the dependency analysis — you will put it into the first wave plan as a reference.

### 3. Break each wave into tasks

For each user story in a wave:
- Each task = one testable, committable unit of behaviour
- Tasks nested under the US they implement
- TDD cycle: RED → GREEN → REFACTOR → COMMIT
- Tasks describe behaviour to test, not test code itself
- Foundational tasks (DB schema, routing) belong to the earliest US that needs them

### 4. Write one plan file per wave

Save each wave to `specs/PROJ-<X>-<thema>/6_plan/PROJ-<X>-wave-<N>-plan.md`.

**Template for wave plan file:**

````markdown
# PROJ-<X> Wave <N> Implementation Plan

**Goal:** [One sentence describing what this wave delivers]
**Architecture Reference:** `6_plan/PROJ-<X>-architecture.md`
**PRDs involved:** PROJ-<X>-PRD-1, PROJ-<X>-PRD-2, …

---

## Wave Position

- **Previous waves:** Wave <N-1> — [one-line status: completed / in progress]
- **Next waves:** Wave <N+1>, Wave <N+2> (depend on this wave)

## User Stories in this Wave

| US ID | Scope | Agent Type | Complexity | Can start when |
|---|---|---|---|---|
| PROJ-<X>-PRD-1-US-1 | backend | backend-implementer | sonnet | immediately |
| PROJ-<X>-PRD-2-US-1 | backend | backend-implementer | opus | immediately (parallel to PRD-1-US-1) |

All user stories in a wave run in parallel (unless otherwise noted).

**Complexity column — classification rule (the planner sets this, Skill 5 reads it to choose the Agent model):**
- **`sonnet`** (default): standard feature US — CRUD, form handling, a straightforward component, a well-defined route or service, test-only refactor, copy/UI polish.
- **`opus`**: architecture-sensitive — state machines, concurrency, cross-feature contracts, DB migrations, auth/session logic, money/billing, cryptography, anything where getting the shape wrong is expensive to undo.

When in doubt: **sonnet**. Only escalate to opus with a visible reason (name the concern in a parenthetical if it isn't obvious from the US title). Haiku is not used — too lossy for real US work.

---

## PROJ-<X>-PRD-1-US-1: [Text verbatim from PRD]
**Scope:** backend → backend-implementer

**Acceptance Criteria:**
- [ ] AC-1: [verbatim from PRD]
- [ ] AC-2: [verbatim from PRD]

**Smoke Test:** (only for frontend or full-stack scope — omit for backend-only)
- Route: `/path/to/page`
- Verify: "[what agent-browser should check]"

**UI Implementation Notes:** (only for frontend or full-stack scope)
- Project mode: greenfield | brownfield | hybrid
- Mockup reference: `5_mockups/<file>.html`
- Selected direction: [from Visual Companion / implementation handoff]
- Reuse: [existing components from handoff and `docs/components.md`]
- Create new: [component candidates + one-line justification]
- Design tokens: [tokens/fonts/spacing to preserve]
- Interaction contract: [required panels/modals/drawers/tabs/states/responsive behavior]
- Implementation tolerance: existing React components and design tokens take precedence over exact HTML mockup CSS; preserve selected layout direction.

### Task 1.1: [Component Name]
**Fulfills:** AC-1

**Files:**
- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts`
- Test: `tests/exact/path/to/test.ts`

**What to build:** [1-2 sentences describing observable behaviour]

**Components (UI tasks only — mandatory):**
- Reuse: [list from `docs/components.md` registry, e.g. Button, Card, FormField]
- Create new: [list + one-line justification each, e.g. `PriceBadge — no monetary display primitive exists yet`]

**UI handoff constraints (UI tasks only — mandatory):**
- Follow: [relevant `implementation-handoff.md` interaction/tokens/reuse notes]
- May approximate: [mockup details that need not be pixel-perfect]
- Must not change without user approval: [selected layout direction or interaction container]

**TDD cycle:**
- RED: test that [specific observable behaviour]
- GREEN: implement [the minimal thing]
- REFACTOR: [specific concern if any; else "standard cleanup"]
- COMMIT: `feat(PROJ-<X>-PRD-1): implement [task name]`

> ⚠️ **Gotcha:** [only if agent.md revealed one — otherwise omit]

### Task 1.2: …

### Post-Wave Notes (reserved for documentation harvest)
- Deviations from plan: —
- Surprising gotchas: —
- New dependencies: —

---

## PROJ-<X>-PRD-2-US-1: [Text verbatim from PRD]
…
````

The `Post-Wave Notes` block is a **placeholder the planner reserves** for Skill 7. Do not fill it during planning or execution. Skill 7 harvests documentation inputs from wave plans, `progress.md`, commit messages, package diffs, and `agent.md` after QA passes.

**Commit format per task:** `feat(PROJ-<X>-PRD-<Y>): implement [task name]` — use the PRD-Y of the US the task belongs to.

### 5. Write `wave-gate-config.json`

Alongside the wave plans, write `specs/PROJ-<X>-<thema>/6_plan/wave-gate-config.json`. This config feeds the `wave-gate.sh` script (Skill 5) — machine-readable source of truth for each wave's completion checks.

**Schema:**

```json
{
  "build_cmd": "npm run build",
  "dev_url": "http://localhost:3000",
  "timeouts": {
    "ac_seconds": 300,
    "build_seconds": 600,
    "coderabbit_seconds": 600,
    "browser_seconds": 120
  },
  "waves": {
    "1": {
      "codex_effort": "high",
      "advisory_severities": ["medium", "low"],
      "ac_commands": [
        "npm test -- src/auth/password.test.ts",
        "npm test -- src/auth/session.test.ts"
      ],
      "frontend_routes": []
    },
    "2": {
      "codex_effort": "medium",
      "advisory_severities": ["high", "medium", "low"],
      "ac_commands": [
        "npm test -- src/auth/login.test.ts",
        "npm test -- src/auth/signup.test.ts"
      ],
      "frontend_routes": ["/login", "/signup"]
    }
  }
}
```

**Rules:**
- `build_cmd`: whatever builds the project fully (`npm run build`, `tsc --noEmit`, `cargo build`, etc.)
- `dev_url`: dev server URL for agent-browser smoke tests (default `http://localhost:3000`)
- `timeouts`: required budgets for long-running gate steps. Use seconds. The gate fails if any key is missing:
  - `ac_seconds`: per AC command
  - `build_seconds`: full project build
  - `coderabbit_seconds`: per-wave CodeRabbit review
  - `browser_seconds`: per route smoke test
- `ac_commands[]`: one shell command per AC that exits 0 on pass, non-zero on fail. **Each AC in the wave must map to exactly one command.** The `wave-gate.sh` script runs them in order; first failure blocks.
- `frontend_routes[]`: URLs touched by the wave. Empty array = backend-only wave → smoke test skipped. Each listed route is gut-checked via `agent-browser`.
- `advisory_severities`: required list of CodeRabbit severities that do **not** block the wave. Any finding whose normalized severity is not listed blocks.
  - Use `["medium", "low"]` for normal or risky waves. Critical/High/Error/Blocker findings block.
  - Use `["high", "medium", "low"]` only for low-risk polish/doc/test-only waves where High findings can be deferred to the PROJ-end Quality Gate.
  - Never list `critical`, `blocker`, or `error` unless the user explicitly accepts that risk for this wave.
- `codex_effort`: `"minimal" | "low" | "medium" | "high" | "xhigh"` — reasoning effort for Codex-backed PROJ-end reviewers or rescue work if invoked. Default: `"high"` for normal/risky waves, `"medium"` for low-risk polish waves. Optional — omit to accept the default.

The test commands here are the **same commands** Ralph will run during execution — keep them in sync with the Smoke Test and AC sections of the wave plans.

### 6. Plan Self-Review

After writing all wave files, review them with fresh eyes:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete descriptions, vague behaviour?
2. **AC coverage:** Every AC from every PRD is covered by at least one task across the waves?
3. **Task decomposition:** Each task completable in under an hour?
4. **Type consistency:** File paths match the project structure?
5. **Dependency check:** Can each wave actually run after its predecessors?
6. **No vague instructions:** Every "What to build" has concrete inputs/outputs?
7. **Cross-PRD consistency:** If two user stories in the same wave touch the same file/module, is that flagged?
8. **Post-Wave Notes placeholder:** Every US has the empty `### Post-Wave Notes` block for Skill 7's documentation harvest.
9. **Components-section complete:** every UI task declares `Reuse:` and `Create new:` (with 1-line justification per new). Registry `docs/components.md` is up-to-date via `component-scout`.
10. **UI handoff propagated:** every frontend/full-stack US includes UI Implementation Notes from `5_mockups/implementation-handoff.md`; every UI task carries the relevant constraints.

Fix issues inline. Move on.

**Config consistency check:** `wave-gate-config.json` has one entry per wave, every wave has at least one `ac_commands`, all four `timeouts` keys are present, `advisory_severities` never includes `critical`/`blocker`/`error` without explicit user approval, and `frontend_routes` only set for waves that touch UI. Mismatch here will block execution.

### 7. User Review

Present all wave plans for approval. Adjust if needed.

## Rules

- Exact file paths always
- Describe behaviour precisely ("reject input where X is empty, return 400 with message Y")
- No pre-written test or implementation code — that belongs to the teammate/subagent
- DRY, YAGNI, TDD, frequent commits
- Every frontend or full-stack US must include a **Smoke Test** section with route + verification. Backend-only US omit this.
- ACs must be deterministically verifiable — Ralph loop checks each AC with actual test commands.
- Every task must map to at least one AC.
- Waves must respect the dependency graph: no US in wave N+1 depends on a US in wave N that hasn't completed.
- Frontend/full-stack tasks must not rely on raw HTML mockup interpretation alone; they must include the explicit UI handoff constraints.

## Execution Handoff

After saving all wave plans + the gate config:

> "Plans complete. Files in `specs/PROJ-<X>-<thema>/6_plan/`:
> - `PROJ-<X>-architecture.md`
> - `PROJ-<X>-wave-1-plan.md`, `PROJ-<X>-wave-2-plan.md`, …
> - `wave-gate-config.json` (machine-readable Wave Gate)
>
> **Before executing:** ensure `scripts/wave-gate.sh` exists in the project root. If missing, copy from `~/.codex/skills/5_executing/scripts/wave-gate.sh` and commit (`chmod +x` required). Also install `jq`, `coderabbit`, `agent-browser` if missing — the script needs them.
>
> Ready to execute! Use the **executing skill** (`/5_executing`) to implement wave by wave.
> It will read wave plans in order, spawn subagents per US, verify ACs with Ralph loops, run `wave-gate.sh` between waves, and track progress in a single `7_progress/PROJ-<X>-progress.md`.
>
> **After the last wave:** Skill 5 Step 9 (Quality Gate: code-reviewer-gate + sonar-scanner-gate in parallel) runs automatically, then hands off to Skill 6 (QA: 5-persona panel + Playwright). No Quality Gate / QA text needs to live in the wave plans — the skills own those stages."

## Git Commit

```
docs(PROJ-<X>): Add wave-<N> implementation plan
```

One commit per wave file. All wave files for a PROJ can be committed together or individually — your choice.
