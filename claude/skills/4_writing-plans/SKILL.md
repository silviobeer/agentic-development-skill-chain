---
name: writing-plans
description: "Create wave-based implementation plans from architecture + PRDs. One plan file per wave. Use when: (1) the PROJ architecture is approved and PRDs exist, (2) user stories across PRDs need to be grouped into parallel execution waves, (3) before any code is written. Not for: high-level design (use architecture), requirements gathering, or direct implementation."
---

# Writing Plans

Turn the PROJ-level architecture + all PRDs into **one plan file per wave**. Each wave contains parallel-executable user stories that may span multiple PRDs. The plan defines WHAT to build and in what order. Subagents derive HOW during execution.

DRY. YAGNI. TDD. Frequent commits.

## Input

Read both sources:
- Architecture: `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md` (cross-PRD tech design)
- All PRDs: `specs/PROJ-<X>-<theme>/2_PRDs/*.md` (requirements per feature)
- For UI PROJs, UI implementation handoff: `specs/PROJ-<X>-<theme>/1d_mockups/implementation-handoff.md`

The architecture is the source of cross-cutting decisions (data model, tech decisions, dependencies). Each PRD is the source of its user stories and acceptance criteria. The UI implementation handoff is the source for project mode, component reuse, new component candidates, design tokens, interaction contract, and mockup tolerance.

## Decomposed PROJ Handling

Plans are written one PROJ at a time. If the architecture or concept references sibling PROJs:

- Include only current-PROJ user stories in the wave graph.
- Treat sibling PROJs as prerequisites, external contracts, or future dependents.
- Do not create waves for sibling PROJ work in the current PROJ's plan files.
- If a prerequisite sibling is not complete, mark the affected current-PROJ stories as blocked and stop planning those waves until the dependency is resolved.
- Shared design language may be referenced across PROJs, but UI tasks must still map to current-PROJ PRDs and mockups.

## Workflow

### 1. Analyse inputs

- Read architecture file
- Read every PRD in `2_PRDs/`
- If UI work exists, read `1d_mockups/implementation-handoff.md` and extract the implementation-facing UI constraints.
- Extract **all** user stories and acceptance criteria verbatim. Give every story
  the canonical ID `PROJ-<X>-PRD-<Y>-US-<Z>` and every criterion the globally
  unique ID `PROJ-<X>-PRD-<Y>-US-<Z>-AC-<N>`; the text remains verbatim.
- Check existing codebase for relevant files, patterns, and conventions
- **Check for `agent.md`** in the feature's source folder (e.g., `src/features/[feature]/agent.md`). If it exists, read it — incorporate known gotchas into the relevant tasks as warnings.
- **Component Registry — mandatory for UI waves:** The canonical registry is `docs/components.md`, and it is **generated from the code**, not written by hand. If the PROJ has any UI work (any route in `frontend.routes` or frontend-implementer tasks), refresh it before drafting task descriptions:

  ```bash
  node scripts/gen-component-registry.mjs
  ```

  Greenfield projects with zero components yet: run it anyway — it writes an empty registry so later waves have it. If it reports a component without a doc block, that component is undocumented in the code; fix it there, never by editing `docs/components.md`. The registry is the source Task-Components-sections draw from.

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

Save each wave to `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md`.

**Template for wave plan file:**

````markdown
# PROJ-<X> Wave <N> Implementation Plan

**Goal:** [One sentence describing what this wave delivers]
**Architecture Reference:** `3-4_plan/PROJ-<X>-architecture.md`
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

## Execution

- **Mode:** `parallel` | `sequential`
- **Runtime constraints:** `none` | [shared process, external mutable service, or test harness and its owner]

Default to `parallel` only when the stories have no dependency **and** no shared
runtime hazard. Choose `sequential` when they contend on a dev server/port,
hosted database or other mutable external service, browser profile, cache, or
shared test harness. File contact still belongs in the cross-US file-contact
note; runtime constraints are a separate decision and must name the owner.

**Complexity column — classification rule (the planner sets this, Skill 5 reads it to choose the Agent model):**
- **`sonnet`** (default): standard feature US — CRUD, form handling, a straightforward component, a well-defined route or service, test-only refactor, copy/UI polish.
- **`opus`**: architecture-sensitive — state machines, concurrency, cross-feature contracts, DB migrations, auth/session logic, money/billing, cryptography, anything where getting the shape wrong is expensive to undo.

When in doubt: **sonnet**. Only escalate to opus with a visible reason (name the concern in a parenthetical if it isn't obvious from the US title). Haiku is not used — too lossy for real US work.

---

## PROJ-<X>-PRD-1-US-1: [Text verbatim from PRD]
**Scope:** backend → backend-implementer

**Acceptance Criteria:**
- [ ] PROJ-<X>-PRD-1-US-1-AC-1: [verbatim from PRD]
- [ ] PROJ-<X>-PRD-1-US-1-AC-2: [verbatim from PRD]

**Smoke Test:** (only for frontend or full-stack scope — omit for backend-only)
- Route: `/path/to/page`
- Verify: "[what agent-browser should check]"

**UI Implementation Notes:** (only for frontend or full-stack scope)
- Project mode: greenfield | brownfield | hybrid
- Mockup reference: `1d_mockups/<file>.html`
- Selected direction: [from Visual Companion / implementation handoff]
- Reuse: [existing components from handoff and `docs/components.md`]
- Create new: [component candidates + one-line justification]
- Design tokens: [tokens/fonts/spacing to preserve]
- Interaction contract: [required panels/modals/drawers/tabs/states/responsive behavior]
- Implementation tolerance: existing React components and design tokens take precedence over exact HTML mockup CSS; preserve selected layout direction.

### Task PROJ-<X>-PRD-1-US-1-T1: [Component Name]
**Fulfills:** PROJ-<X>-PRD-1-US-1-AC-1

**Files:**
- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts`
- Test: `tests/exact/path/to/test.ts`

**Gate commands:**
- `PROJ-<X>-PRD-1-US-1-AC-1`: `npm test -- tests/exact/path/to/test.ts`

**What to build:** [1-2 sentences describing observable behaviour]

**Components (UI tasks only — mandatory):**
- Reuse: [list from `docs/components.md` registry, e.g. Button, Card, FormField]
- Create new: [list + one-line justification each. The justification must name the semantic
  neighbours checked in the registry and why none fit, e.g. `PriceBadge — checked Badge (status
  only, no numeric alignment) and Chip (removable, interactive); no monetary display primitive exists`]

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

### Task PROJ-<X>-PRD-1-US-1-T2: …

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

Alongside the wave plans, write `specs/PROJ-<X>-<theme>/3-4_plan/wave-gate-config.json`. This config feeds the `wave-gate.sh` script (Skill 5) — machine-readable source of truth for each wave's completion checks.

**Schema:**

```json
{
  "build_cmd": "npm run build",
  "sonar_cmd": "npm run sonar",
  "timeouts": {
    "ac_seconds": 300,
    "ralph_stall_seconds": 300,
    "build_seconds": 600,
    "coderabbit_seconds": 600,
    "browser_seconds": 120
  },
  "auth_provider_rate_limited": true,
  "auth_budget": {
    "preflight_cmd": "npm run auth:budget-check",
    "rate_limit_evidence_cmd": "npm run auth:rate-limit-check",
    "exhausted_exit_code": 75
  },
  "frontend": {
    "dev_cmd": "npm run dev",
    "dev_url": "http://localhost:3000",
    "readiness": {
      "path": "/health",
      "timeout_seconds": 60,
      "interval_seconds": 2
    },
    "routes": [
      {
        "wave": "2",
        "path": "/account",
        "expected_url": "http://localhost:3000/account",
        "expected_text": "Your account",
        "protected": true,
        "auth_state": "tests/e2e/.auth/user.json"
      }
    ]
  },
  "phase_commands": [
    {
      "label": "hosted browser auth regression",
      "phase": "nightly",
      "command": "npm run test:e2e -- tests/e2e/auth.spec.ts",
      "test_files": ["tests/e2e/auth.spec.ts"],
      "auth_consuming": true,
      "workflow_file": ".github/workflows/e2e.yml"
    }
  ],
  "waves": {
    "1": {
      "codex_effort": "high",
      "advisory_severities": ["medium", "low"],
      "ac_commands": [
        {
          "id": "PROJ-1-PRD-1-US-1-AC-1",
          "task": "Task PROJ-1-PRD-1-US-1-T1",
          "command": "npm test -- src/auth/password.test.ts",
          "test_files": ["src/auth/password.test.ts"],
          "auth_consuming": false
        }
      ],
      "regression_commands": [
        {
          "label": "auth regression suite",
          "command": "npm test -- src/auth",
          "test_files": ["src/auth/password.test.ts", "src/auth/session.test.ts"],
          "auth_consuming": false,
          "require_non_empty_selection": true
        }
      ]
    },
    "2": {
      "codex_effort": "medium",
      "advisory_severities": ["high", "medium", "low"],
      "ac_commands": [
        {
          "id": "PROJ-1-PRD-1-US-2-AC-1",
          "task": "Task PROJ-1-PRD-1-US-2-T1",
          "command": "npm test -- src/auth/login.test.ts",
          "test_files": ["src/auth/login.test.ts"],
          "auth_consuming": false
        }
      ],
      "regression_commands": [
        {
          "label": "account component regression",
          "command": "npm test -- src/auth",
          "test_files": ["src/auth/login.test.ts", "src/auth/session.test.ts"],
          "auth_consuming": false,
          "require_non_empty_selection": true
        }
      ]
    }
  }
}
```

**Rules:**
- `build_cmd`: whatever builds the project fully (`npm run build`, `tsc --noEmit`, `cargo build`, etc.)
- `sonar_cmd`: required non-empty project command for the once-per-PROJ Sonar
  scan, run only by the PROJ-end Quality Gate (not by any wave gate). Use the
  repository's real entry point (`sonar-scanner`, an `npm` script, or a
  wrapper) rather than assuming a binary named `sonar` exists.
- `frontend.dev_url`: dev server URL for agent-browser smoke tests (default `http://localhost:3000`)
- `timeouts`: required budgets for long-running gate steps. Use seconds. The gate fails if any key is missing:
  - `ac_seconds`: per AC command
  - `ralph_stall_seconds`: maximum no-progress time for one AC command (optional; defaults to `ac_seconds`)
  - `build_seconds`: full project build
  - `coderabbit_seconds`: per-wave CodeRabbit review
  - `browser_seconds`: per route smoke test
  - `sonar_seconds`: unused by the wave gate; the PROJ-end Quality Gate's Sonar step is not timed from this config
- `ac_commands[]`: one structured object per AC built in this wave. `id` is the unique canonical
  AC ID, `task` exactly matches its stable `### Task ...` heading, `command` is
  exactly the command in that task's `Gate commands` block, and `test_files` is
  the exact set of `Test:` files in that task's `Files` block.
  `auth_consuming` is always an explicit boolean. Use the cheapest deterministic
  proof of the new behavior here; do not replay broad auth or browser suites per
  AC. An auth-consuming wave command is reserved for a story that changes auth
  itself or has no cheaper equivalent proof, and must add a non-empty
  `wave_required_reason`. Each AC maps to exactly one command and one test
  runner; shell-chained commands (`&&`, `||`, or `;`) are rejected. A command must print a recognizable selected-test
  count (`Running N tests`, `Tests N passed`, TAP `# tests N`, or `N passed`);
  zero or unparseable selection blocks even when rc is 0.
- `regression_commands[]`: required, non-empty targeted regression coverage for
  every wave, run after its current AC commands. Each entry has `label`,
  `command`, `test_files`, explicit `auth_consuming`, and optional
  `require_non_empty_selection` (set it to `true` for test runners whose
  selection can silently be empty). Each entry invokes one runner; split
  shell-chained suites into separate entries. Select the smallest suite that covers
  shared behavior actually affected by the wave; do not mechanically repeat every prior
  AC command, auth suite, or the entire E2E inventory. An auth-consuming
  regression needs the same `wave_required_reason` as an AC. Deterministic minimum: a regression
  entry is invalid when its whitespace-normalized `command` and its normalized
  `test_files` set both exactly equal an AC entry. Reusing the same test file is
  allowed when a different command genuinely selects a broader suite.
- `auth_budget`: mandatory whenever any AC or regression command has
  `auth_consuming: true`. `preflight_cmd` is a provider-neutral project hook;
  set `exhausted_exit_code` to `75` by default. A rate-limited hosted-auth project may
  not declare an auth-consuming command without this hook. Set
  `auth_provider_rate_limited: true` for such a project so the validator also
  requires the hook before auth-consuming commands have been added. Such a
  project also supplies `rate_limit_evidence_cmd`: the wave gate runs it after
  a failed auth-consuming command so browser failures can be checked against
  current bucket state or current-attempt server/provider evidence outside the
  test's own output. Exit `0` must print the decisive evidence, exit `1` means
  not rate-limited, and any other exit is infrastructure failure. The hook
  receives `WAVE`, `WAVE_GATE_CONFIG`, `RALPH_STATE`, `AC_ID`, and `AC_LOG`.
  Both hooks must also implement the safe P0 control: when
  `SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1`, `preflight_cmd` reports exhaustion
  without consuming a hosted identity, while `rate_limit_evidence_cmd` exits 0
  and prints simulated decisive evidence.
- `phase_commands[]`: broad checks deliberately kept out of waves. `phase` is
  `quality`, `ci`, or `nightly`; every entry declares `command`, `test_files`,
  and explicit `auth_consuming`. Quality commands run once after all waves.
  CI/nightly commands name the existing `workflow_file` that contains that exact
  command; the validator reads the workflow rather than trusting the path. This is
  where full hosted-auth and Playwright regressions belong. The current wave
  still needs its cheaper AC proof; deferral may not remove coverage.
- `frontend`: omit for a backend-only PROJ. Otherwise provide `dev_cmd`,
  `dev_url`, bounded `readiness`, and route objects. Every route names its
  `wave`, `path`, exact `expected_url`, characteristic `expected_text`, and
  whether it is `protected`. Protected routes require either `auth_state` for
  the smoke or
  `authenticated_e2e_test_files`; every listed E2E file must also occur in the
  same wave's regression `test_files`. An anonymous redirect to login is not
  successful smoke evidence.
- `advisory_severities`: required list of CodeRabbit severities that do **not** block the wave. Any finding whose normalized severity is not listed blocks.
  - Use `["medium", "low"]` for normal or risky waves. Critical/High/Error/Blocker findings block.
  - Use `["high", "medium", "low"]` only for low-risk polish/doc/test-only waves where High findings can be deferred to the PROJ-end Quality Gate.
  - Never list `critical`, `blocker`, or `error` unless the user explicitly accepts that risk for this wave.
- `codex_effort`: `"minimal" | "low" | "medium" | "high" | "xhigh"` — reasoning effort for Codex-backed PROJ-end reviewers or rescue work if invoked. Default: `"high"` for normal/risky waves, `"medium"` for low-risk polish waves. Optional — omit to accept the default.

The test commands here are the **same commands** Ralph will run during execution — keep them in sync with the Smoke Test and AC sections of the wave plans. The plan's `Execution` block, not `Can start when`, decides whether independent stories are dispatched concurrently.

**Legacy migration:** the validator and runtime gate reject string
`ac_commands`. Replace them with structured entries, add the required
regressions/auth metadata, run the validator, and obtain approval again. Never
infer an AC identity from its array index. There is intentionally no automatic migrator: selecting targeted
regressions and identifying auth consumption require planning judgment.

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
9. **Components-section complete:** every UI task declares `Reuse:` and `Create new:`. Registry `docs/components.md` is freshly generated (`node scripts/gen-component-registry.mjs`), and every `Create new:` names the semantic neighbours checked against it (Badge/Chip/Tag, Card/Panel, Drawer/Sheet) and why none fit. A new component without that comparison is an unreviewed duplicate risk — the cheapest place to catch it is here, before anyone writes code.
10. **UI handoff propagated:** every frontend/full-stack US includes UI Implementation Notes from `1d_mockups/implementation-handoff.md`; every UI task carries the relevant constraints.

Fix issues inline. Move on.

**Config consistency check:** every wave plan has an `Execution` block;
`wave-gate-config.json` has one entry per wave; every AC ID occurs exactly once;
every AC names the correct task and command; and its `test_files` equal the
task's `Files: Test:` entries in both directions. Every wave declares at least
one broad regression command. The top-level `sonar_cmd` is non-empty. All
timeout keys, auth-budget hooks, and frontend metadata are complete; protected
routes have authenticated coverage.

Run the deterministic validator after generating or changing any plan/config
artifact. A failure blocks user review and handoff:

```bash
node ~/.claude/skills/4_writing-plans/scripts/validate-wave-plan.mjs \
  specs/PROJ-<X>-<theme>/3-4_plan
```

**Platform-authority check:** for each planned deployment/platform value (region,
runtime, API feature, environment setting), name the platform query, CLI, or
deployment response that will validate it. Do not compare configuration to a
handwritten wish-list, and never call a mutating command such as `config:push`
"verification" unless it reads the deployed value back and compares it.

### 7. User Review

Present all wave plans for approval. Adjust if needed.

Ask the user to review the wave-plan artifacts with a different model before execution, for example GPT reviewing Claude output or Claude reviewing GPT output. The second-model review should look for missing AC coverage, unsafe wave ordering, vague tasks, missing component-reuse constraints, and weak gate commands.

## Rules

- Exact file paths always
- Describe behaviour precisely ("reject input where X is empty, return 400 with message Y")
- No pre-written test or implementation code — that belongs to the teammate/subagent
- DRY, YAGNI, TDD, frequent commits
- Every frontend or full-stack US must include a **Smoke Test** section with route + verification. Backend-only US omit this.
- ACs must be deterministically verifiable — Ralph loop checks each AC with actual test commands.
- Every task must map to at least one AC.
- Waves must respect the dependency graph: no US in wave N+1 depends on a US in wave N that hasn't completed.
- Cross-PROJ prerequisites must be satisfied before scheduling dependent current-PROJ stories.
- Frontend/full-stack tasks must not rely on raw HTML mockup interpretation alone; they must include the explicit UI handoff constraints.

## Execution Handoff

After saving all wave plans + the gate config:

Ask before offering execution: "Shall I run the optional opposite-provider
cross-review of these implementation plans now? Default: yes." Wait for a
yes/no answer. On yes, run it over the complete set of plans — a wave left out
is a wave whose sequencing nobody checked:

```bash
bash scripts/cross-review.sh plan <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-*-plan.md \
    specs/PROJ-<X>-<theme>/3-4_plan/wave-gate-config.json \
  --ground-truth specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md \
    specs/PROJ-<X>-<theme>/2_PRDs/*.md docs/GUIDELINES.md \
  --author-provider <current-writer> --round 1
```

Drop any path that does not exist — the script fails on a missing file. This is
the largest input in the chain, so the embedded-context cap is most likely to
reject it here. Do not silently trim: tell the user which inputs you left out,
and prefer dropping ground truth over dropping a wave plan.
Resolve Critical/High findings with the user before execution. On no, record
that the human declined it.

Once the cross-review is settled (done or declined), say once:

> "Cross-review settled. If you want the rest to run unattended, say
> **'continue automatic until delivery, goal is PR draft'** — that means:
> **checkpoint** (4a) for CP1 approval, **setup** (4b) for branch + preflight,
> then `runner/run-phase.sh auto <X> <theme>` for P5–P8 (execution, QA, docs,
> delivery) ending with the open PR and the morning report. CP1 approval stays
> human — everything after it runs without prompts."

> "Plans complete. Files in `specs/PROJ-<X>-<theme>/3-4_plan/`:
> - `PROJ-<X>-architecture.md`
> - `PROJ-<X>-wave-1-plan.md`, `PROJ-<X>-wave-2-plan.md`, …
> - `wave-gate-config.json` (machine-readable Wave Gate)
>
> **Before executing:** ensure `scripts/wave-gate.sh` exists in the project root. If missing, copy from `~/.claude/skills/5_executing/scripts/wave-gate.sh` and commit (`chmod +x` required). Also install `jq`, `coderabbit`, `agent-browser` if missing — the script needs them.
>
> Ready to execute! Use the **executing skill** (`/5_executing`) to implement wave by wave.
> It will read wave plans in order, spawn subagents per US, verify ACs with Ralph loops, run `wave-gate.sh` between waves, and track progress in a single `5_progress/PROJ-<X>-progress.md`.
>
> **After the last wave:** Skill 5 Step 9 (Quality Gate: code-reviewer-gate + optional sonar-cli stream) runs automatically, then hands off to Skill 6 (QA: six-persona panel + browser testing). No Quality Gate / QA text needs to live in the wave plans — the skills own those stages."

## Git Commit

```
docs(PROJ-<X>): Add wave-<N> implementation plan
```

One commit per wave file. All wave files for a PROJ can be committed together or individually — your choice.

## Legacy Folder Layout

PROJ folders created before the layout rename use different subfolder
names. Mapping, old → current:

`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` ·
`5_mockups/` → `1d_mockups/` · `3_PRDs/` → `2_PRDs/` ·
`8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`

If an expected folder is missing but its legacy twin exists, **read from the
legacy one and keep writing where the existing files already are**. Never
create a second folder next to it — a split PROJ is worse than an old name.
Say it once, then continue either way:

> "This PROJ uses the old folder layout (`<old>`). Rename the folders to the
> current names, or continue with the existing layout?"

Renaming is a `git mv` per folder plus a search for the old paths in the
PROJ's own documents. It is never a precondition for this skill.
